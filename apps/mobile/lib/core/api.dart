import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:nightshift_api/api.dart' as generated;
import 'models.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.code, this.message, {this.status = 0, this.requestId});
  final String code, message;
  final int status;
  final String? requestId;
  @override
  String toString() => message;
}

String newId() {
  final random = Random.secure();
  return List.generate(
      24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class NightShiftApi {
  NightShiftApi(
      {http.Client? client, this.requestTimeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client();
  final http.Client _client;
  final Duration requestTimeout;
  String baseUrl = const String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000');
  String? token;

  Future<Json> request(String method, String path,
      {Json? body, String? idempotencyKey}) async {
    final abort = Completer<void>();
    final transport = _SafeApiClient(
        _client, baseUrl.replaceFirst(RegExp(r'/+$'), ''), token, abort.future);
    final api = generated.DefaultApi(transport);
    try {
      // Generated operations own paths, request models and response decoding.
      // The facade preserves existing presentation state and one total deadline.
      final response =
          await _dispatch(api, method, Uri.parse(path), body, idempotencyKey)
              .timeout(requestTimeout, onTimeout: () {
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
      case 'POST /auth/dev':
        return api.developmentSignIn(
            generated.DevelopmentSignInRequest.fromJson(data)!);
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
            cursor: uri.queryParameters['cursor']);
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
                id, key(), generated.DeclineCallRequest.fromJson(data)!);
          case 'end':
            return api.endCall(
                id, key(), generated.DeclineCallRequest.fromJson(data)!);
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
    client = transport;
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
      throw ApiFailure(error['code'] as String? ?? 'REQUEST_FAILED',
          error['message'] as String? ?? 'The request could not be completed.',
          status: response.statusCode, requestId: json['requestId'] as String?);
    }
    return response;
  }
}
