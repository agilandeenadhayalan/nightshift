import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;
import 'package:nightshift_api/api.dart' as generated;
import 'models.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.code, this.message,
      {this.status = 0, this.requestId, this.retryAfterSeconds});
  final String code, message;
  final int status;
  final String? requestId;
  final int? retryAfterSeconds;
  @override
  String toString() => 'ApiFailure[redacted]';
}

String newId() {
  final random = Random.secure();
  return List.generate(
      24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class NightShiftApi {
  NightShiftApi(
      {http.Client? client,
      this.requestTimeout = const Duration(seconds: 8),
      this.identityRequestTimeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client();
  final http.Client _client;
  final Duration requestTimeout;
  final Duration identityRequestTimeout;
  String baseUrl = const String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000');
  String? token;
  Future<void> Function()? prepareSession;
  Object? Function()? sessionIdentity;

  Future<Json> request(String method, String path,
      {Json? body, String? idempotencyKey}) async {
    // Refresh credentials before dispatch; mutations are never replayed after
    // an uncertain response. The exchange itself cannot recursively refresh.
    if (token != null && !path.startsWith('/auth/')) {
      final identity = sessionIdentity?.call(), origin = baseUrl;
      await prepareSession?.call();
      if (identity != sessionIdentity?.call() ||
          origin != baseUrl ||
          token == null) {
        throw const ApiFailure('PRIVATE_SESSION_CHANGED', 'Sign in again.');
      }
    }
    return _request(method, path, body: body, idempotencyKey: idempotencyKey);
  }

  /// Private materials cannot cross an account or origin change while waiting
  /// for credential renewal. Callers also discard responses from old owners.
  Future<Json> privateRequest(String method, String path,
      {required String origin,
      required bool Function() isCurrent,
      Json? body,
      String? idempotencyKey,
      Uint8List? sample,
      String? uploadToken}) async {
    final uri = Uri.tryParse(origin);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        !(uri.scheme == 'https' ||
            (!kReleaseMode &&
                uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '::1', '10.0.2.2']
                    .contains(uri.host)))) {
      throw const ApiFailure(
          'PRIVATE_ORIGIN_REQUIRED', 'Private service is unavailable.');
    }
    if (!isCurrent() || baseUrl != origin || token == null) {
      throw const ApiFailure('PRIVATE_SESSION_CHANGED', 'Sign in again.');
    }
    final identity = sessionIdentity?.call();
    await prepareSession?.call();
    if (!isCurrent() ||
        baseUrl != origin ||
        token == null ||
        identity != sessionIdentity?.call()) {
      throw const ApiFailure('PRIVATE_SESSION_CHANGED', 'Sign in again.');
    }
    return _request(method, path,
        body: body,
        idempotencyKey: idempotencyKey,
        sample: sample,
        uploadToken: uploadToken);
  }

  Future<Json> _request(String method, String path,
      {Json? body,
      String? idempotencyKey,
      Uint8List? sample,
      String? uploadToken}) async {
    final abort = Completer<void>();
    final transport = _SafeApiClient(
        _client, baseUrl.replaceFirst(RegExp(r'/+$'), ''), token, abort.future);
    final api = generated.DefaultApi(transport);
    try {
      // Generated operations own paths, request models and response decoding.
      // Phone verification includes chained provider verification/token signing.
      // Both budgets include the complete response body and send an abort signal.
      final uri = Uri.parse(path);
      final deadline = sample != null ||
              (method == 'POST' &&
                  [
                    '/auth/otp/verify',
                    '/auth/firebase/verify',
                    '/auth/exchange'
                  ].contains(uri.path))
          ? identityRequestTimeout
          : requestTimeout;
      final operation = sample == null
          ? _dispatch(api, method, uri, body, idempotencyKey)
          : api.uploadListenerSample(
              Uri.encodeComponent(uri.pathSegments[1]),
              Uri.encodeComponent(uri.pathSegments[3]),
              uploadToken!,
              http.MultipartFile('body', Stream.value(sample), sample.length));
      final response = await operation.timeout(deadline, onTimeout: () {
        abort.complete();
        throw const ApiFailure(
            'OFFLINE', 'The server did not respond. Check your connection.');
      });
      if (response == null) throw const FormatException('Empty response');
      return jsonDecode(jsonEncode(response)) as Json;
    } on ApiFailure {
      rethrow;
    } on generated.ApiException catch (error) {
      if (error.innerException is http.ClientException ||
          error.innerException is SocketException ||
          error.innerException is HandshakeException) {
        throw const ApiFailure('OFFLINE',
            'Cannot reach the server. Check your connection and server address.');
      }
      throw const ApiFailure(
          'INVALID_RESPONSE', 'The server returned an unreadable response.');
    } on http.ClientException {
      throw const ApiFailure('OFFLINE',
          'Cannot reach the server. Check your connection and server address.');
    } on FormatException {
      throw const ApiFailure(
          'INVALID_RESPONSE', 'The server returned an unreadable response.');
    } on TypeError {
      throw const ApiFailure(
          'INVALID_RESPONSE', 'The server returned an unreadable response.');
    } on ArgumentError {
      throw const ApiFailure(
          'INVALID_RESPONSE', 'The server returned an unreadable response.');
    }
  }

  Future<Object?> _dispatch(generated.DefaultApi api, String method, Uri uri,
      Json? body, String? idempotencyKey) {
    String key() =>
        idempotencyKey ??
        (throw const ApiFailure(
            'INVALID_REQUEST', 'A request key is required.'));
    final data = body ?? <String, dynamic>{};
    switch ('$method ${uri.path}') {
      case 'GET /health':
        return api.health();
      case 'GET /rtc/config':
        return api.getRtcConfig();
      case 'POST /auth/dev':
        return api.developmentSignIn(
            generated.DevelopmentSignInRequest.fromJson(data)!);
      case 'POST /auth/otp/request':
        return api.requestOtpChallenge(
            key(), generated.OtpRequest.fromJson(data)!);
      case 'POST /auth/firebase/admissions':
        return api.requestFirebasePhoneAdmission(
            key(), generated.OtpRequest.fromJson(data)!);
      case 'POST /auth/otp/verify':
        return api
            .verifyOtpChallenge(generated.OtpVerifyRequest.fromJson(data)!);
      case 'POST /auth/firebase/verify':
        return api.verifyPhoneIdentity(
            generated.FirebaseVerifyRequest.fromJson(data)!);
      case 'POST /auth/exchange':
        return api.exchangePhoneSession(
            generated.PhoneSessionRequest.fromJson(data)!);
      case 'GET /me/onboarding':
        return api.getOnboarding();
      case 'PUT /me/onboarding':
        return api.completeOnboarding(
            generated.CompleteOnboardingRequest.fromJson(data)!);
      case 'GET /me/consents':
        return api.getConsentHistory();
      case 'GET /me/listener-application':
        return api.getListenerApplication();
      case 'GET /me/listener-application/review':
        return api.getListenerApplicationReview();
      case 'POST /listener-applications':
        return api.createListenerApplication(
            key(), generated.ListenerApplicationInput.fromJson(data)!);
      case 'GET /me/deletion-notice':
        return api.getDeletionNotice();
      case 'POST /me/deletion-requests':
        return api
            .requestAccountDeletion(generated.DeletionRequest.fromJson(data)!);
      case 'POST /account-deletion/status':
        return api.getDeletionReceipt(
            generated.DeletionReceiptRequest.fromJson(data)!);
      case 'POST /auth/logout':
        return api.signOut();
      case 'GET /me':
        return api.getMe();
      case 'GET /snapshot':
        return api.getSnapshot(language: uri.queryParameters['language']);
      case 'PUT /me/mode':
        return api.setMode(generated.SetModeRequest.fromJson(data)!);
      case 'PUT /me/availability':
        return api
            .setAvailability(generated.SetAvailabilityRequest.fromJson(data)!);
      case 'PUT /me/languages':
        return api.setLanguages(generated.SetLanguagesRequest.fromJson(data)!);
      case 'POST /presence/heartbeat':
        return api.heartbeat();
      case 'GET /listeners':
        return api.listListeners(
            language: uri.queryParameters['language'],
            availableOnly: uri.queryParameters['availableOnly'] == 'true',
            cursor: uri.queryParameters['cursor']);
      case 'GET /favorites':
        return api.listFavorites(
            language: uri.queryParameters['language'],
            availableOnly: uri.queryParameters['availableOnly'] == 'true',
            cursor: uri.queryParameters['cursor']);
      case 'POST /listeners/status':
        return api.getListenerStatuses(
            generated.ListenerStatusRequest.fromJson(data)!);
      case 'GET /calls':
        return api.listCalls(cursor: uri.queryParameters['cursor']);
      case 'POST /calls':
        return api.createCall(
            key(), generated.CreateCallRequest.fromJson(data)!);
      case 'GET /rates':
        return api.getRates();
      case 'GET /wallet':
        return api.getWallet();
      case 'GET /me/earnings':
        return api.getTestEarnings();
      case 'POST /reports':
        return api.createReport(
            key(), generated.CreateReportRequest.fromJson(data)!);
      case 'GET /events':
        return api.getEvents(cursor: uri.queryParameters['cursor']);
    }
    final parts = uri.pathSegments;
    if (parts.length >= 2 && parts[0] == 'listener-applications') {
      final id = Uri.encodeComponent(parts[1]);
      if (parts.length == 2 && method == 'PUT') {
        return api.updateListenerApplication(
            id, generated.ListenerApplicationInput.fromJson(data)!);
      }
      if (parts.length == 3 && method == 'POST') {
        switch (parts[2]) {
          case 'uploads':
            return api.createReviewUpload(
                id, key(), generated.ReviewUploadRequest.fromJson(data)!);
          case 'submit':
            return api.submitListenerApplication(id, key());
          case 'withdraw':
            return api.withdrawListenerApplication(id, key());
        }
      }
    }
    if (parts.length >= 2 && parts[0] == 'calls') {
      final id = Uri.encodeComponent(parts[1]);
      if (parts.length == 2 && method == 'GET') return api.getCall(id);
      if (parts.length == 3 && method == 'POST') {
        switch (parts[2]) {
          case 'rtc-token':
            return api.getRtcToken(id);
          case 'media':
            return api.reportMediaReady(
                id, generated.ReportMediaReadyRequest.fromJson(data)!);
          case 'accept':
            return api.acceptCall(
                id, key(), generated.AcceptCallRequest.fromJson(data)!);
          case 'decline':
            return api.declineCall(
                id, key(), generated.DeclineCallRequest.fromJson(data)!);
          case 'cancel':
            return api.cancelCall(
                id, key(), generated.CancelCallRequest.fromJson(data)!);
          case 'end':
            return api.endCall(
                id, key(), generated.CancelCallRequest.fromJson(data)!);
        }
      }
    }
    if (parts.length == 2) {
      final id = Uri.encodeComponent(parts[1]);
      if (parts[0] == 'blocks' && method == 'PUT') return api.blockUser(id);
      if (parts[0] == 'favorites' && method == 'PUT') {
        return api.favoriteListener(id);
      }
      if (parts[0] == 'favorites' && method == 'DELETE') {
        return api.unfavoriteListener(id);
      }
    }
    throw const ApiFailure('INVALID_REQUEST', 'Unsupported API operation.');
  }

  void close() => _client.close();
}

class _SafeApiClient extends generated.ApiClient {
  _SafeApiClient(
      http.Client transport, String basePath, String? token, this.abort)
      : super(basePath: basePath) {
    client = _NoRedirectClient(transport);
    addDefaultHeader('Accept', 'application/json');
    if (token != null) addDefaultHeader('Authorization', 'Bearer $token');
  }
  final Future<void> abort;

  @override
  Future<http.Response> invokeAPI(
      String path,
      String method,
      List<generated.QueryParam> queryParams,
      Object? body,
      Map<String, String> headerParams,
      Map<String, String> formParams,
      String? contentType,
      {Future<void>? abortTrigger}) async {
    final response = await super.invokeAPI(
        path, method, queryParams, body, headerParams, formParams, contentType,
        abortTrigger: abort);
    if (response.statusCode >= 400) {
      Json json = {};
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Json) json = decoded;
      } on FormatException {
        /* A non-JSON error must not echo response content. */
      }
      final error =
          json['error'] is Json ? json['error'] as Json : <String, dynamic>{};
      final retry = error['retryAfterSeconds'];
      // Only bounded, positive integer hints can drive a future retry timer.
      // Malformed optional metadata must not hide the underlying safe failure.
      final retryAfterSeconds =
          retry is int && retry > 0 && retry <= 86400 ? retry : null;
      throw ApiFailure(error['code'] as String? ?? 'REQUEST_FAILED',
          error['message'] as String? ?? 'The request could not be completed.',
          status: response.statusCode,
          requestId: json['requestId'] as String?,
          retryAfterSeconds: retryAfterSeconds);
    }
    return response;
  }
}

class _NoRedirectClient extends http.BaseClient {
  _NoRedirectClient(this.transport);
  final http.Client transport;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Never forward OTPs or bearer credentials to a redirect destination.
    request.followRedirects = false;
    return transport.send(request);
  }
}
