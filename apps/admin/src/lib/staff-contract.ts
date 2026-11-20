export const permissions = ['listener.review.read', 'listener.review.evidence.read', 'listener.review.decide'] as const;
export type Permission = typeof permissions[number];
export type StaffSession = {staff: {id: string}; permissions: Permission[]; expiresAt: string; csrfToken: string};
export type StaffStatus = {configured: boolean; available: boolean; reasonCode: 'STAFF_AUTH_UNAVAILABLE' | null};
export const hex64 = /^[a-f0-9]{64}$/;
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i;
export function object(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
export function exactKeys(value: Record<string, unknown>, keys: string[]): boolean {
  return Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value, key));
}
export function utcTime(value: unknown): value is string {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) &&
    Number.isFinite(Date.parse(value)) && new Date(value).toISOString() === value;
}
export function statusValue(value: unknown): value is StaffStatus {
  if (!object(value) || typeof value.configured !== 'boolean' || typeof value.available !== 'boolean') return false;
  if (value.available) return value.configured && value.reasonCode === null && exactKeys(value, ['configured', 'available', 'reasonCode']);
  return value.reasonCode === 'STAFF_AUTH_UNAVAILABLE' && exactKeys(value, ['configured', 'available', 'reasonCode']);
}
export function sessionValue(value: unknown): value is StaffSession {
  return object(value) && exactKeys(value, ['staff', 'permissions', 'expiresAt', 'csrfToken']) &&
    object(value.staff) && exactKeys(value.staff, ['id']) && typeof value.staff.id === 'string' && uuid.test(value.staff.id) &&
    Array.isArray(value.permissions) && value.permissions.length <= permissions.length &&
    new Set(value.permissions).size === value.permissions.length && value.permissions.every(p => permissions.includes(p)) &&
    utcTime(value.expiresAt) && typeof value.csrfToken === 'string' && hex64.test(value.csrfToken);
}
