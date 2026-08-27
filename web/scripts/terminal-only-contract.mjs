import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');
const navigation = read('../../app/src/main/java/com/example/controlhorario/ui/navigation/AppNavigation.kt');
const camera = read('../../app/src/main/java/com/example/controlhorario/ui/face/FaceIdentificationScreen.kt');
const terminalClient = read('../../app/src/main/java/com/example/controlhorario/face/AndroidTerminalFaceEnrollmentGateway.kt');
const edge = read('../../supabase/functions/face-enrollment/index.ts');
const migration = read('../../supabase/migrations/0060_terminal_face_enrollment.sql');
const app = read('../src/App.tsx');
const card = read('../src/modules/face-enrollment/FaceEnrollmentCard.tsx');
const form = read('../src/pages/EmployeeFormPage.tsx');
const pdf = read('../src/modules/face-enrollment/faceInvitationPdf.ts');
const index = read('../index.html');

assert.ok(navigation.includes('TerminalScreen.FACE_ENROLLMENT'));
assert.ok(!navigation.includes('LoginScreen'));
assert.ok(camera.includes('PendingFaceEnrollmentButtonPolicy.visible(pendingFaceCount)'));
assert.ok(camera.includes('onRegisterFace'));
assert.ok(terminalClient.includes('x-device-signature'));
assert.ok(terminalClient.includes('identity.sign'));
assert.ok(edge.includes("['lookup', 'complete']"));
assert.ok(edge.includes("namedCurve: 'P-256'"));
assert.ok(edge.includes('FACE_QR_ENROLLMENT_DEPRECATED'));
assert.ok(migration.includes('cardinality(h.dias_laborales) between 1 and 6'));
assert.ok(migration.includes('FACE_DUPLICATE'));
assert.ok(migration.includes("face_enrollment_source='ANDROID_TERMINAL'"));
assert.ok(!app.includes('path="/enrolar-rostro"'));
assert.ok(!card.includes('createInvitation'));
assert.ok(!card.includes('enrollment_url'));
assert.ok(!form.includes('QR'));
assert.ok(!pdf.includes("from 'qrcode'"));
assert.ok(pdf.includes('no contiene QR, token ni credencial'));
assert.ok(!index.includes('/vendor/tfjs/'));
assert.ok(!index.includes('/vendor/tflite/'));
for (const obsoletePath of [
  '../face-runtime-compat.html',
  './face-model-runtime-compat.mjs',
  '../public/vendor/tfjs',
  '../public/vendor/tflite',
  '../public/models/face_landmarker.task',
  '../public/models/facenet.tflite',
]) {
  assert.equal(existsSync(new URL(obsoletePath, import.meta.url)), false, obsoletePath);
}
console.log('PASS Android terminal-only enrollment contract');
console.log('PASS pending button is conditional and server-authoritative');
console.log('PASS terminal credential and P-256 signature are required');
console.log('PASS public QR route and UI are removed');
console.log('PASS browser face runtimes and models are removed');
