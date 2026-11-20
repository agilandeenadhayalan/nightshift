package com.nightshift.app;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InterruptedIOException;
import java.util.Arrays;
import java.util.concurrent.atomic.AtomicBoolean;

/** Standalone JVM checks; no Android device, real file, provider or audio required. */
public final class BoundedReviewSampleReaderTest {
    private static final class Source extends InputStream {
        int read, limit;
        boolean closed, broken;
        AtomicBoolean cancelAfterRead;
        Source(int limit) { this.limit = limit; }
        @Override public int read(byte[] bytes, int offset, int length) throws IOException {
            if (broken) throw new IOException("Synthetic provider failure");
            if (read == limit) return -1;
            int count = Math.min(length, limit - read);
            Arrays.fill(bytes, offset, offset + count, (byte) 7);
            read += count;
            if (cancelAfterRead != null) cancelAfterRead.set(true);
            return count;
        }
        @Override public int read() throws IOException {
            byte[] one = new byte[1];
            return read(one, 0, 1) < 0 ? -1 : one[0];
        }
        @Override public void close() { closed = true; }
    }
    private static void check(boolean result) { if (!result) throw new AssertionError(); }
    public static void main(String[] args) throws Exception {
        Source exact = new Source(BoundedReviewSampleReader.MAX_BYTES);
        byte[] accepted = BoundedReviewSampleReader.readAndClose(exact, () -> false);
        check(accepted.length == BoundedReviewSampleReader.MAX_BYTES && exact.closed);
        Source unbounded = new Source(Integer.MAX_VALUE);
        try { BoundedReviewSampleReader.readAndClose(unbounded, () -> false); throw new AssertionError(); }
        catch (BoundedReviewSampleReader.TooLargeException expected) {
            check(unbounded.read == BoundedReviewSampleReader.MAX_BYTES + 1 && unbounded.closed);
        }
        Source cancelled = new Source(100);
        try { BoundedReviewSampleReader.readAndClose(cancelled, () -> true); throw new AssertionError(); }
        catch (InterruptedIOException expected) { check(cancelled.read == 0 && cancelled.closed); }
        AtomicBoolean cancel = new AtomicBoolean();
        Source inFlight = new Source(100000); inFlight.cancelAfterRead = cancel;
        try { BoundedReviewSampleReader.readAndClose(inFlight, cancel::get); throw new AssertionError(); }
        catch (InterruptedIOException expected) { check(inFlight.read <= 8192 && inFlight.closed); }
        Source broken = new Source(100); broken.broken = true;
        try { BoundedReviewSampleReader.readAndClose(broken, () -> false); throw new AssertionError(); }
        catch (IOException expected) { check(broken.closed); }
        byte[] small = {1, 2, 3};
        check(Arrays.equals(small, BoundedReviewSampleReader.readAndClose(new ByteArrayInputStream(small), () -> false)));
        System.out.println("Bounded review sample reader: 6 checks passed");
    }
}
