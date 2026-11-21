import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdtemp,readFile,readdir,rm,writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {ensureVerifiedDownload} from './verified-download.mjs';

const bytes=Buffer.from('synthetic fixed artifact'),sha256=createHash('sha256').update(bytes).digest('hex');
const url='https://repo.maven.apache.org/synthetic-test-artifact.jar';
async function isolated(run){
  const directory=await mkdtemp(path.join(tmpdir(),'nightshift-download-'));
  try{await run({target:path.join(directory,'artifact.jar'),url,sha256},directory);}
  finally{
    assert.equal(path.dirname(path.resolve(directory)),path.resolve(tmpdir()));
    assert.ok(path.basename(directory).startsWith('nightshift-download-'));
    await rm(directory,{recursive:true,force:true});
  }
}

test('HTTP429 waits the requested Retry-After then verifies and publishes one artifact',()=>isolated(async asset=>{
  let calls=0,now=0;const waits=[];
  const result=await ensureVerifiedDownload(asset,{
    fetchImpl:async()=>++calls===1?new Response(null,{status:429,headers:{'retry-after':'2'}}):new Response(bytes),
    now:()=>now,sleep:async ms=>{waits.push(ms);now+=ms;},
  });
  assert.equal(result,asset.target);assert.equal(calls,2);assert.deepEqual(waits,[2000]);
  assert.deepEqual(await readFile(asset.target),bytes);
}));

test('a valid existing artifact is verified and reused without any network request',()=>isolated(async asset=>{
  await writeFile(asset.target,bytes);
  await ensureVerifiedDownload(asset,{fetchImpl:async()=>{throw new Error('network must not run');}});
  assert.deepEqual(await readFile(asset.target),bytes);
}));

test('corrupt cached bytes fail closed without downloading a replacement',()=>isolated(async asset=>{
  await writeFile(asset.target,'corrupt');let calls=0;
  await assert.rejects(ensureVerifiedDownload(asset,{fetchImpl:async()=>{calls++;return new Response(bytes);}}),/Cached generator checksum mismatch/);
  assert.equal(calls,0);assert.equal(await readFile(asset.target,'utf8'),'corrupt');
}));

test('HTTP-date Retry-After is respected exactly and past dates permit immediate retry',()=>isolated(async asset=>{
  for(const seconds of [3,-3]){
    let calls=0,now=Date.UTC(2026,10,21,12);const waits=[];
    const header=new Date(now+seconds*1000).toUTCString();
    await ensureVerifiedDownload({...asset,target:`${asset.target}-${seconds}`},{now:()=>now,
      sleep:async ms=>{waits.push(ms);now+=ms;},fetchImpl:async()=>++calls===1?
        new Response(null,{status:503,headers:{'retry-after':header}}):new Response(bytes)});
    assert.equal(calls,2);assert.deepEqual(waits,seconds>0?[3000]:[]);
  }
}));

test('Retry-After beyond the delay cap or remaining total budget fails without an early retry',()=>isolated(async(asset,directory)=>{
  for(const [value,options] of [['31',{}],['2',{totalTimeoutMs:2000}]]){
    let calls=0;const waits=[];
    await assert.rejects(ensureVerifiedDownload(asset,{...options,now:()=>0,sleep:async ms=>{waits.push(ms);},
      fetchImpl:async()=>{calls++;return new Response(null,{status:429,headers:{'retry-after':value}});}}),/retry delay exceeds remaining limit/);
    assert.equal(calls,1);assert.deepEqual(waits,[]);assert.deepEqual(await readdir(directory),[]);
  }
}));

test('negative malformed fractional and noncanonical Retry-After values never become fallback retries',()=>isolated(async(asset,directory)=>{
  for(const value of ['-1','1.5','1e1','tomorrow','999999999999999999','Sun, 21 Nov 2026 12:00:00 GMT']){
    let calls=0;const waits=[];
    await assert.rejects(ensureVerifiedDownload(asset,{now:()=>Date.UTC(2026,10,21),sleep:async ms=>{waits.push(ms);},
      fetchImpl:async()=>{calls++;return new Response(null,{status:429,headers:{'retry-after':value}});}}),/Invalid generator Retry-After/);
    assert.equal(calls,1);assert.deepEqual(waits,[]);assert.deepEqual(await readdir(directory),[]);
  }
}));

test('transient server and network failures retry at most three times with bounded backoff',()=>isolated(async asset=>{
  let calls=0,now=0;const waits=[];
  await ensureVerifiedDownload(asset,{now:()=>now,sleep:async ms=>{waits.push(ms);now+=ms;},fetchImpl:async()=>{
    calls++;if(calls===1)return new Response(null,{status:502});
    if(calls===2)throw new TypeError('synthetic private network detail');return new Response(bytes);
  }});
  assert.equal(calls,3);assert.deepEqual(waits,[1000,2000]);assert.deepEqual(await readFile(asset.target),bytes);
  let failedCalls=0;
  await assert.rejects(ensureVerifiedDownload({...asset,target:`${asset.target}-missing`},{now:()=>0,
    fetchImpl:async()=>{failedCalls++;return new Response(null,{status:429,headers:{'retry-after':'0'}});}}),/HTTP 429/);
  assert.equal(failedCalls,3);
}));

test('other retryable server statuses recover while permanent HTTP and redirects fail immediately',()=>isolated(async(asset,directory)=>{
  for(const status of [500,503,504]){
    let calls=0,now=0;const target=path.join(directory,`server-${status}`);
    await ensureVerifiedDownload({...asset,target},{now:()=>now,sleep:async ms=>{now+=ms;},fetchImpl:async()=>++calls===1?new Response(null,{status}):new Response(bytes)});
    assert.equal(calls,2);
  }
  for(const status of [302,401,403,404,501]){
    let calls=0;
    await assert.rejects(ensureVerifiedDownload(asset,{fetchImpl:async(request,options)=>{
      calls++;assert.equal(request,url);assert.equal(options.redirect,'manual');assert.equal(options.headers,undefined);
      return new Response(null,{status,headers:{location:'https://unrelated.invalid/artifact'}});
    }}),new RegExp(`HTTP ${status}`));assert.equal(calls,1);
  }
}));

test('download checksum failure is not retried and publishes neither cache nor temporary files',()=>isolated(async(asset,directory)=>{
  let calls=0;
  await assert.rejects(ensureVerifiedDownload(asset,{fetchImpl:async()=>{calls++;return new Response('incorrect bytes');}}),/download checksum mismatch/);
  assert.equal(calls,1);assert.deepEqual(await readdir(directory),[]);
}));

test('an interrupted stream is retried without publishing its partial bytes',()=>isolated(async(asset,directory)=>{
  let calls=0,now=0;
  await ensureVerifiedDownload(asset,{now:()=>now,sleep:async ms=>{now+=ms;},fetchImpl:async()=>{
    calls++;assert.deepEqual(await readdir(directory),[]);
    if(calls===1)return new Response(new ReadableStream({start(controller){controller.enqueue(bytes.subarray(0,3));controller.error(new Error('synthetic interruption'));}}));
    return new Response(bytes);
  }});
  assert.equal(calls,2);assert.deepEqual(await readFile(asset.target),bytes);assert.deepEqual(await readdir(directory),['artifact.jar']);
}));

test('declared and streamed oversized bodies fail closed without retry or cache publication',()=>isolated(async(asset,directory)=>{
  for(const declared of [true,false]){
    let calls=0;
    await assert.rejects(ensureVerifiedDownload(asset,{fetchImpl:async()=>{
      calls++;return declared?new Response(bytes,{headers:{'content-length':String(64*1024*1024+1)}}):
        new Response(new ReadableStream({start(controller){controller.enqueue(new Uint8Array(64*1024*1024+1));controller.close();}}));
    }}),/size exceeds limit/);
    assert.equal(calls,1);assert.deepEqual(await readdir(directory),[]);
  }
}));

test('a hanging request is bounded and a late successful response cannot publish a cache',()=>isolated(async(asset,directory)=>{
  let release,calls=0,signal;
  const pending=new Promise(resolve=>{release=resolve;});
  await assert.rejects(ensureVerifiedDownload(asset,{requestTimeoutMs:15,totalTimeoutMs:30,fetchImpl:async(_url,options)=>{
    calls++;signal=options.signal;return pending;
  }}),/deadline exceeded|retry delay exceeds remaining limit/);
  assert.equal(calls,1);assert.equal(signal.aborted,true);
  release(new Response(bytes));await new Promise(resolve=>setTimeout(resolve,10));
  assert.deepEqual(await readdir(directory),[]);
}));

test('a hanging Retry-After wait cannot outlive the total budget or dispatch later',()=>isolated(async(asset,directory)=>{
  let calls=0,release;const wait=new Promise(resolve=>{release=resolve;});
  await assert.rejects(ensureVerifiedDownload(asset,{totalTimeoutMs:30,now:()=>990,sleep:()=>wait,
    fetchImpl:async()=>{calls++;return new Response(null,{status:429,headers:{'retry-after':'Thu, 01 Jan 1970 00:00:01 GMT'}});}}),/deadline exceeded/);
  assert.equal(calls,1);release();await new Promise(resolve=>setTimeout(resolve,10));
  assert.equal(calls,1);assert.deepEqual(await readdir(directory),[]);
}));

test('a held response body times out without retaining partial or late cache contents',()=>isolated(async(asset,directory)=>{
  let controller,calls=0;
  await assert.rejects(ensureVerifiedDownload(asset,{requestTimeoutMs:15,totalTimeoutMs:30,fetchImpl:async()=>{
    calls++;return new Response(new ReadableStream({start(value){controller=value;value.enqueue(bytes.subarray(0,3));}}));
  }}),/deadline exceeded|retry delay exceeds remaining limit/);
  assert.equal(calls,1);controller.enqueue(bytes.subarray(3));controller.close();
  await new Promise(resolve=>setTimeout(resolve,10));assert.deepEqual(await readdir(directory),[]);
}));

test('concurrent verified publishers preserve one complete cache and remove all temporary files',()=>isolated(async(asset,directory)=>{
  let count=0,release;const gate=new Promise(resolve=>{release=resolve;});
  const fetchImpl=async()=>{if(++count===4)release();await gate;return new Response(bytes);};
  await Promise.all(Array.from({length:4},()=>ensureVerifiedDownload(asset,{fetchImpl})));
  assert.equal(count,4);assert.deepEqual(await readFile(asset.target),bytes);assert.deepEqual(await readdir(directory),['artifact.jar']);
}));

test('a corrupt concurrent winner is never overwritten and every later cache hit is reverified',()=>isolated(async(asset,directory)=>{
  await assert.rejects(ensureVerifiedDownload(asset,{fetchImpl:async()=>{await writeFile(asset.target,'corrupt winner');return new Response(bytes);}}),/Cached generator checksum mismatch/);
  assert.equal(await readFile(asset.target,'utf8'),'corrupt winner');assert.deepEqual(await readdir(directory),['artifact.jar']);
  await writeFile(asset.target,bytes);await ensureVerifiedDownload(asset);
  await writeFile(asset.target,'corrupt after first check');
  await assert.rejects(ensureVerifiedDownload(asset),/Cached generator checksum mismatch/);
}));
