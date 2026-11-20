package com.nightshift.app;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InterruptedIOException;

/** Reads a selected provider stream into memory without ever copying it to disk. */
public final class BoundedReviewSampleReader {
    public static final int MAX_BYTES = 2 * 1024 * 1024;
    public static final class TooLargeException extends IOException {}
    @FunctionalInterface public interface Cancellation { boolean isCancelled(); }
    private BoundedReviewSampleReader() {}

    public static byte[] readAndClose(InputStream source, Cancellation cancelled) throws IOException {
        try (InputStream input = source; ByteArrayOutputStream output = new ByteArrayOutputStream(8192)) {
            byte[] buffer = new byte[8192];
            int total = 0;
            while (true) {
                if (cancelled.isCancelled() || Thread.currentThread().isInterrupted()) {
                    throw new InterruptedIOException("Selection cancelled");
                }
                // Read at most one byte past the bound, even for an endless provider.
                int count = input.read(buffer, 0, Math.min(buffer.length, MAX_BYTES + 1 - total));
                if (count < 0) return output.toByteArray();
                if (count == 0) {
                    int single = input.read();
                    if (single < 0) return output.toByteArray();
                    buffer[0] = (byte) single;
                    count = 1;
                }
                total += count;
                if (total > MAX_BYTES) throw new TooLargeException();
                output.write(buffer, 0, count);
            }
        }
    }
}
