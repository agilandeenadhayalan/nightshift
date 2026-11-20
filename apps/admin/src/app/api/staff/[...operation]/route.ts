import {nativeStaffRequest, reviewRequest, staffRequest} from '../../../../server/runtime';
import type {NativeOperation, Operation} from '../../../../server/transport';

export const dynamic = 'force-dynamic';
const operations: Record<string, Operation> = {'auth/status': 'status', 'auth/challenge': 'challenge', 'auth/exchange': 'exchange', 'session': 'session', 'auth/logout': 'logout'};
const nativeOperations: Record<string, NativeOperation> = {'native/challenge': 'challenge', 'native/exchange': 'exchange', 'native/access-request': 'access-request', 'native/access-request-current': 'access-request-current'};
async function handle(request: Request, context: {params: Promise<{operation: string[]}>}) {
  const parts = (await context.params).operation;
  const name = parts.join('/');
  if (parts[0] === 'listener-applications') {
    if (parts.length === 1) return reviewRequest(request, {kind: 'queue'});
    if (parts.length === 2) return reviewRequest(request, {kind: 'detail', id: parts[1]});
    if (parts.length === 3 && parts[2] === 'voice-sample') return reviewRequest(request, {kind: 'sample', id: parts[1]});
  }
  if (Object.hasOwn(nativeOperations, name)) return nativeStaffRequest(request, nativeOperations[name]);
  if (!Object.hasOwn(operations, name)) return new Response(null, {status: 404, headers: {'Cache-Control': 'no-store'}});
  return staffRequest(request, operations[name]);
}
export {handle as GET, handle as POST};
