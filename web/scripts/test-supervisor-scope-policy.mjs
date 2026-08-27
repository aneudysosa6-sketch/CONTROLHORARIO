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
  return import('data:text/javascript;base64,' + Buffer.from(javascript).toString('base64'));
};

const policy = await loadTypeScriptModule(new URL('../src/modules/userProvisioning/supervisorScopePolicy.ts', import.meta.url));
const departments = [
  { id: 'dep-a1', branch_id: 'branch-a', is_active: true },
  { id: 'dep-a2', branch_id: 'branch-a', is_active: true },
  { id: 'dep-a-off', branch_id: 'branch-a', is_active: false },
  { id: 'dep-b1', branch_id: 'branch-b', is_active: true },
  { id: 'dep-corporate', branch_id: null, is_active: true },
  { id: 'dep-a1', branch_id: 'branch-a', is_active: true },
];

assert.equal(policy.isSupervisorCanonicalRole('SUPERVISOR'), true);
assert.equal(policy.isSupervisorCanonicalRole('supervisor'), false);
assert.deepEqual(policy.buildSupervisorScopeRequest(undefined, { branchIds: ['branch-a'], departmentIds: ['dep-a1'] }, departments), { ok: false, error: 'ROLE_CANONICAL_REQUIRED' });
assert.deepEqual(policy.selectAllActiveDepartmentIds(departments, ['branch-a', 'branch-b']), ['dep-a1', 'dep-a2', 'dep-b1']);
assert.deepEqual(policy.deduplicateDepartmentIds(['dep-a1', 'dep-a2', 'dep-a1']), ['dep-a1', 'dep-a2']);
assert.deepEqual(policy.deduplicateBranchIds(['branch-a', 'branch-b', 'branch-a']), ['branch-a', 'branch-b']);
assert.deepEqual(policy.toggleDepartmentSelection(['dep-a1'], 'dep-a2', true), ['dep-a1', 'dep-a2']);

assert.deepEqual(
  policy.toggleSupervisorBranch({ branchIds: ['branch-a', 'branch-b'], departmentIds: ['dep-a1', 'dep-b1'] }, 'branch-b', false, departments),
  { branchIds: ['branch-a'], departmentIds: ['dep-a1'] },
);
assert.deepEqual(
  policy.toggleSupervisorBranch({ branchIds: ['branch-a'], departmentIds: ['dep-a1'] }, 'branch-b', true, departments),
  { branchIds: ['branch-a', 'branch-b'], departmentIds: ['dep-a1'] },
);
assert.deepEqual(
  policy.validateSupervisorScope('SUPERVISOR', { branchIds: ['branch-a', 'branch-b'], departmentIds: ['dep-a1', 'dep-b1'] }, departments),
  { valid: true, applies: true, branchIds: ['branch-a', 'branch-b'], departmentIds: ['dep-a1', 'dep-b1'] },
);
assert.deepEqual(policy.validateSupervisorScope('SUPERVISOR', { branchIds: [], departmentIds: ['dep-a1'] }, departments), { valid: false, error: 'SUPERVISOR_BRANCH_REQUIRED' });
assert.deepEqual(policy.validateSupervisorScope('SUPERVISOR', { branchIds: ['branch-a'], departmentIds: [] }, departments), { valid: false, error: 'SIN_DEPARTAMENTOS' });
assert.deepEqual(
  policy.validateSupervisorScope('SUPERVISOR', { branchIds: ['branch-a', 'branch-b'], departmentIds: ['dep-a1'] }, departments),
  { valid: false, error: 'SUPERVISOR_BRANCH_WITHOUT_DEPARTMENTS' },
);
assert.deepEqual(policy.validateSupervisorScope('SUPERVISOR', { branchIds: ['branch-a'], departmentIds: ['dep-b1'] }, departments), { valid: false, error: 'SUPERVISOR_DEPARTMENTS_INVALID' });
assert.deepEqual(policy.validateSupervisorScope('SUPERVISOR', { branchIds: ['branch-a'], departmentIds: ['dep-a-off'] }, departments), { valid: false, error: 'SUPERVISOR_DEPARTMENTS_INVALID' });

const adminResult = policy.buildSupervisorScopeRequest('ADMIN', { branchIds: ['branch-a'], departmentIds: ['dep-a1'] }, departments);
assert.deepEqual(adminResult, { ok: true, scope: null });
assert.deepEqual({ action: 'update-access', ...(adminResult.scope ?? {}) }, { action: 'update-access' });
assert.deepEqual(
  policy.buildSupervisorScopeRequest('SUPERVISOR', { branchIds: ['branch-a', 'branch-b'], departmentIds: ['dep-a2', 'dep-b1', 'dep-a2'] }, departments),
  { ok: true, scope: { branch_ids: ['branch-a', 'branch-b'], department_ids: ['dep-a2', 'dep-b1'] } },
);
console.log('supervisorScopePolicy: PASS');