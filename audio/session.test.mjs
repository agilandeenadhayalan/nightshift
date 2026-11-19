import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
test('two roles discover, accept, signal, disconnect, reconnect and settle exactly once', async()=>{
 const child=spawn(process.execPath,['server.mjs'],{env:{...process.env,PORT:'0',DB_FILE:':memory:'}});
 try{
 const [line]=await once(child.stdout,'data');const url=new URL(line.toString().trim().split(' ').at(-1));
 const send=async(action,token,more={})=>(await fetch(url.origin+'/api',{method:'POST',body:JSON.stringify({action,token,...more})})).json();
 const login=async role=>(await send('login',null,{role,key:url.hash.slice(1)})).token;
 const a=await login('customer'),b=await login('listener');
 await send('online',b,{value:true});
 const id=(await send('invite',a)).call.id;
 await send('accept',b,{id});
 await send('signal',a,{id,data:'offer'});assert.deepEqual((await send('poll',b)).call.signals,['offer']);
 for(const token of [a,b])await send('media',token,{id,value:true});
 await new Promise(r=>setTimeout(r,100));
 const paused=(await send('media',b,{id,value:false})).call.ms;
 assert.ok(paused>0);assert.equal((await send('poll',a)).call.ms,paused);
 await send('media',b,{id,value:true});
 const done=await send('end',a,{id});assert.equal(done.balance,10000);assert.equal(done.last.cost,0);
 assert.ok((await send('end',b,{id})).error);
 }finally{child.kill();}
});
