import {createHash,randomUUID} from 'node:crypto';
import {link,lstat,mkdir,readFile,unlink,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {setTimeout as defaultSleep} from 'node:timers/promises';

const maxBytes=64*1024*1024,maxAttempts=3;
const retryableStatuses=new Set([429,500,502,503,504]);
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
class DownloadFailure extends Error {}
class RetryableFailure extends Error {
  constructor(message,delay){super(message);this.delay=delay;}
}

async function verifyCache(target,sha256){
  let stat;
  try{stat=await lstat(target);}catch(error){if(error.code==='ENOENT')return false;throw error;}
  if(!stat.isFile()||stat.size>maxBytes)throw new DownloadFailure('Invalid generator cache file');
  if(digest(await readFile(target))!==sha256)throw new Error('Cached generator checksum mismatch; remove the invalid cached JAR');
  return true;
}

function retryAfter(value,now){
  if(value===null)return undefined;
  const raw=value.trim();
  if(/^\d+$/.test(raw)){
    const delay=Number(raw)*1000;
    if(Number.isSafeInteger(delay))return delay;
  }else if(/^(Mon|Tue|Wed|Thu|Fri|Sat|Sun), \d{2} [A-Z][a-z]{2} \d{4} \d{2}:\d{2}:\d{2} GMT$/.test(raw)){
    const date=Date.parse(raw);
    if(Number.isFinite(date)&&new Date(date).toUTCString()===raw)return Math.max(0,date-now);
  }
  // An unparseable instruction must not become a shorter fallback delay.
  throw new DownloadFailure('Invalid generator Retry-After');
}

async function bounded(operation,timeoutMs,onTimeout){
  let timer;
  const timeout=new Promise((_,reject)=>{timer=setTimeout(()=>{
    onTimeout();reject(new RetryableFailure('Generator download deadline exceeded'));
  },timeoutMs);});
  try{return await Promise.race([Promise.resolve().then(operation),timeout]);}
  finally{clearTimeout(timer);}
}

async function readAttempt(url,fetchImpl,now,timeoutMs){
  const controller=new AbortController();
  try{
    return await bounded(async()=>{
      let response;
      try{response=await fetchImpl(url,{signal:controller.signal,redirect:'manual'});}
      catch{throw new RetryableFailure('Generator download network failure');}
      if(controller.signal.aborted)throw new DownloadFailure('Generator download deadline exceeded');
      if(response.status!==200){
        // Abort closes the unused response body without waiting on its producer.
        controller.abort();
        if(retryableStatuses.has(response.status))throw new RetryableFailure(
          `Generator download failed: HTTP ${response.status}`,retryAfter(response.headers.get('retry-after'),now()));
        throw new DownloadFailure(`Generator download failed: HTTP ${response.status}`);
      }
      const length=response.headers.get('content-length');
      if(length!==null&&(!/^\d+$/.test(length)||Number(length)>maxBytes))throw new DownloadFailure('Generator download size exceeds limit');
      if(!response.body)throw new DownloadFailure('Generator download body missing');
      const reader=response.body.getReader(),chunks=[];let size=0;
      try{
        while(true){
          let part;
          try{part=await reader.read();}catch{throw new RetryableFailure('Generator download body failure');}
          if(controller.signal.aborted)throw new DownloadFailure('Generator download deadline exceeded');
          if(part.done)break;
          size+=part.value.byteLength;
          if(size>maxBytes)throw new DownloadFailure('Generator download size exceeds limit');
          chunks.push(Buffer.from(part.value));
        }
      }finally{reader.releaseLock();}
      return Buffer.concat(chunks,size);
    },timeoutMs,()=>controller.abort());
  }finally{controller.abort();}
}

/** Generic verified artifact cache. The CLI supplies its fixed official URL/hash;
 * dependency injection lets offline tests exercise delays and interrupted I/O. */
export async function ensureVerifiedDownload({target,url,sha256},{fetchImpl=fetch,sleep=defaultSleep,now=Date.now,
  requestTimeoutMs=60_000,totalTimeoutMs=180_000,maxRetryDelayMs=30_000}={}){
  const parsed=new URL(url);
  if(parsed.protocol!=='https:'||parsed.username||parsed.password||!/^[a-f0-9]{64}$/.test(sha256))throw new DownloadFailure('Invalid pinned artifact configuration');
  for(const value of [requestTimeoutMs,totalTimeoutMs,maxRetryDelayMs])if(!Number.isSafeInteger(value)||value<=0)throw new DownloadFailure('Invalid download deadline');
  await mkdir(path.dirname(target),{recursive:true});
  if(await verifyCache(target,sha256))return target;
  const deadline=now()+totalTimeoutMs;
  let bytes;
  for(let attempt=0;attempt<maxAttempts;attempt++){
    const remaining=deadline-now();
    if(remaining<=0)throw new DownloadFailure('Generator download deadline exceeded');
    try{
      bytes=await readAttempt(url,fetchImpl,now,Math.min(requestTimeoutMs,remaining));
      if(now()>=deadline)throw new DownloadFailure('Generator download deadline exceeded');
      if(digest(bytes)!==sha256)throw new DownloadFailure('Generator download checksum mismatch');
      break;
    }catch(error){
      if(!(error instanceof RetryableFailure)||attempt===maxAttempts-1)throw error;
      const delay=error.delay??1000*2**attempt;
      if(delay>maxRetryDelayMs||delay>=deadline-now())throw new DownloadFailure('Generator retry delay exceeds remaining limit');
      const retryAt=now()+delay;
      // Never clamp Retry-After down to our cap or retry after a timed-out wait.
      for(let waits=0;now()<retryAt;waits++){
        if(waits===3)throw new DownloadFailure('Generator retry wait did not complete');
        await bounded(()=>sleep(retryAt-now()),deadline-now(),()=>{});
      }
    }
  }
  if(!bytes)throw new DownloadFailure('Generator download unavailable');
  const temporary=path.join(path.dirname(target),`.${path.basename(target)}.${randomUUID()}.tmp`);
  try{
    await writeFile(temporary,bytes,{flag:'wx',mode:0o600});
    if(now()>=deadline)throw new DownloadFailure('Generator download deadline exceeded');
    // Exclusive hard-link publication cannot overwrite a concurrent cache file.
    try{await link(temporary,target);}catch(error){if(error.code!=='EEXIST')throw error;}
    if(!await verifyCache(target,sha256))throw new DownloadFailure('Generator cache publication missing');
  }finally{await unlink(temporary).catch(error=>{if(error.code!=='ENOENT')throw error;});}
  return target;
}
