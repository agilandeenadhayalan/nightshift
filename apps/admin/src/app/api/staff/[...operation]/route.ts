import {nativeStaffRequest, staffRequest} from '../../../../server/runtime';
import type {NativeOperation, Operation} from '../../../../server/transport';

export const dynamic = 'force-dynamic';
const operations: Record<string, Operation> = {'auth/status': 'status', 'auth/challenge': 'challenge', 'auth/exchange': 'exchange', 'session': 'session', 'auth/logout': 'logout'};
const nativeOperations: Record<string, NativeOperation> = {'native/challenge': 'challenge', 'native/exchange': 'exchange', 'native/access-request': 'access-request', 'native/access-request-current': 'access-request-current'};
async function handle(request: Request, context: {params: Promise<{operation: string[]}>}) {
  const name = (await context.params).operation.join('/');
  if (Object.hasOwn(nativeOperations, name)) return nativeStaffRequest(request, nativeOperations[name]);
  if (!Object.hasOwn(operations, name)) return new Response(null, {status: 404, headers: {'Cache-Control': 'no-store'}});
  return staffRequest(request, operations[name]);
}
export {handle as GET, handle as POST};
