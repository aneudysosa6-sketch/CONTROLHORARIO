import assert from 'node:assert/strict';
import { access, readFile, readdir } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';

const expectedVersion = '2.110.2';
const expectedSpecifier = `npm:@supabase/supabase-js@${expectedVersion}`;
const functionsRoot = fileURLToPath(new URL('../../supabase/functions/', import.meta.url));
const checkedExtensions = new Set(['.ts', '.js', '.json', '.jsonc', '.lock']);

const isFile = async (path) => {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
};

const collectFiles = async (directory) => {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await collectFiles(path));
    else if (entry.isFile()) files.push(path);
  }
  return files;
};

const entries = await readdir(functionsRoot, { withFileTypes: true });
const functionDirectories = [];
for (const entry of entries) {
  if (!entry.isDirectory() || entry.name.startsWith('_')) continue;
  const directory = join(functionsRoot, entry.name);
  if (await isFile(join(directory, 'index.ts'))) functionDirectories.push(directory);
}
functionDirectories.sort();
assert.ok(functionDirectories.length > 0, 'No se encontraron Edge Functions para validar.');

for (const directory of functionDirectories) {
  const functionName = relative(functionsRoot, directory);
  const configPath = join(directory, 'deno.json');
  const lockPath = join(directory, 'deno.lock');
  assert.ok(await isFile(configPath), `${functionName}: falta deno.json propio.`);
  assert.ok(await isFile(lockPath), `${functionName}: falta deno.lock propio.`);

  const config = JSON.parse(await readFile(configPath, 'utf8'));
  assert.equal(
    config.imports?.['@supabase/supabase-js'],
    expectedSpecifier,
    `${functionName}: supabase-js debe usar ${expectedSpecifier}.`,
  );

  for (const [alias, target] of Object.entries(config.imports ?? {})) {
    if (!/^(?:npm:|jsr:|https?:\/\/)/.test(target)) continue;
    assert.match(
      target,
      /@\d+\.\d+\.\d+(?:$|[/?#])/,
      `${functionName}: ${alias} no usa una version SemVer exacta: ${target}`,
    );
  }

  const source = await readFile(join(directory, 'index.ts'), 'utf8');
  const syntaxDiagnostics = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.ESNext,
      target: ts.ScriptTarget.ES2022,
    },
    fileName: `${functionName}/index.ts`,
    reportDiagnostics: true,
  }).diagnostics?.filter((diagnostic) => diagnostic.category === ts.DiagnosticCategory.Error) ?? [];
  assert.deepEqual(
    syntaxDiagnostics.map((diagnostic) => ts.flattenDiagnosticMessageText(diagnostic.messageText, '\n')),
    [],
    `${functionName}: TypeScript contiene errores de sintaxis.`,
  );
  const importSpecifiers = [
    ...source.matchAll(/\bfrom\s*["']([^"']+)["']/g),
    ...source.matchAll(/\bimport\s*\(\s*["']([^"']+)["']\s*\)/g),
    ...source.matchAll(/\bimport\s*["']([^"']+)["']/g),
  ].map((match) => match[1]);
  assert.ok(
    importSpecifiers.includes('@supabase/supabase-js'),
    `${functionName}: el import de supabase-js debe usar el alias controlado.`,
  );
  for (const specifier of importSpecifiers) {
    assert.ok(
      !/^(?:npm:|jsr:|https?:\/\/)/.test(specifier),
      `${functionName}: import remoto directo no controlado: ${specifier}`,
    );
  }

  const lock = JSON.parse(await readFile(lockPath, 'utf8'));
  assert.equal(
    lock.specifiers?.[expectedSpecifier],
    expectedVersion,
    `${functionName}: deno.lock no resuelve ${expectedSpecifier}.`,
  );
  assert.ok(
    lock.npm?.[`@supabase/supabase-js@${expectedVersion}`]?.integrity,
    `${functionName}: deno.lock no contiene la integridad de supabase-js ${expectedVersion}.`,
  );
  assert.ok(
    lock.workspace?.dependencies?.includes(expectedSpecifier),
    `${functionName}: deno.lock no vincula el specifier exacto del workspace.`,
  );
}

for (const path of await collectFiles(functionsRoot)) {
  const extension = path.endsWith('.lock') ? '.lock' : path.slice(path.lastIndexOf('.'));
  if (!checkedExtensions.has(extension)) continue;
  const content = await readFile(path, 'utf8');
  for (const match of content.matchAll(/@supabase\/supabase-js@([^"'`\s,}\]]+)/g)) {
    assert.equal(
      match[1],
      expectedVersion,
      `${relative(functionsRoot, path)}: referencia flotante o version distinta (${match[0]}).`,
    );
  }
}

console.log(`edgeDependencyPinning: PASS (${functionDirectories.length} funciones, supabase-js ${expectedVersion})`);
