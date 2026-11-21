import 'server-only';
import {configuration, proxyNativeStaff, proxyStaff, type NativeOperation, type Operation} from './transport';
import {proxyReview, type ReviewOperation} from './review-transport';
import {proxyDecision, type DecisionOperation} from './decision-transport';
export function decisionRequest(request: Request, operation: DecisionOperation): Promise<Response> {
  return proxyDecision(request, operation, configuration(process.env.STAFF_API_BASE_URL, process.env.STAFF_CONSOLE_ORIGIN));
}

export function reviewRequest(request: Request, operation: ReviewOperation): Promise<Response> {
  return proxyReview(request, operation, configuration(process.env.STAFF_API_BASE_URL, process.env.STAFF_CONSOLE_ORIGIN));
}

export function staffRequest(request: Request, operation: Operation): Promise<Response> {
  return proxyStaff(request, operation, configuration(process.env.STAFF_API_BASE_URL, process.env.STAFF_CONSOLE_ORIGIN));
}
export function nativeStaffRequest(request: Request, operation: NativeOperation): Promise<Response> {
  return proxyNativeStaff(request, operation, configuration(process.env.STAFF_API_BASE_URL, process.env.STAFF_CONSOLE_ORIGIN));
}
