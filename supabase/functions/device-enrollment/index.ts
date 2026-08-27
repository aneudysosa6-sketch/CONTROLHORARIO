import { createClient } from '@supabase/supabase-js';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,x-client-info,apikey,content-type,x-device-id,x-device-credential',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
const text = (value: unknown) => typeof value === 'string' ? value.trim() : '';
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const random = (size: number) => {
  const bytes = new Uint8Array(size);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (value) => value.toString(16).padStart(2, '0')).join('');
};
const hash = async (value: string) =>
  Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))))
    .map((item) => item.toString(16).padStart(2, '0')).join('');

const validSigningKey = async (value: string) => {
  if (value.length < 80 || value.length > 1024) return false;
  try {
    const bytes = Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
    await crypto.subtle.importKey('spki', bytes, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
    return true;
  } catch {
    return false;
  }
};

const usageType = (value: unknown) => text(value).toUpperCase();
const departmentIds = (value: unknown) =>
  [...new Set((Array.isArray(value) ? value : []).map(text).filter((id) => uuid.test(id)))];

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const url = Deno.env.get('SUPABASE_URL');
    const anon = Deno.env.get('SUPABASE_ANON_KEY');
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anon || !service) throw new Error('DEVICE_ENROLLMENT_CONFIGURATION_MISSING');
    const body = await request.json() as Record<string, unknown>;
    const action = text(body.action);
    const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });

    if (action === 'exchange') {
      const code = text(body.code).toUpperCase();
      const installationId = text(body.installation_id);
      const publicKey = text(body.public_key_spki);
      const requestedCompanyId = text(body.company_id);
      const terminalName = text(body.name);
      const model = text(body.model);
      const androidVersion = text(body.android_version);
      const appVersion = text(body.app_version);
      if (
        !/^[A-F0-9]{16}$/.test(code) || !uuid.test(installationId) ||
        !await validSigningKey(publicKey) || !terminalName || terminalName.length > 120 ||
        !model || model.length > 120 || !androidVersion || androidVersion.length > 64 ||
        !appVersion || appVersion.length > 64
      ) {
        return json({ error_code: 'DEVICE_ENROLLMENT_INVALID_REQUEST' }, 400);
      }
      const { data: enrollment, error: enrollmentError } = await admin
        .from('codigos_enrolamiento_dispositivo').select('id,empresa_id,sucursal_id,tipo_uso')
        .eq('codigo_hash', await hash(code)).is('usado_at', null).is('revocado_at', null)
        .gt('expires_at', new Date().toISOString()).maybeSingle();
      if (enrollmentError) throw enrollmentError;
      if (!enrollment) return json({ error_code: 'DEVICE_ENROLLMENT_CODE_INVALID' }, 403);
      if (requestedCompanyId && (!uuid.test(requestedCompanyId) || requestedCompanyId !== enrollment.empresa_id)) {
        return json({ error_code: 'DEVICE_ENROLLMENT_TENANT_MISMATCH' }, 403);
      }
      const deviceId = crypto.randomUUID();
      const credential = random(32);
      const now = new Date().toISOString();
      const { error } = await admin.rpc('enroll_android_device_internal', {
        payload: {
          enrollment_id: enrollment.id,
          device_id: deviceId,
          installation_id: installationId,
          public_key_spki: publicKey,
          name: terminalName,
          model,
          android_version: androidVersion,
          app_version: appVersion,
          token_hash: await hash(credential),
          now,
        },
      });
      if (error) throw error;
      const { error: configurationError } = await admin.rpc(
        'aplicar_configuracion_codigo_terminal_internal',
        { p_enrollment: enrollment.id, p_device: deviceId },
      );
      if (configurationError) throw configurationError;
      return json({
        device_id: deviceId,
        credential,
        terminal_config: { branch_id: enrollment.sucursal_id, usage_type: enrollment.tipo_uso ?? 'GENERAL' },
        expires_at: new Date(Date.now() + 30 * 86_400_000).toISOString(),
      });
    }

    if (action === 'employee-sync') {
      const deviceId = text(request.headers.get('x-device-id'));
      const credential = text(request.headers.get('x-device-credential'));
      if (!uuid.test(deviceId) || !/^[0-9a-f]{64}$/i.test(credential)) {
        return json({ error_code: 'DEVICE_CREDENTIAL_REQUIRED' }, 401);
      }
      const now = new Date().toISOString();
      const { data: auth, error: authError } = await admin
        .from('credenciales_dispositivo').select('empresa_id,dispositivo_id')
        .eq('dispositivo_id', deviceId).eq('token_hash', await hash(credential))
        .is('revocado_at', null).gt('expires_at', now).maybeSingle();
      if (authError) throw authError;
      if (!auth) return json({ error_code: 'DEVICE_CREDENTIAL_INVALID' }, 401);
      const { data: device, error: deviceError } = await admin
        .from('dispositivos_android').select('id,sucursal_id,tipo_uso,configuracion_revision')
        .eq('id', deviceId).eq('empresa_id', auth.empresa_id).eq('estado', 'activo').maybeSingle();
      if (deviceError) throw deviceError;
      if (!device) return json({ error_code: 'DEVICE_REVOKED' }, 403);
      const { data: configuredDepartments, error: departmentsError } = await admin
        .from('dispositivo_departamentos').select('departamento_id')
        .eq('empresa_id', auth.empresa_id).eq('dispositivo_id', deviceId);
      if (departmentsError) throw departmentsError;
      const allowedDepartments = new Set((configuredDepartments ?? []).map((row) => row.departamento_id));
      const terminalMode = device.tipo_uso === 'DEPARTMENTS' ? 'DEPARTMENTS' : 'GENERAL';
      const { data: employees, error } = await admin.from('empleados')
        .select('id,codigo_empleado,nombre_completo,telefono,activo,sucursal_id,departamento_id,estado_laboral,updated_at')
        .eq('empresa_id', auth.empresa_id).eq('activo', true).eq('estado_laboral', 'activo').order('id');
      if (error) throw error;
      const eligibleEmployees = (employees ?? []).filter((employee) =>
        terminalMode === 'GENERAL' || allowedDepartments.has(employee.departamento_id));
      const { data: pendingMessages, error: messageError } = await admin.rpc(
        'obtener_mensajes_pendientes_dispositivo',
        { p_empresa: auth.empresa_id, p_dispositivo: deviceId },
      );
      if (messageError) throw messageError;
      const messages = await Promise.all(
        ((pendingMessages ?? []) as Record<string, unknown>[]).map(async (message) => {
          const audioObjectPath = text(message.audio_object_path);
          if (!audioObjectPath) return message;
          const { data: signed } = await admin.storage.from('employee-message-audio').createSignedUrl(audioObjectPath, 600);
          return { ...message, audio_url: signed?.signedUrl ?? null, audio_object_path: undefined };
        }),
      );
      await admin.from('dispositivos_android').update({ ultima_conexion_at: now }).eq('id', deviceId).eq('empresa_id', auth.empresa_id);
      await admin.from('credenciales_dispositivo').update({ ultima_uso_at: now }).eq('dispositivo_id', deviceId).eq('empresa_id', auth.empresa_id);
      return json({
        employees: eligibleEmployees,
        messages,
        synced_at: now,
        terminal_config: {
          branch_id: device.sucursal_id,
          usage_type: terminalMode,
          department_ids: [...allowedDepartments],
          configuration_revision: Number(device.configuracion_revision ?? 0),
        },
      });
    }

    const jwt = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
    if (!jwt) return json({ error_code: 'SESSION_REQUIRED' }, 401);
    const caller = createClient(url, anon, {
      global: { headers: { Authorization: 'Bearer ' + jwt } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user } } = await admin.auth.getUser(jwt);
    if (!user) return json({ error_code: 'SESSION_INVALID' }, 401);
    const { data: profile } = await admin.from('profiles').select('company_id').eq('id', user.id).eq('status', 'active').maybeSingle();
    if (!profile) return json({ error_code: 'ACTIVE_PROFILE_REQUIRED' }, 403);
    if (!['list', 'create-code', 'configure', 'revoke'].includes(action)) return json({ error_code: 'ACTION_NOT_SUPPORTED' }, 400);
    const permission = action === 'list' ? 'dispositivos.ver' : action === 'revoke' ? 'dispositivos.revocar' : 'dispositivos.registrar';
    const { data: allowed } = await caller.rpc('tiene_permiso', { codigo_permiso: permission });
    if (allowed !== true) return json({ error_code: 'PERMISSION_REQUIRED' }, 403);

    if (action === 'list') {
      const [{ data, error }, { data: credentials, error: credentialsError }, { data: departments, error: departmentsError }] = await Promise.all([
        admin.from('dispositivos_android')
          .select('id,nombre,modelo,android_version,app_version,sucursal_id,tipo_uso,configuracion_revision,estado,registrado_at,ultima_conexion_at,revocado_at')
          .eq('empresa_id', profile.company_id).order('registrado_at', { ascending: false }),
        admin.from('credenciales_dispositivo').select('dispositivo_id,ultima_uso_at,created_at').eq('empresa_id', profile.company_id).order('created_at', { ascending: false }),
        admin.from('dispositivo_departamentos').select('dispositivo_id,departamento_id').eq('empresa_id', profile.company_id),
      ]);
      if (error) throw error;
      if (credentialsError) throw credentialsError;
      if (departmentsError) throw departmentsError;
      const lastSync = new Map<string, string | null>();
      const departmentsByDevice = new Map<string, string[]>();
      for (const row of credentials ?? []) if (!lastSync.has(row.dispositivo_id)) lastSync.set(row.dispositivo_id, row.ultima_uso_at);
      for (const row of departments ?? []) departmentsByDevice.set(row.dispositivo_id, [...(departmentsByDevice.get(row.dispositivo_id) ?? []), row.departamento_id]);
      return json({ devices: (data ?? []).map((device) => ({
        ...device,
        department_ids: departmentsByDevice.get(device.id) ?? [],
        ultima_sincronizacion_at: lastSync.get(device.id) ?? null,
      })) });
    }

    if (action === 'create-code') {
      const branchId = text(body.branch_id);
      const terminalMode = usageType(body.usage_type || 'GENERAL');
      const selectedDepartments = departmentIds(body.department_ids);
      if (!uuid.test(branchId)) return json({ error_code: 'DEVICE_BRANCH_REQUIRED' }, 400);
      if (!['GENERAL', 'DEPARTMENTS'].includes(terminalMode)) return json({ error_code: 'DEVICE_USAGE_TYPE_INVALID' }, 400);
      if (terminalMode === 'DEPARTMENTS' && selectedDepartments.length === 0) return json({ error_code: 'DEVICE_DEPARTMENT_REQUIRED' }, 400);
      const { data: branch } = await admin.from('branches').select('id')
        .eq('id', branchId).eq('company_id', profile.company_id).eq('status', 'active').maybeSingle();
      if (!branch) return json({ error_code: 'DEVICE_BRANCH_INVALID' }, 400);
      if (selectedDepartments.length > 0) {
        const { data: validDepartments, error: validationError } = await admin.from('departments')
          .select('id').eq('company_id', profile.company_id).eq('branch_id', branchId)
          .eq('is_active', true).in('id', selectedDepartments);
        if (validationError) throw validationError;
        if ((validDepartments ?? []).length !== selectedDepartments.length) return json({ error_code: 'DEVICE_DEPARTMENT_INVALID' }, 400);
      }
      const code = random(8).toUpperCase();
      const expiresAt = new Date(Date.now() + 10 * 60_000).toISOString();
      const { data: enrollment, error } = await admin.from('codigos_enrolamiento_dispositivo').insert({
        empresa_id: profile.company_id,
        sucursal_id: branchId,
        tipo_uso: terminalMode,
        codigo_hash: await hash(code),
        expires_at: expiresAt,
        creado_por: user.id,
      }).select('id').single();
      if (error) throw error;
      if (terminalMode === 'DEPARTMENTS') {
        const { error: departmentError } = await admin.from('codigo_enrolamiento_departamentos').insert(
          selectedDepartments.map((departmentId) => ({
            empresa_id: profile.company_id,
            codigo_enrolamiento_id: enrollment.id,
            departamento_id: departmentId,
          })),
        );
        if (departmentError) throw departmentError;
      }
      return json({ code, expires_at: expiresAt });
    }

    if (action === 'configure') {
      const deviceId = text(body.device_id);
      const branchId = text(body.branch_id);
      const terminalMode = usageType(body.usage_type);
      const selectedDepartments = departmentIds(body.department_ids);
      if (!uuid.test(deviceId) || !uuid.test(branchId) || !['GENERAL', 'DEPARTMENTS'].includes(terminalMode)) {
        return json({ error_code: 'DEVICE_CONFIGURATION_INVALID' }, 400);
      }
      if (terminalMode === 'DEPARTMENTS' && selectedDepartments.length === 0) return json({ error_code: 'DEVICE_DEPARTMENT_REQUIRED' }, 400);
      const { data, error } = await caller.rpc('configurar_terminal', {
        payload: { device_id: deviceId, branch_id: branchId, usage_type: terminalMode, department_ids: selectedDepartments },
      });
      if (error) return json({ error_code: error.code || 'DEVICE_CONFIGURATION_REJECTED' }, 409);
      return json({ device: data });
    }

    const deviceId = text(body.device_id);
    if (!uuid.test(deviceId)) return json({ error_code: 'DEVICE_ID_INVALID' }, 400);
    const now = new Date().toISOString();
    const { data: device, error } = await admin.from('dispositivos_android')
      .update({ estado: 'revocado', revocado_at: now })
      .eq('id', deviceId).eq('empresa_id', profile.company_id).select('id').maybeSingle();
    if (error) throw error;
    if (!device) return json({ error_code: 'DEVICE_NOT_FOUND' }, 404);
    const { error: credentialError } = await admin.from('credenciales_dispositivo')
      .update({ revocado_at: now }).eq('dispositivo_id', deviceId).eq('empresa_id', profile.company_id);
    if (credentialError) throw credentialError;
    return json({ id: device.id, status: 'revocado' });
  } catch (error) {
    console.error('DEVICE_ENROLLMENT_ERROR', { name: error instanceof Error ? error.name : 'UnknownError' });
    return json({ error_code: 'DEVICE_ENROLLMENT_ERROR' }, 500);
  }
});
