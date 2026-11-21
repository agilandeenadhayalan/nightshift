package com.nightshift.app;

/** Two independent stores: old ciphertext must be unreadable before publication. */
public final class InvitationInvalidation {
  public interface Storage {
    void deleteKey() throws Exception;
    void deleteCiphertext() throws Exception;
  }
  public static void invalidate(Storage storage) throws Exception {
    try { storage.deleteKey(); }
    catch (Exception keyFailure) {
      // If the keystore is unavailable, a committed ciphertext deletion is the
      // alternate durable deny boundary. Never report success if both fail.
      storage.deleteCiphertext();
    }
  }
}
