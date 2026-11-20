import { existsSync, globSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';

// Add a policy deliberately when registering a new runnable workspace.
const allowedDependencies = new Map([
  ['@nightshift/api', new Set(['@nightshift/backend-domain', '@nightshift/contracts'])],
  ['@nightshift/mobile', new Set(['@nightshift/contracts'])],
  ['@nightshift/backend-domain', new Set()],
  ['@nightshift/contracts', new Set()],
  ['@nightshift/audio', new Set()],
]);
const dependencyFields = ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'];
const inside = (parent, child) => {
  const path = relative(parent, child);
  return path !== '..' && !path.startsWith(`..${sep}`) && !isAbsolute(path);
};
const json = (path) => JSON.parse(readFileSync(path, 'utf8'));
const display = (root, path) => relative(root, path).split(sep).join('/');

function isPublicEntry(manifest, packageName, specifier) {
  const subpath = specifier === packageName ? '.' : `.${specifier.slice(packageName.length)}`;
  const exports = manifest?.exports;
  if (exports === undefined) return subpath === '.';
  if (exports === null) return false;
  if (typeof exports === 'object' && !Array.isArray(exports) && Object.keys(exports).some((key) => key.startsWith('.'))) {
    // Only exact, explicitly exported subpaths are public; no private deep imports.
    return Object.hasOwn(exports, subpath) && exports[subpath] !== null;
  }
  return subpath === '.';
}

function* sourceFiles(directory) {
  if (!existsSync(directory)) return;
  for (const item of readdirSync(directory, { withFileTypes: true })) {
    const path = resolve(directory, item.name);
    if (item.isDirectory()) yield* sourceFiles(path);
    else if (item.isFile() && /\.(?:[cm]?tsx?|dart)$/.test(item.name)) yield path;
  }
}

function tsImports(path, source) {
  const file = ts.createSourceFile(path, source, ts.ScriptTarget.Latest, true);
  const imports = [];
  const add = (node) => {
    if (node && ts.isStringLiteralLike(node)) imports.push(node.text);
  };
  const visit = (node) => {
    if (ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) add(node.moduleSpecifier);
    else if (ts.isImportEqualsDeclaration(node) && ts.isExternalModuleReference(node.moduleReference)) {
      add(node.moduleReference.expression);
    } else if (ts.isImportTypeNode(node) && ts.isLiteralTypeNode(node.argument)) {
      add(node.argument.literal);
    } else if (ts.isCallExpression(node) &&
      (node.expression.kind === ts.SyntaxKind.ImportKeyword ||
        (ts.isIdentifier(node.expression) && node.expression.text === 'require'))) {
      add(node.arguments[0]);
    }
    ts.forEachChild(node, visit);
  };
  visit(file);
  return imports;
}

// Dart directives can include conditional URIs. Tokenize comments and strings so
// comments or UI text containing "import" cannot create false boundary failures.
function dartImports(source) {
  const tokens = [];
  let i = 0;
  while (i < source.length) {
    if (/\s/.test(source[i])) { i++; continue; }
    if (source.startsWith('//', i)) {
      const end = source.indexOf('\n', i + 2);
      i = end < 0 ? source.length : end + 1;
      continue;
    }
    if (source.startsWith('/*', i)) {
      i += 2;
      let depth = 1;
      while (i < source.length && depth) {
        if (source.startsWith('/*', i)) { depth++; i += 2; }
        else if (source.startsWith('*/', i)) { depth--; i += 2; }
        else i++;
      }
      continue;
    }
    const raw = source[i] === 'r' && /['"]/.test(source[i + 1] ?? '');
    if (raw) i++;
    if (/['"]/.test(source[i])) {
      const quote = source[i];
      const delimiter = source.startsWith(quote.repeat(3), i) ? quote.repeat(3) : quote;
      i += delimiter.length;
      let value = '';
      while (i < source.length && !source.startsWith(delimiter, i)) {
        if (!raw && source[i] === '\\') {
          value += source[i + 1] ?? '';
          i += 2;
        } else value += source[i++];
      }
      i += delimiter.length;
      tokens.push({ kind: 'string', value });
    } else {
      const word = /^[A-Za-z_$][\w$]*/.exec(source.slice(i));
      if (word) { tokens.push({ kind: 'word', value: word[0] }); i += word[0].length; }
      else tokens.push({ kind: 'symbol', value: source[i++] });
    }
  }
  const imports = [];
  for (let j = 0; j < tokens.length; j++) {
    if (tokens[j].kind !== 'word' || !['import', 'export', 'part'].includes(tokens[j].value)) continue;
    while (++j < tokens.length && tokens[j].value !== ';') {
      if (tokens[j].kind === 'string') imports.push(tokens[j].value);
    }
  }
  return imports;
}

export function checkBoundaries(root) {
  root = resolve(root);
  const findings = [];
  const rootManifest = json(resolve(root, 'package.json'));
  const patterns = Array.isArray(rootManifest.workspaces) ? rootManifest.workspaces : rootManifest.workspaces?.packages;
  if (!patterns?.length) return ['package.json: no workspaces are registered'];
  const packages = new Map();
  for (const path of globSync(patterns, { cwd: root })) {
    const directory = resolve(root, path);
    const manifestPath = resolve(directory, 'package.json');
    if (!existsSync(manifestPath)) continue;
    const manifest = json(manifestPath);
    if (packages.has(manifest.name)) findings.push(`${display(root, manifestPath)}: duplicate workspace name ${manifest.name}`);
    packages.set(manifest.name, { directory, manifest, manifestPath });
  }
  for (const [name, workspace] of packages) {
    const { directory, manifest, manifestPath } = workspace;
    const dependencies = new Set(dependencyFields.flatMap((field) => Object.keys(manifest[field] ?? {})));
    const allowed = allowedDependencies.get(name);
    const report = (path, message) => findings.push(`${display(root, path)}: ${message}`);
    if (!allowed) report(manifestPath, `workspace ${name} needs an explicit architecture policy`);
    for (const dependency of dependencies) {
      if (!dependency.startsWith('@nightshift/') && !packages.has(dependency)) continue;
      const target = packages.get(dependency);
      if (!target) report(manifestPath, `internal dependency ${dependency} is not a registered workspace`);
      else if (inside(resolve(root, 'apps'), target.directory)) {
        report(manifestPath, `${name} cannot depend on application workspace ${dependency}`);
      } else if (!allowed?.has(dependency)) {
        report(manifestPath, `${name} cannot depend on ${dependency}`);
      }
    }
    // Tests may read external reference fixtures. Runtime source must stay within
    // its package or use an explicitly declared package's public entry point.
    for (const sourceRoot of ['src', 'lib']) {
      for (const path of sourceFiles(resolve(directory, sourceRoot))) {
        const dart = path.endsWith('.dart');
        const source = readFileSync(path, 'utf8');
        for (const specifier of dart ? dartImports(source) : tsImports(path, source)) {
          if (dart) {
            if (specifier.startsWith('dart:')) continue;
            if (specifier.startsWith('package:')) {
              if (specifier.includes('backend-domain') || specifier.includes('@nightshift/') ||
                specifier.split('/').includes('..')) report(path, `invalid client package import ${specifier}`);
              continue;
            }
            if (/^[a-z][a-z0-9+.-]*:/i.test(specifier) || !inside(directory, resolve(dirname(path), specifier))) {
              report(path, `Dart import escapes its workspace: ${specifier}`);
            }
            continue;
          }
          if (specifier.startsWith('.') || isAbsolute(specifier)) {
            if (!inside(directory, resolve(dirname(path), specifier))) report(path, `relative import escapes its workspace: ${specifier}`);
            continue;
          }
          const packageName = specifier.startsWith('@') ? specifier.split('/').slice(0, 2).join('/') : specifier.split('/')[0];
          if (!packageName.startsWith('@nightshift/') && !packages.has(packageName)) continue;
          if (!packages.has(packageName)) report(path, `unknown internal package ${packageName}`);
          else if (!dependencies.has(packageName)) report(path, `internal import ${packageName} is not declared in package.json`);
          if (!isPublicEntry(packages.get(packageName)?.manifest, packageName, specifier)) {
            report(path, `use the public package entry or an explicit export instead of ${specifier}`);
          }
        }
      }
    }
  }
  return findings;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const findings = checkBoundaries(resolve(dirname(fileURLToPath(import.meta.url)), '..'));
  for (const finding of findings) console.error(finding);
  if (findings.length) process.exitCode = 1;
  else console.log('Workspace dependency and runtime import boundaries passed.');
}
