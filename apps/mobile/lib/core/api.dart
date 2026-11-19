import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
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
    final uri =
        Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/v1$path');
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (idempotencyKey != null) {
      request.headers['Idempotency-Key'] = idempotencyKey;
    }
    if (body != null) request.body = jsonEncode(body);
    try {
      // The deadline includes connection establishment and response headers,
      // not just the body. Otherwise a silent server can keep audio alive.
      final response = await (() async =>
              http.Response.fromStream(await _client.send(request)))()
          .timeout(requestTimeout);
      final dynamic decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final json = decoded is Json ? decoded : <String, dynamic>{};
      if (response.statusCode >= 400) {
        final error =
            json['error'] is Json ? json['error'] as Json : <String, dynamic>{};
        throw ApiFailure(
            error['code'] as String? ?? 'REQUEST_FAILED',
            error['message'] as String? ??
                'The request could not be completed.',
            status: response.statusCode,
            requestId: json['requestId'] as String?);
      }
      return json;
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(
          'OFFLINE', 'The server did not respond. Check your connection.');
    } on http.ClientException {
      throw const ApiFailure('OFFLINE',
          'Cannot reach the server. Check your connection and server address.');
    } on FormatException {
      throw const ApiFailure(
          'INVALID_RESPONSE', 'The server returned an unreadable response.');
    }
  }

  void close() => _client.close();
}
