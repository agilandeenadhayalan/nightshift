import { ApiError } from '../errors';
import type { OtpProvider } from './otp';

const origin = 'https://api.msg91.com/api/v5/widget';
const responseByteLimit = 32 * 1024;
type Json = Record<string, unknown>;
type Transport = typeof fetch;

function success(value: Json): boolean {
  return value.type === 'success' && value.hasError !== true &&
    (value.status === undefined || value.status === 'success') &&
    (value.code === undefined || value.code === 200);
}

function unavailable(): ApiError {
  return new ApiError(503, 'OTP_PROVIDER_UNAVAILABLE', 'Phone verification is temporarily unavailable.');
}

function validatePhone(phone: string): void {
  if (typeof phone !== 'string' || !/^\+91[6-9]\d{9}$/.test(phone)) {
    throw new ApiError(400, 'OTP_INVALID_INPUT', 'Enter a valid Indian mobile number.');
  }
}

/**
 * Server-only MSG91 Widget adapter. It is instantiated only by explicitly enabled
 * phone-auth configuration; there is no fallback to a fake verification result.
 *
 * Protocol: https://docs.msg91.com/otp-widget/{send-otp-1,verify-otp,verify-access-token}
 * Official success examples carry reqId, access token, then verified identifier
 * in `message`. HTTP 200 alone is not verification. No provider prose is exposed.
 */
export class Msg91OtpProvider implements OtpProvider {
  readonly #authKey: string;
  readonly #widgetId: string;
  readonly #transport: Transport;
  readonly #timeoutMs: number;

  constructor(config: { authKey: string; widgetId: string; timeoutMs?: number }, transport: Transport = fetch) {
    if (typeof config.authKey !== 'string' || !/^[!-~]{16,512}$/.test(config.authKey) ||
        typeof config.widgetId !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(config.widgetId)) {
      throw new Error('MSG91_AUTH_KEY and MSG91_WIDGET_ID must be configured on the server');
    }
    const timeout = config.timeoutMs ?? 3000;
    if (!Number.isInteger(timeout) || timeout < 1 || timeout > 5000) {
      throw new Error('MSG91 request timeout must be between 1 and 5000 milliseconds');
    }
    this.#authKey = config.authKey;
    this.#widgetId = config.widgetId;
    this.#transport = transport;
    this.#timeoutMs = timeout;
  }

  async send(phone: string): Promise<{ reference: string }> {
    validatePhone(phone);
    const response = await this.#post('sendOtp', { widgetId: this.#widgetId, identifier: phone.slice(1) });
    if (!success(response) || typeof response.message !== 'string' ||
        !/^[A-Za-z0-9_-]{16,200}$/.test(response.message)) throw unavailable();
    // reqId is provider correlation metadata, not an OTP or a verification token.
    return { reference: response.message };
  }

  async verify(phone: string, code: string, reference: string): Promise<'valid' | 'wrong' | 'expired'> {
    validatePhone(phone);
    if (typeof code !== 'string' || !/^\d{6}$/.test(code) || typeof reference !== 'string' ||
        !/^[A-Za-z0-9_-]{16,200}$/.test(reference)) {
      throw new ApiError(400, 'OTP_INVALID_INPUT', 'Enter a valid verification code and challenge.');
    }
    const response = await this.#post('verifyOtp', { widgetId: this.#widgetId, reqId: reference, otp: code });
    // Only the documented invalid-code response can reopen a local attempt.
    // Expiration is enforced by the challenge service; unknown errors fail closed.
    if (response.type === 'error' && response.code === 705) return 'wrong';
    if (!success(response) || typeof response.message !== 'string' ||
        response.message.length > 16384 || !/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(response.message)) {
      throw unavailable();
    }
    // Never decode an unverified JWT and trust its phone claim. Consume its proof
    // through MSG91's server endpoint, then bind the returned identity exactly.
    const proof = await this.#post('verifyAccessToken', { 'access-token': response.message });
    if (!success(proof) || proof.message !== phone.slice(1)) throw unavailable();
    return 'valid';
  }

  async #post(operation: 'sendOtp' | 'verifyOtp' | 'verifyAccessToken', body: Json): Promise<Json> {
    const controller = new AbortController();
    let deadline: ReturnType<typeof setTimeout> | undefined;
    const expired = new Promise<never>((_, reject) => {
      deadline = setTimeout(() => { controller.abort(); reject(unavailable()); }, this.#timeoutMs);
    });
    try {
      return await Promise.race([expired, (async () => {
        const response = await this.#transport(`${origin}/${operation}`, {
          method: 'POST',
          headers: { 'content-type': 'application/json', authkey: this.#authKey },
          body: JSON.stringify(body),
          redirect: 'error',
          cache: 'no-store',
          signal: controller.signal,
        });
        controller.signal.throwIfAborted();
        // Refuse redirects so credentials cannot be forwarded to another host.
        if (!response.ok || response.redirected) {
          void response.body?.cancel().catch(() => {});
          throw unavailable();
        }
        const length = response.headers.get('content-length');
        if (length !== null && (!/^\d+$/.test(length) || Number(length) > responseByteLimit)) {
          void response.body?.cancel().catch(() => {});
          throw unavailable();
        }
        if (!response.body) throw unavailable();
        const reader = response.body.getReader();
        const cancelReader = () => { void reader.cancel().catch(() => {}); };
        controller.signal.addEventListener('abort', cancelReader, { once: true });
        const decoder = new TextDecoder('utf-8', { fatal: true });
        let bytes = 0, text = '';
        try {
          for (;;) {
            const next = await reader.read();
            if (next.done) break;
            bytes += next.value.byteLength;
            if (bytes > responseByteLimit) throw unavailable();
            text += decoder.decode(next.value, { stream: true });
          }
          text += decoder.decode();
        } finally {
          // A failing/oversized response must not continue streaming in the background.
          controller.signal.removeEventListener('abort', cancelReader);
          cancelReader();
          reader.releaseLock();
        }
        const value: unknown = JSON.parse(text);
        if (value === null || typeof value !== 'object' || Array.isArray(value)) throw unavailable();
        return value as Json;
      })()]);
    } catch {
      // Fetch exceptions can contain URLs and response bodies. Do not attach a
      // cause, provider message, OTP, raw phone, authkey or token to diagnostics.
      throw unavailable();
    } finally {
      if (deadline !== undefined) clearTimeout(deadline);
      controller.abort();
    }
  }
}
