import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');
const [migration, attendance, employeeSync, deviceEnrollment, inbox, auth, pages, payroll] = await Promise.all([
  read('../supabase/migrations/0050_p0_functional_contracts.sql'),
  read('../supabase/functions/attendance-sync/index.ts'),
  read('../supabase/functions/employee-sync/index.ts'),
  read('../supabase/functions/device-enrollment/index.ts'),
  read('../app/src/main/java/messages/EmployeeMessageInbox.kt'),
  read('src/context/AuthContext.tsx'),
  read('src/pages/P0OperationsPages.tsx'),
  read('src/modules/payroll/payrollService.ts'),
]);

assert.match(migration, /tipo_uso/);
assert.match(migration, /DEPARTMENTS/);
assert.match(migration, /salario[^\n]*30|\/\s*30/si);
assert.match(migration, /ajustes_periodos_anteriores|ajuste.*anterior/si);
assert.match(attendance, /TERMINAL NO AUTORIZADO PARA SU DEPARTAMENTO/);
assert.match(attendance, /branch_id: device\.sucursal_id/);
assert.match(employeeSync, /configuration_revision/);
assert.match(employeeSync, /obtener_mensajes_pendientes_dispositivo/);
assert.match(deviceEnrollment, /GENERAL/);
assert.match(deviceEnrollment, /DEPARTMENTS/);
assert.match(inbox, /reconcilePreloaded/);
assert.match(inbox, /AndroidKeyStore/);
assert.match(auth, /5_000|5000/);
assert.doesNotMatch(pages, /aprobar licencia|rechazar licencia/i);
assert.match(pages, /NO PAGAR/);
assert.match(pages, /Seguimiento, no bloqueo/);
assert.match(payroll, /calcular_nomina_p0/);
console.log('P0 contract checks passed');
