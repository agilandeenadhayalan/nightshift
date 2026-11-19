import 'reflect-metadata';
import { loadConfig } from './config';
import { createApplication } from './http';

async function main(){
  const config=loadConfig();const runtime=await createApplication(config);
  await runtime.app.listen(config.port,'0.0.0.0');
  console.log(`NightShift test API listening on port ${config.port}; no real purchases or payouts`);
  let closing=false;
  const stop=async()=>{if(closing)return;closing=true;await runtime.close();};
  process.once('SIGINT',()=>void stop());process.once('SIGTERM',()=>void stop());
}
main().catch(error=>{console.error(error instanceof Error && error.message.startsWith('PRODUCTION_NOT_READY')?error.message:'API startup failed. Check private environment and local services.');process.exitCode=1;});
