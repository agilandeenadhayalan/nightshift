import {createHash} from 'node:crypto';
import {fields,object,requireThat} from '../errors';

export const REVIEW_OUTCOMES=['approved','rejected','needs_information'] as const;
export type ReviewOutcome=typeof REVIEW_OUTCOMES[number];
export const EVIDENCE_KINDS=['application','voice_sample','self_declaration'] as const;
export type EvidenceKind=typeof EVIDENCE_KINDS[number];
export interface ReviewText {en:string;ta:string;}
export interface ReviewCheck {id:string;label:ReviewText;requiredForApproval:boolean;evidenceKinds:EvidenceKind[];}
export interface ReviewReason {code:string;label:ReviewText;message:ReviewText;}
/** Trusted approved configuration only. No fixture/default policy is bundled. */
export interface ApprovedReviewPolicy {version:string;approvalReference:string;checks:ReviewCheck[];reasons:Record<ReviewOutcome,ReviewReason[]>;}
export function canonical(value:unknown):string{
  if(Array.isArray(value))return `[${value.map(canonical).join(',')}]`;
  if(value&&typeof value==='object')return `{${Object.keys(value).sort().map(k=>`${JSON.stringify(k)}:${canonical((value as Record<string,unknown>)[k])}`).join(',')}}`;
  return JSON.stringify(value);
}
export const reviewHash=(value:unknown)=>createHash('sha256').update(canonical(value)).digest('hex');
const slug=(value:unknown)=>typeof value==='string'&&/^[a-z][a-z0-9_]{0,63}$/.test(value);
const text=(value:unknown,max:number)=>typeof value==='string'&&[...value].length>=1&&[...value].length<=max&&!/[\x00-\x1f\x7f]/.test(value);
function translated(value:unknown,max:number){const row=object(value);fields(row,['en','ta']);return text(row.en,max)&&text(row.ta,max);}
export function validateReviewPolicy(input:ApprovedReviewPolicy):ApprovedReviewPolicy{
  const p=object(input);fields(p,['version','approvalReference','checks','reasons']);
  const valid=(condition:unknown)=>requireThat(condition,503,'REVIEW_POLICY_UNAVAILABLE','An approved review policy is unavailable.');
  valid(text(p.version,80)&&text(p.approvalReference,160)&&Array.isArray(p.checks)&&p.checks.length>=1&&p.checks.length<=20);
  const ids=new Set<string>();
  for(const value of p.checks as unknown[]){const c=object(value);fields(c,['id','label','requiredForApproval','evidenceKinds']);
    valid(slug(c.id)&&!ids.has(c.id as string)&&translated(c.label,160)&&typeof c.requiredForApproval==='boolean'
      &&Array.isArray(c.evidenceKinds)&&c.evidenceKinds.length>=1&&c.evidenceKinds.length<=3
      &&new Set(c.evidenceKinds).size===c.evidenceKinds.length&&c.evidenceKinds.every(k=>EVIDENCE_KINDS.includes(k as EvidenceKind)));ids.add(c.id as string);
  }
  valid((p.checks as ReviewCheck[]).some(c=>c.requiredForApproval));
  const reasons=object(p.reasons);fields(reasons,[...REVIEW_OUTCOMES]);
  for(const outcome of REVIEW_OUTCOMES){const values=reasons[outcome];valid(Array.isArray(values)&&values.length>=1&&values.length<=20);const codes=new Set<string>();
    for(const value of values as unknown[]){const r=object(value);fields(r,['code','label','message']);valid(slug(r.code)&&!codes.has(r.code as string)&&translated(r.label,160)&&translated(r.message,500));codes.add(r.code as string);}
  }
  // Detach approved configuration from any later caller mutation.
  return JSON.parse(canonical(input)) as ApprovedReviewPolicy;
}
