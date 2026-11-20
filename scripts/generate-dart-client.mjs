// Official OpenAPI Generator; only the checked-in templates customize its output.
import { createHash } from 'node:crypto';
import { existsSync } from 'node:fs';
import { mkdir, mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const version = '7.26.0';
const sha256 = '1760050094997b9cc790cc1350be095f15da8c08a996b184d3eadc4ccda5e35e';
const jar = path.join(root, 'artifacts', 'openapi-generator', `openapi-generator-cli-${version}.jar`);
const destination = path.join(root, 'packages', 'contracts', 'dart');
const check = process.argv.includes('--check');
if (process.argv.slice(2).some(arg => arg !== '--check')) throw new Error('Use --check or no arguments');
const normalize = buffer => buffer.toString('utf8').replaceAll('\r\n', '\n');
const digest = buffer => createHash('sha256').update(buffer).digest('hex');

await mkdir(path.dirname(jar), { recursive: true });
if (!existsSync(jar)) {
  const response = await fetch(`https://repo.maven.apache.org/maven2/org/openapitools/openapi-generator-cli/${version}/openapi-generator-cli-${version}.jar`, { signal: AbortSignal.timeout(120_000) });
  if (!response.ok) throw new Error(`Generator download failed: HTTP ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (digest(bytes) !== sha256) throw new Error('Generator download checksum mismatch');
  await writeFile(jar, bytes);
}
if (digest(await readFile(jar)) !== sha256) throw new Error('Cached generator checksum mismatch; remove the invalid cached JAR');

async function files(directory, prefix = '') {
  if (!existsSync(directory)) return new Map();
  const result = new Map();
  for (const item of await readdir(directory, { withFileTypes: true })) {
    if (['.dart_tool', 'build', 'pubspec.lock'].includes(item.name)) continue;
    if (item.isSymbolicLink()) throw new Error('Generated SDK must not contain symlinks');
    const file = path.join(directory, item.name), relative = `${prefix}${item.name}`;
    if (item.isDirectory()) {
      for (const entry of await files(file, `${relative}/`)) result.set(...entry);
    } else result.set(relative, normalize(await readFile(file)));
  }
  return result;
}

const temporary = await mkdtemp(path.join(tmpdir(), 'nightshift-client-'));
try {
  const java = process.env.JAVA_HOME ? path.join(process.env.JAVA_HOME, 'bin', process.platform === 'win32' ? 'java.exe' : 'java') : 'java';
  const generated = path.join(temporary, 'generated');
  const args = ['-jar', jar, 'generate', '-g', 'dart', '-i', path.join(root, 'packages/contracts/openapi.json'),
    '-c', path.join(root, 'packages/contracts/generator/config.json'),
    '-t', path.join(root, 'packages/contracts/generator/templates'), '-o', generated,
    '--global-property=apiTests=false,modelTests=false,apiDocs=false,modelDocs=false'];
  const run = spawnSync(java, args, { encoding: 'utf8', maxBuffer: 4 * 1024 * 1024 });
  if (run.error || run.status !== 0) {
    console.error(run.stderr || run.stdout || run.error?.message);
    throw new Error('OpenAPI Generator failed; install Java 17+ and set JAVA_HOME');
  }
  const expected = new Map([...await files(generated)].filter(([name]) => name.startsWith('lib/') || ['pubspec.yaml', 'analysis_options.yaml', 'README.md'].includes(name)));
  const actual = await files(destination);
  const changed = [...new Set([...expected.keys(), ...actual.keys()])].filter(name => expected.get(name) !== actual.get(name));
  if (check) {
    if (changed.length) throw new Error(`Generated client drift (${changed.length} files): ${changed.join(', ')}. Run npm run generate:client.`);
    console.log(`Generated client matches OpenAPI Generator ${version} (${expected.size} files).`);
  } else {
    for (const name of actual.keys()) {
      if (!expected.has(name)) await rm(path.join(destination, name));
    }
    for (const [name, content] of expected) {
      const target = path.join(destination, name);
      await mkdir(path.dirname(target), { recursive: true });
      await writeFile(target, content);
    }
    console.log(`Generated ${expected.size} Dart client files with OpenAPI Generator ${version}.`);
  }
} finally {
  const relative = path.relative(path.resolve(tmpdir()), path.resolve(temporary));
  if (!relative.startsWith('nightshift-client-') || relative.includes(path.sep)) throw new Error('Unsafe temporary cleanup path');
  await rm(temporary, { recursive: true, force: true });
}
