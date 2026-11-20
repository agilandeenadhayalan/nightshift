import 'server-only';
import {configuration, proxyStaff, type Operation} from './transport';

export function staffRequest(request: Request, operation: Operation): Promise<Response> {
  return proxyStaff(request, operation, configuration(process.env.STAFF_API_BASE_URL, process.env.STAFF_CONSOLE_ORIGIN));
}
