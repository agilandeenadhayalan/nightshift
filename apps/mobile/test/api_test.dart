import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';
import 'fakes.dart';

void main() {
  test('timeout includes a connection that never returns response headers',
      () async {
    final neverResponds = Completer<http.Response>();
    final api = NightShiftApi(
        client: MockClient((_) => neverResponds.future),
        requestTimeout: const Duration(milliseconds: 10));
    await expectLater(api.request('GET', '/snapshot'),
        throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'OFFLINE')));
    api.close();
  });
  test('mutations attach auth and stable caller-supplied idempotency key',
      () async {
    final api = NightShiftApi(client: MockClient((request) async {
      expect(request.url.toString(), 'https://example.test/v1/calls');
      expect(request.headers['Authorization'], 'Bearer session');
      expect(request.headers['Idempotency-Key'], 'same-attempt');
      expect(jsonDecode(request.body),
          {'listenerId': 'id', 'quoteId': 'test-audio-v1'});
      return http.Response(jsonEncode(callJson()), 201);
    }))
      ..baseUrl = 'https://example.test/'
      ..token = 'session';
    expect(
        (await api.request('POST', '/calls',
            body: {'listenerId': 'id', 'quoteId': 'test-audio-v1'},
            idempotencyKey: 'same-attempt'))['id'],
        'call-id');
    api.close();
  });
  test('structured failures preserve safe diagnostic ID', () async {
    final api = NightShiftApi(
        client: MockClient((_) async => http.Response(
            '{"error":{"code":"LISTENER_BUSY","message":"Listener is busy"},"requestId":"req-1"}',
            409)));
    await expectLater(
        api.request('GET', '/snapshot'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'LISTENER_BUSY')
            .having((e) => e.requestId, 'requestId', 'req-1')));
    api.close();
  });

  const callBodies = <(String, String, Map<String, dynamic>)>[
    (
      'video create consent true',
      '/calls',
      {
        'listenerId': 'listener-id',
        'quoteId': 'test-video-v1',
        'mediaType': 'video',
        'videoConsent': true,
      }
    ),
    (
      'video create consent false',
      '/calls',
      {
        'listenerId': 'listener-id',
        'quoteId': 'test-video-v1',
        'mediaType': 'video',
        'videoConsent': false,
      }
    ),
    (
      'audio accept omits video consent',
      '/calls/call-id/accept',
      {
        'expectedVersion': 1,
      }
    ),
    (
      'video accept consent true',
      '/calls/call-id/accept',
      {
        'expectedVersion': 1,
        'videoConsent': true,
      }
    ),
    (
      'video accept consent false',
      '/calls/call-id/accept',
      {
        'expectedVersion': 1,
        'videoConsent': false,
      }
    ),
    (
      'audio ready omits video readiness',
      '/calls/call-id/media',
      {
        'ready': true,
      }
    ),
    (
      'audio stopped omits video readiness',
      '/calls/call-id/media',
      {
        'ready': false,
      }
    ),
    (
      'both video media ready',
      '/calls/call-id/media',
      {
        'ready': true,
        'videoReady': true,
      }
    ),
    (
      'video camera stopped retains false',
      '/calls/call-id/media',
      {
        'ready': true,
        'videoReady': false,
      }
    ),
    (
      'both video media stopped retain false',
      '/calls/call-id/media',
      {
        'ready': false,
        'videoReady': false,
      }
    ),
  ];
  for (final (label, path, body) in callBodies) {
    test('generated call wire body: $label', () async {
      late http.Request sent;
      final api = NightShiftApi(client: MockClient((request) async {
        sent = request;
        final video = body['mediaType'] == 'video' ||
            body.containsKey('videoConsent') ||
            body.containsKey('videoReady');
        return http.Response(
            jsonEncode(callJson(state: 'connecting', video: video)), 200);
      }));
      addTearDown(api.close);
      await api.request('POST', path,
          body: body, idempotencyKey: 'wire-body-attempt');
      expect(sent.method, 'POST');
      expect(sent.url.path, '/v1$path');
      expect(jsonDecode(sent.body), body,
          reason:
              'Omitted fields must stay absent; explicit booleans must survive serialization.');
    });
  }

  test('structured failure preserves a bounded positive integer retry hint',
      () async {
    final api = NightShiftApi(
        client: MockClient((_) async => http.Response(
            '{"error":{"code":"OTP_COOLDOWN","message":"Wait","retryAfterSeconds":60},"requestId":"retry-reference"}',
            429)));
    addTearDown(api.close);
    await expectLater(
        api.request('GET', '/snapshot'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'OTP_COOLDOWN')
            .having((e) => e.status, 'status', 429)
            .having((e) => e.requestId, 'requestId', 'retry-reference')
            .having((e) => e.retryAfterSeconds, 'retry seconds', 60)));
  });

  test('malformed retry metadata does not replace the underlying failure',
      () async {
    for (final value in [null, 0, -1, 1.5, '60', true, 86401, 1e30]) {
      final api = NightShiftApi(
          client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'OTP_RATE_LIMITED',
                  'message': 'Wait',
                  'retryAfterSeconds': value,
                }
              }),
              429)));
      try {
        await expectLater(
            api.request('GET', '/snapshot'),
            throwsA(isA<ApiFailure>()
                .having((e) => e.code, 'code', 'OTP_RATE_LIMITED')
                .having((e) => e.status, 'status', 429)
                .having((e) => e.retryAfterSeconds, 'retry seconds', isNull)));
      } finally {
        api.close();
      }
    }
  });

  test('failure diagnostics do not expose server prose or request identifiers',
      () {
    const failure = ApiFailure(
        'UNTRUSTED_CODE', 'private-phone-code-token-message',
        requestId: 'private-reference', retryAfterSeconds: 30);
    expect(failure.toString(), 'ApiFailure[redacted]');
    expect(failure.message, 'private-phone-code-token-message');
  });

  test(
      'generated response contract rejects missing fields instead of zero defaults',
      () async {
    final api = NightShiftApi(
        client: MockClient((_) async => http.Response(
            '{"balanceMicrocredits":6000000,"heldMicrocredits":0,"testOnly":true}',
            200)));
    await expectLater(
        api.request('GET', '/wallet'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'INVALID_RESPONSE')));
    api.close();
  });

  test('cursor and runtime base URL are encoded by generated operations',
      () async {
    final api = NightShiftApi(client: MockClient((request) async {
      expect(request.url.path, '/gateway/v1/calls');
      expect(request.url.queryParameters['cursor'], 'cursor /+?');
      return http.Response('{"items":[],"nextCursor":null}', 200);
    }))
      ..baseUrl = 'https://example.test/gateway/';
    final page = await api.request(
        'GET', '/calls?cursor=${Uri.encodeQueryComponent('cursor /+?')}');
    expect(page['items'], isEmpty);
    expect(page.containsKey('nextCursor'), isTrue);
    api.close();
  });

  test(
      'non-JSON server errors preserve HTTP status without exposing response text',
      () async {
    final api = NightShiftApi(
        client: MockClient(
            (_) async => http.Response('private-upstream-content', 503)));
    await expectLater(
        api.request('GET', '/snapshot'),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 503).having(
            (e) => e.toString().contains('private-upstream-content'),
            'redacted',
            false)));
    api.close();
  });

  test('deadline includes a response body that never finishes', () async {
    final stream = StreamController<List<int>>();
    final api = NightShiftApi(
        client: _StreamingClient(stream.stream),
        requestTimeout: const Duration(milliseconds: 10));
    await expectLater(api.request('GET', '/snapshot'),
        throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'OFFLINE')));
    await stream.close();
    api.close();
  });
}

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.stream);
  final Stream<List<int>> stream;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(stream, 200);
}
