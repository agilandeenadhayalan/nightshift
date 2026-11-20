package com.nightshift.app;

import java.util.ArrayList;
import java.util.List;

/** Real native policy/state-machine tests, with deterministic platform callbacks. */
public final class StaffCookieCoordinatorTest {
    static final String TOKEN = "a".repeat(64);
    static final class Clock implements StaffCookieCoordinator.Clock { long now = 1800000000000L; public long now() { return now; } }
    static final class Task { Runnable run; boolean cancelled; Task(Runnable run) { this.run=run; } }
    static final class Scheduler implements StaffCookieCoordinator.Scheduler {
        final List<Task> tasks=new ArrayList<>();
        public StaffCookieCoordinator.Cancellation after(long ms,Runnable run) { Task task=new Task(run);tasks.add(task);return ()->task.cancelled=true; }
        void expire() { for(Task task:new ArrayList<>(tasks)) if(!task.cancelled) {task.cancelled=true;task.run.run();} }
    }
    static final class Writer implements StaffCookieCoordinator.Writer {
        final List<String> cookies=new ArrayList<>(); final List<StaffCookieCoordinator.Written> callbacks=new ArrayList<>();
        public void write(String cookie,StaffCookieCoordinator.Written callback) {cookies.add(cookie);callbacks.add(callback);}
        void done(int index,boolean success) {callbacks.get(index).complete(success);}
    }
    static final class Result implements StaffCookieCoordinator.Completion {
        int calls;String error;
        public void complete(String code) {calls++;error=code;}
        void expect(String code) {check(calls==1 && java.util.Objects.equals(code,error));}
    }
    static final class Fixture {
        final Clock clock=new Clock();final Scheduler scheduler=new Scheduler();final Writer writer=new Writer();int fences;
        final StaffCookieCoordinator coordinator=new StaffCookieCoordinator(clock,scheduler,writer,()->fences++);
        String expiry() {return StaffCookiePolicy.timestamp(clock.now+900000);}
    }
    static void check(boolean yes) {if(!yes)throw new AssertionError();}
    static void invalid(Runnable action) {try{action.run();throw new AssertionError();}catch(IllegalArgumentException expected){}}
    public static void main(String[] args) {
        check(StaffCookiePolicy.origin("https://staff.example.test",false).equals("https://staff.example.test"));
        check(StaffCookiePolicy.origin("https://localhost:8443",true).equals("https://localhost:8443"));
        for(String bad:new String[]{"http://staff.example.test","https://u:p@staff.example.test","https://staff.example.test/","https://staff.example.test?x=1","https://staff.example.test#x","https://staff.example.test:443"}) invalid(()->StaffCookiePolicy.origin(bad,true));
        invalid(()->StaffCookiePolicy.origin("https://localhost:8443",false));
        Fixture f=new Fixture();Result result=new Result();f.coordinator.install(1,TOKEN,f.expiry(),result);
        check(f.writer.cookies.size()==1 && !f.coordinator.canUse(1));f.writer.done(0,true);result.expect(null);check(f.coordinator.canUse(1));
        String cookie=f.writer.cookies.get(0);check(cookie.startsWith("__Host-nightshift_staff="+TOKEN+"; Path=/;")&&cookie.contains("Secure; HttpOnly; SameSite=Strict")&&!cookie.contains("Domain="));
        Result stale=new Result();f.coordinator.clear(0,stale);stale.expect("STAFF_STALE");check(f.coordinator.canUse(1));
        Fixture race=new Fixture();Result old=new Result(),clear=new Result();race.coordinator.install(1,TOKEN,race.expiry(),old);race.coordinator.clear(2,clear);old.expect("STAFF_STALE");check(race.writer.cookies.size()==1);
        race.writer.done(0,true);check(race.writer.cookies.size()==2&&race.writer.cookies.get(1).contains("Max-Age=0"));race.writer.done(1,true);clear.expect(null);check(!race.coordinator.canUse(1));
        Result newer=new Result();race.coordinator.install(3,TOKEN,race.expiry(),newer);race.writer.done(2,true);newer.expect(null);check(race.coordinator.canUse(3));race.writer.done(0,true);check(race.coordinator.canUse(3));
        Fixture timeout=new Fixture();Result hung=new Result();timeout.coordinator.install(1,TOKEN,timeout.expiry(),hung);timeout.scheduler.expire();hung.expect("STAFF_COOKIE_TIMEOUT");
        Result busy=new Result();timeout.coordinator.install(2,TOKEN,timeout.expiry(),busy);busy.expect("STAFF_COOKIE_BUSY");check(timeout.writer.cookies.size()==1);
        timeout.writer.done(0,true);check(timeout.writer.cookies.size()==2&&timeout.writer.cookies.get(1).contains("Max-Age=0"));timeout.writer.done(1,true);check(!timeout.coordinator.canUse(2));
        Fixture coalesced=new Fixture();Result first=new Result(),second=new Result(),third=new Result();coalesced.coordinator.install(1,TOKEN,coalesced.expiry(),first);coalesced.coordinator.clear(2,second);coalesced.coordinator.clear(3,third);second.expect("STAFF_STALE");coalesced.writer.done(0,true);check(coalesced.writer.cookies.size()==2);coalesced.writer.done(1,true);third.expect(null);
        Fixture expired=new Fixture();Result late=new Result();expired.coordinator.install(1,TOKEN,expired.expiry(),late);expired.clock.now+=900001;expired.writer.done(0,true);late.expect("STAFF_INVALID_SESSION");check(expired.writer.cookies.size()==2&&!expired.coordinator.canUse(1));
        Fixture bad=new Fixture();for(String value:new String[]{"",TOKEN+"; Domain=evil.test","A".repeat(64)}) {Result r=new Result();bad.coordinator.install(1,value,bad.expiry(),r);r.expect("STAFF_INVALID_SESSION");}check(bad.writer.cookies.isEmpty());
        for(String expiry:new String[]{StaffCookiePolicy.timestamp(bad.clock.now),StaffCookiePolicy.timestamp(bad.clock.now+1800001),"2026-02-30T00:00:00.000Z","2026-11-21T00:00:00Z"}) {Result r=new Result();bad.coordinator.install(1,TOKEN,expiry,r);r.expect("STAFF_INVALID_SESSION");}check(bad.writer.cookies.isEmpty());
        Fixture failed=new Fixture();Result fail=new Result();failed.coordinator.install(1,TOKEN,failed.expiry(),fail);failed.writer.done(0,false);fail.expect("STAFF_COOKIE_FAILED");failed.writer.done(1,false);Result blocked=new Result();failed.coordinator.install(2,TOKEN,failed.expiry(),blocked);blocked.expect("STAFF_COOKIE_BUSY");Result retry=new Result();failed.coordinator.clear(3,retry);failed.writer.done(2,true);retry.expect(null);
        Result recovered=new Result();failed.coordinator.install(4,TOKEN,failed.expiry(),recovered);failed.writer.done(3,true);recovered.expect(null);check(failed.coordinator.canUse(4));
        Fixture cleanupTimeout=new Fixture();Result oldInstall=new Result(),lateClear=new Result();cleanupTimeout.coordinator.install(1,TOKEN,cleanupTimeout.expiry(),oldInstall);cleanupTimeout.coordinator.clear(2,lateClear);check(cleanupTimeout.fences==2);cleanupTimeout.scheduler.expire();lateClear.expect("STAFF_COOKIE_TIMEOUT");check(cleanupTimeout.writer.cookies.size()==1);cleanupTimeout.writer.done(0,true);cleanupTimeout.writer.done(1,true);lateClear.expect("STAFF_COOKIE_TIMEOUT");check(!cleanupTimeout.coordinator.canUse(2));
        Fixture same=new Fixture();Result sameInstall=new Result(),sameClear=new Result();same.coordinator.install(1,TOKEN,same.expiry(),sameInstall);same.writer.done(0,true);same.coordinator.clear(1,sameClear);check(!same.coordinator.canUse(1));same.writer.done(1,true);sameClear.expect(null);Result oldGeneration=new Result();same.coordinator.install(1,TOKEN,same.expiry(),oldGeneration);oldGeneration.expect("STAFF_STALE");
        Fixture lifetime=new Fixture();Result maximum=new Result();lifetime.coordinator.install(1,TOKEN,StaffCookiePolicy.timestamp(lifetime.clock.now+1800000),maximum);lifetime.writer.done(0,true);check(lifetime.writer.cookies.get(0).contains("Max-Age=1800"));lifetime.clock.now+=1800000;check(!lifetime.coordinator.canUse(1));
        System.out.println("Staff cookie coordinator: 14 policy, expiry and serialized-race checks passed");
    }
}
