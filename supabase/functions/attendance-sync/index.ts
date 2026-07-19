import { createClient } from '@supabase/supabase-js';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'content-type, x-device-id, x-device-credential' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
const text = (value: unknown) => typeof value === 'string' ? value.trim() : '';
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const isDevelopment = () => Deno.env.get('ENVIRONMENT') === 'development';
const debug = (event: string, payload: Record<string, unknown>) => { if (isDevelopment()) console.log(event, payload); };

const sha256 = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))).map((x) => x.toString(16).padStart(2, '0')).join('');
const b64 = (v: string) => Uint8Array.from(atob(v), (c) => c.charCodeAt(0));
const derToRaw = (der: Uint8Array) => {
  let p = 2;
  if (der[1] & 128) p += der[1] & 127;
  const read = () => { p++; const n = der[p++]; const x = der.slice(p, p + n); p += n; const r = new Uint8Array(32); r.set(x.slice(Math.max(0, x.length - 32)), Math.max(0, 32 - x.length)); return r; };
  const r = read(), s = read(), out = new Uint8Array(64); out.set(r); out.set(s, 32); return out;
};
const businessDate = (occurredAt: string, timezone: string) => {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date(occurredAt));
  const value = (type: Intl.DateTimeFormatPartTypes) => parts.find((part) => part.type === type)?.value ?? '';
  return `${value('year')}-${value('month')}-${value('day')}`;
};

async function validProof(publicKey: string, op: Record<string, unknown>, deviceId: string) {
  const id = text(op.biometric_proof_id), employee = text(op.employee_remote_id), action = text(op.action), issued = text(op.biometric_proof_issued_at), expires = text(op.biometric_proof_expires_at), signature = text(op.biometric_proof_signature);
  if (!uuid.test(id) || !signature || Date.parse(issued) > Date.now() + 60_000 || Date.parse(expires) < Date.now() || Date.parse(expires) - Date.parse(issued) > 90_000) return false;
  const key = await crypto.subtle.importKey('spki', b64(publicKey), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
  return crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, derToRaw(b64(signature)), new TextEncoder().encode(`${id}|${employee}|${deviceId}|${action}|${issued}|${expires}`));
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const requestId = crypto.randomUUID();
  try {
    const deviceId = text(req.headers.get('x-device-id'));
    const credential = text(req.headers.get('x-device-credential'));
    if (!uuid.test(deviceId) || !credential) return json({ error_code: 'INVALID_DEVICE_CREDENTIAL', request_id: requestId }, 401);
    const url = Deno.env.get('SUPABASE_URL'), service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !service) throw new Error('SUPABASE_CONFIGURATION_MISSING');
    const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
    const now = new Date().toISOString();
    const hash = await sha256(credential);
    const { data: auth } = await admin.from('credenciales_dispositivo').select('empresa_id').eq('dispositivo_id', deviceId).eq('token_hash', hash).is('revocado_at', null).gt('expires_at', now).maybeSingle();
    if (!auth) return json({ error_code: 'INVALID_DEVICE_CREDENTIAL', request_id: requestId }, 401);
    const { data: device } = await admin.from('dispositivos_android').select('id,empresa_id,estado,sucursal_id,public_key_spki').eq('id', deviceId).eq('empresa_id', auth.empresa_id).maybeSingle();
    if (!device || device.estado !== 'activo') return json({ error_code: 'DEVICE_REVOKED', request_id: requestId }, 403);
    const { data: company } = await admin.from('companies').select('timezone').eq('id', auth.empresa_id).maybeSingle();
    const timezone = company?.timezone || 'America/Santo_Domingo';
    const body = await req.json() as { operations?: unknown[] };
    if (!Array.isArray(body.operations) || body.operations.length < 1 || body.operations.length > 100) return json({ error_code: 'INVALID_PAYLOAD', request_id: requestId }, 400);

    const results: Record<string, unknown>[] = [];
    for (const raw of body.operations) {
      const op = (raw ?? {}) as Record<string, unknown>;
      const key = text(op.idempotency_key), employee = text(op.employee_remote_id), action = text(op.action), workDate = text(op.work_date), occurred = text(op.occurred_at);
      if (!uuid.test(key) || !uuid.test(employee) || !['INICIAR', 'PAUSAR', 'REANUDAR', 'FINALIZAR'].includes(action) || !/^\d{4}-\d{2}-\d{2}$/.test(workDate) || Number.isNaN(Date.parse(occurred))) {
        results.push({ idempotency_key: key, result: 'rejected', error_code: 'INVALID_PAYLOAD' });
        continue;
      }
      if (!await validProof(device.public_key_spki, op, deviceId)) {
        results.push({ idempotency_key: key, result: 'rejected', error_code: 'BIOMETRIC_PROOF_REQUIRED' });
        continue;
      }
      const localWorkDate = businessDate(occurred, timezone);
      debug('PUNCH_API', { requestId, employeeId: employee, action, endpoint: 'attendance-sync', workDate: localWorkDate, timezone, idempotencyKey: key });
      const payload = {
        ...op,
        contract_version: 1,
        empresa_id: auth.empresa_id,
        empleado_id: employee,
        dispositivo_id: deviceId,
        fecha_laboral: localWorkDate,
        accion: action,
        ocurrido_en: occurred,
        version_conocida: Number(op.known_version ?? 0),
        branch_id: text(op.branch_id) || device.sucursal_id,
        biometric_verified: true,
      };
      const { data, error } = await admin.rpc('registrar_evento_jornada_dispositivo', { payload });
      if (error) {
        debug('PUNCH_API', { requestId, employeeId: employee, action, result: 'rejected', errorCode: error.code });
        results.push({ idempotency_key: key, result: 'rejected', error_code: error.code || 'DATABASE_ERROR' });
        continue;
      }
      debug('PUNCH_API', { requestId, employeeId: employee, action, result: (data as Record<string, unknown>).result ?? 'accepted' });
      results.push({ idempotency_key: key, ...(data as Record<string, unknown>) });
    }
    await admin.from('credenciales_dispositivo').update({ ultima_uso_at: now }).eq('dispositivo_id', deviceId);
    await admin.from('dispositivos_android').update({ ultima_conexion_at: now }).eq('id', deviceId);
    return json({ contract_version: 2, company_id: auth.empresa_id, request_id: requestId, results });
  } catch (error) {
    debug('PUNCH_API', { requestId, result: 'server_error', error: error instanceof Error ? error.message : 'unknown' });
    return json({ error_code: 'ATTENDANCE_SYNC_ERROR', request_id: requestId }, 500);
  }
});
