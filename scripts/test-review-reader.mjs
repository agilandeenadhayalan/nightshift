import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Exercise the actual native byte-boundary helper, including an endless source
// and stream closure on cancellation/errors. No emulator or private file needed.
const root = fileURLToPath(new URL('../', import.meta.url));
const temporaryRoot = path.resolve(tmpdir());
const output = await mkdtemp(path.join(temporaryRoot, 'nightshift-review-reader-'));
const executable = name => process.env.JAVA_HOME
  ? path.join(process.env.JAVA_HOME, 'bin', process.platform === 'win32' ? `${name}.exe` : name)
  : name;
function run(command, args) {
  const result = spawnSync(executable(command), args, {
    cwd: root, stdio: 'inherit', windowsHide: true, timeout: 30000,
  });
  if (result.error || result.status !== 0) throw new Error(`Native review reader ${command} failed`);
}
try {
  run('javac', ['--release', '17', '-d', output,
    'apps/mobile/android/app/src/main/java/com/nightshift/app/BoundedReviewSampleReader.java',
    'apps/mobile/android/app/src/test/java/com/nightshift/app/BoundedReviewSampleReaderTest.java']);
  run('java', ['-cp', output, 'com.nightshift.app.BoundedReviewSampleReaderTest']);
} finally {
  const resolved = path.resolve(output);
  if (path.dirname(resolved) !== temporaryRoot || !path.basename(resolved).startsWith('nightshift-review-reader-')) {
    throw new Error('Refusing unexpected native test output directory');
  }
  await rm(resolved, { recursive: true, force: true });
}
