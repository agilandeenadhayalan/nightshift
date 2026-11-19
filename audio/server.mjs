import http from 'node:http';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {coins,payoutPaise} from './billing.mjs';
const db=new DatabaseSync(process.env.DB_FILE || 'nightshift.sqlite');
db.exec('CREATE TABLE IF NOT EXISTS receipts(id TEXT PRIMARY KEY, ms INTEGER, cost INTEGER);');
const total=()=>db.prepare('SELECT coalesce(sum(cost),0) n FROM receipts').get().n;
const key=randomUUID(), sessions=new Map(), roles=['customer','listener'];
let online=false, call=null;
const available=()=>10000-total();
function pause(now){
  if(call.since!==null){call.ms+=Math.max(0,now-call.since);call.since=null;}
}
function finish(now){
  pause(now);
  db.prepare('INSERT INTO receipts VALUES(?,?,?)').run(call.id,Math.min(call.ms,call.limit*1000),Math.min(call.limit,coins(call.ms)));
  call=null;
}
function tick(now){
  if(!call)return;
  if(call.since!==null && call.ms+now-call.since>=call.limit*1000){finish(now);return;}
  for(const role of roles){
    if(call.ready[role] && now-call.seen[role]>5000){
      pause(call.seen[role]+5000);call.ready[role]=false;
    }
  }
  if(now-Math.min(...Object.values(call.seen))>45000)finish(now);
}
setInterval(()=>tick(Date.now()),500).unref();
const fail=m=>{throw Error(m)};
const server=http.createServer(async(req,res)=>{
 const now=Date.now();tick(now);
 try{
  if(req.method==='GET' && ['/','/app.js'].includes(req.url)){
   const js=req.url==='/app.js';res.setHeader('Content-Type',js?'application/javascript':'text/html; charset=utf-8');
   return res.end(readFileSync(new URL(js?'./public/app.js':'./public/index.html',import.meta.url)));
  }
  if(req.method!=='POST'||req.url!=='/api')fail('Unknown route');
  let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>100000)fail('Request too large');}
  const b=JSON.parse(raw);let out={};
  if(b.action==='login'){
    if(b.key!==key||!roles.includes(b.role))fail('Use the private demo link');
    const token=randomUUID();sessions.set(token,b.role);out={token};
  }else{
    const role=sessions.get(b.token);if(!role)fail('Sign in first');
    const other=roles.find(r=>r!==role);
    if(b.action==='online'&&role==='listener')online=!!b.value;
    if(b.action==='invite'){
      if(role!=='customer'||!online||call||available()<60)fail('Listener or 60 coins unavailable');
      call={id:randomUUID(),accepted:false,limit:available(),ms:0,since:null,ready:{},seen:{customer:now,listener:now},signals:{customer:[],listener:[]}};
    }
    if(['accept','signal','media','end'].includes(b.action)){
      if(!call||call.id!==b.id)fail('Call has already ended');
      if(b.action==='accept'&&role==='listener')call.accepted=true;
      if(b.action==='signal'&&call.accepted)call.signals[other].push(b.data);
      if(b.action==='media'&&call.accepted){
        call.ready[role]=b.value===true;
        if(call.ready.customer&&call.ready.listener){call.since??=now;}else pause(now);
      }
      if(b.action==='end')finish(now);
    }
    if(call)call.seen[role]=now;
    const used=total(),ms=call?call.ms+(call.since===null?0:now-call.since):0;
    out={online,balance:10000-used,diamonds:used/60,payout:payoutPaise(used)/100,
      call:call?{id:call.id,accepted:call.accepted,ms,cost:coins(ms),signals:b.action==='poll'?call.signals[role].splice(0):[]}:null,
      last:db.prepare('SELECT ms,cost FROM receipts ORDER BY rowid DESC LIMIT 1').get()};
  }
  res.setHeader('Content-Type','application/json');res.end(JSON.stringify(out));
 }catch(e){res.writeHead(400);res.end(JSON.stringify({error:e.message}));}
});
server.listen(Number(process.env.PORT||8787),'127.0.0.1',()=>console.log('Open both roles at http://localhost:'+server.address().port+'/#'+key));
