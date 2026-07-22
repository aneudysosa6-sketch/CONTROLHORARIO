import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type,x-device-id,x-device-credential",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
const text = (value: unknown) => typeof value === "string" ? value.trim() : "";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const validEmployeeCode = (value: string) =>
  /^[0-9]{6}$/.test(value) && value !== "000000";
const maskedEmployeeCode = (value: string) =>
  validEmployeeCode(value) ? `****${value.slice(-2)}` : "unassigned";
const validIsoTimestamp = (value: string) =>
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/.test(value);
const validEmbedding = (value: unknown): value is number[] =>
  Array.isArray(value) &&
  value.length === 128 &&
  value.every((item) => typeof item === "number" && Number.isFinite(item));
const hash = async (value: string) =>
  Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
    ),
  ).map((item) => item.toString(16).padStart(2, "0")).join("");

type InitialFaceRpcResult = {
  result?: unknown;
  error_code?: unknown;
  remote_id?: unknown;
  updated_at?: unknown;
  operation_applied?: unknown;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const deviceId = text(request.headers.get("x-device-id"));
    const credential = text(request.headers.get("x-device-credential"));
    if (!uuid.test(deviceId) || !credential) {
      return json({ error_code: "INVALID_DEVICE_CREDENTIAL" }, 401);
    }

    const url = Deno.env.get("SUPABASE_URL");
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !service) throw new Error("SUPABASE_CONFIGURATION_MISSING");
    const admin = createClient(url, service, { auth: { persistSession: false } });
    const now = new Date().toISOString();
    const { data: auth } = await admin.from("credenciales_dispositivo")
      .select("empresa_id")
      .eq("dispositivo_id", deviceId)
      .eq("token_hash", await hash(credential))
      .is("revocado_at", null)
      .gt("expires_at", now)
      .maybeSingle();
    if (!auth) return json({ error_code: "INVALID_DEVICE_CREDENTIAL" }, 401);

    const { data: device } = await admin.from("dispositivos_android")
      .select("sucursal_id,estado")
      .eq("id", deviceId)
      .eq("empresa_id", auth.empresa_id)
      .maybeSingle();
    if (!device || device.estado !== "activo") {
      return json({ error_code: "DEVICE_REVOKED" }, 403);
    }

    const body = await request.json() as { operations?: unknown[] };
    if (!Array.isArray(body.operations) || body.operations.length < 1 || body.operations.length > 20) {
      return json({ error_code: "INVALID_PAYLOAD" }, 400);
    }

    const results: Record<string, unknown>[] = [];
    for (const raw of body.operations) {
      const operationPayload = (raw ?? {}) as Record<string, unknown>;
      const idempotencyKey = text(operationPayload.idempotency_key);
      // En UPDATE el codigo identifica una fila existente. En CREATE cualquier
      // propuesta del dispositivo es solo legacy: Supabase asigna la autoridad.
      let employeeCode = text(operationPayload.employee_code);
      const requestedRemoteId = text(operationPayload.remote_id);
      const name = text(operationPayload.name);
      const operation = text(operationPayload.operation);
      // CREATE usa un UUID estable por operacion. Esto hace idempotente una
      // reserva que haya quedado pendiente si la escritura HTTP se interrumpe.
      const employeeRemoteId = operation === "CREATE"
        ? idempotencyKey
        : requestedRemoteId;
      const embedding = operationPayload.face_embedding;
      const hasEnrollmentMode = Object.prototype.hasOwnProperty.call(
        operationPayload,
        "face_enrollment_mode",
      );
      const enrollmentMode = text(operationPayload.face_enrollment_mode);
      const initialOnly = hasEnrollmentMode && enrollmentMode === "INITIAL_ONLY";
      const validationMode = text(
        operationPayload.face_enrollment_validation_mode,
      ) || text(operationPayload.validation_mode);
      const occurredAt = text(operationPayload.face_enrollment_occurred_at) ||
        text(operationPayload.occurred_at);
      const occurredAtMillis = Date.parse(occurredAt);
      const currentMillis = Date.now();

      console.log("FACE_EMBEDDING_FLOW", {
        stage: "edge_received",
        employeeCode: maskedEmployeeCode(employeeCode),
        present: embedding !== undefined,
        type: Array.isArray(embedding) ? "array" : typeof embedding,
        dimension: Array.isArray(embedding) ? embedding.length : null,
        enrollmentMode: initialOnly ? "INITIAL_ONLY" : "LEGACY",
      });

      const invalidCommon = !uuid.test(idempotencyKey) ||
        !["CREATE", "UPDATE"].includes(operation) ||
        (operation === "UPDATE" &&
          (!uuid.test(requestedRemoteId) || !validEmployeeCode(employeeCode))) ||
        (hasEnrollmentMode && !initialOnly);
      const invalidInitial = initialOnly &&
        (operation !== "UPDATE" ||
          !uuid.test(employeeRemoteId) ||
          !validEmbedding(embedding) ||
          !["ONLINE_VERIFIED", "OFFLINE_CACHED"].includes(validationMode) ||
          !validIsoTimestamp(occurredAt) ||
          !Number.isFinite(occurredAtMillis) ||
          occurredAtMillis > currentMillis + 10 * 60 * 1000);
      const invalidLegacy = !initialOnly &&
        (name.length < 2 ||
          (embedding !== undefined && !validEmbedding(embedding)));
      if (invalidCommon || invalidInitial || invalidLegacy) {
        results.push({
          idempotency_key: idempotencyKey,
          employee_code: employeeCode,
          result: "rejected",
          error_code: "INVALID_PAYLOAD",
        });
        continue;
      }

      if (initialOnly) {
        const { data, error } = await admin.rpc(
          "initial_face_enrollment_internal",
          {
            payload: {
              company_id: auth.empresa_id,
              device_id: deviceId,
              employee_id: employeeRemoteId,
              employee_code: employeeCode,
              face_embedding: embedding,
              idempotency_key: idempotencyKey,
              validation_mode: validationMode,
              occurred_at: occurredAt,
            },
          },
        );
        if (error) {
          console.error("FACE_FIRST_ENROLLMENT", {
            employeeCode: maskedEmployeeCode(employeeCode),
            finalResult: "RPC_ERROR",
            errorCode: error.code ?? "DATABASE_ERROR",
          });
          results.push({
            idempotency_key: idempotencyKey,
            employee_code: employeeCode,
            result: "rejected",
            error_code: error.code || "DATABASE_ERROR",
          });
          continue;
        }

        const rpc = (data ?? {}) as InitialFaceRpcResult;
        const rpcResult = text(rpc.result);
        const errorCode = text(rpc.error_code);
        const remoteId = text(rpc.remote_id);
        const updatedAt = text(rpc.updated_at);
        console.log("FACE_FIRST_ENROLLMENT", {
          employeeCode: maskedEmployeeCode(employeeCode),
          remoteId: remoteId || null,
          remoteEmbeddingDimension: Array.isArray(embedding) ? embedding.length : null,
          finalResult: rpcResult || "INVALID_RPC_RESPONSE",
          errorCode: errorCode || null,
        });
        if (!["accepted", "duplicate", "rejected"].includes(rpcResult)) {
          results.push({
            idempotency_key: idempotencyKey,
            employee_code: employeeCode,
            result: "rejected",
            error_code: "INVALID_RPC_RESPONSE",
          });
          continue;
        }
        results.push({
          idempotency_key: idempotencyKey,
          employee_code: employeeCode,
          result: rpcResult,
          ...(errorCode ? { error_code: errorCode } : {}),
          ...(remoteId ? { remote_id: remoteId } : {}),
          ...(updatedAt ? { updated_at: updatedAt } : {}),
          ...(rpcResult !== "rejected"
            ? { operation_applied: text(rpc.operation_applied) || "UPDATE" }
            : {}),
        });
        continue;
      }

      // El modo INITIAL_ONLY delega este chequeo a la RPC para validar tambien
      // que una clave previa corresponda al mismo employee_code.
      const { data: prior } = await admin.from("employee_upload_idempotency")
        .select("empleado_id,empleados!inner(id,codigo_empleado,updated_at)")
        .eq("empresa_id", auth.empresa_id)
        .eq("idempotency_key", idempotencyKey)
        .maybeSingle();
      if (prior) {
        const employee = (prior as Record<string, unknown>).empleados as
          | Record<string, unknown>
          | undefined;
        results.push({
          idempotency_key: idempotencyKey,
          employee_code: employee?.codigo_empleado ?? employeeCode,
          result: "duplicate",
          remote_id: prior.empleado_id,
          updated_at: employee?.updated_at ?? now,
        });
        continue;
      }

      if (operation === "CREATE") {
        // Si el empleado se escribio pero la fila idempotente no alcanzo a
        // persistirse, se repara sin reservar ni crear otra identidad.
        const { data: existingById, error: existingError } = await admin
          .from("empleados")
          .select("id,codigo_empleado,updated_at")
          .eq("id", employeeRemoteId)
          .eq("empresa_id", auth.empresa_id)
          .maybeSingle();
        if (existingError) {
          results.push({
            idempotency_key: idempotencyKey,
            employee_code: employeeCode,
            result: "rejected",
            error_code: existingError.code || "DATABASE_ERROR",
          });
          continue;
        }
        if (existingById) {
          // A UUID collision without the idempotency row is not proof that this
          // device created the employee. Never bind a local row to that identity.
          results.push({
            idempotency_key: idempotencyKey,
            employee_code: existingById.codigo_empleado,
            result: "rejected",
            error_code: "EMPLOYEE_IDENTITY_COLLISION",
          });
          continue;
        }

        const { data: allocatedCode, error: allocationError } = await admin.rpc(
          "allocate_next_employee_code_internal",
          {
            p_company_id: auth.empresa_id,
            p_employee_id: employeeRemoteId,
          },
        );
        const authoritativeCode = text(allocatedCode);
        if (allocationError || !validEmployeeCode(authoritativeCode)) {
          results.push({
            idempotency_key: idempotencyKey,
            employee_code: employeeCode,
            result: "rejected",
            error_code: allocationError?.message === "EMPLOYEE_CODE_EXHAUSTED"
              ? "EMPLOYEE_CODE_EXHAUSTED"
              : "EMPLOYEE_CODE_ALLOCATION_FAILED",
          });
          continue;
        }
        employeeCode = authoritativeCode;
        console.log("EMPLOYEE_CODE_FLOW", {
          stage: "server_code_allocated",
          employeeId: employeeRemoteId,
          employeeCode: maskedEmployeeCode(employeeCode),
        });
      }

      if (operation === "UPDATE") {
        const existingResult = await admin.from("empleados")
          .select("id,activo,estado_laboral")
          .eq("id", employeeRemoteId)
          .eq("empresa_id", auth.empresa_id)
          .eq("codigo_empleado", employeeCode)
          .maybeSingle();
        if (existingResult.error || !existingResult.data) {
          results.push({
            idempotency_key: idempotencyKey,
            employee_code: employeeCode,
            result: "rejected",
            error_code: existingResult.error?.code || "EMPLOYEE_IDENTITY_MISMATCH",
          });
          continue;
        }
        if (existingResult.data.activo !== true ||
          existingResult.data.estado_laboral !== "activo") {
          results.push({
            idempotency_key: idempotencyKey,
            employee_code: employeeCode,
            result: "rejected",
            error_code: "EMPLOYEE_INACTIVE",
          });
          continue;
        }
      }

      // El dispositivo nunca decide el ciclo laboral. CREATE nace activo y
      // UPDATE conserva activo/estado_laboral remotos; una baja o reactivacion
      // solo puede pasar por las RPC administrativas auditadas.
      const record = {
        empresa_id: auth.empresa_id,
        codigo_empleado: employeeCode,
        nombre_completo: name,
        telefono: text(operationPayload.phone) || null,
        correo: text(operationPayload.email).toLowerCase() || null,
        ...(operation === "CREATE"
          ? { activo: true, estado_laboral: "activo" }
          : {}),
        sucursal_id: device.sucursal_id,
        ...(embedding === undefined ? {} : { face_embedding: embedding }),
      };
      // CREATE nunca puede convertirse en UPDATE por una colision de codigo.
      // UPDATE exige identidad remota y codigo coincidentes; no crea filas.
      const write = operation === "CREATE"
        ? admin.from("empleados").insert({ id: employeeRemoteId, ...record })
        : admin.from("empleados").update(record)
          .eq("id", employeeRemoteId)
          .eq("empresa_id", auth.empresa_id)
          .eq("codigo_empleado", employeeCode)
          .eq("activo", true)
          .eq("estado_laboral", "activo");
      const { data: employee, error } = await write
        .select("id,codigo_empleado,updated_at,face_embedding")
        .single();
      if (error) {
        console.error("FACE_EMBEDDING_FLOW", {
          stage: "edge_upsert_error",
          employeeCode: maskedEmployeeCode(employeeCode),
          errorCode: error.code,
        });
        results.push({
          idempotency_key: idempotencyKey,
          employee_code: employeeCode,
          result: "rejected",
          error_code: operation === "UPDATE" && error.code === "PGRST116"
            ? "EMPLOYEE_INACTIVE"
            : error.code || "DATABASE_ERROR",
        });
        continue;
      }
      console.log("FACE_EMBEDDING_FLOW", {
        stage: "edge_upserted",
        employeeId: employee.id,
        persisted: Array.isArray(employee.face_embedding),
        dimension: Array.isArray(employee.face_embedding)
          ? employee.face_embedding.length
          : null,
      });
      const { error: idempotencyError } = await admin
        .from("employee_upload_idempotency").upsert({
        empresa_id: auth.empresa_id,
        idempotency_key: idempotencyKey,
        empleado_id: employee.id,
        operation,
      }, { onConflict: "empresa_id,idempotency_key" });
      if (idempotencyError) {
        console.error("EMPLOYEE_UPSERT_IDEMPOTENCY", {
          employeeId: employee.id,
          errorCode: idempotencyError.code,
        });
        results.push({
          idempotency_key: idempotencyKey,
          employee_code: employee.codigo_empleado,
          result: "rejected",
          error_code: "IDEMPOTENCY_PERSIST_FAILED",
        });
        continue;
      }
      results.push({
        idempotency_key: idempotencyKey,
        employee_code: employee.codigo_empleado,
        result: "accepted",
        remote_id: employee.id,
        updated_at: employee.updated_at,
        operation_applied: operation,
      });
    }
    return json({ results });
  } catch (error) {
    console.error("EMPLOYEE_UPSERT_ERROR", error);
    return json({ error_code: "EMPLOYEE_UPSERT_ERROR" }, 500);
  }
});
