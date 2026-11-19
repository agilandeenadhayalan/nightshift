import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';

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
      expect(request.body, '{"listenerId":"id"}');
      return http.Response('{"id":"call"}', 201);
    }))
      ..baseUrl = 'https://example.test/'
      ..token = 'session';
    expect(
        (await api.request('POST', '/calls',
            body: {'listenerId': 'id'}, idempotencyKey: 'same-attempt'))['id'],
        'call');
    api.close();
  });
  test('structured failures preserve safe diagnostic ID', () async {
    final api = NightShiftApi(
        client: MockClient((_) async => http.Response(
            '{"error":{"code":"LISTENER_BUSY","message":"Listener is busy"},"requestId":"req-1"}',
            409)));
    await expectLater(
        api.request('POST', '/calls'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'LISTENER_BUSY')
            .having((e) => e.requestId, 'requestId', 'req-1')));
    api.close();
  });
}
