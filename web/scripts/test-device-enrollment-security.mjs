import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(process.cwd(), '..');
const android = readFileSync(resolve(root, 'app/src/main/java/com/example/controlhorario/device/DeviceEnrollmentClient.kt'), 'utf8');
const enrollment = readFileSync(resolve(root, 'supabase/functions/device-enrollment/index.ts'), 'utf8');
const employeeSync = readFileSync(resolve(root, 'supabase/functions/employee-sync/index.ts'), 'utf8');
const attendance = readFileSync(resolve(root, 'supabase/functions/attendance-sync/index.ts'), 'utf8');
const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

assert(!android.includes('Response Body completo'), 'Android must not log the enrollment response');
assert(!android.includes('JSONObject(response).also'), 'Android must not log parsed enrollment JSON');
assert(enrollment.includes("crypto.subtle.importKey('spki'"), 'Edge must validate the P-256 public key');
assert(enrollment.includes("terminalMode === 'GENERAL' || allowedDepartments.has"), 'Legacy sync must support GENERAL and DEPARTMENTS');
assert(!enrollment.includes("employeeQuery.eq('sucursal_id', device.sucursal_id)"), 'GENERAL must not be branch-scoped');
assert(employeeSync.includes(".eq('empresa_id',auth.empresa_id)"), 'Employee sync must isolate companies');
assert(employeeSync.includes("terminalMode==='GENERAL'||terminalDepartmentSet.has"), 'Employee sync must enforce department mode');
assert(attendance.includes("terminal_empleado_elegible"), 'Attendance must enforce eligibility on the server');
assert(attendance.includes('branch_id: device.sucursal_id'), 'Attendance must preserve the terminal branch');
assert(attendance.includes('TERMINAL NO AUTORIZADO PARA SU DEPARTAMENTO'), 'Department rejection must be exact');
assert(enrollment.includes("return json({ error_code: 'DEVICE_ENROLLMENT_ERROR' }, 500)"), 'Internal errors must be generic');
assert(!/return json\(\{ error: error instanceof Error \? error\.message/.test(enrollment), 'Internal errors must not leak');
console.log('deviceEnrollmentSecurity: PASS');
