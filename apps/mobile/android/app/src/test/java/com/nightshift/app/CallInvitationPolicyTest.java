package com.nightshift.app;
import java.util.*;

public final class CallInvitationPolicyTest {
  static void check(boolean value,String name) { if(!value) throw new AssertionError(name); }
  public static void main(String[] args) throws Exception {
    long server=CallInvitationPolicy.date(InvitationFixtures.SERVER);
    Map<String,String> invitation=InvitationFixtures.payload();
    CallInvitationPolicy.Binding binding=new CallInvitationPolicy.Binding(invitation.get("registrationId"),invitation.get("bindingId"),1,"boot:1",server,server+1800000,500000,100000,0);
    for(int i=0;i<InvitationFixtures.CASES.size();i++) {
      check(CallInvitationPolicy.receive(InvitationFixtures.CASES.get(i),binding,new LinkedHashMap<>(),500000,100000,"boot:1",true).action.equals(InvitationFixtures.EXPECTED.get(i)),InvitationFixtures.NAMES.get(i));
    }
    var seen=new LinkedHashMap<String,CallInvitationPolicy.Seen>();
    check(CallInvitationPolicy.receive(invitation,binding,seen,500000,100000,"boot:1",true).action.equals("show"),"first display");
    check(CallInvitationPolicy.receive(invitation,binding,seen,500000,100000,"boot:1",true).action.equals("ignore"),"dedup");
    var terminal=new HashMap<>(invitation);terminal.put("type","call.terminal");terminal.put("callVersion","2");
    check(CallInvitationPolicy.receive(terminal,binding,seen,500001,100001,"boot:1",true).action.equals("dismiss"),"terminal wins");
    var later=new HashMap<>(invitation);later.put("callVersion","3");
    check(CallInvitationPolicy.receive(later,binding,seen,500002,100002,"boot:1",true).action.equals("ignore"),"terminal cannot revive");
    check(!binding.valid(494000,100000,"boot:1"),"wall rollback");
    check(!binding.valid(506000,100000,"boot:1"),"wall advance");
    check(!binding.valid(500000,100000,"boot:2"),"reboot");
    check(!binding.valid(500000,99999,"boot:1"),"monotonic rollback");
    check(!binding.valid(2300000,1900000,"boot:1"),"absolute lease expiry");
    check(CallInvitationPolicy.receive(invitation,binding,new LinkedHashMap<>(),500000,100000,"boot:1",false).action.equals("ignore"),"permission denied");
    check(!CallInvitationPolicy.addressed(invitation,binding,530000,130000,"boot:1"),"tap expired");
    var delayed=new CallInvitationPolicy.Binding(invitation.get("registrationId"),invitation.get("bindingId"),1,"boot:1",server,server+1800000,500000,100000,30000);
    check(!CallInvitationPolicy.addressed(invitation,delayed,500000,100000,"boot:1"),"network latency never extends invitation");
    var shortLease=new CallInvitationPolicy.Binding(invitation.get("registrationId"),invitation.get("bindingId"),1,"boot:1",server,server+500,500000,100000,0);
    check(CallInvitationPolicy.remaining(invitation,shortLease,500000,100000,"boot:1")==500,"notification cannot outlive opt-in lease");
    for(int i=0;i<64;i++) seen.put(UUID.randomUUID().toString(),new CallInvitationPolicy.Seen(2,server+30000,true));
    var distinct=new HashMap<>(invitation);distinct.put("callId",UUID.randomUUID().toString());
    check(CallInvitationPolicy.receive(distinct,binding,seen,500000,100000,"boot:1",true).action.equals("ignore"),"bounded tombstones fail closed");
    boolean[] keyPresent={true}, ciphertextPresent={true};
    InvitationInvalidation.invalidate(new InvitationInvalidation.Storage() {
      public void deleteKey() { keyPresent[0]=false; }
      public void deleteCiphertext() { throw new RuntimeException("disk unavailable"); }
    });
    // A subsequent state write fails, retaining old bytes. Cold load still
    // cannot decrypt them because their key was destroyed first.
    check(!keyPresent[0] && ciphertextPresent[0],"failed persist cannot restore old binding");
    InvitationInvalidation.invalidate(new InvitationInvalidation.Storage() {
      public void deleteKey() { throw new RuntimeException("keystore unavailable"); }
      public void deleteCiphertext() { ciphertextPresent[0]=false; }
    });
    check(!ciphertextPresent[0],"ciphertext fallback invalidates old binding");
    boolean rejected=false;
    try { InvitationInvalidation.invalidate(new InvitationInvalidation.Storage() {
      public void deleteKey() { throw new RuntimeException(); }
      public void deleteCiphertext() { throw new RuntimeException(); }
    }); } catch(Exception expected) { rejected=true; }
    check(rejected,"both storage failures cannot acknowledge cleanup");
    var tokenGate=new InvitationTokenGate();
    check(tokenGate.enter(),"first token task admitted");
    check(!tokenGate.enter(),"timeout/activity recreation cannot admit another task");
    tokenGate.settled();check(tokenGate.enter(),"only actual completion releases token gate");
    System.out.println("Call invitation policy: shared9 + 20 clock/binding/order/durability/admission checks passed");
  }
}
