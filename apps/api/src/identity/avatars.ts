/** Built-in asset identifiers only; names describe the chosen artwork, not a
 * verified attribute of its owner or a Customer/Listener role. */
export const AVATAR_CODES: readonly string[] = Object.freeze([
  'moon','star','leaf','wave',
  ...['male','female'].flatMap(prefix=>Array.from({length:30},(_,i)=>`${prefix}_${String(i+1).padStart(2,'0')}`)),
]);

export function isAvatarCode(value:unknown):value is string {
  return typeof value==='string'&&AVATAR_CODES.includes(value);
}
