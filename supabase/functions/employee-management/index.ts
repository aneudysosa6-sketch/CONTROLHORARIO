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
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const normalizeEmployeeCode = (value: unknown): string | null => {
  const candidate = text(value);
  const normalized = /^\d{5}$/.test(candidate) ? `0${candidate}` : candidate;
  return /^\d{6}$/.test(normalized) && normalized !== "000000"
    ? normalized
    : null;
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
      .single();
    if (!profile) return json({ error: "Profile activo requerido" }, 403);

    const body = await request.json();
    const action = text(body.action);

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
        const normalized = normalizeEmployeeCode(input.code);
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
        estado_laboral: text(input.status) || "activo",
        activo: input.active !== false,
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

    if (action === "toggle") {
      const { data: allowed } = await caller.rpc("tiene_permiso", {
        codigo_permiso: "empleados.desactivar",
      });
      if (allowed !== true) {
        return json({ error: "Permiso empleados.desactivar requerido" }, 403);
      }
      const id = text(body.id);
      const active = body.active === true;
      const { error } = await admin.from("empleados").update({
        activo: active,
        estado_laboral: active ? "activo" : "desvinculado",
      }).eq("id", id).eq("empresa_id", profile.company_id);
      if (error) throw error;
      return json({ id, active });
    }

    return json({ error: "Acción no soportada" }, 400);
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : "Error inesperado",
    }, 400);
  }
});
