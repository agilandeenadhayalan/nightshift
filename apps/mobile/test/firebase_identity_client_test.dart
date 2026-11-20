import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/firebase_identity_client.dart';

void main() {
  test('custom token exchange uses the fixed Google endpoint and private body',
      () async {
    final client = RestFirebaseIdentityClient(
        apiKey: 'fixture-public-key',
        client: MockClient((r) async {
          expect(r.url.host, 'identitytoolkit.googleapis.com');
          expect(r.url.path, '/v1/accounts:signInWithCustomToken');
          expect(r.url.queryParameters, {'key': 'fixture-public-key'});
          expect(jsonDecode(r.body),
              {'token': 'private-custom', 'returnSecureToken': true});
          return http.Response(
              jsonEncode({
                'idToken': 'private-id',
                'refreshToken': 'private-refresh',
                'expiresIn': '3600'
              }),
              200);
        }));
    final result = await client.exchange('private-custom');
    expect(result.idToken, 'private-id');
    expect(result.refreshToken, 'private-refresh');
    expect(result.toString(), isNot(contains('private-')));
  });
  test('refresh uses form data and accepts rotated refresh tokens', () async {
    final client = RestFirebaseIdentityClient(
        apiKey: 'fixture-public-key',
        client: MockClient((r) async {
          expect(r.url.host, 'securetoken.googleapis.com');
          expect(r.bodyFields, {
            'grant_type': 'refresh_token',
            'refresh_token': 'private-refresh'
          });
          return http.Response(
              jsonEncode({
                'id_token': 'fresh-id',
                'refresh_token': 'rotated-refresh',
                'expires_in': '3600'
              }),
              200);
        }));
    final result = await client.refresh('private-refresh');
    expect(result.idToken, 'fresh-id');
    expect(result.refreshToken, 'rotated-refresh');
  });
  test('provider prose is redacted and disabled credentials cannot send',
      () async {
    var sent = 0;
    final transport = MockClient((_) async {
      sent++;
      return http.Response(
          '{"error":{"message":"USER_DISABLED private-data"}}', 400);
    });
    final disabled = RestFirebaseIdentityClient(client: transport, apiKey: '');
    await expectLater(
        disabled.exchange('secret'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'PHONE_AUTH_UNAVAILABLE')));
    expect(sent, 0);
    final client =
        RestFirebaseIdentityClient(client: transport, apiKey: 'fixture');
    await expectLater(
        client.exchange('secret'),
        throwsA(isA<ApiFailure>().having(
            (e) => e.toString(), 'redacted', isNot(contains('private-data')))));
  });
  test('malformed success and hung requests fail closed', () async {
    final malformed = RestFirebaseIdentityClient(
        apiKey: 'fixture',
        client:
            MockClient((_) async => http.Response('{"idToken":"token"}', 200)));
    await expectLater(
        malformed.exchange('secret'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'IDENTITY_UNAVAILABLE')));
    final pending = Completer<http.Response>();
    final slow = RestFirebaseIdentityClient(
        apiKey: 'fixture',
        timeout: const Duration(milliseconds: 1),
        client: MockClient((_) => pending.future));
    await expectLater(slow.exchange('secret'),
        throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'OFFLINE')));
    pending.complete(http.Response('{}', 200));
  });
}
