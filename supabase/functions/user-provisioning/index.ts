import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type JsonRecord = Record<string, unknown>;
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

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, 'Content-Type': 'application/json' },
});

const required = (value: unknown, name: string) => {
  if (typeof value !== 'string' || !value.trim()) throw new HttpError(400, `${name} es obligatorio`);
  return value.trim();
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

const errorMessage = (error: unknown) => {
  if (error instanceof Error) return error.message;
  if (error && typeof error === 'object' && 'message' in error && typeof error.message === 'string') {
    return error.message;
  }
  return 'Error inesperado';
};

const errorStatus = (error: unknown) => {
  if (error instanceof HttpError) return error.status;
  if (error && typeof error === 'object') {
    const status = 'status' in error && typeof error.status === 'number' ? error.status : undefined;
    const code = 'code' in error && typeof error.code === 'string' ? error.code : '';
    const message = errorMessage(error);
    if (status && status >= 400 && status < 600) return status;
    if (code === '42501' || message.includes('PERMISSION_DENIED')) return 403;
    if (message.includes('NO_ENCONTRADO')) return 404;
    if (code === '23505' || /YA_TIENE|ULTIMO_ADMINISTRADOR|AUTO_/i.test(message)) return 409;
  }
  return 400;
};

const publicErrorMessage = (error: unknown) => {
  const message = errorMessage(error);
  const known: Record<string, string> = {
    EMPLEADO_YA_TIENE_ACCESO: 'El empleado seleccionado ya tiene un acceso.',
    AUTO_ELIMINACION_NO_PERMITIDA: 'No puedes eliminar el acceso de la sesión actual.',
    ULTIMO_ADMINISTRADOR_NO_ELIMINABLE: 'No se puede eliminar el último administrador activo.',
    ULTIMO_ADMINISTRADOR_NO_DESACTIVABLE: 'No se puede desactivar el último administrador activo.',
    ULTIMO_ADMINISTRADOR_NO_MODIFICABLE: 'La empresa debe conservar al menos un administrador activo.',
    AUTO_DESACTIVACION_NO_PERMITIDA: 'No puedes desactivar el acceso de la sesión actual.',
    AUTO_CAMBIO_ACCESO_NO_PERMITIDO: 'No puedes cambiar tu propio rol o estado desde este módulo.',
    ACCESO_NO_ENCONTRADO: 'El acceso no existe o no pertenece a tu empresa.',
  };
  return known[message] ?? message;
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
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
      case 'create-access':
        return await createAccess(admin, body, companyId, user.id);
      case 'update-access':
        return await updateAccess(admin, body, companyId, user.id);
      case 'update-password':
        return await updateAccessPassword(admin, body, companyId, user.id);
      case 'set-status':
        return await setAccessStatus(admin, body, companyId, user.id);
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
    return json({ error: publicErrorMessage(error) }, errorStatus(error));
  }
});

async function internalRpc(admin: AdminClient, name: string, payload: JsonRecord) {
  const { data, error } = await admin.rpc(name, { payload });
  if (error) throw error;
  return data;
}

function permissionsForAction(action: string) {
  switch (action) {
    case 'list-accesses':
      return ['usuarios.view', 'usuarios.create', 'usuarios.edit', 'usuarios.administrar'];
    case 'create-access':
      return ['usuarios.create', 'usuarios.administrar'];
    case 'update-access':
      return ['usuarios.edit', 'usuarios.administrar'];
    case 'update-password':
    case 'set-status':
    case 'delete-access':
      return ['usuarios.administrar'];
    default:
      return ['usuarios.administrar'];
  }
}

async function hasAnyPermission(client: ReturnType<typeof createClient>, permissions: string[]) {
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

async function createAccess(admin: AdminClient, body: JsonRecord, companyId: string, actorId: string) {
  const employeeId = required(body.employee_id, 'employee_id');
  const roleId = required(body.role_id, 'role_id');
  const username = loginEmail(body.username);
  const password = accessPassword(body.password);
  const status = accessStatus(body.status);
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
    },
  });
  if (created.error || !created.data.user) throw created.error ?? new HttpError(400, 'No se creó el usuario Auth');

  try {
    const profile = await internalRpc(admin, 'crear_acceso_internal', {
      actor_user_id: actorId,
      company_id: companyId,
      user_id: created.data.user.id,
      employee_id: employeeId,
      role_id: roleId,
      status,
    });
    const { error: authStatusError } = await admin.auth.admin.updateUserById(created.data.user.id, {
      ban_duration: status === 'active' ? 'none' : '876000h',
    });
    return json({
      access: profile,
      auth_status_sync: authStatusError ? 'pending' : 'completed',
    }, 201);
  } catch (error) {
    await admin.auth.admin.deleteUser(created.data.user.id);
    throw error;
  }
}

async function updateAccess(admin: AdminClient, body: JsonRecord, companyId: string, actorId: string) {
  const profileId = required(body.profile_id, 'profile_id');
  const employeeId = required(body.employee_id, 'employee_id');
  const roleId = required(body.role_id, 'role_id');
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
    },
  });
  if (authUpdate.error) throw authUpdate.error;

  let profile: unknown;
  try {
    profile = await internalRpc(admin, 'actualizar_acceso_internal', {
      actor_user_id: actorId,
      company_id: companyId,
      profile_id: profileId,
      employee_id: employeeId,
      role_id: roleId,
      status,
    });
  } catch (error) {
    if (previousEmail) {
      await admin.auth.admin.updateUserById(profileId, {
        email: previousEmail,
        email_confirm: true,
        user_metadata: previousMetadata,
      });
    }
    throw error;
  }

  let auditSync = 'completed';
  const { error: authStatusError } = await admin.auth.admin.updateUserById(profileId, {
    ban_duration: status === 'active' ? 'none' : '876000h',
  });
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
    auth_status_sync: authStatusError ? 'pending' : 'completed',
  });
}

async function updateAccessPassword(admin: AdminClient, body: JsonRecord, companyId: string, actorId: string) {
  const profileId = required(body.profile_id, 'profile_id');
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
  return json({ updated: true, audit_sync: auditSync });
}

async function setAccessStatus(admin: AdminClient, body: JsonRecord, companyId: string, actorId: string) {
  const profileId = required(body.profile_id, 'profile_id');
  const status = accessStatus(body.status);
  if (!['active', 'inactive'].includes(status)) throw new HttpError(400, 'Estado permitido: active o inactive');
  const profile = await internalRpc(admin, 'cambiar_estado_acceso_internal', {
    actor_user_id: actorId,
    company_id: companyId,
    profile_id: profileId,
    status,
  });
  const { error: authStatusError } = await admin.auth.admin.updateUserById(profileId, {
    ban_duration: status === 'active' ? 'none' : '876000h',
  });
  return json({
    access: profile,
    auth_status_sync: authStatusError ? 'pending' : 'completed',
  });
}

async function deleteAccess(admin: AdminClient, body: JsonRecord, companyId: string, actorId: string) {
  const profileId = required(body.profile_id, 'profile_id');
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
