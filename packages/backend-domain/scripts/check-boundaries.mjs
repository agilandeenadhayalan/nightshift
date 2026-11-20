import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';

const packageRoot = fileURLToPath(new URL('../', import.meta.url));
const sourceRoot = path.join(packageRoot, 'src');
const manifest = JSON.parse(await readFile(path.join(packageRoot, 'package.json'), 'utf8'));
for (const field of ['dependencies', 'optionalDependencies', 'peerDependencies']) {
  assert.equal(Object.keys(manifest[field] ?? {}).length, 0, `backend-domain must have no ${field}`);
}

function checkSpecifier(node, file) {
  assert.ok(node && ts.isStringLiteralLike(node), `${file}: computed module imports are forbidden`);
  const specifier = node.text;
  assert.ok(specifier.startsWith('./') || specifier.startsWith('../'),
    `${file}: backend-domain cannot import external module ${specifier}`);
  const relative = path.relative(sourceRoot, path.resolve(path.dirname(file), specifier));
  assert.ok(relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative),
    `${file}: backend-domain cannot import outside its own source directory`);
}

async function checkDirectory(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      await checkDirectory(file);
    } else if (entry.name.endsWith('.ts')) {
      const source = ts.createSourceFile(file, await readFile(file, 'utf8'), ts.ScriptTarget.Latest, true);
      assert.equal(source.typeReferenceDirectives.length, 0, `${file}: external type references are forbidden`);
      for (const reference of source.referencedFiles) {
        checkSpecifier(ts.factory.createStringLiteral(reference.fileName), file);
      }
      function visit(node) {
        if ((ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) && node.moduleSpecifier) {
          checkSpecifier(node.moduleSpecifier, file);
        } else if (ts.isImportEqualsDeclaration(node) && ts.isExternalModuleReference(node.moduleReference)) {
          checkSpecifier(node.moduleReference.expression, file);
        } else if (ts.isImportTypeNode(node) && ts.isLiteralTypeNode(node.argument)) {
          checkSpecifier(node.argument.literal, file);
        } else if (ts.isCallExpression(node) && (node.expression.kind === ts.SyntaxKind.ImportKeyword ||
          (ts.isIdentifier(node.expression) && node.expression.text === 'require'))) {
          checkSpecifier(node.arguments[0], file);
        }
        ts.forEachChild(node, visit);
      }
      visit(source);
    }
  }
}

await checkDirectory(sourceRoot);
console.log('backend-domain boundary passed: no runtime dependencies or external source imports');
