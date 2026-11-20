import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, dirname } from 'node:path';
import { checkBoundaries } from './check-boundaries.mjs';

function fixture(t) {
  const tempRoot = resolve(tmpdir());
  const root = mkdtempSync(resolve(tempRoot, 'nightshift-boundaries-'));
  t.after(() => {
    assert.equal(dirname(root), tempRoot, 'cleanup stays inside the temporary directory');
    rmSync(root, { recursive: true, force: true });
  });
  const write = (path, content) => {
    const target = resolve(root, path);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, typeof content === 'string' ? content : JSON.stringify(content));
  };
  const manifests = {
    'apps/api': { name: '@nightshift/api', dependencies: { '@nightshift/backend-domain': '0.1.0' }, devDependencies: { '@nightshift/contracts': '0.1.0' } },
    'apps/mobile': { name: '@nightshift/mobile', devDependencies: { '@nightshift/contracts': '0.1.0' } },
    'apps/admin': { name: '@nightshift/admin', dependencies: { '@nightshift/contracts': '0.1.0' } },
    'packages/backend-domain': { name: '@nightshift/backend-domain' },
    'packages/contracts': { name: '@nightshift/contracts' },
    audio: { name: '@nightshift/audio' },
  };
  write('package.json', { workspaces: Object.keys(manifests) });
  for (const [path, manifest] of Object.entries(manifests)) write(`${path}/package.json`, manifest);
  return { root, write, manifests };
}

test('declared public dependencies, local imports, and reference-only tests are allowed', (t) => {
  const { root, write } = fixture(t);
  write('apps/api/src/main.ts', "import { testCharge } from '@nightshift/backend-domain'; import './config'; import { Pool } from 'pg';");
  write('apps/mobile/lib/main.dart', "import 'package:flutter/material.dart'; import 'screens/home.dart';");
  write('packages/backend-domain/test/parity.test.mjs', "import '../../../audio/billing.mjs';");
  assert.deepEqual(checkBoundaries(root), []);
});

test('staff console consumes only public contracts and cannot import API implementation', (t) => {
  const { root, write, manifests } = fixture(t);
  manifests['packages/contracts'].exports = { './staff.openapi.json': './staff.openapi.json' };
  write('packages/contracts/package.json', manifests['packages/contracts']);
  write('packages/contracts/staff.openapi.json', {});
  write('apps/admin/src/session.ts', "import schema from '@nightshift/contracts/staff.openapi.json';");
  assert.deepEqual(checkBoundaries(root), []);
  write('apps/admin/src/session.ts', "import schema from '@nightshift/contracts/staff.openapi.json'; import '../../api/src/service';");
  assert.ok(checkBoundaries(root).some(item => item.includes('apps/admin/src/session.ts')));
  manifests['apps/admin'].dependencies['@nightshift/api'] = '0.1.0';
  write('apps/admin/package.json', manifests['apps/admin']);
  assert.ok(checkBoundaries(root).some(item => item.includes('application workspace @nightshift/api')));
});

test('client/server, application/application, and domain/contract dependency edges fail', (t) => {
  const { root, write, manifests } = fixture(t);
  manifests['apps/mobile'].dependencies = { '@nightshift/backend-domain': '0.1.0' };
  manifests['apps/api'].dependencies['@nightshift/mobile'] = '0.1.0';
  manifests['packages/backend-domain'].devDependencies = { '@nightshift/contracts': '0.1.0' };
  for (const [path, manifest] of Object.entries(manifests)) write(`${path}/package.json`, manifest);
  const failures = checkBoundaries(root);
  assert.equal(failures.length, 3);
  assert.ok(failures.some((item) => item.includes('application workspace @nightshift/mobile')));
  assert.ok(failures.some((item) => item.includes('@nightshift/mobile cannot depend on @nightshift/backend-domain')));
  assert.ok(failures.some((item) => item.includes('@nightshift/backend-domain cannot depend on @nightshift/contracts')));
});

test('undeclared internal packages and imports through private source paths fail', (t) => {
  const { root, write, manifests } = fixture(t);
  delete manifests['apps/api'].dependencies;
  write('apps/api/package.json', manifests['apps/api']);
  write('apps/api/src/main.ts', "import '@nightshift/backend-domain'; export * from '@nightshift/contracts/src/internal';");
  const failures = checkBoundaries(root);
  assert.equal(failures.length, 2);
  assert.ok(failures.some((item) => item.includes('not declared')));
  assert.ok(failures.some((item) => item.includes('public package entry')));
});

test('require, dynamic import, import types, and import-equals cannot hide deep imports', (t) => {
  const { root, write } = fixture(t);
  write('apps/api/src/main.ts', [
    "const a = require('@nightshift/backend-domain/dist/index');",
    "const b = import('@nightshift/backend-domain/src/index');",
    "type C = import('@nightshift/backend-domain/src/index').Charge;",
    "import D = require('@nightshift/backend-domain/src/index');",
  ].join('\n'));
  assert.equal(checkBoundaries(root).filter((item) => item.includes('public package entry')).length, 4);
});

test('explicit public JSON exports are allowed while private subpaths stay blocked', (t) => {
  const { root, write, manifests } = fixture(t);
  manifests['packages/contracts'].exports = {
    './openapi.json': './openapi.json',
    './events.schema.json': './events.schema.json',
    './blocked.json': null,
  };
  write('packages/contracts/package.json', manifests['packages/contracts']);
  write('apps/api/src/main.ts', "import '@nightshift/contracts/openapi.json'; import '@nightshift/contracts/events.schema.json';");
  assert.deepEqual(checkBoundaries(root), []);
  write('apps/api/src/main.ts', [
    "import '@nightshift/contracts/src/internal';",
    "import '@nightshift/contracts/dist/openapi.json';",
    "import '@nightshift/contracts/blocked.json';",
    "import '@nightshift/contracts';",
  ].join('\n'));
  assert.equal(checkBoundaries(root).filter((item) => item.includes('public package entry')).length, 4);
});

test('relative source imports cannot leave TypeScript or Flutter workspaces', (t) => {
  const { root, write } = fixture(t);
  write('apps/api/src/main.ts', "export * from '../../../packages/backend-domain/src/index';");
  write('apps/mobile/lib/main.dart', [
    "import '../../../packages/backend-domain/src/index.dart';",
    "export 'safe.dart' if (dart.library.io) '../../api/src/main.dart';",
    "part 'file:///outside.dart';",
  ].join('\n'));
  assert.equal(checkBoundaries(root).filter((item) => item.includes('escapes its workspace')).length, 4);
});

test('comments and string content are not treated as source imports', (t) => {
  const { root, write } = fixture(t);
  write('apps/api/src/main.ts', "// import '@nightshift/missing';\nconst text = \"import '@nightshift/missing'\";");
  write('apps/mobile/lib/main.dart', [
    "/* import '../../api/private.dart'; /* nested comment */ */",
    "// import '../../api/private.dart';",
    'const text = "import \'../../api/private.dart\';";',
    "import r'package:flutter/material.dart';",
  ].join('\n'));
  assert.deepEqual(checkBoundaries(root), []);
});

test('unregistered internal dependencies fail instead of resolving from a registry', (t) => {
  const { root, write, manifests } = fixture(t);
  manifests['apps/api'].dependencies['@nightshift/missing'] = '0.1.0';
  write('apps/api/package.json', manifests['apps/api']);
  assert.ok(checkBoundaries(root).some((item) => item.includes('not a registered workspace')));
});
