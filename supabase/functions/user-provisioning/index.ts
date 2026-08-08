import { createClient } from '@supabase/supabase-js';

type JsonRecord = Record<string, unknown>;
type SupabaseClient = ReturnType<typeof createClient<any>>;
type AdminClient = ReturnType<typeof createAdminClient>;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-bootstrap-secret',
};

class HttpError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
  }
}

type RecoveryStatus =
  | 'auth_compensated'
  | 'auth_cleanup_pending'
  | 'auth_restored'
  | 'auth_restore_pending';

class ProvisioningOperationError extends Error {
  constructor(
    public readonly rootCause: unknown,
    public readonly stage: string,
    public readonly recoveryStatus: RecoveryStatus,
    public readonly publicCode?: string,
    public readonly forcedStatus?: number,
    public readonly recoveryCause?: unknown,
  ) {
    super(publicCode ?? 'USER_PROVISIONING_FAILED');
    this.name = 'ProvisioningOperationError';
  }
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, 'Content-Type': 'application/json' },
});

const required = (value: unknown, name: string) => {
  if (typeof value !== 'string' || !value.trim()) throw new HttpError(400, `${name} es obligatorio`);
  return value.trim();
};

const requiredUuid = (value: unknown, name: string) => {
  const uuid = required(value, name).toLowerCase();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(uuid)) {
    throw new HttpError(400, `${name} debe ser un UUID valido`);
  }
  return uuid;
};

const createAdminClient = (url: string, serviceKey: string) => createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const accessStatus = (value: unknown) => {
  const status = required(value, 'status').toLowerCase();
  if (!['active', 'inactive', 'suspended'].includes(status)) {
    throw new HttpError(400, 'Estado de acceso inválido');
  }
  return status;
};

const loginEmail = (value: unknown) => {
  const username = required(value, 'username').toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(username)) {
    throw new HttpError(400, 'El usuario debe ser un correo válido compatible con Supabase Auth');
  }
  return username;
};

const accessPassword = (value: unknown) => {
  const password = required(value, 'password');
  if (password.length < 8) throw new HttpError(400, 'La contraseña debe tener al menos 8 caracteres');
  if (password.length > 128) throw new HttpError(400, 'La contraseña excede la longitud permitida');
  return password;
};

type NormalizedError = {
  constructor: string;
  type: string;
  name: string;
  message: string;
  code: string;
  details: string;
  hint: string;
  status: number | null;
  stack: string;
};

const sanitizeDiagnostic = (value: unknown) => {
  if (typeof value !== 'string') return '';
  return value
    .trim()
    .replace(/Bearer\s+[^\s,;]+/gi, 'Bearer [REDACTED]')
    .replace(/\bsb_(?:publishable|secret)_[A-Za-z0-9_-]+\b/g, 'sb_[REDACTED]')
    .replace(/\beyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, '[REDACTED_JWT]')
    .replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/gi, '[REDACTED_ID]')
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[REDACTED_EMAIL]')
    .replace(/\b(password|secret|token|apikey|authorization)\s*[:=]\s*["']?[^"'\s,;]+/gi, '$1=[REDACTED]')
    .slice(0, 2000);
};

const normalizeError = (error: unknown, responseStatus?: number): NormalizedError => {
  const record = error && typeof error === 'object' ? error as JsonRecord : {};
  const constructorName = error && typeof error === 'object'
    ? (error as { constructor?: { name?: string } }).constructor?.name
    : undefined;
  const status = typeof responseStatus === 'number'
    ? responseStatus
    : typeof record.status === 'number'
      ? record.status
      : null;
  const message = sanitizeDiagnostic(error instanceof Error ? error.message : record.message);
  return {
    constructor: sanitizeDiagnostic(constructorName) || 'Unknown',
    type: error === null ? 'null' : Array.isArray(error) ? 'array' : typeof error,
    name: sanitizeDiagnostic(error instanceof Error ? error.name : record.name) || constructorName || 'Unknown',
    message: message || 'Unknown error',
    code: sanitizeDiagnostic(record.code),
    details: sanitizeDiagnostic(record.details),
    hint: sanitizeDiagnostic(record.hint),
    status,
    stack: sanitizeDiagnostic(error instanceof Error ? error.stack : record.stack),
  };
};

const errorMessage = (error: unknown) => normalizeError(error).message;

const errorStatus = (error: unknown): number => {
  if (error instanceof ProvisioningOperationError) {
    return error.forcedStatus ?? errorStatus(error.rootCause);
  }
  if (error instanceof HttpError) return error.status;
  const normalized = normalizeError(error);
  if (normalized.code === '42501' || normalized.message.includes('PERMISSION_DENIED')) return 403;
  if (normalized.code === '22P02') return 400;
  if (normalized.code === '28000' || normalized.message === 'AUTH_SESSION_REQUIRED') return 401;
  if (normalized.message === 'SCOPE_ADMIN_PROFILE_INVALID') return 403;
  if (normalized.message === 'SUPERVISOR_PROFILE_NOT_FOUND') return 404;
  if (normalized.message.includes('NO_ENCONTRADO')) return 404;
  if (
    normalized.code === '23505'
    || /YA_TIENE|ULTIMO_ADMINISTRADOR|AUTO_|SIN_DEPARTAMENTOS|IDEMPOTENCY_KEY_REUSED|SUPERVISOR_PROFILE_INACTIVE|SUPERVISOR_EXPLICIT_SCOPE_INVALID|SUPERVISOR_SCOPE_MULTIPLE_BRANCHES|SUPERVISOR_BRANCH_HAS_ASSIGNED_DEPARTMENTS|SUPERVISOR_SCOPE_MANAGED_IN_ACCESS/i.test(normalized.message)
  ) return 409;
  if (
    /IDEMPOTENCY_KEY_(?:REQUIRED|INVALID)|SUPERVISOR_SCOPE_(?:REQUIRED_FIELDS|DEPARTMENT_IDS_INVALID|BRANCH_REQUIRED|BRANCH_INVALID|DEPARTMENT_INVALID|EMPTY|ROLE_INVALID)|SUPERVISOR_(?:BRANCH_CROSS_COMPANY|DEPARTMENT_CROSS_COMPANY|DEPARTMENT_BRANCH_NOT_AUTHORIZED)/i.test(normalized.message)
  ) return 400;
  if (normalized.status && normalized.status >= 400 && normalized.status < 600) return normalized.status;
  return 500;
};

const publicErrorMessage = (error: unknown): string => {
  if (error instanceof ProvisioningOperationError && error.publicCode) {
    return publicErrorMessage(new HttpError(error.forcedStatus ?? 500, error.publicCode));
  }
  const source = error instanceof ProvisioningOperationError ? error.rootCause : error;
  const message = errorMessage(source);
  const known: Record<string, string> = {
    EMPLEADO_YA_TIENE_ACCESO: 'El empleado seleccionado ya tiene un usuario.',
    ACCESS_ADMIN_PERMISSION_DENIED: 'No tienes permisos para consultar los empleados de esta empresa.',
    SCOPE_ADMIN_PROFILE_INVALID: 'No se pudo validar un perfil administrador activo.',
    SUPERVISOR_SCOPE_PERMISSION_DENIED: 'No tienes permisos para administrar el alcance del supervisor.',
    SUPERVISOR_SCOPE_REQUIRED_FIELDS: 'Faltan datos obligatorios del alcance del supervisor.',
    SUPERVISOR_SCOPE_DEPARTMENT_IDS_INVALID: 'La seleccion de departamentos no es valida.',
    SUPERVISOR_SCOPE_BRANCH_REQUIRED: 'Selecciona una sucursal para el supervisor.',
    SUPERVISOR_SCOPE_BRANCH_INVALID: 'La sucursal no esta activa o no pertenece a la empresa autorizada.',
    SUPERVISOR_SCOPE_DEPARTMENT_INVALID: 'Uno o mas departamentos no estan activos o no pertenecen a la sucursal seleccionada.',
    SUPERVISOR_SCOPE_EMPTY: 'Selecciona al menos un departamento para la sucursal.',
    SUPERVISOR_SCOPE_ROLE_INVALID: 'El alcance por departamentos solo puede asignarse a un rol SUPERVISOR.',
    SUPERVISOR_SCOPE_MULTIPLE_BRANCHES: 'El supervisor tiene asignaciones en mas de una sucursal y requiere conciliacion.',
    SUPERVISOR_EXPLICIT_SCOPE_INVALID: 'El alcance explicito del supervisor es inconsistente y requiere conciliacion.',
    SUPERVISOR_PROFILE_NOT_FOUND: 'El acceso del supervisor no existe o no pertenece a tu empresa.',
    SUPERVISOR_PROFILE_INACTIVE: 'El perfil supervisor debe estar activo para recibir alcance.',
    SUPERVISOR_BRANCH_CROSS_COMPANY: 'La sucursal seleccionada no pertenece a la empresa autorizada.',
    SUPERVISOR_DEPARTMENT_CROSS_COMPANY: 'Uno o mas departamentos no pertenecen a la empresa autorizada.',
    SUPERVISOR_DEPARTMENT_BRANCH_NOT_AUTHORIZED: 'Los departamentos deben pertenecer a la sucursal seleccionada.',
    SUPERVISOR_BRANCH_HAS_ASSIGNED_DEPARTMENTS: 'No se puede retirar una sucursal mientras conserve departamentos asignados.',
    SUPERVISOR_SCOPE_MANAGED_IN_ACCESS: 'El alcance del supervisor debe modificarse desde la administracion de accesos.',
    SIN_DEPARTAMENTOS: 'SIN_DEPARTAMENTOS',
    IDEMPOTENCY_KEY_REQUIRED: 'La solicitud de creacion requiere una clave de idempotencia.',
    IDEMPOTENCY_KEY_INVALID: 'La clave de idempotencia no es valida.',
    IDEMPOTENCY_KEY_REUSED: 'La clave de idempotencia ya fue utilizada con otros datos.',
    ACCESS_CREATION_RECOVERY_PENDING: 'No se completo la creacion y la identidad Auth requiere revision antes de reintentar.',
    ACCESS_UPDATE_RECOVERY_PENDING: 'No se completo la actualizacion y la identidad Auth requiere revision antes de reintentar.',
    AUTO_ELIMINACION_NO_PERMITIDA: 'No puedes eliminar el acceso de la sesión actual.',
    ULTIMO_ADMINISTRADOR_NO_ELIMINABLE: 'No se puede eliminar el último administrador activo.',
    ULTIMO_ADMINISTRADOR_NO_DESACTIVABLE: 'No se puede desactivar el último administrador activo.',
    ULTIMO_ADMINISTRADOR_NO_MODIFICABLE: 'La empresa debe conservar al menos un administrador activo.',
    AUTO_DESACTIVACION_NO_PERMITIDA: 'No puedes desactivar el acceso de la sesión actual.',
    AUTO_CAMBIO_ACCESO_NO_PERMITIDO: 'No puedes cambiar tu propio rol o estado desde este módulo.',
    ACCESO_NO_ENCONTRADO: 'El acceso no existe o no pertenece a tu empresa.',
  };
  if (/^Permiso requerido:/i.test(message)) {
    return 'No tienes permisos para consultar los empleados de esta empresa.';
  }
  if (message === 'Profile activo requerido') {
    return 'No se pudo determinar la empresa activa.';
  }
  if (known[message]) return known[message];
  if (source instanceof HttpError) return message === 'Unknown error' ? 'REQUEST_FAILED' : message;
  return 'USER_PROVISIONING_FAILED';
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const requestId = crypto.randomUUID();
  try {
    const url = required(Deno.env.get('SUPABASE_URL'), 'SUPABASE_URL');
    const publishable = required(Deno.env.get('SUPABASE_ANON_KEY'), 'SUPABASE_ANON_KEY');
    const serviceKey = required(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), 'SUPABASE_SERVICE_ROLE_KEY');
    const body = await req.json() as JsonRecord;
    const action = required(body.action, 'action');
    const admin = createAdminClient(url, serviceKey);

    if (action === 'bootstrap-status') {
      const { count, error } = await admin.from('profiles').select('id', { count: 'exact', head: true });
      if (error) throw error;
      return json({ bootstrap_required: count === 0 });
    }

    const jwt = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
    if (!jwt) throw new HttpError(401, 'Sesión requerida');
    const callerClient = createClient(url, publishable, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false },
    });
    const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
    if (userError || !user) throw new HttpError(401, 'Sesión inválida');

    if (action === 'bootstrap') {
      const expectedSecret = Deno.env.get('USER_PROVISIONING_BOOTSTRAP_SECRET')?.trim() ?? '';
      const receivedSecret = req.headers.get('x-bootstrap-secret')?.trim() ?? '';
      if (!expectedSecret || !receivedSecret || receivedSecret !== expectedSecret) {
        throw new HttpError(403, 'Bootstrap no autorizado');
      }
      const { count } = await admin.from('profiles').select('id', { count: 'exact', head: true });
      if (count !== 0) throw new HttpError(409, 'Bootstrap cerrado: ya existe al menos un profile');
      const { data, error } = await admin.rpc('bootstrap_tenant_internal', { payload: { ...body, user_id: user.id } });
      if (error) throw error;
      return json({ profile: data });
    }

    const { data: callerProfile, error: profileError } = await admin
      .from('profiles')
      .select('company_id')
      .eq('id', user.id)
      .eq('status', 'active')
      .single();
    if (profileError || !callerProfile) throw new HttpError(403, 'Profile activo requerido');
    const companyId = callerProfile.company_id as string;
    const permissions = permissionsForAction(action);
    if (!await hasAnyPermission(callerClient, permissions)) {
      if (action === 'get-supervisor-scope' || action === 'save-supervisor-scope') {
        throw new HttpError(403, 'SUPERVISOR_SCOPE_PERMISSION_DENIED');
      }
      throw new HttpError(403, `Permiso requerido: ${permissions.join(' o ')}`);
    }

    switch (action) {
      case 'list-accesses': {
        const data = await internalRpc(admin, 'listar_accesos_internal', {
          actor_user_id: user.id,
          company_id: companyId,
        });
        return json(data);
      }
      case 'get-supervisor-scope': {
        const payload: JsonRecord = { actor_user_id: user.id };
        if (typeof body.profile_id === 'string' && body.profile_id.trim()) {
          payload.profile_id = requiredUuid(body.profile_id, 'profile_id');
        } else if (body.profile_id !== undefined && body.profile_id !== null && body.profile_id !== '') {
          throw new HttpError(400, 'profile_id no es valido');
        }
        const data = await internalRpc(admin, 'obtener_alcance_supervisor_internal', payload);
        return json(data);
      }
      case 'save-supervisor-scope': {
        const payload = receivedScopePayload(body, {
          actor_user_id: user.id,
          profile_id: requiredUuid(body.profile_id, 'profile_id'),
        });
        const data = await internalRpc(admin, 'guardar_alcance_supervisor_internal', payload);
        return json(data);
      }
      case 'create-access':
        return await createAccess(admin, body, companyId, user.id, requestId);
      case 'update-access':
        return await updateAccess(admin, body, companyId, user.id, requestId);
      case 'update-password':
        return await updateAccessPassword(admin, body, companyId, user.id, requestId);
      case 'set-status':
        return await setAccessStatus(admin, body, companyId, user.id, requestId);
      case 'delete-access':
        return await deleteAccess(admin, body, companyId, user.id);
      // Contratos anteriores conservados durante la transición del módulo Usuarios -> Accesos.
      case 'list':
        return await listLegacyState(admin, companyId);
      case 'create':
      case 'invite':
        return await createLegacyUser(admin, body, companyId, user.id, action);
      case 'provision':
        return await provisionLegacy(admin, { ...body, company_id: companyId, actor_user_id: user.id, action: 'provision_user' });
      default:
        throw new HttpError(400, 'Acción no soportada');
    }
  } catch (error) {
    const publicContext = error instanceof ProvisioningOperationError
      ? { stage: error.stage, recovery_status: error.recoveryStatus }
      : {};
    return json({ error: publicErrorMessage(error), requestId, ...publicContext }, errorStatus(error));
  }
});

async function internalRpc(admin: AdminClient, name: string, payload: JsonRecord) {
  const { data, error } = await admin.rpc(name, { payload });
  if (error) throw error;
  return data;
}

function receivedScopePayload(body: JsonRecord, base: JsonRecord) {
  const payload = { ...base };
  if (Object.prototype.hasOwnProperty.call(body, 'branch_id')) {
    payload.branch_id = requiredUuid(body.branch_id, 'branch_id');
  }
  if (Object.prototype.hasOwnProperty.call(body, 'department_ids')) {
    if (!Array.isArray(body.department_ids)) {
      throw new HttpError(400, 'department_ids debe ser una lista de UUID');
    }
    payload.department_ids = [...new Set(
      body.department_ids.map((value, index) => requiredUuid(value, `department_ids[${index}]`)),
    )].sort();
  }
  return payload;
}

function permissionsForAction(action: string) {
  switch (action) {
    case 'list-accesses':
      return ['usuarios.view', 'usuarios.create', 'usuarios.edit', 'usuarios.administrar'];
    case 'create-access':
      return ['usuarios.create', 'usuarios.administrar'];
    case 'update-access':
      return ['usuarios.edit', 'usuarios.administrar'];
    case 'get-supervisor-scope':
    case 'save-supervisor-scope':
      return ['usuarios.administrar', 'roles.administrar', 'permisos.administrar'];
    case 'update-password':
    case 'set-status':
    case 'delete-access':
      return ['usuarios.administrar'];
    default:
      return ['usuarios.administrar'];
  }
}

async function hasAnyPermission(client: SupabaseClient, permissions: string[]) {
  for (const permission of permissions) {
    const { data, error } = await client.rpc('tiene_permiso', { codigo_permiso: permission });
    if (!error && data === true) return true;
  }
  return false;
}

async function employeeForAccess(admin: AdminClient, companyId: string, employeeId: string) {
  const { data, error } = await admin
    .from('empleados')
    .select('id,nombre_completo,codigo_empleado,empresa_id,perfil_id,activo')
    .eq('id', employeeId)
    .eq('empresa_id', companyId)
    .eq('activo', true)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new HttpError(404, 'EMPLEADO_ACCESO_INVALIDO');
  return data;
}

async function roleForAccess(admin: AdminClient, companyId: string, roleId: string) {
  const { data, error } = await admin
    .from('roles')
    .select('id,name,code')
    .eq('id', roleId)
    .eq('company_id', companyId)
    .eq('is_active', true)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new HttpError(400, 'ROL_ACCESO_INVALIDO');
  return data;
}

async function compensateCreatedAuth(admin: AdminClient, userId: string) {
  try {
    const cleanup = await admin.auth.admin.deleteUser(userId);
    const cleanupMessage = cleanup.error?.message.toLowerCase() ?? '';
    const recovered = !cleanup.error
      || cleanupMessage.includes('user not found')
      || cleanupMessage.includes('not_found');
    return { recovered, cause: recovered ? undefined : cleanup.error };
  } catch (cause) {
    return { recovered: false, cause };
  }
}

async function synchronizeAuthStatus(
  admin: AdminClient,
  access: unknown,
  fallbackStatus?: string,
): Promise<'completed' | 'pending'> {
  const record = access && typeof access === 'object' ? access as JsonRecord : {};
  const profileId = typeof record.profile_id === 'string'
    ? record.profile_id
    : typeof record.id === 'string'
    ? record.id
    : null;
  const status = typeof record.status === 'string' ? record.status : fallbackStatus;
  if (!profileId || !status || !['active', 'inactive', 'suspended'].includes(status)) return 'pending';
  try {
    const { error } = await admin.auth.admin.updateUserById(profileId, {
      ban_duration: status === 'active' ? 'none' : '876000h',
    });
    return error ? 'pending' : 'completed';
  } catch {
    return 'pending';
  }
}

async function accessForOperation(
  admin: AdminClient,
  companyId: string,
  actorId: string,
  profileId: string,
  requiredPermission: 'usuarios.view' | 'usuarios.edit' | 'usuarios.administrar',
) {
  return await internalRpc(admin, 'obtener_acceso_internal', {
    actor_user_id: actorId,
    company_id: companyId,
    profile_id: profileId,
    required_permission: requiredPermission,
  }) as JsonRecord;
}

async function createAccess(
  admin: AdminClient,
  body: JsonRecord,
  companyId: string,
  actorId: string,
  requestId: string,
) {
  const employeeId = requiredUuid(body.employee_id, 'employee_id');
  const roleId = requiredUuid(body.role_id, 'role_id');
  const username = loginEmail(body.username);
  const password = accessPassword(body.password);
  const status = accessStatus(body.status);
  const idempotencyKey = requiredUuid(body.idempotency_key, 'idempotency_key');
  const idempotencyPayload = receivedScopePayload(body, {
    actor_user_id: actorId,
    company_id: companyId,
    employee_id: employeeId,
    role_id: roleId,
    username,
    status,
    idempotency_key: idempotencyKey,
  });
  const replay = await internalRpc(admin, 'obtener_creacion_acceso_idempotente_internal', idempotencyPayload);
  if (replay) {
    const authStatusSync = await synchronizeAuthStatus(admin, replay);
    return json({
      access: replay,
      idempotent_replay: true,
      auth_status_sync: authStatusSync,
      requestId,
    });
  }
  const employee = await employeeForAccess(admin, companyId, employeeId);
  await roleForAccess(admin, companyId, roleId);
  if (employee.perfil_id) throw new HttpError(409, 'EMPLEADO_YA_TIENE_ACCESO');

  const created = await admin.auth.admin.createUser({
    email: username,
    password,
    email_confirm: true,
    user_metadata: {
      username,
      full_name: employee.nombre_completo,
      employee_id: employee.id,
      employee_code: employee.codigo_empleado,
      provisioning_request_id: requestId,
      provisioning_idempotency_key: idempotencyKey,
    },
  });
  if (created.error || !created.data.user) {
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        const replayAfterAuthConflict = await internalRpc(
          admin,
          'obtener_creacion_acceso_idempotente_internal',
          idempotencyPayload,
        );
        if (replayAfterAuthConflict) {
          const authStatusSync = await synchronizeAuthStatus(admin, replayAfterAuthConflict);
          return json({
            access: replayAfterAuthConflict,
            idempotent_replay: true,
            auth_status_sync: authStatusSync,
            requestId,
          });
        }
      } catch (replayError) {
        if (errorMessage(replayError) === 'IDEMPOTENCY_KEY_REUSED') throw replayError;
        break;
      }
      if (attempt < 2) {
        await new Promise((resolve) => setTimeout(resolve, 75 * (attempt + 1)));
      }
    }
    throw created.error ?? new HttpError(400, 'No se creó el usuario Auth');
  }

  try {
    const profile = await internalRpc(admin, 'crear_acceso_con_alcance_internal', receivedScopePayload(body, {
      actor_user_id: actorId,
      company_id: companyId,
      user_id: created.data.user.id,
      employee_id: employeeId,
      role_id: roleId,
      username,
      status,
      idempotency_key: idempotencyKey,
    }));
    const authStatusSync = await synchronizeAuthStatus(admin, profile, status);
    return json({
      access: profile,
      idempotent_replay: false,
      auth_status_sync: authStatusSync,
      requestId,
    }, 201);
  } catch (error) {
    let replayAfterFailure: JsonRecord | null;
    try {
      replayAfterFailure = await internalRpc(
        admin,
        'obtener_creacion_acceso_idempotente_internal',
        idempotencyPayload,
      ) as JsonRecord | null;
    } catch (replayError) {
      if (errorMessage(replayError) === 'IDEMPOTENCY_KEY_REUSED') {
        const compensation = await compensateCreatedAuth(admin, created.data.user.id);
        throw new ProvisioningOperationError(
          replayError,
          'create_access_transaction',
          compensation.recovered ? 'auth_compensated' : 'auth_cleanup_pending',
          compensation.recovered ? undefined : 'ACCESS_CREATION_RECOVERY_PENDING',
          compensation.recovered ? undefined : 500,
          compensation.cause,
        );
      }
      // Si no podemos confirmar si PostgreSQL hizo commit, conservar Auth es
      // más seguro que borrar una identidad que podría tener un profile válido.
      throw new ProvisioningOperationError(
        error,
        'create_access_transaction',
        'auth_cleanup_pending',
        'ACCESS_CREATION_RECOVERY_PENDING',
        500,
        replayError,
      );
    }

    const replayProfileId = typeof replayAfterFailure?.profile_id === 'string'
      ? replayAfterFailure.profile_id
      : typeof replayAfterFailure?.id === 'string'
      ? replayAfterFailure.id
      : null;
    if (replayAfterFailure && replayProfileId === created.data.user.id) {
      const authStatusSync = await synchronizeAuthStatus(admin, replayAfterFailure, status);
      return json({
        access: replayAfterFailure,
        idempotent_replay: true,
        recovered_committed_transaction: true,
        auth_status_sync: authStatusSync,
        requestId,
      });
    }

    const compensation = await compensateCreatedAuth(admin, created.data.user.id);
    const recovered = compensation.recovered;
    if (recovered && replayAfterFailure) {
      const authStatusSync = await synchronizeAuthStatus(admin, replayAfterFailure);
      return json({
        access: replayAfterFailure,
        idempotent_replay: true,
        auth_compensation: 'completed',
        auth_status_sync: authStatusSync,
        requestId,
      });
    }
    throw new ProvisioningOperationError(
      error,
      'create_access_transaction',
      recovered ? 'auth_compensated' : 'auth_cleanup_pending',
      recovered ? undefined : 'ACCESS_CREATION_RECOVERY_PENDING',
      recovered ? undefined : 500,
      compensation.cause,
    );
  }
}

async function updateAccess(
  admin: AdminClient,
  body: JsonRecord,
  companyId: string,
  actorId: string,
  requestId: string,
) {
  const profileId = requiredUuid(body.profile_id, 'profile_id');
  const employeeId = requiredUuid(body.employee_id, 'employee_id');
  const roleId = requiredUuid(body.role_id, 'role_id');
  const username = loginEmail(body.username);
  const status = accessStatus(body.status);
  await accessForOperation(admin, companyId, actorId, profileId, 'usuarios.edit');
  const employee = await employeeForAccess(admin, companyId, employeeId);
  await roleForAccess(admin, companyId, roleId);
  if (employee.perfil_id && employee.perfil_id !== profileId) {
    throw new HttpError(409, 'EMPLEADO_YA_TIENE_ACCESO');
  }

  const authResult = await admin.auth.admin.getUserById(profileId);
  if (authResult.error || !authResult.data.user) throw authResult.error ?? new HttpError(404, 'USUARIO_AUTH_NO_ENCONTRADO');
  const previousEmail = authResult.data.user.email;
  const previousMetadata = authResult.data.user.user_metadata;
  const authUpdate = await admin.auth.admin.updateUserById(profileId, {
    email: username,
    email_confirm: true,
    user_metadata: {
      ...previousMetadata,
      username,
      full_name: employee.nombre_completo,
      employee_id: employee.id,
      employee_code: employee.codigo_empleado,
      provisioning_last_request_id: requestId,
    },
  });
  if (authUpdate.error) throw authUpdate.error;

  let profile: unknown;
  try {
    profile = await internalRpc(admin, 'actualizar_acceso_con_alcance_internal', receivedScopePayload(body, {
      actor_user_id: actorId,
      company_id: companyId,
      profile_id: profileId,
      employee_id: employeeId,
      role_id: roleId,
      username,
      status,
      operation_id: requestId,
    }));
  } catch (error) {
    let committedUpdate: JsonRecord | null;
    try {
      committedUpdate = await internalRpc(
        admin,
        'obtener_actualizacion_acceso_confirmada_internal',
        {
          actor_user_id: actorId,
          profile_id: profileId,
          operation_id: requestId,
        },
      ) as JsonRecord | null;
    } catch (verificationError) {
      // Un resultado ambiguo nunca restaura Auth a ciegas: PostgreSQL podría
      // haber confirmado ya el acceso y su alcance.
      throw new ProvisioningOperationError(
        error,
        'update_access_transaction',
        'auth_restore_pending',
        'ACCESS_UPDATE_RECOVERY_PENDING',
        500,
        verificationError,
      );
    }
    if (committedUpdate) {
      const authStatusSync = await synchronizeAuthStatus(admin, committedUpdate, status);
      let auditSync = 'completed';
      if (previousEmail?.toLowerCase() !== username) {
        try {
          await internalRpc(admin, 'registrar_operacion_acceso_internal', {
            actor_user_id: actorId,
            company_id: companyId,
            profile_id: profileId,
            action: 'CAMBIAR_USUARIO',
          });
        } catch {
          auditSync = 'pending';
        }
      }
      return json({
        access: committedUpdate,
        recovered_committed_transaction: true,
        audit_sync: auditSync,
        auth_status_sync: authStatusSync,
        requestId,
      });
    }

    let recoveryCause: unknown;
    let recovered = false;
    try {
      const restore = await admin.auth.admin.updateUserById(profileId, {
        ...(previousEmail ? { email: previousEmail, email_confirm: true } : {}),
        user_metadata: previousMetadata,
      });
      recoveryCause = restore.error ?? undefined;
      recovered = !restore.error;
    } catch (restoreError) {
      recoveryCause = restoreError;
    }
    throw new ProvisioningOperationError(
      error,
      'update_access_transaction',
      recovered ? 'auth_restored' : 'auth_restore_pending',
      recovered ? undefined : 'ACCESS_UPDATE_RECOVERY_PENDING',
      recovered ? undefined : 500,
      recoveryCause,
    );
  }

  let auditSync = 'completed';
  const authStatusSync = await synchronizeAuthStatus(admin, profile, status);
  if (previousEmail?.toLowerCase() !== username) {
    try {
      await internalRpc(admin, 'registrar_operacion_acceso_internal', {
        actor_user_id: actorId,
        company_id: companyId,
        profile_id: profileId,
        action: 'CAMBIAR_USUARIO',
      });
    } catch {
      auditSync = 'pending';
    }
  }
  return json({
    access: profile,
    audit_sync: auditSync,
    auth_status_sync: authStatusSync,
    requestId,
  });
}

async function updateAccessPassword(
  admin: AdminClient,
  body: JsonRecord,
  companyId: string,
  actorId: string,
  requestId: string,
) {
  const profileId = requiredUuid(body.profile_id, 'profile_id');
  const password = accessPassword(body.password);
  await accessForOperation(admin, companyId, actorId, profileId, 'usuarios.administrar');
  const { error } = await admin.auth.admin.updateUserById(profileId, { password });
  if (error) throw error;
  let auditSync = 'completed';
  try {
    await internalRpc(admin, 'registrar_operacion_acceso_internal', {
      actor_user_id: actorId,
      company_id: companyId,
      profile_id: profileId,
      action: 'CAMBIAR_CONTRASENA',
    });
  } catch {
    auditSync = 'pending';
  }
  return json({ updated: true, audit_sync: auditSync, requestId });
}

async function setAccessStatus(
  admin: AdminClient,
  body: JsonRecord,
  companyId: string,
  actorId: string,
  requestId: string,
) {
  const profileId = requiredUuid(body.profile_id, 'profile_id');
  const status = accessStatus(body.status);
  if (!['active', 'inactive'].includes(status)) throw new HttpError(400, 'Estado permitido: active o inactive');
  const profile = await internalRpc(admin, 'cambiar_estado_acceso_con_alcance_internal', {
    actor_user_id: actorId,
    company_id: companyId,
    profile_id: profileId,
    status,
  });
  const authStatusSync = await synchronizeAuthStatus(admin, profile, status);
  return json({
    access: profile,
    auth_status_sync: authStatusSync,
    requestId,
  });
}

async function deleteAccess(admin: AdminClient, body: JsonRecord, companyId: string, actorId: string) {
  const profileId = requiredUuid(body.profile_id, 'profile_id');
  const { data: existing, error: existingError } = await admin
    .from('profiles')
    .select('id,access_deleted_at')
    .eq('id', profileId)
    .eq('company_id', companyId)
    .maybeSingle();
  if (existingError) throw existingError;
  if (!existing) throw new HttpError(404, 'ACCESO_NO_ENCONTRADO');

  const result = existing.access_deleted_at
    ? { deleted: true, profile_id: profileId, employee_preserved: true, already_deleted: true }
    : await internalRpc(admin, 'eliminar_acceso_internal', {
      actor_user_id: actorId,
      company_id: companyId,
      profile_id: profileId,
    }) as JsonRecord;
  const authCleanup = await disableDeletedAuthIdentity(admin, profileId);
  return json({
    ...result,
    auth_cleanup: authCleanup.completed ? 'completed' : 'pending',
    auth_cleanup_pending: !authCleanup.completed,
  });
}

async function disableDeletedAuthIdentity(admin: AdminClient, profileId: string) {
  const tombstoneEmail = `deleted+${profileId.replaceAll('-', '')}@access.invalid`;
  const { error } = await admin.auth.admin.updateUserById(profileId, {
    email: tombstoneEmail,
    email_confirm: true,
    ban_duration: '876000h',
    user_metadata: {
      access_deleted: true,
      deleted_at: new Date().toISOString(),
    },
  });
  if (!error) return { completed: true };
  const message = error.message.toLowerCase();
  if (message.includes('user not found') || message.includes('not_found')) return { completed: true };
  // La baja de profiles ya es efectiva. No se revierte ni se reactiva el acceso si
  // el mantenimiento secundario de Auth falla; una repeticion es idempotente.
  return { completed: false };
}

async function createLegacyUser(
  admin: AdminClient,
  body: JsonRecord,
  companyId: string,
  actorId: string,
  action: string,
) {
  const email = required(body.email, 'email').toLowerCase();
  const fullName = required(body.full_name, 'full_name');
  const created = action === 'invite'
    ? await admin.auth.admin.inviteUserByEmail(email, { data: { full_name: fullName } })
    : await admin.auth.admin.createUser({
      email,
      password: required(body.password, 'password'),
      email_confirm: true,
      user_metadata: { full_name: fullName },
    });
  if (created.error || !created.data.user) throw created.error ?? new HttpError(400, 'No se creó el usuario Auth');
  try {
    return await provisionLegacy(admin, {
      ...body,
      company_id: companyId,
      status: 'active',
      user_id: created.data.user.id,
      actor_user_id: actorId,
      action: action === 'invite' ? 'invite_user' : 'create_user',
    });
  } catch (error) {
    if (action === 'create') await admin.auth.admin.deleteUser(created.data.user.id);
    throw error;
  }
}

async function listLegacyState(admin: AdminClient, companyId: string) {
  const authUsers: Array<{
    id: string;
    email?: string;
    user_metadata?: JsonRecord;
    created_at: string;
  }> = [];
  for (let page = 1;; page += 1) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    authUsers.push(...data.users);
    if (data.users.length < 1000) break;
  }
  const ids = authUsers.map((entry) => entry.id);
  const { data: profiles, error: profileError } = ids.length
    ? await admin.from('profiles').select('id').in('id', ids)
    : { data: [], error: null };
  if (profileError) throw profileError;
  const known = new Set((profiles ?? []).map((profile) => profile.id));

  const [{ data: companies, error: companyError }, { data: roles, error: rolesError }, { data: employees, error: employeesError }] = await Promise.all([
    admin.from('companies').select('id,name,slug').eq('id', companyId).eq('status', 'active'),
    admin.from('roles').select('id,name,code,company_id').eq('company_id', companyId).eq('is_active', true),
    admin.from('empleados').select('id,nombre_completo,codigo_empleado,empresa_id').eq('empresa_id', companyId).is('perfil_id', null).eq('activo', true),
  ]);
  if (companyError) throw companyError;
  if (rolesError) throw rolesError;
  if (employeesError) throw employeesError;
  return json({
    users: authUsers.filter((entry) => !known.has(entry.id)).map((entry) => ({
      id: entry.id,
      email: entry.email ?? '',
      full_name: typeof entry.user_metadata?.full_name === 'string' ? entry.user_metadata.full_name : entry.email ?? '',
      created_at: entry.created_at,
    })),
    companies: companies ?? [],
    roles: roles ?? [],
    employees: employees ?? [],
  });
}

async function provisionLegacy(admin: AdminClient, payload: JsonRecord) {
  required(payload.user_id, 'user_id');
  required(payload.company_id, 'company_id');
  required(payload.role_id, 'role_id');
  required(payload.full_name, 'full_name');
  const { data, error } = await admin.rpc('provision_user_internal', { payload });
  if (error) throw error;
  return json({ profile: data });
}
