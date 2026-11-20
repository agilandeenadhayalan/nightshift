import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models.dart';
import 'staff_session.dart';

enum StaffOperation { challenge, exchange, accessRequest, currentRequest }

class StaffResponse {
  const StaffResponse(this.body, [this.cookies = const []]);
  final Json body;
  final List<String> cookies;
  @override
  String toString() => 'StaffResponse[redacted]';
}

abstract interface class StaffTransport {
  Future<StaffResponse> request(StaffOperation operation,
      {required String proof,
      required bool Function() isCurrent,
      String? challenge,
      String? csrf});
  void cancel();
}

class NativeStaffTransport implements StaffTransport {
  NativeStaffTransport(this.cookies,
      {this.timeout = const Duration(seconds: 20),
      @visibleForTesting this.clientFactory});
  final StaffCookies cookies;
  final Duration timeout;
  final HttpClient Function(SecurityContext)? clientFactory;
  HttpClient? _client;
  int _revision = 0;
  static const _paths = {
    StaffOperation.challenge: 'challenge',
    StaffOperation.exchange: 'exchange',
    StaffOperation.accessRequest: 'access-request',
    StaffOperation.currentRequest: 'access-request-current',
  };

  @override
  Future<StaffResponse> request(StaffOperation operation,
      {required String proof,
      required bool Function() isCurrent,
      String? challenge,
      String? csrf}) async {
    if (_client != null ||
        proof.isEmpty ||
        proof.length > 16384 ||
        proof.trim() != proof) {
      throw staffUnavailable;
    }
    final revision = ++_revision;
    final config = await cookies.configuration();
    bool current() => revision == _revision && isCurrent();
    if (!current()) throw staffChanged;
    final context = SecurityContext(withTrustedRoots: true);
    // This client only ever connects to the compiled origin. The public local
    // CA is absent from profile/release; TLS verification is never bypassed.
    if (config.debugTrust != null) {
      if (!kDebugMode) throw staffUnavailable;
      context.setTrustedCertificatesBytes(config.debugTrust!);
    }
    final client =
        (clientFactory ?? (context) => HttpClient(context: context))(context);
    _client = client;
    client.connectionTimeout = timeout;
    final timer = Timer(timeout, () => client.close(force: true));
    try {
      return await (() async {
        final method =
            operation == StaffOperation.currentRequest ? 'GET' : 'POST';
        final request = await client.openUrl(method,
            config.origin.resolve('/api/staff/native/${_paths[operation]}'));
        if (!current()) throw staffChanged;
        request.followRedirects = false;
        request.maxRedirects = 0;
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $proof');
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set('Origin', config.origin.origin);
        if (operation == StaffOperation.exchange) {
          if (challenge == null ||
              csrf == null ||
              !staffHex.hasMatch(challenge) ||
              !staffHex.hasMatch(csrf)) {
            throw staffUnavailable;
          }
          request.headers.set(HttpHeaders.cookieHeader,
              '__Host-nightshift_staff_challenge=$challenge');
          request.headers.set('X-CSRF-Token', csrf);
        }
        if (method == 'POST') {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(operation == StaffOperation.exchange
              ? {'proof': proof}
              : <String, Object>{}));
        }
        final response = await request.close();
        if (!current()) throw staffChanged;
        if (response.statusCode >= 300 && response.statusCode < 400) {
          throw staffUnavailable;
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          if (!current()) throw staffChanged;
          if (bytes.length + chunk.length > 65536) throw staffUnavailable;
          bytes.addAll(chunk);
        }
        if (!current()) throw staffChanged;
        final body = jsonDecode(utf8.decode(bytes));
        if (body is! Json) throw staffUnavailable;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final error = body['error'];
          final code = error is Json ? error['code'] : null;
          throw ApiFailure(
              code is String && RegExp(r'^[A-Z_]{1,64}$').hasMatch(code)
                  ? code
                  : 'STAFF_UNAVAILABLE',
              'Staff access could not be completed.',
              status: response.statusCode);
        }
        return StaffResponse(
            body, response.headers[HttpHeaders.setCookieHeader] ?? const []);
      })()
          .timeout(timeout);
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure(
          'STAFF_CONNECTION_FAILED', 'Staff access could not be reached.');
    } finally {
      timer.cancel();
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }

  @override
  void cancel() {
    _revision++;
    _client?.close(force: true);
    _client = null;
  }
}

/// Extract a capability only after validating every cookie. Unknown attributes,
/// duplicate names and broader scopes are never accepted or forwarded.
String staffCookie(List<String> cookies, String wanted, int maxAge) {
  if (cookies.isEmpty || cookies.length > 2) throw staffUnavailable;
  String? selected;
  final names = <String>{};
  for (final cookie in cookies) {
    final parts = cookie.split(';').map((p) => p.trim()).toList();
    final pair = parts.removeAt(0).split('=');
    if (pair.length != 2 ||
        !['__Host-nightshift_staff', '__Host-nightshift_staff_challenge']
            .contains(pair[0]) ||
        !names.add(pair[0])) {
      throw staffUnavailable;
    }
    final attrs = parts.map((p) => p.toLowerCase()).toList();
    if (attrs.toSet().length != attrs.length ||
        !['secure', 'httponly', 'samesite=strict', 'path=/']
            .every(attrs.contains) ||
        attrs.any((p) =>
            !['secure', 'httponly', 'samesite=strict', 'path=/'].contains(p) &&
            !RegExp(r'^max-age=\d+$').hasMatch(p))) {
      throw staffUnavailable;
    }
    final ages = attrs.where((p) => p.startsWith('max-age=')).toList();
    if (ages.length != 1) throw staffUnavailable;
    final age = int.parse(ages.single.substring(8));
    if (pair[0] == wanted) {
      if (!staffHex.hasMatch(pair[1]) || age < 1 || age > maxAge) {
        throw staffUnavailable;
      }
      selected = pair[1];
    } else if (!(pair[1].isEmpty && age == 0)) {
      throw staffUnavailable;
    }
  }
  return selected ?? (throw staffUnavailable);
}
