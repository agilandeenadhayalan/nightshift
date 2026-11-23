import { randomUUID } from 'node:crypto';
import { Actor } from '../auth';
import { Database } from '../db';
import { fields, object, requireThat, string } from '../errors';
import { isAvatarCode } from './avatars';

export const ONBOARDING_CONSENT = 'adult-onboarding-v1';

/** Calendar comparisons are UTC dates; self-declaration is not identity verification. */
export function validateBirthDate(value: unknown, clock: () => number): string {
  const raw = string(value, 'dateOfBirth', 10);
  requireThat(/^\d{4}-\d{2}-\d{2}$/.test(raw), 400, 'INVALID_BIRTH_DATE', 'Enter a valid date of birth.');
  const date = new Date(`${raw}T00:00:00.000Z`);
  requireThat(Number.isFinite(date.getTime()) && date.toISOString().slice(0,10) === raw,
    400, 'INVALID_BIRTH_DATE', 'Enter a valid date of birth.');
  const today = new Date(clock());
  requireThat(raw >= '1900-01-01' && raw <= today.toISOString().slice(0,10),
    400, 'INVALID_BIRTH_DATE', 'Enter a valid date of birth.');
  return raw;
}

export function isAdultOn(birthDate: string, instant: number): boolean {
  const today=new Date(instant), cutoffYear=today.getUTCFullYear()-18;
  // A 29-Feb declaration reaches 18 on 1 March in a non-leap year.
  const boundary=`${String(cutoffYear).padStart(4,'0')}-${String(today.getUTCMonth()+1).padStart(2,'0')}-${String(today.getUTCDate()).padStart(2,'0')}`;
  return birthDate<=boundary;
}

export class Onboarding {
  constructor(private readonly db: Database, private readonly clock: () => number = Date.now,
    private readonly restrictMedia: (actor: Actor) => Promise<void> = async () => {}) {}

  async get(actor: Actor) {
    const {rows} = await this.db.pool.query(`SELECT u.adult_confirmed,u.display_name,u.languages,
      a.date_of_birth::text,p.submitted_display_name,p.avatar_code,p.interface_language
      FROM users u LEFT JOIN profiles p ON p.user_id=u.id LEFT JOIN age_declarations a ON a.user_id=u.id WHERE u.id=$1`, [actor.id]);
    requireThat(rows.length,404,'NOT_FOUND','Account not found.');
    const row = rows[0];
    return { required: !row.adult_confirmed, profile: {
      displayName: row.submitted_display_name ?? row.display_name,
      avatarCode: row.avatar_code ?? 'moon', interfaceLanguage: row.interface_language ?? 'en',
      languages: row.languages as string[], dateOfBirth: row.date_of_birth ?? null,
    } };
  }

  async complete(actor: Actor, raw: unknown) {
    const body = object(raw);
    fields(body,['dateOfBirth','displayName','avatarCode','interfaceLanguage','languages','consentVersion']);
    requireThat(body.consentVersion === ONBOARDING_CONSENT,400,'ONBOARDING_CONSENT_REQUIRED','Accept the current adult onboarding notice.');
    const birthDate = validateBirthDate(body.dateOfBirth,this.clock);
    const adult=isAdultOn(birthDate,this.clock());
    const displayName = string(body.displayName,'displayName',80).normalize('NFC').trim();
    requireThat([...displayName].length >= 2 && [...displayName].length <= 40
      && /^[\p{L}\p{M}\p{N} ._-]+$/u.test(displayName) && /[\p{L}]/u.test(displayName)
      && !/[\p{N}]{6}/u.test(displayName),400,'INVALID_DISPLAY_NAME','Use a short nickname without contact details.');
    requireThat(isAvatarCode(body.avatarCode),400,'INVALID_AVATAR','Choose a built-in avatar.');
    requireThat(typeof body.interfaceLanguage==='string' && ['ta','en'].includes(body.interfaceLanguage),400,'INVALID_LANGUAGE','Choose Tamil or English.');
    requireThat(Array.isArray(body.languages) && body.languages.length > 0 && body.languages.length <= 2
      && body.languages.every(x=>['ta','en'].includes(x)) && new Set(body.languages).size===body.languages.length,
      400,'INVALID_LANGUAGE','Choose your speaking languages.');
    const languages = [...new Set(body.languages)];
    await this.db.tx(async c => {
      const user = await c.query('SELECT suspended FROM users WHERE id=$1 FOR NO KEY UPDATE',[actor.id]);
      requireThat(user.rows.length && !user.rows[0].suspended,401,'UNAUTHENTICATED','Sign in again.');
      const session=await c.query('SELECT 1 FROM auth_sessions WHERE token_hash=$1 AND user_id=$2 AND revoked_at IS NULL AND expires_at>$3',
        [actor.sessionHash,actor.id,new Date(this.clock())]);
      requireThat(session.rows.length,401,'UNAUTHENTICATED','Sign in again.');
      const old = await c.query('SELECT date_of_birth::text FROM age_declarations WHERE user_id=$1',[actor.id]);
      requireThat(!old.rows.length || old.rows[0].date_of_birth === birthDate,409,'DOB_IMMUTABLE','Date of birth cannot be changed here.');
      await c.query('INSERT INTO age_declarations(user_id,date_of_birth) VALUES($1,$2::date) ON CONFLICT DO NOTHING',[actor.id,birthDate]);
      // Commit the first valid self-declaration even when the age gate fails;
      // changing the date on a retry must not bypass the adult boundary.
      if(!adult){
        await c.query('UPDATE users SET adult_confirmed=false,listener_approved=false,desired_online=false,presence_version=presence_version+1 WHERE id=$1',[actor.id]);
        return;
      }
      const active = await c.query('SELECT 1 FROM active_participant_claims WHERE user_id=$1',[actor.id]);
      requireThat(!active.rows.length,409,'CALL_ACTIVE','End the call before changing your profile.');
      await c.query(`INSERT INTO profiles(user_id,date_of_birth,submitted_display_name,avatar_code,interface_language)
        VALUES($1,$2::date,$3,$4,$5) ON CONFLICT(user_id) DO UPDATE SET
        submitted_display_name=EXCLUDED.submitted_display_name,avatar_code=EXCLUDED.avatar_code,
        interface_language=EXCLUDED.interface_language,moderation_state='pending',updated_at=now()`,
      [actor.id,birthDate,displayName,body.avatarCode,body.interfaceLanguage]);
      // Self-declared adult status never grants Listener eligibility or funds.
      await c.query('UPDATE users SET adult_confirmed=true,languages=$2 WHERE id=$1',[actor.id,languages]);
      await c.query(`INSERT INTO consents(id,user_id,purpose,notice_version,granted)
        VALUES($1,$2,'adult-service-onboarding',$3,true) ON CONFLICT DO NOTHING`,[randomUUID(),actor.id,ONBOARDING_CONSENT]);
    });
    if(!adult)await this.restrictMedia(actor);
    requireThat(adult,403,'ADULT_ONLY','NightShift is for adults aged 18 and over.');
    return this.get(actor);
  }
}
