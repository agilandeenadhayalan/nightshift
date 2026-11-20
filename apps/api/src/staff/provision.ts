import { loadConfig } from '../config';
import { Database } from '../db';
import { Presence } from '../presence';
import { Auth } from '../auth';
import { createPhoneAuthentication } from '../identity/phone-auth';
import { createStaffAuthority } from './factory';
import { STAFF_PERMISSIONS,StaffPermission } from './authority';

/** Offline owner command. Default is read-only; no migration or seed runs. */
export async function runProvision(args:readonly string[]){
  const options=new Map<string,string>();let apply=false;
  for(let i=0;i<args.length;i++){
    const key=args[i]!;if(key==='--apply'){if(apply)throw new Error('Duplicate apply');apply=true;continue;}
    if(!['--request-id','--expected-user-id','--permissions'].includes(key)||options.has(key)||!args[i+1])throw new Error('Specify --request-id, --expected-user-id and --permissions; --apply is optional');
    options.set(key,args[++i]!);
  }
  const permissions=(options.get('--permissions')??'').split(',');
  if(!options.get('--request-id')||!options.get('--expected-user-id')||permissions.some(p=>!STAFF_PERMISSIONS.includes(p as StaffPermission)))throw new Error('Explicit request, account reference and permissions are required');
  const config=loadConfig();if(!config.staffAuth)throw new Error('Configure the reviewed staff adapter before provisioning');
  const db=new Database(config.databaseUrl),presence=new Presence(config.redisUrl);
  // No Redis connection is needed for this read-only/provider-and-DB command.
  const phone=await createPhoneAuthentication(db,presence,config,Date.now);
  const runtime=createStaffAuthority(db,new Auth(db,presence,config,phone),config);
  try{return await runtime.authority.provision(options.get('--request-id')!,options.get('--expected-user-id')!,permissions as StaffPermission[],apply);}
  finally{await runtime.close();await phone.close();await db.close();}
}
if(require.main===module)void runProvision(process.argv.slice(2)).then(result=>process.stdout.write(`${JSON.stringify(result)}\n`)).catch(()=>{
  // Never echo provider exceptions, UID, phone, DB URLs, credentials or proofs.
  process.stderr.write('Staff provisioning failed. Check the explicit request, account reference, configuration and current sign-in. No automatic recovery or grants were attempted.\n');process.exitCode=1;
});
