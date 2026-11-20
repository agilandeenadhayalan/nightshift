import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';

class FirebaseTokens {
  const FirebaseTokens(this.idToken, this.refreshToken, this.expiresAt);
  final String idToken, refreshToken;
  final DateTime expiresAt;
  @override
  String toString() => 'FirebaseTokens[redacted]';
}

abstract interface class FirebaseIdentityClient {
  bool get configured;
  Future<FirebaseTokens> exchange(String customToken);
  Future<FirebaseTokens> refresh(String refreshToken);
  void close();
}

/// Official Firebase Auth REST exchange. Only Google's fixed HTTPS endpoints
/// receive provider credentials; the app backend verifies the resulting JWT.
/// https://firebase.google.com/docs/reference/rest/auth
class RestFirebaseIdentityClient implements FirebaseIdentityClient {
  RestFirebaseIdentityClient(
      {http.Client? client,
      this.apiKey = const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
      this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();
  final http.Client _client;
  final String apiKey;
  final Duration timeout;
  @override
  bool get configured => apiKey.isNotEmpty;
  @override
  Future<FirebaseTokens> exchange(String customToken) =>
      _request(false, customToken);
  @override
  Future<FirebaseTokens> refresh(String refreshToken) =>
      _request(true, refreshToken);

  Future<FirebaseTokens> _request(bool refresh, String credential) async {
    if (!configured) {
      throw const ApiFailure(
          'PHONE_AUTH_UNAVAILABLE', 'Phone sign-in is unavailable.');
    }
    final abort = Completer<void>();
    final request = http.AbortableRequest(
        'POST',
        Uri.https(
            refresh
                ? 'securetoken.googleapis.com'
                : 'identitytoolkit.googleapis.com',
            refresh ? '/v1/token' : '/v1/accounts:signInWithCustomToken',
            {'key': apiKey}),
        abortTrigger: abort.future)
      ..followRedirects = false;
    if (refresh) {
      request.bodyFields = {
        'grant_type': 'refresh_token',
        'refresh_token': credential
      };
    } else {
      request.headers['Content-Type'] = 'application/json';
      request.body =
          jsonEncode({'token': credential, 'returnSecureToken': true});
    }
    try {
      return await (() async {
        final response = await _client.send(request);
        if ((response.contentLength ?? 0) > 65536) {
          throw const FormatException('Oversized identity response');
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          if (bytes.length > 65536) {
            if (!abort.isCompleted) abort.complete();
            throw const FormatException('Oversized identity response');
          }
        }
        final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        if (response.statusCode != 200) {
          final providerCode =
              data['error'] is Map ? data['error']['message'] : null;
          final safeCode = switch (providerCode) {
            'TOKEN_EXPIRED' ||
            'INVALID_REFRESH_TOKEN' ||
            'USER_NOT_FOUND' =>
              'ID_TOKEN_EXPIRED',
            'USER_DISABLED' => 'IDENTITY_DISABLED',
            'INVALID_CUSTOM_TOKEN' ||
            'CREDENTIAL_MISMATCH' =>
              'INVALID_ID_TOKEN',
            _ => 'IDENTITY_UNAVAILABLE',
          };
          throw ApiFailure(safeCode, 'Phone identity could not be verified.',
              status: [
                'ID_TOKEN_EXPIRED',
                'IDENTITY_DISABLED',
                'INVALID_ID_TOKEN'
              ].contains(safeCode)
                  ? 401
                  : 503);
        }
        final token = data[refresh ? 'id_token' : 'idToken'];
        final refreshToken = data[refresh ? 'refresh_token' : 'refreshToken'];
        final seconds =
            int.tryParse('${data[refresh ? 'expires_in' : 'expiresIn']}');
        if (token is! String ||
            token.isEmpty ||
            token.length > 16384 ||
            refreshToken is! String ||
            refreshToken.isEmpty ||
            refreshToken.length > 16384 ||
            seconds == null ||
            seconds <= 0 ||
            seconds > 3600) {
          throw const FormatException('Invalid identity response');
        }
        return FirebaseTokens(token, refreshToken,
            DateTime.now().toUtc().add(Duration(seconds: seconds)));
      })()
          .timeout(timeout, onTimeout: () {
        if (!abort.isCompleted) abort.complete();
        throw const ApiFailure('OFFLINE', 'Identity service did not respond.');
      });
    } on ApiFailure {
      rethrow;
    } on http.ClientException {
      throw const ApiFailure('OFFLINE', 'Identity service is unavailable.');
    } catch (_) {
      throw const ApiFailure('IDENTITY_UNAVAILABLE',
          'Identity service could not complete sign-in.');
    }
  }

  @override
  void close() => _client.close();
}
