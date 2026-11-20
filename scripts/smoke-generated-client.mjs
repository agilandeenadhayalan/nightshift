import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Credentials are inherited through the environment, never command-line arguments.
if (!process.env.DEV_ACCESS_KEY || process.env.DEV_ACCESS_KEY.length < 24) {
  throw new Error('Load the private development access key from the local environment');
}
const cwd = fileURLToPath(new URL('../apps/mobile/', import.meta.url));
const windows = process.platform === 'win32';
const command = windows ? (process.env.ComSpec || 'cmd.exe') : 'dart';
const args = windows
  ? ['/d', '/s', '/c', 'dart run tool/smoke_generated_client.dart']
  : ['run', 'tool/smoke_generated_client.dart'];
const child = spawn(command, args, { cwd, stdio: 'inherit', windowsHide: true });
child.on('error', () => {
  console.error('Could not launch Dart. Add the pinned Flutter SDK to PATH and run flutter pub get.');
  process.exitCode = 1;
});
child.on('exit', code => { process.exitCode = code ?? 1; });
