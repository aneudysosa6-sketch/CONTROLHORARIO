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

const policy = await loadTypeScriptModule(new URL('../src/modules/employees/employeeCodePolicy.ts', import.meta.url));
const mutation = await loadTypeScriptModule(new URL('../src/modules/employees/employeeMutationPayload.ts', import.meta.url));

assert.equal(policy.normalizeEmployeeCode('000001'), '000001');
assert.equal(policy.normalizeEmployeeCode('123456'), '123456');
assert.equal(policy.normalizeEmployeeCode('999999'), '999999');
assert.equal(policy.normalizeEmployeeCode('48575'), '048575');
assert.equal(policy.normalizeEmployeeCode('000000'), null);
assert.equal(policy.normalizeEmployeeCode('1234'), null);
assert.equal(policy.normalizeEmployeeCode('48A75'), null);
assert.equal(policy.normalizeEmployeeCode('1234567'), null);
assert.equal(policy.isValidEmployeeCode('000001'), true);
assert.equal(policy.isValidEmployeeCode('48575'), false);
assert.equal(policy.isAcceptedEmployeeCodeInput('48575'), true);
assert.equal(policy.sanitizeEmployeeCode('12a34567'), '123456');

const employeePayload = mutation.buildEmployeeMutationPayload({
  id: 'employee-id',
  code: 'ignored-input-code',
  pin: 'legacy-value-must-not-leak',
  name: 'Empleado Demo',
  status: 'activo',
  active: true,
  pay: { ignored: true },
  payReason: 'ignored',
}, '000123');
assert.equal(employeePayload.code, '000123');
assert.equal(Object.hasOwn(employeePayload, 'pin'), false);
assert.equal(Object.hasOwn(employeePayload, 'pay'), false);
assert.equal(Object.hasOwn(employeePayload, 'payReason'), false);

const createPayload = mutation.buildEmployeeMutationPayload({
  name: 'Empleado Nuevo',
  status: 'activo',
  active: true,
});
assert.equal(Object.hasOwn(createPayload, 'code'), false);

console.log('employeeCodePolicy + employeeMutationPayload: PASS');
