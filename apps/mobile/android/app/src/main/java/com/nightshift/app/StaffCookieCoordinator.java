package com.nightshift.app;

/** Main-thread-confined coordinator. CookieManager writes cannot be cancelled:
 * a timeout never releases the active slot. Only one cleanup may wait behind it. */
public final class StaffCookieCoordinator {
    public interface Clock {long now();}
    public interface Cancellation {void cancel();}
    public interface Scheduler {Cancellation after(long milliseconds,Runnable action);}
    public interface Written {void complete(boolean success);}
    public interface Writer {void write(String cookie,Written completion);}
    public interface Completion {void complete(String errorCode);}
    private static final long TIMEOUT_MS=8000;
    private final Clock clock;private final Scheduler scheduler;private final Writer writer;private final Runnable fence;
    private long generation=0,installedGeneration=-1,installedExpiry=0;
    private Command active,pendingClear;private boolean cleanupFailed;
    private static final class Command {
        final long generation,expiry;final boolean clear;String cookie;Completion completion;Cancellation timeout;
        Command(long generation,boolean clear,String cookie,long expiry,Completion completion) {
            this.generation=generation;this.clear=clear;this.cookie=cookie;this.expiry=expiry;this.completion=completion;
        }
    }
    public StaffCookieCoordinator(Clock clock,Scheduler scheduler,Writer writer,Runnable fence) {
        this.clock=clock;this.scheduler=scheduler;this.writer=writer;this.fence=fence;
    }
    public long generation() {return generation;}
    public boolean canUse(long value) {return value==generation&&value==installedGeneration&&clock.now()<installedExpiry&&active==null&&pendingClear==null&&!cleanupFailed;}
    private boolean validGeneration(long value) {return value>=0&&value<=StaffCookiePolicy.MAX_GENERATION;}
    private void finish(Command command,String error) {
        Completion completion=command.completion;command.completion=null;
        if(command.timeout!=null){command.timeout.cancel();command.timeout=null;}
        if(completion!=null)completion.complete(error);
    }
    private void invalidate(long next) {
        generation=next;installedGeneration=-1;installedExpiry=0;fence.run();
        if(active!=null)finish(active,"STAFF_STALE");
    }
    public void install(long next,String token,String expiresAt,Completion completion) {
        final long expiry;final String cookie;
        try {expiry=StaffCookiePolicy.expiry(expiresAt,clock.now());cookie=StaffCookiePolicy.install(token,expiry,clock.now());}
        catch(IllegalArgumentException error){completion.complete("STAFF_INVALID_SESSION");return;}
        if(!validGeneration(next)||next<=generation){completion.complete("STAFF_STALE");return;}
        invalidate(next);
        if(active!=null||pendingClear!=null||cleanupFailed) {
            if(active!=null)queueClear(next,null);
            completion.complete("STAFF_COOKIE_BUSY");return;
        }
        start(new Command(next,false,cookie,expiry,completion));
    }
    public void clear(long next,Completion completion) {
        if(!validGeneration(next)||next<generation){if(completion!=null)completion.complete("STAFF_STALE");return;}
        invalidate(next);
        if(active!=null)queueClear(next,completion);
        else start(new Command(next,true,StaffCookiePolicy.clear(),0,completion));
    }
    private void queueClear(long next,Completion completion) {
        if(pendingClear!=null)finish(pendingClear,"STAFF_STALE");
        pendingClear=new Command(next,true,StaffCookiePolicy.clear(),0,completion);
        final Command queued=pendingClear;
        queued.timeout=scheduler.after(TIMEOUT_MS,()->{if(pendingClear==queued)finish(queued,"STAFF_COOKIE_TIMEOUT");});
    }
    private void start(Command command) {
        active=command;
        if(command.timeout!=null)command.timeout.cancel();
        command.timeout=scheduler.after(TIMEOUT_MS,()->{
            if(active!=command)return;
            finish(command,"STAFF_COOKIE_TIMEOUT");
            installedGeneration=-1;installedExpiry=0;fence.run();
            if(!command.clear&&pendingClear==null)queueClear(generation,null);
        });
        String cookie=command.cookie;command.cookie=null;
        try {writer.write(cookie,success->completed(command,success));}
        catch(Exception error){completed(command,false);}
    }
    private void completed(Command command,boolean success) {
        if(active!=command)return; // Reject duplicate/out-of-order platform callbacks.
        active=null;
        if(command.clear) {
            cleanupFailed=!success;finish(command,success?null:"STAFF_COOKIE_FAILED");
        } else if(success&&command.generation==generation&&command.completion!=null&&clock.now()<command.expiry&&pendingClear==null) {
            installedGeneration=command.generation;installedExpiry=command.expiry;cleanupFailed=false;finish(command,null);
        } else {
            finish(command,!success?"STAFF_COOKIE_FAILED":command.generation!=generation?"STAFF_STALE":"STAFF_INVALID_SESSION");
            if(pendingClear==null)queueClear(generation,null);
        }
        if(pendingClear!=null) {Command next=pendingClear;pendingClear=null;start(next);}
    }
}
