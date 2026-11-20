import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/directory_events.dart';

void main() {
  test('fixed origin socket authenticates and acknowledges scoped subscription',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[],
        auth = Completer<String>(),
        ack = Completer<bool>();
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.add('0${jsonEncode({
            'sid': 'synthetic',
            'upgrades': [],
            'pingInterval': 25000,
            'pingTimeout': 20000
          })}');
      socket.listen((message) {
        final text = message as String;
        if (text.startsWith('40')) {
          auth.complete(
              (jsonDecode(text.substring(2)) as Map)['token'] as String);
          socket.add('40{"sid":"synthetic"}');
        } else if (text.startsWith('42')) {
          final marker = text.indexOf('['), id = text.substring(2, marker);
          final value = jsonDecode(text.substring(marker)) as List;
          expect(value.first, 'directory.subscribe');
          expect((value[1] as Map)['visibleIds'], ['visible-listener']);
          socket.add('43$id[{"ok":true,"viewEpoch":"view"}]');
        }
      });
    });
    final events = SocketDirectoryEvents();
    try {
      events.connect(
          origin: 'http://127.0.0.1:${server.port}',
          token: 'synthetic-fixture-only',
          onUpdate: (_) {},
          onConnection: (connected) {
            if (connected) {
              events.subscribe({
                'viewEpoch': 'view',
                'language': 'ta',
                'visibleIds': ['visible-listener']
              }, (result) {
                if (!ack.isCompleted) ack.complete(result['ok'] == true);
              });
            }
          });
      expect(await auth.future.timeout(const Duration(seconds: 3)),
          'synthetic-fixture-only');
      expect(await ack.future.timeout(const Duration(seconds: 3)), true);
    } finally {
      events.close();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    }
  });

  test('cross-origin redirect receives no request or synthetic authentication',
      () async {
    final sink = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var redirectedRequests = 0;
    sink.listen((request) async {
      redirectedRequests++;
      request.response.statusCode = 400;
      await request.response.close();
    });
    origin.listen((request) async {
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(HttpHeaders.locationHeader,
          'http://127.0.0.1:${sink.port}${request.uri}');
      await request.response.close();
    });
    final events = SocketDirectoryEvents(), failed = Completer<void>();
    try {
      events.connect(
          origin: 'http://127.0.0.1:${origin.port}',
          token: 'synthetic-fixture-only',
          onUpdate: (_) {},
          onConnection: (connected) {
            if (!connected && !failed.isCompleted) failed.complete();
          });
      await failed.future.timeout(const Duration(seconds: 3));
      expect(redirectedRequests, 0);
    } finally {
      events.close();
      await origin.close(force: true);
      await sink.close(force: true);
    }
  });

  test('closing a pending handshake prevents late authentication', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final arrived = Completer<HttpRequest>();
    server.listen((request) {
      if (!arrived.isCompleted) arrived.complete(request);
    });
    final events = SocketDirectoryEvents();
    var connected = false;
    try {
      events.connect(
          origin: 'http://127.0.0.1:${server.port}',
          token: 'synthetic-fixture-only',
          onUpdate: (_) {},
          onConnection: (value) {
            connected = connected || value;
          });
      final pending = await arrived.future.timeout(const Duration(seconds: 3));
      events.close();
      // A server finishing after local cancellation cannot revive this manager.
      try {
        pending.response.statusCode = 400;
        await pending.response.close();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(connected, false);
    } finally {
      events.close();
      await server.close(force: true);
    }
  });
  test(
      'full upgrade deadline closes a held response and allows a fresh attempt',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <HttpRequest>[];
    server.listen(requests.add);
    final events = SocketDirectoryEvents(
        handshakeTimeout: const Duration(milliseconds: 80));
    var failures = 0;
    final failed = Completer<void>();
    try {
      void connect() => events.connect(
          origin: 'http://127.0.0.1:${server.port}',
          token: 'synthetic-only',
          onUpdate: (_) {},
          onConnection: (value) {
            if (!value) {
              failures++;
              if (!failed.isCompleted) failed.complete();
            }
          });
      connect();
      await failed.future.timeout(const Duration(seconds: 2));
      expect(requests.length, 1);
      expect(events.pendingHandshakes, 0);
      connect();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(requests.length, 2);
      expect(failures, 2);
      expect(events.pendingHandshakes, 0);
      events.close();
      expect(events.pendingHandshakes, 0);
    } finally {
      events.close();
      for (final request in requests) {
        try {
          await request.response.close();
        } catch (_) {}
      }
      await server.close(force: true);
    }
  });
}
