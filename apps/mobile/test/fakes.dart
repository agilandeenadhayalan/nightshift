import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/audio.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/core/session_store.dart';

Json userJson(
        {bool listener = false, bool approved = false, bool online = false}) =>
    {
      'id': listener ? 'listener-id' : 'customer-id',
      'displayName': listener ? 'Test Listener' : 'Test Customer',
      'mode': listener ? 'listener' : 'customer',
      'listenerApproved': approved,
      'online': online,
      'languages': ['ta', 'en'],
    };

Json callJson({String state = 'ringing', int version = 1}) => {
      'id': 'call-id',
      'customerId': 'customer-id',
      'listenerId': 'listener-id',
      'customerName': 'Test Customer',
      'listenerName': 'Test Listener',
      'state': state,
      'version': version,
      'connectedMs': 41000,
      'chargeMicrocredits': 3600000,
      'earningPaise': 833,
      'createdAt': '2026-11-20T00:00:00.000Z',
      'expiresAt': '2026-11-20T00:00:30.000Z',
      'acceptedAt': state == 'ringing' ? null : '2026-11-20T00:00:01.000Z',
      'endedAt': state == 'ended' ? '2026-11-20T00:00:41.000Z' : null,
      'reason': state == 'ended' ? 'ended' : null,
      'maxDurationSeconds': 600,
      'rate': rateJson(),
      'testOnly': true,
    };

Json rateJson() => {
      'id': 'test-audio-v1',
      'coinsPerMinute': 60,
      'microcreditsPerCoin': 60000,
      'microcreditsPerSecond': 60000,
      'freeThroughSeconds': 40,
      'minimumChargedSeconds': 60,
      'listenerPaisePerHour': 50000,
      'testOnly': true,
    };

class MemoryStore implements SessionStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeAudio implements CallAudio {
  bool denied = false;
  int leaveCount = 0, joinCount = 0;
  @override
  bool ready = false;
  @override
  bool muted = false;
  @override
  bool speaker = false;
  @override
  void Function()? onChanged;
  @override
  void Function(String)? onFailure;
  @override
  Future<void> checkPermission() async {
    if (denied) {
      throw const ApiFailure('MICROPHONE_DENIED', 'Microphone denied');
    }
  }

  @override
  Future<void> join(RtcCredentials credentials,
      Future<RtcCredentials> Function() renew) async {
    joinCount++;
  }

  @override
  Future<void> leave() async {
    leaveCount++;
    ready = false;
  }

  @override
  Future<void> toggleMute() async {
    muted = !muted;
    onChanged?.call();
  }

  @override
  Future<void> toggleSpeaker() async {
    speaker = !speaker;
    onChanged?.call();
  }
}

class FakeApi extends NightShiftApi {
  Json user = userJson();
  Json? call;
  final List<Json> requests = [];
  List<Json> historyItems = [];
  List<Json> directory = [];
  ApiFailure? snapshotFailure;
  ApiFailure? rtcFailure;
  Future<Json?> Function(String method, String path, Json? body)? interceptor;
  @override
  Future<Json> request(String method, String path,
      {Json? body, String? idempotencyKey}) async {
    requests.add(
        {'method': method, 'path': path, 'body': body, 'key': idempotencyKey});
    final intercepted = await interceptor?.call(method, path, body);
    if (intercepted != null) return intercepted;
    if (path == '/auth/dev') {
      return {'token': 'test-session-token', 'user': user};
    }
    if (path.startsWith('/snapshot')) {
      if (snapshotFailure != null) throw snapshotFailure!;
      return {
        'user': user,
        'activeCall': call,
        'listeners': directory,
        'wallet': {'balanceMicrocredits': 600000000, 'heldMicrocredits': 0}
      };
    }
    if (path == '/calls' && method == 'GET') return {'items': historyItems};
    if (path.startsWith('/blocks/')) {
      if (call != null) {
        historyItems = [
          {...callJson(state: 'ended'), 'reason': 'blocked'}
        ];
        call = null;
      }
      return {'blocked': true};
    }
    if (path == '/calls/call-id' && method == 'GET') {
      return call ?? callJson(state: 'ended');
    }
    if (path == '/calls' && method == 'POST') {
      call = callJson();
      return call!;
    }
    if (path == '/me/mode') {
      user = {...user, 'mode': body!['mode']};
      return user;
    }
    if (path == '/me/availability') {
      user = {...user, 'online': body!['online']};
      return user;
    }
    if (path.endsWith('/rtc-token')) {
      if (rtcFailure != null) throw rtcFailure!;
      return {
        'appId': 'app',
        'channel': 'channel',
        'uid': 1,
        'remoteUid': 2,
        'token': 'rtc-test-token'
      };
    }
    if (path.endsWith('/end') ||
        path.endsWith('/decline') ||
        path.endsWith('/cancel')) {
      final ended = callJson(state: 'ended', version: 2);
      historyItems = [ended];
      call = null;
      return ended;
    }
    if (path.endsWith('/accept')) {
      call = callJson(state: 'connecting', version: 2);
      return call!;
    }
    return {};
  }
}
