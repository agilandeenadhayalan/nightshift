package com.nightshift.app;
import java.util.concurrent.atomic.AtomicBoolean;
/** Process-wide ownership: a caller timeout is not provider-task completion. */
public final class InvitationTokenGate {
  private final AtomicBoolean active=new AtomicBoolean(false);
  public boolean enter() { return active.compareAndSet(false,true); }
  public void settled() { active.set(false); }
}
