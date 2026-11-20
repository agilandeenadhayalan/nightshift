import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/staff_transport.dart';
import 'staff_fakes.dart';

class Headers implements HttpHeaders {
  final values = <String, List<String>>{};
  @override
  ContentType? contentType;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = [value.toString()];
  }

  @override
  List<String>? operator [](String name) => values[name.toLowerCase()];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Response extends Stream<List<int>> implements HttpClientResponse {
  Response(this.statusCode, {this.source}) : headers = Headers();
  final Stream<List<int>>? source;
  @override
  final int statusCode;
  @override
  final Headers headers;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      (source ?? Stream.value(utf8.encode('{"ok":true}'))).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Request implements HttpClientRequest {
  Request(this.response);
  final Response response;
  @override
  final headers = Headers();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  String body = '';
  bool sent = false;
  @override
  void write(Object? value) {
    body += '$value';
  }

  @override
  Future<HttpClientResponse> close() async {
    sent = true;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Client implements HttpClient {
  Client(this.request);
  final Request request;
  Uri? target;
  String? method;
  Future<void>? gate;
  bool forcedClosed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    this.method = method;
    target = url;
    await gate;
    return request;
  }

  @override
  void close({bool force = false}) {
    forcedClosed = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only origin mapping lets two local HTTP servers exercise the real IO
// redirect machinery while production still accepts only the fixed HTTPS URI.
class LoopbackClient implements HttpClient {
  LoopbackClient(this.port);
  final int port;
  final HttpClient actual = HttpClient();
  @override
  set connectionTimeout(Duration? value) {
    actual.connectionTimeout = value;
  }

  @override
  Duration? get connectionTimeout => actual.connectionTimeout;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => actual.openUrl(
      method,
      Uri(scheme: 'http', host: '127.0.0.1', port: port, path: url.path));
  @override
  void close({bool force = false}) => actual.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('real IO redirect target receives no synthetic authorization', () async {
    final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await source.close(force: true);
      await target.close(force: true);
    });
    var sourceRequests = 0, targetRequests = 0;
    source.listen((request) async {
      sourceRequests++;
      expect(request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer synthetic-proof');
      request.response.statusCode = 307;
      request.response.headers.set(
          HttpHeaders.locationHeader, 'http://127.0.0.1:${target.port}/leak');
      await request.response.close();
    });
    target.listen((request) async {
      targetRequests++;
      await request.response.close();
    });
    final api = NativeStaffTransport(FakeStaffCookies(),
        clientFactory: (_) => LoopbackClient(source.port));
    await expectLater(
        api.request(StaffOperation.challenge,
            proof: 'synthetic-proof', isCurrent: () => true),
        throwsA(isA<ApiFailure>()));
    expect(sourceRequests, 1);
    expect(targetRequests, 0);
  });
  test(
      'fixed origin native request never enables redirects or places proof in URL',
      () async {
    final request = Request(Response(200)), cookies = FakeStaffCookies();
    final client = Client(request);
    final api = NativeStaffTransport(cookies, clientFactory: (_) => client);
    await api.request(StaffOperation.exchange,
        proof: 'synthetic-proof',
        challenge: opaque('b'),
        csrf: opaque('c'),
        isCurrent: () => true);
    expect(client.target.toString(),
        'https://staff.example/api/staff/native/exchange');
    expect(request.followRedirects, false);
    expect(request.maxRedirects, 0);
    expect(request.headers['authorization'], ['Bearer synthetic-proof']);
    expect(request.headers['cookie'],
        ['__Host-nightshift_staff_challenge=${opaque('b')}']);
    expect(jsonDecode(request.body), {'proof': 'synthetic-proof'});
    expect(client.forcedClosed, true);
  });
  test('redirect response is rejected before reading its body', () async {
    var read = false;
    Stream<List<int>> responseBody() async* {
      read = true;
      yield utf8.encode('{}');
    }

    final request = Request(Response(307, source: responseBody()));
    final client = Client(request);
    final api =
        NativeStaffTransport(FakeStaffCookies(), clientFactory: (_) => client);
    await expectLater(
        api.request(StaffOperation.challenge,
            proof: 'synthetic-proof', isCurrent: () => true),
        throwsA(isA<ApiFailure>()));
    expect(read, false);
    expect(client.forcedClosed, true);
  });
  test('account switch during TCP/TLS opening sends no authorization or body',
      () async {
    final request = Request(Response(200)), gate = Completer<void>();
    final client = Client(request)..gate = gate.future;
    final api =
        NativeStaffTransport(FakeStaffCookies(), clientFactory: (_) => client);
    var current = true;
    final work = api.request(StaffOperation.exchange,
        proof: 'old-proof',
        challenge: opaque('b'),
        csrf: opaque('c'),
        isCurrent: () => current);
    final rejected = expectLater(work, throwsA(isA<ApiFailure>()));
    await Future<void>.delayed(Duration.zero);
    current = false;
    api.cancel();
    gate.complete();
    await rejected;
    expect(request.sent, false);
    expect(request.headers['authorization'], null);
    expect(request.body, '');
    expect(client.forcedClosed, true);
  });
  test('full response deadline force closes a held body', () async {
    final body = StreamController<List<int>>();
    final client = Client(Request(Response(200, source: body.stream)));
    final api = NativeStaffTransport(FakeStaffCookies(),
        clientFactory: (_) => client,
        timeout: const Duration(milliseconds: 20));
    await expectLater(
        api.request(StaffOperation.challenge,
            proof: 'synthetic-proof', isCurrent: () => true),
        throwsA(isA<ApiFailure>()));
    expect(client.forcedClosed, true);
    await body.close();
  });
  test('oversize native response is rejected without retaining a capability',
      () async {
    final response =
        Response(200, source: Stream.value(List.filled(65537, 32)));
    final client = Client(Request(response));
    final api =
        NativeStaffTransport(FakeStaffCookies(), clientFactory: (_) => client);
    await expectLater(
        api.request(StaffOperation.challenge,
            proof: 'synthetic-proof', isCurrent: () => true),
        throwsA(isA<ApiFailure>()));
    expect(client.forcedClosed, true);
  });
}
