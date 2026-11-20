import {randomBytes} from 'node:crypto';
import {NextRequest, NextResponse} from 'next/server';

// Dynamic documents receive a new nonce. Never trust an inbound nonce or CSP.
export function proxy(request: NextRequest) {
  const nonce = randomBytes(24).toString('base64');
  const development = process.env.NODE_ENV === 'development';
  const policy = [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${development ? " 'unsafe-eval'" : ''}`,
    `style-src 'self' 'nonce-${nonce}'`,
    "connect-src 'self'", "img-src 'self'", "font-src 'self'", "media-src 'self'",
    "object-src 'none'", "base-uri 'none'", "frame-ancestors 'none'", "frame-src 'none'",
    "form-action 'self'", "worker-src 'none'",
  ].join('; ');
  const headers = new Headers(request.headers);
  headers.set('x-nonce', nonce);
  headers.set('Content-Security-Policy', policy);
  const response = NextResponse.next({request: {headers}});
  response.headers.set('Content-Security-Policy', policy);
  response.headers.set('Cache-Control', 'no-store, private');
  return response;
}
export const config = {matcher: ['/((?!api/|_next/static/|_next/image|favicon.ico).*)']};
