import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const edge = readFileSync(new URL('../../supabase/functions/face-enrollment/index.ts', import.meta.url), 'utf8');
const sql = readFileSync(new URL('../../supabase/migrations/0060_terminal_face_enrollment.sql', import.meta.url), 'utf8');
const client = readFileSync(new URL('../../app/src/main/java/com/example/controlhorario/face/AndroidTerminalFaceEnrollmentGateway.kt', import.meta.url), 'utf8');

assert.ok(edge.includes("request.headers.get('x-device-id')"));
assert.ok(edge.includes("request.headers.get('x-device-credential')"));
assert.ok(edge.includes("request.headers.get('x-device-signature')"));
assert.ok(edge.includes('verifyRequestSignature'));
assert.ok(edge.includes('Number(metadata.poses_completed) !== 3'));
assert.ok(edge.includes('metadata.blink_verified !== true'));
assert.ok(edge.includes('view.setFloat32(index * 4, Math.fround(item), true)'));
assert.ok(client.includes('ByteOrder.LITTLE_ENDIAN'));
assert.ok(sql.includes('terminal_face_enrollment_idempotency'));
assert.ok(sql.includes('terminal_empleado_elegible'));
assert.ok(sql.includes('SCHEDULE_DAYOFF_REQUIRED'));
assert.ok(sql.includes('FACE_ALREADY_REGISTERED'));
assert.ok(sql.includes('FACE_DUPLICATE'));
assert.ok(client.includes('FaceNet-128'));
assert.ok(client.includes('embeddingDimension'));
assert.ok(!edge.includes("action === 'exchange'"));
console.log('PASS terminal face enrollment Edge/Android/SQL contract');
