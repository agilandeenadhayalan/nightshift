export class ApiError extends Error {
  constructor(public readonly status: number, public readonly code: string, message: string) { super(message); }
}
export function requireThat(condition: unknown, status: number, code: string, message: string): asserts condition {
  if (!condition) throw new ApiError(status, code, message);
}
export function object(value: unknown): Record<string, unknown> {
  requireThat(value !== null && typeof value === 'object' && !Array.isArray(value), 400, 'INVALID_BODY', 'A JSON object is required');
  return value as Record<string, unknown>;
}
export function fields(body: Record<string, unknown>, allowed: string[]) {
  requireThat(Object.keys(body).every(k => allowed.includes(k)), 400, 'INVALID_FIELD', 'The request contains unsupported fields');
}
export function string(value: unknown, name: string, max = 100): string {
  requireThat(typeof value === 'string' && value.length > 0 && value.length <= max, 400, 'INVALID_FIELD', `Invalid ${name}`);
  return value;
}
export function uuid(value: unknown): string {
  const id = string(value, 'id', 36);
  requireThat(/^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i.test(id), 400, 'INVALID_ID', 'Invalid resource ID');
  return id;
}
