import {mkdtemp,readFile,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const fixture=JSON.parse(await readFile(path.join(root,'packages/contracts/fixtures/call-invitations.json'),'utf8'));
const output=await mkdtemp(path.join(tmpdir(),'nightshift-invitations-'));
const quote=value=>JSON.stringify(value);
const map=value=>`new java.util.HashMap<>(java.util.Map.ofEntries(${Object.entries(value).map(([k,v])=>`java.util.Map.entry(${quote(k)},${quote(v)})`).join(',')}))`;
const executable=name=>process.env.JAVA_HOME?path.join(process.env.JAVA_HOME,'bin',process.platform==='win32'?`${name}.exe`:name):name;
try {
  const source=`package com.nightshift.app; public final class InvitationFixtures {
    static final String SERVER=${quote(fixture.serverTime)};
    static java.util.Map<String,String> payload(){return ${map(fixture.payload)};}
    static final java.util.List<java.util.Map<String,String>> CASES=java.util.List.of(${fixture.cases.map(c=>map({...fixture.payload,...c.override})).join(',')});
    static final java.util.List<String> EXPECTED=java.util.List.of(${fixture.cases.map(c=>quote(c.expected)).join(',')});
    static final java.util.List<String> NAMES=java.util.List.of(${fixture.cases.map(c=>quote(c.name)).join(',')});
  }`;
  const fixturePath=path.join(output,'InvitationFixtures.java');await writeFile(fixturePath,source);
  for(const [command,args] of [['javac',['--release','17','-d',output,fixturePath,
    'apps/mobile/android/app/src/main/java/com/nightshift/app/CallInvitationPolicy.java',
    'apps/mobile/android/app/src/main/java/com/nightshift/app/InvitationInvalidation.java',
    'apps/mobile/android/app/src/main/java/com/nightshift/app/InvitationTokenGate.java',
    'apps/mobile/android/app/src/test/java/com/nightshift/app/CallInvitationPolicyTest.java']],['java',['-cp',output,'com.nightshift.app.CallInvitationPolicyTest']]]) {
    const result=spawnSync(executable(command),args,{cwd:root,stdio:'inherit',windowsHide:true,timeout:30000});
    if(result.error||result.status!==0) throw new Error('Native invitation test failed');
  }
} finally {
  if(path.dirname(path.resolve(output))!==path.resolve(tmpdir())||!path.basename(output).startsWith('nightshift-invitations-')) throw new Error('Unexpected temporary path');
  await rm(output,{recursive:true,force:true});
}
