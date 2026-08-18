import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import ts from 'typescript';

const loadTypeScriptModule = async (url) => {
  const source = await readFile(url, 'utf8');
  const javascript = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
    fileName: pathToFileURL(url.pathname).href,
  }).outputText;
  return import(`data:text/javascript;base64,${Buffer.from(javascript).toString('base64')}`);
};

const policy = await loadTypeScriptModule(
  new URL('../src/modules/userProvisioning/supervisorScopePolicy.ts', import.meta.url),
);

const departments = [
  { id: 'dep-a1', branch_id: 'branch-a', is_active: true },
  { id: 'dep-a2', branch_id: 'branch-a', is_active: true },
  { id: 'dep-a-off', branch_id: 'branch-a', is_active: false },
  { id: 'dep-b1', branch_id: 'branch-b', is_active: true },
  { id: 'dep-corporate', branch_id: null, is_active: true },
  { id: 'dep-a1', branch_id: 'branch-a', is_active: true },
];

// El cliente solo acepta el codigo canonico exacto que entrega el servidor.
assert.equal(policy.isSupervisorCanonicalRole('SUPERVISOR'), true);
assert.equal(policy.isSupervisorCanonicalRole('supervisor'), false);
assert.equal(policy.isSupervisorCanonicalRole('SUP'), false);
assert.equal(policy.isSupervisorCanonicalRole(null), false);
assert.deepEqual(
  policy.buildSupervisorScopeRequest(
    undefined,
    { branchId: 'branch-a', departmentIds: ['dep-a1'] },
    departments,
  ),
  { ok: false, error: 'ROLE_CANONICAL_REQUIRED' },
);

// Solo se muestran departamentos activos de la sucursal seleccionada.
assert.deepEqual(
  policy.activeDepartmentsForBranch(departments, 'branch-a').map(({ id }) => id),
  ['dep-a1', 'dep-a2', 'dep-a1'],
);
assert.deepEqual(
  policy.selectAllActiveDepartmentIds(departments, 'branch-a'),
  ['dep-a1', 'dep-a2'],
);

// La seleccion conserva orden y elimina duplicados.
assert.deepEqual(policy.deduplicateDepartmentIds(['dep-a1', 'dep-a2', 'dep-a1']), ['dep-a1', 'dep-a2']);

// Agregar y quitar departamentos no produce duplicados.
assert.deepEqual(policy.toggleDepartmentSelection(['dep-a1'], 'dep-a2', true), ['dep-a1', 'dep-a2']);
assert.deepEqual(policy.toggleDepartmentSelection(['dep-a1'], 'dep-a1', true), ['dep-a1']);
assert.deepEqual(policy.toggleDepartmentSelection(['dep-a1', 'dep-a2'], 'dep-a1', false), ['dep-a2']);

// Cambiar de sucursal limpia selecciones incompatibles; mantenerla las deduplica.
assert.deepEqual(
  policy.changeSupervisorBranch(
    { branchId: 'branch-a', departmentIds: ['dep-a1', 'dep-a1'] },
    'branch-b',
  ),
  { branchId: 'branch-b', departmentIds: [] },
);
assert.deepEqual(
  policy.changeSupervisorBranch(
    { branchId: 'branch-a', departmentIds: ['dep-a1', 'dep-a1'] },
    'branch-a',
  ),
  { branchId: 'branch-a', departmentIds: ['dep-a1'] },
);

// Un supervisor con un departamento es valido.
assert.deepEqual(
  policy.validateSupervisorScope(
    'SUPERVISOR',
    { branchId: 'branch-a', departmentIds: ['dep-a1'] },
    departments,
  ),
  { valid: true, applies: true, branchId: 'branch-a', departmentIds: ['dep-a1'] },
);

// Un supervisor con varios departamentos validos conserva ambos y deduplica.
assert.deepEqual(
  policy.validateSupervisorScope(
    'SUPERVISOR',
    { branchId: 'branch-a', departmentIds: ['dep-a1', 'dep-a2', 'dep-a1'] },
    departments,
  ),
  { valid: true, applies: true, branchId: 'branch-a', departmentIds: ['dep-a1', 'dep-a2'] },
);

// Sucursal y al menos un departamento son obligatorios para SUPERVISOR.
assert.deepEqual(
  policy.validateSupervisorScope(
    'SUPERVISOR',
    { branchId: '', departmentIds: ['dep-a1'] },
    departments,
  ),
  { valid: false, error: 'SUPERVISOR_BRANCH_REQUIRED' },
);
assert.deepEqual(
  policy.validateSupervisorScope(
    'SUPERVISOR',
    { branchId: 'branch-a', departmentIds: [] },
    departments,
  ),
  { valid: false, error: 'SIN_DEPARTAMENTOS' },
);

// Un cambio de otro rol a SUPERVISOR tambien exige el alcance completo.
assert.deepEqual(
  policy.buildSupervisorScopeRequest(
    'SUPERVISOR',
    { branchId: 'branch-a', departmentIds: [] },
    departments,
  ),
  { ok: false, error: 'SIN_DEPARTAMENTOS' },
);

// IDs de otra sucursal o inactivos quedan rechazados.
assert.deepEqual(
  policy.validateSupervisorScope(
    'SUPERVISOR',
    { branchId: 'branch-a', departmentIds: ['dep-b1'] },
    departments,
  ),
  { valid: false, error: 'SUPERVISOR_DEPARTMENTS_INVALID' },
);
assert.deepEqual(
  policy.validateSupervisorScope(
    'SUPERVISOR',
    { branchId: 'branch-a', departmentIds: ['dep-a-off'] },
    departments,
  ),
  { valid: false, error: 'SUPERVISOR_DEPARTMENTS_INVALID' },
);

// Para roles no supervisores se omite por completo el alcance del request.
const adminResult = policy.buildSupervisorScopeRequest(
  'ADMIN',
  { branchId: 'branch-a', departmentIds: ['dep-a1'] },
  departments,
);
assert.deepEqual(adminResult, { ok: true, scope: null });
assert.deepEqual({ action: 'update-access', ...(adminResult.scope ?? {}) }, { action: 'update-access' });

// El request valido usa nombres de contrato y seleccion deduplicada.
assert.deepEqual(
  policy.buildSupervisorScopeRequest(
    'SUPERVISOR',
    { branchId: 'branch-a', departmentIds: ['dep-a2', 'dep-a1', 'dep-a2'] },
    departments,
  ),
  {
    ok: true,
    scope: { branch_id: 'branch-a', department_ids: ['dep-a2', 'dep-a1'] },
  },
);

console.log('supervisorScopePolicy: PASS');
