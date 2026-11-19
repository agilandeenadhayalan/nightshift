const $=id=>document.getElementById(id);
let role,token,state,pc,stream,callId,offered=false;
const api=async(action,extra={})=>{
 const r=await fetch('/api',{method:'POST',body:JSON.stringify({action,token,...extra})});const j=await r.json();if(!r.ok)throw Error(j.error);return j;
};
const showError=e=>{$('error').textContent=e.message;};
const bind=(id,fn)=>$(id).onclick=()=>fn().catch(showError);
async function mic(){stream??=await navigator.mediaDevices.getUserMedia({audio:true});}
function cleanup(){if(pc){pc.onconnectionstatechange=null;pc.close();pc=null;}stream?.getTracks().forEach(t=>t.stop());stream=null;offered=false;callId=null;}
for(const el of document.querySelectorAll('[data-role]'))el.onclick=async()=>{
 try{role=el.dataset.role;({token}=await api('login',{key:location.hash.slice(1),role}));$('entry').hidden=true;$('room').hidden=false;$('name').textContent=role==='customer'?'Customer':'Listener';await poll();}catch(e){showError(e);}
};
bind('available',async()=>api('online',{value:!state.online}));
bind('dial',async()=>{await mic();try{await api('invite');}catch(e){cleanup();throw e;}});
bind('accept',async()=>{await mic();await api('accept',{id:state.call.id});});
bind('end',async()=>{await api('end',{id:state.call.id});cleanup();});
async function poll(){
 try{
 state=await api('poll');const c=state.call;
 $('wallet').textContent=role==='customer'?state.balance+' test coins':'Earned '+state.diamonds.toFixed(3)+' diamonds · ₹'+state.payout.toFixed(2);
 $('available').hidden=role!=='listener'||!!c;$('available').textContent=state.online?'Go offline':'Go online';
 $('dial').hidden=role!=='customer'||!!c;$('dial').disabled=!state.online||state.balance<60;
 $('accept').hidden=role!=='listener'||!c||c.accepted;$('end').hidden=!c;
 $('status').textContent=c?(c.accepted?'Call · '+Math.floor(c.ms/1000)+' connected seconds · '+c.cost+' coins':'Ringing…'):(state.online?'Listener available':'Listener offline');
 $('receipt').textContent=state.last?'Last call · '+state.last.cost+' coins · '+(state.last.cost/60).toFixed(3)+' diamonds':'';
 if(!c && callId)cleanup();
 if(c)callId=c.id;
 if(c?.accepted){
  if(!pc){
   await mic();pc=new RTCPeerConnection();const id=c.id;
   stream.getTracks().forEach(t=>pc.addTrack(t,stream));
   pc.ontrack=e=>{$('remote').srcObject=e.streams[0];};
   pc.onconnectionstatechange=()=>api('media',{id,value:pc?.connectionState==='connected'}).catch(showError);
  }
  async function sendSDP(desc){await pc.setLocalDescription(desc);if(pc.iceGatheringState!=='complete')await new Promise(resolve=>{const f=()=>{if(pc.iceGatheringState==='complete'){pc.removeEventListener('icegatheringstatechange',f);resolve();}};pc.addEventListener('icegatheringstatechange',f);f();});await api('signal',{id:c.id,data:pc.localDescription});}
  if(role==='customer'&&!offered){offered=true;await sendSDP(await pc.createOffer());}
  for(const s of c.signals){await pc.setRemoteDescription(s);if(s.type==='offer')await sendSDP(await pc.createAnswer());}
 }
 }catch(e){showError(e);}finally{setTimeout(poll,450);}
}
