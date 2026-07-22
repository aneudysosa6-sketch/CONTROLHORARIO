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
const validEmployeeCode = (value: string) => /^[0-9]{5,12}$/.test(value);
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
      const employeeCode = text(operationPayload.employee_code);
      const employeeRemoteId = text(operationPayload.remote_id);
      const name = text(operationPayload.name);
      const operation = text(operationPayload.operation);
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
        employeeCode,
        present: embedding !== undefined,
        type: Array.isArray(embedding) ? "array" : typeof embedding,
        dimension: Array.isArray(embedding) ? embedding.length : null,
        enrollmentMode: initialOnly ? "INITIAL_ONLY" : "LEGACY",
      });

      const invalidCommon = !uuid.test(idempotencyKey) ||
        !validEmployeeCode(employeeCode) ||
        !["CREATE", "UPDATE"].includes(operation) ||
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
            employeeCode,
            finalResult: "RPC_ERROR",
            errorCode: error.code ?? "DATABASE_ERROR",
          });
          results.push({
            idempotency_key: idempotencyKey,
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
          employeeCode,
          remoteId: remoteId || null,
          remoteEmbeddingDimension: Array.isArray(embedding) ? embedding.length : null,
          finalResult: rpcResult || "INVALID_RPC_RESPONSE",
          errorCode: errorCode || null,
        });
        if (!["accepted", "duplicate", "rejected"].includes(rpcResult)) {
          results.push({
            idempotency_key: idempotencyKey,
            result: "rejected",
            error_code: "INVALID_RPC_RESPONSE",
          });
          continue;
        }
        results.push({
          idempotency_key: idempotencyKey,
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
        .select("empleado_id,empleados!inner(id,updated_at)")
        .eq("empresa_id", auth.empresa_id)
        .eq("idempotency_key", idempotencyKey)
        .maybeSingle();
      if (prior) {
        const employee = (prior as Record<string, unknown>).empleados as
          | Record<string, unknown>
          | undefined;
        results.push({
          idempotency_key: idempotencyKey,
          result: "duplicate",
          remote_id: prior.empleado_id,
          updated_at: employee?.updated_at ?? now,
        });
        continue;
      }

      // Flujo legacy/admin: conserva el upsert existente y su capacidad de reemplazo.
      const record = {
        empresa_id: auth.empresa_id,
        codigo_empleado: employeeCode,
        nombre_completo: name,
        telefono: text(operationPayload.phone) || null,
        correo: text(operationPayload.email).toLowerCase() || null,
        activo: operationPayload.active !== false,
        estado_laboral: operationPayload.active === false ? "desvinculado" : "activo",
        sucursal_id: device.sucursal_id,
        ...(embedding === undefined ? {} : { face_embedding: embedding }),
      };
      const { data: employee, error } = await admin.from("empleados")
        .upsert(record, { onConflict: "empresa_id,codigo_empleado" })
        .select("id,updated_at,face_embedding")
        .single();
      if (error) {
        console.error("FACE_EMBEDDING_FLOW", {
          stage: "edge_upsert_error",
          employeeCode,
          errorCode: error.code,
        });
        results.push({
          idempotency_key: idempotencyKey,
          result: "rejected",
          error_code: error.code || "DATABASE_ERROR",
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
      await admin.from("employee_upload_idempotency").insert({
        empresa_id: auth.empresa_id,
        idempotency_key: idempotencyKey,
        empleado_id: employee.id,
        operation,
      });
      results.push({
        idempotency_key: idempotencyKey,
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
