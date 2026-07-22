import { createClient } from "@supabase/supabase-js";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
const text = (value: unknown) => typeof value === "string" ? value.trim() : "";
const scalarText = (value: unknown) =>
  typeof value === "string" || typeof value === "number" || typeof value === "bigint"
    ? String(value).trim()
    : "";
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const normalizeEmployeeCode = (value: unknown): string | null => {
  const candidate = text(value);
  const normalized = /^\d{5}$/.test(candidate) ? `0${candidate}` : candidate;
  return /^\d{6}$/.test(normalized) && normalized !== "000000"
    ? normalized
    : null;
};

type SupabaseClient = ReturnType<typeof createClient>;
type LifecycleResult = {
  id?: unknown;
  perfil_id?: unknown;
  lifecycle_event_id?: unknown;
  auth_ban_event_id?: unknown;
  auth_sync_status?: unknown;
  [key: string]: unknown;
};

type LifecycleEvent = "EMPLOYEE_TERMINATED" | "EMPLOYEE_REACTIVATED";

const lifecycleBanMarker = "employee_lifecycle_ban_event_id";

const authUserIsBanned = (value: unknown) => {
  const bannedUntil = text(value);
  const timestamp = Date.parse(bannedUntil);
  return Number.isFinite(timestamp) && timestamp > Date.now();
};

const objectRecord = (value: unknown): Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value)
    ? { ...(value as Record<string, unknown>) }
    : {};

const transitionLifecycleAuthStatus = async (
  admin: SupabaseClient,
  companyId: string,
  eventId: unknown,
  event: LifecycleEvent,
  expected: string[],
  next: string,
) => {
  const canonicalEventId = scalarText(eventId);
  if (!canonicalEventId) return { status: "", error: new Error("LIFECYCLE_EVENT_ID_REQUIRED") };
  const { data, error } = await admin.rpc(
    "actualizar_auth_sync_ciclo_empleado_internal",
    {
      p_empresa: companyId,
      p_evento_id: canonicalEventId,
      p_evento: event,
      p_expected: expected,
      p_nuevo: next,
    },
  );
  return { status: error ? "" : text(data), error };
};

const lifecycleAccessCanBeRestored = async (
  admin: SupabaseClient,
  companyId: string,
  employeeId: unknown,
  profileId: string,
) => {
  const canonicalEmployeeId = text(employeeId);
  if (!uuid.test(canonicalEmployeeId) || !uuid.test(profileId)) {
    return { restorable: false, error: null };
  }
  const employeeResult = await admin.from("empleados")
    .select("id,perfil_id,activo,estado_laboral")
    .eq("empresa_id", companyId)
    .eq("id", canonicalEmployeeId)
    .maybeSingle();
  if (employeeResult.error) return { restorable: false, error: employeeResult.error };
  const employee = employeeResult.data;
  if (!employee || employee.perfil_id !== profileId || employee.activo !== true ||
    employee.estado_laboral !== "activo") {
    return { restorable: false, error: null };
  }
  const profileResult = await admin.from("profiles")
    .select("id,status,access_deleted_at")
    .eq("company_id", companyId)
    .eq("id", profileId)
    .maybeSingle();
  if (profileResult.error) return { restorable: false, error: profileResult.error };
  return {
    restorable: profileResult.data?.status === "inactive" &&
      profileResult.data.access_deleted_at == null,
    error: null,
  };
};

const syncTerminationAuth = async (
  admin: SupabaseClient,
  companyId: string,
  lifecycle: LifecycleResult,
) => {
  const profileId = text(lifecycle.perfil_id);
  const eventId = lifecycle.lifecycle_event_id;
  const marker = scalarText(eventId);
  let status = text(lifecycle.auth_sync_status);
  if (!profileId || !marker || [
    "NOT_APPLICABLE", "BAN_APPLIED", "PREEXISTING_BAN_PRESERVED",
    "AUTH_USER_NOT_FOUND",
  ].includes(status)) return status || "NOT_APPLICABLE";
  if (!["PENDING_BAN", "BAN_REQUESTED", "BAN_FAILED"].includes(status)) {
    return status || "NOT_APPLICABLE";
  }

  const authResult = await admin.auth.admin.getUserById(profileId);
  if (authResult.error || !authResult.data.user) {
    const notFound = authResult.error?.message.toLowerCase().includes("not found") === true;
    const finalStatus = notFound ? "AUTH_USER_NOT_FOUND" : "BAN_FAILED";
    const recorded = await transitionLifecycleAuthStatus(
      admin, companyId, eventId, "EMPLOYEE_TERMINATED",
      ["PENDING_BAN", "BAN_REQUESTED", "BAN_FAILED"], finalStatus,
    );
    return recorded.status || status;
  }

  const banned = authUserIsBanned(authResult.data.user.banned_until);
  const metadata = objectRecord(authResult.data.user.app_metadata);
  const recordedMarker = scalarText(metadata[lifecycleBanMarker]);
  if (banned) {
    const finalStatus = recordedMarker === marker
      ? "BAN_APPLIED"
      : "PREEXISTING_BAN_PRESERVED";
    const recorded = await transitionLifecycleAuthStatus(
      admin, companyId, eventId, "EMPLOYEE_TERMINATED",
      ["PENDING_BAN", "BAN_REQUESTED", "BAN_FAILED"], finalStatus,
    );
    return recorded.status || status;
  }

  const requested = await transitionLifecycleAuthStatus(
    admin, companyId, eventId, "EMPLOYEE_TERMINATED",
    ["PENDING_BAN", "BAN_FAILED"], "BAN_REQUESTED",
  );
  if (requested.error || requested.status !== "BAN_REQUESTED") {
    return requested.status || status;
  }

  const ban = await admin.auth.admin.updateUserById(profileId, {
    ban_duration: "876000h",
    app_metadata: { ...metadata, [lifecycleBanMarker]: marker },
  });
  if (ban.error) {
    const failed = await transitionLifecycleAuthStatus(
      admin, companyId, eventId, "EMPLOYEE_TERMINATED",
      ["BAN_REQUESTED"], "BAN_FAILED",
    );
    return failed.status || "BAN_FAILED";
  }
  const completed = await transitionLifecycleAuthStatus(
    admin, companyId, eventId, "EMPLOYEE_TERMINATED",
    ["BAN_REQUESTED"], "BAN_APPLIED",
  );
  return completed.status || "BAN_REQUESTED";
};

const syncReactivationAuth = async (
  admin: SupabaseClient,
  companyId: string,
  lifecycle: LifecycleResult,
) => {
  const profileId = text(lifecycle.perfil_id);
  const eventId = lifecycle.lifecycle_event_id;
  const terminationEventId = scalarText(lifecycle.auth_ban_event_id);
  let status = text(lifecycle.auth_sync_status);
  if (!profileId || !scalarText(eventId) || !terminationEventId || [
    "NOT_APPLICABLE", "UNBAN_APPLIED", "AUTH_USER_NOT_FOUND",
  ].includes(status)) return status || "NOT_APPLICABLE";
  if (!["PENDING_UNBAN", "UNBAN_REQUESTED", "UNBAN_FAILED"].includes(status)) {
    return status || "NOT_APPLICABLE";
  }

  const accessBefore = await lifecycleAccessCanBeRestored(
    admin, companyId, lifecycle.id, profileId,
  );
  if (accessBefore.error) return status;
  if (!accessBefore.restorable) {
    const preserved = await transitionLifecycleAuthStatus(
      admin, companyId, eventId, "EMPLOYEE_REACTIVATED",
      ["PENDING_UNBAN", "UNBAN_REQUESTED", "UNBAN_FAILED"],
      "ACCESS_BLOCK_PRESERVED",
    );
    return preserved.status || status;
  }

  const authResult = await admin.auth.admin.getUserById(profileId);
  if (authResult.error || !authResult.data.user) {
    const finalStatus = authResult.error?.message.toLowerCase().includes("not found")
      ? "AUTH_USER_NOT_FOUND"
      : "UNBAN_FAILED";
    const recorded = await transitionLifecycleAuthStatus(
      admin, companyId, eventId, "EMPLOYEE_REACTIVATED",
      ["PENDING_UNBAN", "UNBAN_REQUESTED", "UNBAN_FAILED"], finalStatus,
    );
    return recorded.status || status;
  }

  const metadata = objectRecord(authResult.data.user.app_metadata);
  const markerOwned = scalarText(metadata[lifecycleBanMarker]) === terminationEventId;
  const banned = authUserIsBanned(authResult.data.user.banned_until);
  if (banned && !markerOwned) {
    const recorded = await transitionLifecycleAuthStatus(
      admin, companyId, eventId, "EMPLOYEE_REACTIVATED",
      ["PENDING_UNBAN", "UNBAN_REQUESTED", "UNBAN_FAILED"],
      "PREEXISTING_BAN_PRESERVED",
    );
    return recorded.status || status;
  }

  const requested = await transitionLifecycleAuthStatus(
    admin, companyId, eventId, "EMPLOYEE_REACTIVATED",
    ["PENDING_UNBAN", "UNBAN_FAILED"], "UNBAN_REQUESTED",
  );
  if (requested.error || requested.status !== "UNBAN_REQUESTED") {
    return requested.status || status;
  }

  const accessImmediatelyBefore = await lifecycleAccessCanBeRestored(
    admin, companyId, lifecycle.id, profileId,
  );
  if (accessImmediatelyBefore.error || !accessImmediatelyBefore.restorable) {
    const next = accessImmediatelyBefore.error
      ? "UNBAN_FAILED"
      : "ACCESS_BLOCK_PRESERVED";
    const preserved = await transitionLifecycleAuthStatus(
      admin, companyId, eventId, "EMPLOYEE_REACTIVATED",
      ["UNBAN_REQUESTED"], next,
    );
    return preserved.status || status;
  }

  const cleanedMetadata = { ...metadata };
  if (markerOwned) delete cleanedMetadata[lifecycleBanMarker];
  if (banned || markerOwned) {
    const unban = await admin.auth.admin.updateUserById(profileId, {
      ban_duration: "none",
      app_metadata: cleanedMetadata,
    });
    if (unban.error) {
      const failed = await transitionLifecycleAuthStatus(
        admin, companyId, eventId, "EMPLOYEE_REACTIVATED",
        ["UNBAN_REQUESTED"], "UNBAN_FAILED",
      );
      return failed.status || "UNBAN_FAILED";
    }
  }

  const finalized = await admin.rpc("finalizar_reactivacion_acceso_internal", {
    p_empresa: companyId,
    p_evento_id: scalarText(eventId),
  });
  if (!finalized.error) return text(finalized.data) || "UNBAN_APPLIED";

  // Una respuesta de red puede perderse despues del commit. Leer primero evita
  // volver a banear un acceso que la RPC ya finalizo.
  const observed = await admin.from("empleado_ciclo_laboral_auditoria")
    .select("auth_sync_status")
    .eq("empresa_id", companyId)
    .eq("id", scalarText(eventId))
    .maybeSingle();
  if (observed.data?.auth_sync_status === "UNBAN_APPLIED") {
    return "UNBAN_APPLIED";
  }

  let next = "ACCESS_BLOCK_PRESERVED";
  if (markerOwned) {
    const restoredMetadata = {
      ...cleanedMetadata,
      [lifecycleBanMarker]: terminationEventId,
    };
    const reban = await admin.auth.admin.updateUserById(profileId, {
      ban_duration: "876000h",
      app_metadata: restoredMetadata,
    });
    if (reban.error) next = "UNBAN_FAILED";
  }
  const preserved = await transitionLifecycleAuthStatus(
    admin, companyId, eventId, "EMPLOYEE_REACTIVATED",
    ["UNBAN_REQUESTED"], next,
  );
  return preserved.status || next;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const jwt = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
    if (!jwt) return json({ error: "Sesión requerida" }, 401);

    const admin = createClient(url, service, { auth: { persistSession: false } });
    const caller = createClient(url, anon, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false },
    });
    const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
    if (userError || !user) return json({ error: "Sesión inválida" }, 401);
    const { data: profile } = await admin.from("profiles")
      .select("company_id")
      .eq("id", user.id)
      .eq("status", "active")
      .is("access_deleted_at", null)
      .single();
    if (!profile) return json({ error: "Profile activo requerido" }, 403);

    const body = await request.json();
    const action = text(body.action);

    if (action === "reconcile-lifecycle-auth") {
      const { data: allowed } = await caller.rpc("tiene_permiso", {
        codigo_permiso: "empleados.desactivar",
      });
      if (allowed !== true) {
        return json({ error: "Permiso empleados.desactivar requerido" }, 403);
      }
      const { data: pending, error } = await admin
        .from("empleado_ciclo_laboral_auditoria")
        .select("id,empleado_id,perfil_id,evento,evento_relacionado_id,auth_sync_status")
        .eq("empresa_id", profile.company_id)
        .in("evento", ["EMPLOYEE_TERMINATED", "EMPLOYEE_REACTIVATED"])
        .in("auth_sync_status", [
          "PENDING_BAN", "BAN_REQUESTED", "BAN_FAILED",
          "PENDING_UNBAN", "UNBAN_REQUESTED", "UNBAN_FAILED",
        ])
        .order("id", { ascending: true })
        .limit(100);
      if (error) throw error;
      const statuses: Record<string, number> = {};
      for (const event of pending ?? []) {
        const lifecycle = {
          id: event.empleado_id,
          perfil_id: event.perfil_id,
          lifecycle_event_id: event.id,
          auth_ban_event_id: event.evento_relacionado_id,
          auth_sync_status: event.auth_sync_status,
        };
        const finalStatus = event.evento === "EMPLOYEE_REACTIVATED"
          ? await syncReactivationAuth(admin, profile.company_id, lifecycle)
          : await syncTerminationAuth(admin, profile.company_id, lifecycle);
        statuses[finalStatus] = (statuses[finalStatus] ?? 0) + 1;
      }
      return json({ processed: pending?.length ?? 0, statuses });
    }

    if (["terminate", "reactivate", "toggle"].includes(action)) {
      const id = text(body.id) || text(body.employee_id);
      if (!uuid.test(id)) return json({ error: "Empleado invÃ¡lido" }, 400);
      const reactivating = action === "reactivate" ||
        (action === "toggle" && body.active === true);
      if (reactivating) {
        const { data, error } = await caller.rpc("reactivar_empleado", {
          p_empleado: id,
          p_motivo: text(body.reason) || text(body.motivo) || null,
        });
        if (error) throw error;
        const employee = (data ?? {}) as LifecycleResult;
        const authSessionSync = await syncReactivationAuth(
          admin, profile.company_id, employee,
        );
        return json({ employee, auth_session_sync: authSessionSync });
      }

      const effectiveDate = text(body.date) || text(body.fecha) ||
        text(body.termination_date);
      const reason = text(body.reason) || text(body.motivo);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(effectiveDate)) {
        return json({ error: "Fecha de desvinculaciÃ³n requerida" }, 400);
      }
      if (reason.length < 3) {
        return json({ error: "Motivo de desvinculaciÃ³n requerido" }, 400);
      }
      const { data, error } = await caller.rpc("desvincular_empleado", {
        p_empleado: id,
        p_fecha: effectiveDate,
        p_motivo: reason,
        p_observacion: text(body.observation) || text(body.observacion) || null,
      });
      if (error) throw error;
      const employee = (data ?? {}) as LifecycleResult;
      const authSessionSync = await syncTerminationAuth(
        admin, profile.company_id, employee,
      );
      return json({ employee, auth_session_sync: authSessionSync });
    }

    if (action === "next-code") {
      const { data: allowed } = await caller.rpc("tiene_permiso", {
        codigo_permiso: "empleados.crear",
      });
      if (allowed !== true) {
        return json({ error: "Permiso empleados.crear requerido" }, 403);
      }
      const { data: code, error } = await admin.rpc(
        "preview_next_employee_code_internal",
        { p_company_id: profile.company_id },
      );
      if (error) throw error;
      const normalized = normalizeEmployeeCode(code);
      if (!normalized) throw new Error("EMPLOYEE_CODE_PREVIEW_INVALID");
      return json({ code: normalized });
    }

    if (action === "save") {
      const input = body.employee ?? {};
      const id = text(input.id);
      const creating = !id;
      const permission = creating ? "empleados.crear" : "empleados.editar";
      const { data: allowed } = await caller.rpc("tiene_permiso", {
        codigo_permiso: permission,
      });
      if (allowed !== true) {
        return json({ error: `Permiso ${permission} requerido` }, 403);
      }
      if (!creating && !uuid.test(id)) {
        return json({ error: "Empleado inválido" }, 400);
      }

      let existing: {
        codigo_empleado: string;
        estado_laboral: string;
        activo: boolean;
      } | null = null;
      if (!creating) {
        const existingResult = await admin.from("empleados")
          .select("codigo_empleado,estado_laboral,activo")
          .eq("empresa_id", profile.company_id)
          .eq("id", id)
          .maybeSingle();
        if (existingResult.error) throw existingResult.error;
        if (!existingResult.data) return json({ error: "Empleado no encontrado" }, 404);
        existing = existingResult.data;
      }

      const desiredStatus = text(input.status) || existing?.estado_laboral || "activo";
      const desiredActive = typeof input.active === "boolean"
        ? input.active
        : existing?.activo ?? true;
      const currentlyTerminated = existing?.estado_laboral === "desvinculado" &&
        existing.activo === false;
      const requestsTermination = desiredStatus === "desvinculado" || !desiredActive;
      if ((creating && requestsTermination) || (!currentlyTerminated && requestsTermination)) {
        return json({ error: "Use la acciÃ³n de desvinculaciÃ³n con fecha y motivo" }, 409);
      }
      if (currentlyTerminated && !requestsTermination) {
        return json({ error: "Use la acciÃ³n de reactivaciÃ³n" }, 409);
      }

      const name = text(input.name);
      const email = text(input.email).toLowerCase();
      if (name.length < 2) return json({ error: "Nombre completo requerido" }, 400);
      if (email && !/^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$/.test(email)) {
        return json({ error: "Correo inválido" }, 400);
      }

      if (email) {
        const emailQuery = admin.from("empleados").select("id")
          .eq("empresa_id", profile.company_id)
          .eq("correo", email);
        if (!creating) emailQuery.neq("id", id);
        const { data: emailRows } = await emailQuery;
        if (emailRows?.length) {
          return json({ error: "El correo ya está registrado" }, 409);
        }
      }

      const employeeId = creating ? crypto.randomUUID() : id;
      let code: string;
      if (creating) {
        // La vista previa nunca decide el codigo. Esta reserva monotónica es la
        // autoridad final y queda consumida aunque la escritura posterior falle.
        const { data: allocated, error } = await admin.rpc(
          "allocate_next_employee_code_internal",
          { p_company_id: profile.company_id, p_employee_id: employeeId },
        );
        if (error) throw error;
        const normalized = normalizeEmployeeCode(allocated);
        if (!normalized) throw new Error("EMPLOYEE_CODE_ALLOCATION_INVALID");
        code = normalized;
      } else {
        const normalized = normalizeEmployeeCode(input.code) ??
          normalizeEmployeeCode(existing?.codigo_empleado);
        if (!normalized) {
          return json({ error: "El código debe contener exactamente 6 dígitos." }, 400);
        }
        code = normalized;
        const duplicate = admin.from("empleados").select("id")
          .eq("empresa_id", profile.company_id)
          .eq("codigo_empleado", code)
          .neq("id", id);
        const { data: codeRows } = await duplicate;
        if (codeRows?.length) {
          return json({ error: "El código de empleado ya existe" }, 409);
        }
      }

      const payload = {
        empresa_id: profile.company_id,
        codigo_empleado: code,
        nombre_completo: name,
        cedula: text(input.cedula) || null,
        correo: email || null,
        telefono: text(input.phone) || null,
        fecha_ingreso: text(input.startDate) || null,
        ...(creating
          ? { estado_laboral: desiredStatus, activo: desiredActive }
          : {}),
        salario: input.salary === "" || input.salary == null
          ? null
          : Number(input.salary),
        tipo_pago: text(input.payType) || null,
        sucursal_id: text(input.branchId) || null,
        departamento_id: text(input.departmentId) || null,
        puesto_id: text(input.positionId) || null,
      };
      const result = creating
        ? await admin.from("empleados").insert({ id: employeeId, ...payload })
          .select("id,codigo_empleado").single()
        : await admin.from("empleados").update(payload)
          .eq("id", id).eq("empresa_id", profile.company_id)
          .select("id,codigo_empleado").single();
      if (result.error) throw result.error;
      return json({
        employee: {
          id: result.data.id,
          code: result.data.codigo_empleado,
        },
        code: result.data.codigo_empleado,
      });
    }

    return json({ error: "Acción no soportada" }, 400);
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : "Error inesperado",
    }, 400);
  }
});
