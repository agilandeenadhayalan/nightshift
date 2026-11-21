import {Database} from '../db';
import {StaffAuthority} from './authority';
import {StaffReviewDecisions} from './review-decisions';
import {ApprovedReviewPolicy} from './review-policy';
import {StaffReviewQueries} from './review-queries';
import {lstat,open,realpath} from 'node:fs/promises';
import path from 'node:path';
import {ApiError} from '../errors';
import {validateReviewPolicy} from './review-policy';

export async function loadApprovedReviewPolicy(file?:string):Promise<ApprovedReviewPolicy|undefined>{
  if(!file)return;
  try{
    if(!path.isAbsolute(file))throw Error();
    const target=path.resolve(file),info=await lstat(target);
    if(!info.isFile()||info.isSymbolicLink()||info.size>524288||path.resolve(await realpath(target))!==target)throw Error();
    const handle=await open(target,'r');
    try{
      const current=await handle.stat();if(!current.isFile()||current.size>524288)throw Error();
      const bytes=Buffer.alloc(524289),read=await handle.read(bytes,0,bytes.length,0);
      if(read.bytesRead>524288)throw Error();
      return validateReviewPolicy(JSON.parse(bytes.subarray(0,read.bytesRead).toString('utf8')));
    }finally{await handle.close();}
  }catch{throw new ApiError(503,'REVIEW_POLICY_UNAVAILABLE','The explicitly configured approved review policy is unavailable.');}
}

/** Explicit trusted configuration boundary. There is no fixture name, default
 * checklist, environment switch or automatic owner-policy approval. */
export function createStaffReviewDecisions(db:Database,authority:StaffAuthority,reviews:StaffReviewQueries,
  approvedPolicy?:ApprovedReviewPolicy,clock:()=>number=Date.now){
  return new StaffReviewDecisions(db,authority,reviews,approvedPolicy,clock);
}
