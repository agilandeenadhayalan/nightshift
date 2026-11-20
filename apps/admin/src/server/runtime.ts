import 'server-only';
import {configuration, proxyNativeStaff, proxyStaff, type NativeOperation, type Operation} from './transport';

export function staffRequest(request: Request, operation: Operation): Promise<Response> {
  return proxyStaff(request, operation, configuration(process.env.STAFF_API_BASE_URL, process.env.STAFF_CONSOLE_ORIGIN));
}
export function nativeStaffRequest(request: Request, operation: NativeOperation): Promise<Response> {
  return proxyNativeStaff(request, operation, configuration(process.env.STAFF_API_BASE_URL, process.env.STAFF_CONSOLE_ORIGIN));
}
