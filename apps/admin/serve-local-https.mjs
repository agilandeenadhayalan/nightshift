// Private device QA only: use existing certificate files, never install trust.
import {createServer} from 'node:https';
import {readFileSync} from 'node:fs';
import {dirname, isAbsolute, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import next from 'next';

const origin = 'https://127.0.0.1:3443';
const directory = process.env.STAFF_LOCAL_TLS_DIR;
if (process.env.STAFF_CONSOLE_ORIGIN !== origin || !directory || !isAbsolute(directory)) {
  throw Error('Local staff HTTPS requires the fixed loopback origin and a private certificate directory.');
}
const app = next({dev: false, dir: dirname(fileURLToPath(import.meta.url)), hostname: '127.0.0.1', port: 3443});
await app.prepare();
const handler = app.getRequestHandler();
const server = createServer({key: readFileSync(join(directory, 'localhost-key.pem')), cert: readFileSync(join(directory, 'localhost-cert.pem')), minVersion: 'TLSv1.2'}, (request, response) => {
  if (request.headers.host !== '127.0.0.1:3443') {response.writeHead(421, {'Cache-Control': 'no-store'}); response.end(); return;}
  // There is no reverse proxy on this private listener.
  for (const name of Object.keys(request.headers)) if (name.startsWith('x-forwarded-')) delete request.headers[name];
  request.headers['x-forwarded-proto'] = 'https';
  void handler(request, response).catch(() => {
    if (!response.headersSent) response.writeHead(503, {'Cache-Control': 'no-store'});
    response.end();
  });
});
server.requestTimeout = 15000;
server.headersTimeout = 10000;
server.listen(3443, '127.0.0.1', () => process.stdout.write('Private staff HTTPS listener ready on loopback.\n'));
function stop() {server.closeAllConnections(); server.close(() => {void app.close();});}
process.on('SIGTERM', stop); process.on('SIGINT', stop);
