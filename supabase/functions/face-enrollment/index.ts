import { createClient } from '@supabase/supabase-js'

const encoder = new TextEncoder()
const text = (value: unknown) => typeof value === 'string' ? value.trim() : ''
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const employeeCode = /^[0-9]{6}$/
const sha256 = async (value: string) => Array.from(
  new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value))),
).map((byte) => byte.toString(16).padStart(2, '0')).join('')
const bytes = (value: string) => Uint8Array.from(atob(value), (character) => character.charCodeAt(0))
const responseHeaders = {
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
  'Referrer-Policy': 'no-referrer',
}
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: responseHeaders })
const validEmbedding = (value: unknown): value is number[] => Array.isArray(value) &&
  value.length === 128 && value.every((item) => typeof item === 'number' && Number.isFinite(item) && Math.abs(item) <= 1.000001)
const embeddingSha256 = async (value: number[]) => {
  const buffer = new ArrayBuffer(value.length * 4)
  const view = new DataView(buffer)
  value.forEach((item, index) => view.setFloat32(index * 4, Math.fround(item), true))
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', buffer)))
    .map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

function derToRaw(der: Uint8Array): Uint8Array {
  let offset = 0
  if (der[offset++] !== 0x30) throw new Error('FACE_SIGNATURE_INVALID')
  let sequenceLength = der[offset++]
  if ((sequenceLength & 0x80) !== 0) {
    const count = sequenceLength & 0x7f
    sequenceLength = 0
    for (let index = 0; index < count; index++) sequenceLength = (sequenceLength << 8) | der[offset++]
  }
  if (sequenceLength <= 0 || der[offset++] !== 0x02) throw new Error('FACE_SIGNATURE_INVALID')
  const rLength = der[offset++]
  const r = der.slice(offset, offset + rLength)
  offset += rLength
  if (der[offset++] !== 0x02) throw new Error('FACE_SIGNATURE_INVALID')
  const sLength = der[offset++]
  const s = der.slice(offset, offset + sLength)
  const raw = new Uint8Array(64)
  const normalizedR = r[0] === 0 ? r.slice(1) : r
  const normalizedS = s[0] === 0 ? s.slice(1) : s
  if (normalizedR.length > 32 || normalizedS.length > 32) throw new Error('FACE_SIGNATURE_INVALID')
  raw.set(normalizedR, 32 - normalizedR.length)
  raw.set(normalizedS, 64 - normalizedS.length)
  return raw
}

async function verifyRequestSignature(
  publicKeySpki: string,
  signatureBase64: string,
  requestId: string,
  deviceId: string,
  occurredAt: string,
  rawBody: string,
) {
  try {
    const key = await crypto.subtle.importKey(
      'spki', bytes(publicKeySpki), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify'],
    )
    const bodyHash = await sha256(rawBody)
    return await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      key,
      derToRaw(bytes(signatureBase64)),
      encoder.encode(requestId + '|' + deviceId + '|' + occurredAt + '|' + bodyHash),
    )
  } catch {
    return false
  }
}

function errorCode(error: unknown) {
  const value = error && typeof error === 'object' ? error as Record<string, unknown> : {}
  return text(value.message) || text(value.code) || 'FACE_ENROLLMENT_ERROR'
}

function statusFor(code: string) {
  if (code === 'FACE_QR_ENROLLMENT_DEPRECATED') return 410
  if (code.includes('DEVICE_REVOKED') || code.includes('SCOPE_DENIED')) return 403
  if (code.includes('CREDENTIAL') || code.includes('SIGNATURE')) return 401
  if (code.includes('DUPLICATE') || code.includes('ALREADY_REGISTERED') || code.includes('IDEMPOTENCY')) return 409
  if (code.includes('SCHEDULE') || code.includes('NOT_ELIGIBLE') || code.includes('LIVENESS')) return 422
  if (code.includes('INVALID') || code.includes('NOT_FOUND')) return 400
  return 500
}

const publicMessage = (code: string) => {
  if (code === 'SCHEDULE_DAYOFF_REQUIRED') return 'SUPERVISOR DEBE ASIGNAR HORARIO Y DÍA LIBRE'
  if (code === 'FACE_DUPLICATE') return 'Rostro ya registrado en otro empleado'
  if (code === 'FACE_ALREADY_REGISTERED') return 'Este empleado ya tiene un rostro registrado.'
  return undefined
}

Deno.serve(async (request) => {
  const diagnosticRequestId = crypto.randomUUID()
  if (request.method === 'OPTIONS') return new Response(null, { status: 204 })
  if (request.method !== 'POST') return json({ error_code: 'METHOD_NOT_ALLOWED', request_id: diagnosticRequestId }, 405)
  const rawBody = await request.text()
  let body: Record<string, unknown>
  try {
    body = JSON.parse(rawBody) as Record<string, unknown>
  } catch {
    return json({ error_code: 'INVALID_PAYLOAD', request_id: diagnosticRequestId }, 400)
  }
  const action = text(body.action).toLowerCase()
  if (['create', 'exchange', 'revoke'].includes(action) || 'token' in body) {
    return json({ error_code: 'FACE_QR_ENROLLMENT_DEPRECATED', request_id: diagnosticRequestId }, 410)
  }
  if (!['lookup', 'complete'].includes(action)) {
    return json({ error_code: 'FACE_ACTION_INVALID', request_id: diagnosticRequestId }, 400)
  }

  try {
    const url = text(Deno.env.get('SUPABASE_URL'))
    const service = text(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))
    if (!url || !service) throw new Error('FACE_ENROLLMENT_CONFIGURATION_MISSING')
    const deviceId = text(request.headers.get('x-device-id'))
    const credential = text(request.headers.get('x-device-credential'))
    const requestId = text(request.headers.get('x-device-request-id'))
    const signature = text(request.headers.get('x-device-signature'))
    const occurredAt = text(body.occurred_at)
    if (!uuid.test(deviceId) || credential.length !== 64 || !uuid.test(requestId) ||
        requestId !== text(body.request_id) || !signature || !Number.isFinite(Date.parse(occurredAt)) ||
        Math.abs(Date.now() - Date.parse(occurredAt)) > 90_000) {
      return json({ error_code: 'INVALID_DEVICE_CREDENTIAL', request_id: diagnosticRequestId }, 401)
    }

    const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } })
    const now = new Date().toISOString()
    const { data: credentialRow, error: credentialError } = await admin.from('credenciales_dispositivo')
      .select('empresa_id,expires_at')
      .eq('dispositivo_id', deviceId)
      .eq('token_hash', await sha256(credential))
      .is('revocado_at', null)
      .gt('expires_at', now)
      .maybeSingle()
    if (credentialError) throw credentialError
    if (!credentialRow) return json({ error_code: 'INVALID_DEVICE_CREDENTIAL', request_id: diagnosticRequestId }, 401)
    const { data: device, error: deviceError } = await admin.from('dispositivos_android')
      .select('id,empresa_id,estado,public_key_spki')
      .eq('id', deviceId)
      .eq('empresa_id', credentialRow.empresa_id)
      .maybeSingle()
    if (deviceError) throw deviceError
    if (!device || device.estado !== 'activo') {
      return json({ error_code: 'DEVICE_REVOKED', request_id: diagnosticRequestId }, 403)
    }
    if (!await verifyRequestSignature(device.public_key_spki, signature, requestId, deviceId, occurredAt, rawBody)) {
      return json({ error_code: 'FACE_SIGNATURE_INVALID', request_id: diagnosticRequestId }, 401)
    }

    if (action === 'lookup') {
      const code = text(body.employee_code)
      if (!employeeCode.test(code) || code === '000000') {
        return json({ error_code: 'EMPLOYEE_CODE_INVALID', request_id: diagnosticRequestId }, 400)
      }
      const { data, error } = await admin.rpc('terminal_face_enrollment_lookup', {
        p_empresa: credentialRow.empresa_id,
        p_dispositivo: deviceId,
        p_codigo: code,
      })
      if (error) throw error
      const result = (data ?? {}) as Record<string, unknown>
      if (text(result.result) !== 'eligible') {
        const code = text(result.error_code) || 'EMPLOYEE_NOT_ELIGIBLE'
        return json({ error_code: code, message: publicMessage(code), request_id: diagnosticRequestId }, statusFor(code))
      }
      await admin.from('credenciales_dispositivo').update({ ultima_uso_at: now }).eq('dispositivo_id', deviceId)
      return json({
        status: 'ELIGIBLE',
        employee_id: result.employee_id,
        employee_code: result.employee_code,
        employee_name: result.employee_name,
        model_name: 'FaceNet-128',
        embedding_dimension: 128,
        required_poses: ['FRONT', 'LEFT', 'RIGHT'],
        liveness: { blink_required: true },
        request_id: diagnosticRequestId,
      })
    }

    const idempotencyKey = text(body.idempotency_key)
    const employeeId = text(body.employee_id)
    const embedding = body.embedding
    const providedHash = text(body.embedding_sha256).toLowerCase()
    const metadata = body.capture_metadata && typeof body.capture_metadata === 'object'
      ? body.capture_metadata as Record<string, unknown> : {}
    if (!uuid.test(idempotencyKey) || requestId !== idempotencyKey || !uuid.test(employeeId) ||
        !validEmbedding(embedding) || !/^[0-9a-f]{64}$/.test(providedHash) ||
        providedHash !== await embeddingSha256(embedding) ||
        Number(metadata.poses_completed) !== 3 || metadata.blink_verified !== true ||
        text(metadata.client_model) !== 'FaceNet-128') {
      return json({ error_code: 'FACE_LIVENESS_OR_EMBEDDING_INVALID', request_id: diagnosticRequestId }, 422)
    }
    const { data, error } = await admin.rpc('confirmar_enrolamiento_facial_terminal', {
      payload: {
        empresa_id: credentialRow.empresa_id,
        dispositivo_id: deviceId,
        empleado_id: employeeId,
        idempotency_key: idempotencyKey,
        embedding_sha256: providedHash,
        embedding,
        ocurrido_en: occurredAt,
      },
    })
    if (error) throw error
    const result = (data ?? {}) as Record<string, unknown>
    if (!['accepted', 'duplicate'].includes(text(result.result))) {
      const code = text(result.error_code) || 'FACE_ENROLLMENT_ERROR'
      return json({ error_code: code, message: publicMessage(code), request_id: diagnosticRequestId }, statusFor(code))
    }
    await Promise.all([
      admin.from('credenciales_dispositivo').update({ ultima_uso_at: now }).eq('dispositivo_id', deviceId),
      admin.from('dispositivos_android').update({ ultima_conexion_at: now }).eq('id', deviceId),
    ])
    return json({
      status: 'ENROLLED',
      result: result.result,
      employee_id: result.employee_id,
      enrolled_at: result.enrolled_at,
      model_name: result.model_name,
      embedding_dimension: result.embedding_dimension,
      embedding_sha256: result.embedding_sha256,
      face_embedding: result.face_embedding,
      pending_face_count: result.pending_face_count,
      request_id: diagnosticRequestId,
    })
  } catch (error) {
    const code = errorCode(error)
    console.error('TerminalFaceEnrollment failed', { request_id: diagnosticRequestId, error_code: code })
    return json({ error_code: code, message: publicMessage(code), request_id: diagnosticRequestId }, statusFor(code))
  }
})
