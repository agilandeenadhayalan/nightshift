import 'dart:async';
import 'dart:io' as native;
import 'package:web_socket/io_web_socket.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'models.dart';

abstract interface class DirectoryEvents {
  void connect(
      {required String origin,
      required String token,
      required void Function(Json) onUpdate,
      required void Function(bool) onConnection});
  void subscribe(Json subscription, void Function(Json) ack);
  void close();
}

/// A new manager per identity prevents the library's host cache reusing tokens.
class SocketDirectoryEvents implements DirectoryEvents {
  SocketDirectoryEvents({this.handshakeTimeout = const Duration(seconds: 8)});
  final Duration handshakeTimeout;
  io.Socket? _socket;
  final Set<_OriginSocketClient> _clients = {};
  int _generation = 0;
  int get pendingHandshakes => _clients.length;
  @override
  void connect(
      {required String origin,
      required String token,
      required void Function(Json) onUpdate,
      required void Function(bool) onConnection}) {
    close();
    final uri = Uri.parse(origin);
    final generation = _generation;
    final socket = io.io(
        uri.origin,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setWebSocketConnector((address, {protocols, headers}) async {
              if (generation != _generation) {
                throw const native.HttpException('Socket closed.');
              }
              final client = _OriginSocketClient(uri.origin);
              _clients.add(client);
              final deadline =
                  Timer(handshakeTimeout, () => client.close(force: true));
              try {
                final raw = await native.WebSocket.connect(address.toString(),
                    protocols: protocols,
                    headers: headers,
                    customClient: client);
                if (client.closed || generation != _generation) {
                  await raw.close();
                  throw const native.HttpException('Socket closed.');
                }
                return IOWebSocket.fromWebSocket(raw);
              } finally {
                deadline.cancel();
                _clients.remove(client);
                // The upgraded socket is detached from HttpClient ownership.
                client.close(force: true);
              }
            })
            .disableAutoConnect()
            .enableForceNew()
            .disableMultiplex()
            .setAckTimeout(5000)
            .setAuth({'token': token})
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(10000)
            .build());
    _socket = socket;
    bool current() => identical(_socket, socket);
    socket.onConnect((_) {
      if (current()) onConnection(true);
    });
    socket.onDisconnect((_) {
      if (current()) onConnection(false);
    });
    socket.onConnectError((_) {
      if (current()) onConnection(false);
    });
    socket.on('directory.updated', (data) {
      if (current() && data is Map) {
        try {
          onUpdate(Map<String, dynamic>.from(data));
        } catch (_) {
          onConnection(false);
        }
      }
    });
    socket.on('directory.invalidated', (data) {
      if (current() && data is Map) {
        try {
          onUpdate({...Map<String, dynamic>.from(data), 'invalidated': true});
        } catch (_) {
          onConnection(false);
        }
      }
    });
    socket.connect();
  }

  @override
  void subscribe(Json subscription, void Function(Json) ack) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emitWithAck('directory.subscribe', subscription,
        ack: (error, [data]) {
      if (!identical(socket, _socket)) return;
      if (error != null) {
        ack({'ok': false, 'code': 'OFFLINE'});
      } else if (data is Map) {
        ack(Map<String, dynamic>.from(data));
      }
    });
  }

  @override
  void close() {
    _generation++;
    final old = _socket;
    _socket = null;
    old?.dispose();
    for (final client in _clients.toList()) {
      client.close(force: true);
    }
    _clients.clear();
  }
}

/// WebSocket.connect otherwise follows HTTP redirects before Socket.IO sends
/// its bearer handshake. Only this frozen origin may receive that handshake.
class _OriginSocketClient implements native.HttpClient {
  _OriginSocketClient(this.origin)
      : _client = native.HttpClient()
          ..connectionTimeout = const Duration(seconds: 8);
  final String origin;
  final native.HttpClient _client;
  bool closed = false;
  @override
  Future<native.HttpClientRequest> openUrl(String method, Uri url) async {
    if (closed || url.origin != origin || url.userInfo.isNotEmpty) {
      throw const native.HttpException('Socket origin changed.');
    }
    final request = await _client.openUrl(method, url);
    if (closed) {
      request.abort();
      throw const native.HttpException('Socket closed.');
    }
    request.followRedirects = false;
    return request;
  }

  @override
  void close({bool force = false}) {
    closed = true;
    _client.close(force: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
