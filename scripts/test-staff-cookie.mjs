import {mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const parent=path.resolve(tmpdir()),output=await mkdtemp(path.join(parent,'nightshift-staff-cookie-'));
function run(name,args){
  const executable=process.env.JAVA_HOME?path.join(process.env.JAVA_HOME,'bin',process.platform==='win32'?`${name}.exe`:name):name;
  const result=spawnSync(executable,args,{cwd:root,stdio:'inherit',windowsHide:true,timeout:30000});
  if(result.error||result.status!==0)throw new Error(`Native staff cookie ${name} failed`);
}
try{
  run('javac',['--release','17','-d',output,
    'apps/mobile/android/app/src/main/java/com/nightshift/app/StaffCookiePolicy.java',
    'apps/mobile/android/app/src/main/java/com/nightshift/app/StaffCookieCoordinator.java',
    'apps/mobile/android/app/src/test/java/com/nightshift/app/StaffCookieCoordinatorTest.java']);
  run('java',['-cp',output,'com.nightshift.app.StaffCookieCoordinatorTest']);
}finally{
  if(path.dirname(path.resolve(output))!==parent||!path.basename(output).startsWith('nightshift-staff-cookie-'))throw new Error('Unexpected native test output');
  await rm(output,{recursive:true,force:true});
}
