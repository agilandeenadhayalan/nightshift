import { createHash, randomUUID } from 'node:crypto';
import { PoolClient } from 'pg';
import { Actor } from './auth';
import { Database } from './db';
import { ApiError, fields, object, requireThat } from './errors';
import { isAdultOn } from './identity/onboarding';

export const DELETION_NOTICE_VERSION = 'account-deletion-test-v1';
export const DELETION_NOTICE_TEXT = 'Request deletion of your test account. You will be signed out immediately and removed from discovery. '
  + 'Your test credits become inaccessible: they are not money and cannot be refunded, transferred or paid out. Listener test earnings are nonpayable and will not be paid out. '
  + 'End every active call before submitting. We remove your profile, date of birth and local device/session records. A submitted nickname may remain only under a specific unresolved case-evidence hold; underage profile data is removed immediately. '
  + 'Financial journals, dispute records, consent history and a restricted sign-in identity tombstone remain for review. The tombstone prevents sign-in or re-enrollment while review is pending. '
  + 'This foundation has no approved retention schedule or automatic full-account erasure. Keep your private receipt to check the remaining holds; no deletion completion date is promised.';

export type DeletionHold = 'financial_pending' | 'dispute_open' | 'profile_evidence' | 'age_safety_review' | 'private_material_cleanup';
export interface DeletionReceipt {
  requestId: string;
  status: 'pending_hold' | 'review_required';
  requestedAt: string;
  personalDataDeletedAt: string | null;
  holds: DeletionHold[];
  noticeVersion: string;
  testOnly: true;
  retentionReviewRequired: true;
}
type RequestRow = {
  id: string; user_id: string; status: DeletionReceipt['status']; created_at: Date;
  personal_data_deleted_at: Date | null; retention_holds: DeletionHold[]; notice_version: string;
  receipt_token_hash: string; request_fingerprint: string; restriction_review_required: boolean;
  private_material_cleanup_pending: boolean;
};
const digest = (value: string) => createHash('sha256').update(value).digest('hex');
const iso = (value: Date) => new Date(value).toISOString();
function receipt(row: RequestRow): DeletionReceipt {
  return { requestId: row.id, status: row.status, requestedAt: iso(row.created_at),
    personalDataDeletedAt: row.personal_data_deleted_at ? iso(row.personal_data_deleted_at) : null,
    holds: row.retention_holds, noticeVersion: row.notice_version, testOnly: true, retentionReviewRequired: true };
}
function receiptDigest(value: unknown): string {
  requireThat(typeof value === 'string' && /^[a-f0-9]{64}$/.test(value), 400, 'INVALID_FIELD', 'A private 32-byte hexadecimal receipt token is required.');
  return digest(value);
}

/** Actor comes only from the trusted authentication guard, never request JSON.
 * All deletion work here concerns local test infrastructure. Provider erasure,
 * legal retention clearance and authorized casework remain separate gates.
 */
export class AccountLifecycle {
  constructor(private readonly db: Database, private readonly clock: () => number = Date.now,
    private readonly withdrawDiscovery: (userId: string) => Promise<void> = async () => {},
    private readonly purgePrivateMaterials?: (userId: string) => Promise<void>) {}

  deletionNotice() {
    return { noticeVersion: DELETION_NOTICE_VERSION, text: DELETION_NOTICE_TEXT,
      testOnly: true as const, retentionReviewRequired: true as const };
  }

  async consentHistory(actor: Actor) {
    return this.db.tx(async c => {
      await this.liveOwner(c, actor);
      const { rows } = await c.query(`SELECT id,purpose,notice_version,granted,created_at FROM consents
        WHERE user_id=$1 ORDER BY created_at,id`, [actor.id]);
      return { items: rows.map(r => ({ id: r.id, purpose: r.purpose, noticeVersion: r.notice_version,
        granted: r.granted, createdAt: iso(r.created_at) })) };
    });
  }

  /** Public capability read; HTTP layer also rate-limits. Never returns identity,
   * profile, monetary amounts, the capability itself or internal case IDs. */
  async status(raw: unknown): Promise<DeletionReceipt> {
    const body = object(raw); fields(body, ['receiptToken']);
    const hash = receiptDigest(body.receiptToken);
    const { rows } = await this.db.pool.query('SELECT * FROM deletion_requests WHERE receipt_token_hash=$1', [hash]);
    requireThat(rows.length, 404, 'DELETION_RECEIPT_NOT_FOUND', 'Deletion receipt not found.');
    return receipt(rows[0]);
  }

  async requestDeletion(actor: Actor, raw: unknown): Promise<DeletionReceipt> {
    const body = object(raw); fields(body, ['noticeVersion', 'confirm', 'receiptToken']);
    requireThat(body.noticeVersion === DELETION_NOTICE_VERSION, 409, 'NOTICE_OUTDATED', 'Review the current deletion notice.');
    requireThat(body.confirm === true, 400, 'DELETION_CONFIRMATION_REQUIRED', 'Confirm the published deletion effects.');
    const hash = receiptDigest(body.receiptToken);
    const now = this.clock(), authTime = actor.identityAuthTime;
    requireThat(typeof authTime === 'number' && Number.isSafeInteger(authTime) && authTime >= 0
      && authTime * 1000 <= now && now - authTime * 1000 <= 300_000,
    403, 'FRESH_SIGN_IN_REQUIRED', 'Verify your phone again before requesting deletion.');
    const fingerprint = digest(JSON.stringify({ noticeVersion: DELETION_NOTICE_VERSION, confirm: true, receiptTokenHash: hash }));
    let result: DeletionReceipt;
    try {
      result = await this.db.tx(async c => {
        // Same lock as call creation, onboarding and phone-session exchange.
        const owner = await c.query('SELECT id,suspended,adult_confirmed FROM users WHERE id=$1 FOR NO KEY UPDATE', [actor.id]);
        requireThat(owner.rows.length, 401, 'UNAUTHENTICATED', 'Sign in again.');
        const previous = await c.query('SELECT * FROM deletion_requests WHERE user_id=$1', [actor.id]);
        if (previous.rows.length) {
          requireThat(previous.rows[0].receipt_token_hash === hash && previous.rows[0].request_fingerprint === fingerprint,
            409, 'DELETION_REQUEST_EXISTS', 'Use your saved receipt to check the existing request.');
          return receipt(previous.rows[0]);
        }
        await this.liveOwner(c, actor);
        const active = await c.query(`SELECT 1 FROM active_participant_claims WHERE user_id=$1
          UNION ALL SELECT 1 FROM call_sessions WHERE (customer_id=$1 OR listener_id=$1) AND state<>'ended' LIMIT 1`, [actor.id]);
        requireThat(!active.rows.length, 409, 'CALL_ACTIVE', 'End the active call before requesting deletion.');
        const birth = await c.query("SELECT to_char(date_of_birth,'YYYY-MM-DD') birth FROM age_declarations WHERE user_id=$1", [actor.id]);
        const underage = birth.rows.length > 0 && !isAdultOn(birth.rows[0].birth, now);
        const id = randomUUID();
        await c.query(`INSERT INTO deletion_requests(id,user_id,status,notice_version,receipt_token_hash,request_fingerprint,
          restriction_review_required,private_material_cleanup_pending,created_at,updated_at) VALUES($1,$2,'review_required',$3,$4,$5,$6,$7,$8,$8)`,
        [id,actor.id,DELETION_NOTICE_VERSION,hash,fingerprint,underage,!!this.purgePrivateMaterials,new Date(now)]);
        await c.query(`INSERT INTO consents(id,user_id,purpose,notice_version,granted,created_at)
          VALUES($1,$2,'account_deletion',$3,true,$4) ON CONFLICT DO NOTHING`, [randomUUID(),actor.id,DELETION_NOTICE_VERSION,new Date(now)]);
        await this.event(c,id,'requested',[],now);
        await c.query(`UPDATE users SET suspended=true,desired_online=false,listener_approved=false,adult_confirmed=false,
          mode='customer',display_name='Deleted account',languages=ARRAY['en'],test_handle=NULL,
          identity_revoked_before=GREATEST(COALESCE(identity_revoked_before,0),$2),identity_last_issued_at=NULL,identity_last_auth_time=NULL WHERE id=$1`,
        [actor.id,Math.floor(now/1000)]);
        await c.query(`UPDATE auth_identities SET state='revoked',revoked_at=GREATEST(created_at,$2::timestamptz)
          WHERE user_id=$1 AND state<>'revoked'`, [actor.id,new Date(now)]);
        await c.query('DELETE FROM auth_sessions WHERE user_id=$1', [actor.id]);
        await c.query('DELETE FROM devices WHERE user_id=$1', [actor.id]);
        await c.query(`DELETE FROM otp_challenges WHERE user_id=$1 OR EXISTS
          (SELECT 1 FROM auth_identities i WHERE i.user_id=$1 AND i.provider='phone:msg91'
            AND i.issuer=otp_challenges.issuer AND i.subject_digest=otp_challenges.phone_digest)`, [actor.id]);
        await c.query('DELETE FROM favorites WHERE actor_id=$1 OR target_id=$1', [actor.id]);
        // Only the explicitly scoped name can be held. Never copy a whole
        // profile or a minor's profile; DOB is erased in every accepted request.
        if (!underage) await c.query(`UPDATE account_profile_evidence_holds h SET retained_display_name=p.submitted_display_name
          FROM profiles p WHERE h.user_id=$1 AND p.user_id=h.user_id AND h.released_at IS NULL AND h.retained_display_name IS NULL
          AND (EXISTS(SELECT 1 FROM reports r WHERE r.id=h.report_id AND r.status NOT IN ('resolved','closed','dismissed'))
            OR EXISTS(SELECT 1 FROM support_tickets s WHERE s.id=h.support_ticket_id AND s.status NOT IN ('resolved','closed','dismissed')))`, [actor.id]);
        if (underage) await c.query('UPDATE account_profile_evidence_holds SET retained_display_name=NULL WHERE user_id=$1', [actor.id]);
        await c.query('DELETE FROM profiles WHERE user_id=$1', [actor.id]);
        await c.query('DELETE FROM age_declarations WHERE user_id=$1', [actor.id]);
        return this.refresh(c, actor.id, now);
      });
    } catch (error) {
      // A capability cannot be reused across accounts, even concurrently.
      if ((error as {code?:string}).code === '23505') throw new ApiError(409, 'DELETION_REQUEST_EXISTS', 'Use a different private receipt for this account.');
      throw error;
    }
    // Database suspension is authoritative for discovery and authentication.
    // A Redis outage must not turn an already committed deletion into failure.
    await this.withdrawDiscovery(actor.id).catch(() => {});
    if (result.holds.includes('private_material_cleanup')) {
      const refreshed = await this.cleanPrivateMaterials(actor.id);
      if (refreshed) result = refreshed;
    }
    return result;
  }

  /** Internal worker only. It never approves retention or releases an open case.
   * Closed cases/released holds can lose their narrowly scoped name evidence.
   * No provider calls, financial mutations, arbitrary targets or policy override.
   */
  async processPending(): Promise<{ processed: number }> {
    const pending = await this.db.pool.query(`SELECT user_id FROM deletion_requests
      WHERE notice_version=$1 AND receipt_token_hash IS NOT NULL ORDER BY updated_at,id LIMIT 100`, [DELETION_NOTICE_VERSION]);
    for (const row of pending.rows) {
      await this.db.tx(async c => {
        await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE', [row.user_id]);
        await this.refresh(c,row.user_id,this.clock());
      });
      await this.withdrawDiscovery(row.user_id).catch(() => {});
      await this.cleanPrivateMaterials(row.user_id);
    }
    return { processed: pending.rows.length };
  }

  private async liveOwner(c: PoolClient, actor: Actor) {
    const result = await c.query(`SELECT u.id FROM users u JOIN auth_sessions s ON s.user_id=u.id
      WHERE u.id=$1 AND s.token_hash=$2 AND NOT u.suspended AND s.revoked_at IS NULL AND s.expires_at>$3
      FOR NO KEY UPDATE OF u`, [actor.id,actor.sessionHash,new Date(this.clock())]);
    requireThat(result.rows.length, 401, 'UNAUTHENTICATED', 'Sign in again.');
  }

  private async cleanPrivateMaterials(userId: string): Promise<DeletionReceipt | undefined> {
    const pending = await this.db.pool.query('SELECT private_material_cleanup_pending FROM deletion_requests WHERE user_id=$1', [userId]);
    if (!pending.rows[0]?.private_material_cleanup_pending || !this.purgePrivateMaterials) return;
    try {
      // Callback owns the private storage boundary and must be idempotent. A
      // failure leaves durable pending work, including after process restart.
      await this.purgePrivateMaterials(userId);
    } catch { return; }
    return this.db.tx(async c => {
      await c.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE', [userId]);
      await c.query('UPDATE deletion_requests SET private_material_cleanup_pending=false WHERE user_id=$1', [userId]);
      return this.refresh(c,userId,this.clock());
    });
  }

  private async event(c: PoolClient, requestId: string, kind: string, holds: DeletionHold[], now: number) {
    await c.query('INSERT INTO account_deletion_events(id,request_id,kind,holds,created_at) VALUES($1,$2,$3,$4,$5)',
      [randomUUID(),requestId,kind,holds,new Date(now)]);
  }

  private async refresh(c: PoolClient, userId: string, now: number): Promise<DeletionReceipt> {
    const current = (await c.query('SELECT * FROM deletion_requests WHERE user_id=$1 FOR UPDATE', [userId])).rows[0] as RequestRow;
    // Closure is an existing case state; no age/legal retention decision is made.
    await c.query(`UPDATE account_profile_evidence_holds h SET released_at=GREATEST(created_at,$2::timestamptz),retained_display_name=NULL
      WHERE user_id=$1 AND released_at IS NULL AND
      (EXISTS(SELECT 1 FROM reports r WHERE r.id=h.report_id AND r.status IN ('resolved','closed','dismissed'))
        OR EXISTS(SELECT 1 FROM support_tickets s WHERE s.id=h.support_ticket_id AND s.status IN ('resolved','closed','dismissed')))`, [userId,new Date(now)]);
    await c.query('UPDATE account_profile_evidence_holds SET retained_display_name=NULL WHERE user_id=$1 AND released_at IS NOT NULL', [userId]);
    const flags = (await c.query(`SELECT
      (EXISTS(SELECT 1 FROM purchases WHERE user_id=$1 AND state NOT IN ('fulfilled','rejected','cancelled','revoked'))
        OR EXISTS(SELECT 1 FROM refunds WHERE user_id=$1 AND state NOT IN ('succeeded','failed','cancelled'))
        OR EXISTS(SELECT 1 FROM payout_requests WHERE user_id=$1 AND state NOT IN ('paid','failed','cancelled','reversed'))
        OR EXISTS(SELECT 1 FROM spend_holds WHERE user_id=$1 AND released_at IS NULL)) financial,
      (EXISTS(SELECT 1 FROM reports r JOIN call_sessions c ON c.id=r.call_id WHERE $1 IN (r.actor_id,c.customer_id,c.listener_id)
          AND r.status NOT IN ('resolved','closed','dismissed'))
        OR EXISTS(SELECT 1 FROM support_tickets s LEFT JOIN call_sessions c ON c.id=s.call_id WHERE $1 IN (s.actor_id,c.customer_id,c.listener_id)
          AND s.status NOT IN ('resolved','closed','dismissed'))) dispute,
      EXISTS(SELECT 1 FROM account_profile_evidence_holds WHERE user_id=$1 AND released_at IS NULL AND retained_display_name IS NOT NULL) evidence`, [userId])).rows[0];
    const holds: DeletionHold[] = [];
    if (flags.financial) holds.push('financial_pending');
    if (flags.dispute) holds.push('dispute_open');
    if (flags.evidence) holds.push('profile_evidence');
    if (current.restriction_review_required) holds.push('age_safety_review');
    if (current.private_material_cleanup_pending) holds.push('private_material_cleanup');
    const erasedAt = current.personal_data_deleted_at ?? (flags.evidence || current.private_material_cleanup_pending ? null : new Date(now));
    const { rows } = await c.query(`UPDATE deletion_requests SET status=$2,retention_holds=$3,personal_data_deleted_at=$4,updated_at=$5
      WHERE user_id=$1 RETURNING *`, [userId,holds.length ? 'pending_hold' : 'review_required',holds,erasedAt,new Date(now)]);
    if (!current.personal_data_deleted_at && erasedAt) await this.event(c,current.id,'personal_data_deleted',holds,now);
    if (JSON.stringify(current.retention_holds) !== JSON.stringify(holds)) await this.event(c,current.id,'holds_changed',holds,now);
    return receipt(rows[0]);
  }
}
