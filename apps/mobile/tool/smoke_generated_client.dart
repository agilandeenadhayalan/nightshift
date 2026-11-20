// Real HTTP control-plane verification through the generated Dart SDK.
// This never reports RTC readiness or claims that microphones/audio were tested.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:nightshift_api/api.dart' as sdk;

const _deadline = Duration(seconds: 10);

String _newId() {
  final random = Random.secure();
  return List.generate(
      24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class _Failure implements Exception {
  const _Failure(this.code);
  final String code;
}

void _check(bool condition, String code) {
  if (!condition) throw _Failure(code);
}

class _Session {
  _Session(String baseUrl, this.role) {
    client = sdk.ApiClient(basePath: baseUrl, authentication: authentication);
    api = sdk.DefaultApi(client);
  }

  final String role;
  final authentication = sdk.HttpBearerAuth();
  late final sdk.ApiClient client;
  late final sdk.DefaultApi api;
  sdk.Login? login;
}

class _Smoke {
  String step = 'configuration';
  String? callId;
  final sessions = <_Session>[];

  Future<T> request<T>(
      String name, Future<T?> Function(Future<void>) operation) async {
    step = name;
    final abort = Completer<void>();
    final result =
        await operation(abort.future).timeout(_deadline, onTimeout: () {
      abort.complete();
      throw const _Failure('REQUEST_TIMEOUT');
    });
    if (result == null) throw const _Failure('EMPTY_RESPONSE');
    return result;
  }

  Future<void> run() async {
    final key = Platform.environment['DEV_ACCESS_KEY'];
    _check(key != null && key.length >= 24, 'MISSING_DEVELOPMENT_ACCESS_KEY');
    final baseUrl =
        (Platform.environment['API_BASE_URL'] ?? 'http://127.0.0.1:3000')
            .replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(baseUrl);
    _check(
        uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty &&
            uri.query.isEmpty &&
            uri.fragment.isEmpty &&
            uri.path.isEmpty,
        'INVALID_API_BASE_URL');

    final customer = _Session(baseUrl, 'customer');
    final listener = _Session(baseUrl, 'listener');
    sessions.addAll([customer, listener]);
    final health = await request(
        'health', (abort) => customer.api.health(abortTrigger: abort));
    _check(health.status == 'ok' && health.testOnly, 'TEST_BACKEND_REQUIRED');

    for (final session in sessions) {
      final login = await request(
          '${session.role}_sign_in',
          (abort) => session.api.developmentSignIn(
              sdk.DevelopmentSignInRequest(
                  handle: session.role == 'customer'
                      ? sdk.DevelopmentSignInRequestHandleEnum.customer
                      : sdk.DevelopmentSignInRequestHandleEnum.listener,
                  accessKey: key!,
                  deviceId: 'generated-smoke-${session.role}-${_newId()}'),
              abortTrigger: abort));
      session.login = login;
      session.authentication.accessToken = login.token;
      _check(login.testOnly.toJson() == true, 'NON_TEST_IDENTITY');
    }

    await request(
        'customer_mode',
        (abort) => customer.api.setMode(
            sdk.SetModeRequest(mode: sdk.SetModeRequestModeEnum.customer),
            abortTrigger: abort));
    await request(
        'listener_mode',
        (abort) => listener.api.setMode(
            sdk.SetModeRequest(mode: sdk.SetModeRequestModeEnum.listener),
            abortTrigger: abort));
    await request(
        'listener_online',
        (abort) => listener.api.setAvailability(
            sdk.SetAvailabilityRequest(online: true),
            abortTrigger: abort));
    await request('listener_heartbeat',
        (abort) => listener.api.heartbeat(abortTrigger: abort));
    final directory = await request(
        'listener_discovery',
        (abort) =>
            customer.api.listListeners(language: 'ta', abortTrigger: abort));
    final listenerId = listener.login!.user.id;
    _check(
        directory.items.any((item) => item.id == listenerId && item.available),
        'ONLINE_LISTENER_NOT_DISCOVERABLE');

    final invitationKey = _newId();
    final body = sdk.CreateCallRequest(
        listenerId: listenerId,
        quoteId: sdk.CreateCallRequestQuoteIdEnum.testAudioV1);
    var call = await request(
        'invite',
        (abort) =>
            customer.api.createCall(invitationKey, body, abortTrigger: abort));
    callId = call.id;
    _check(call.state == sdk.CallStateEnum.ringing, 'INVITATION_NOT_RINGING');
    final replay = await request(
        'invitation_replay',
        (abort) =>
            customer.api.createCall(invitationKey, body, abortTrigger: abort));
    _check(replay.id == callId, 'INVITATION_REPLAY_CHANGED_CALL');
    final incoming = await request('listener_snapshot',
        (abort) => listener.api.getSnapshot(abortTrigger: abort));
    _check(incoming.activeCall?.id == callId, 'LISTENER_INVITATION_MISSING');

    call = await request(
        'accept',
        (abort) => listener.api.acceptCall(call.id, _newId(),
            sdk.AcceptCallRequest(expectedVersion: call.version),
            abortTrigger: abort));
    _check(call.state == sdk.CallStateEnum.connecting, 'ACCEPT_NOT_CONNECTING');
    // No media-ready report is sent. Acceptance alone must not create billable time.
    call = await request(
        'end',
        (abort) => customer.api.endCall(call.id, _newId(),
            sdk.DeclineCallRequest(expectedVersion: call.version),
            abortTrigger: abort));
    _check(call.state == sdk.CallStateEnum.ended, 'CALL_NOT_ENDED');
    _check(call.chargeMicrocredits == 0 && call.connectedMs == 0,
        'UNJOINED_CALL_WAS_METERED');

    for (final session in sessions) {
      final history = await request('${session.role}_history',
          (abort) => session.api.listCalls(abortTrigger: abort));
      final matches = history.items.where((item) => item.id == callId).toList();
      _check(matches.length == 1, 'COMPLETED_HISTORY_MISSING_OR_DUPLICATED');
      final receipt = matches.single;
      _check(
          receipt.state == sdk.CallStateEnum.ended &&
              receipt.chargeMicrocredits == 0 &&
              receipt.connectedMs == 0,
          'COMPLETED_HISTORY_MISMATCH');
      final snapshot = await request('${session.role}_released',
          (abort) => session.api.getSnapshot(abortTrigger: abort));
      _check(snapshot.activeCall == null, 'ACTIVE_CLAIM_NOT_RELEASED');
    }
  }

  Future<List<String>> cleanup() async {
    final failures = <String>[];
    for (final session in sessions.reversed) {
      if (session.login != null) {
        if (session.role == 'listener') {
          try {
            await request(
                'cleanup_listener_offline',
                (abort) => session.api.setAvailability(
                    sdk.SetAvailabilityRequest(online: false),
                    abortTrigger: abort));
          } catch (_) {
            // An active encounter can reject availability changes. Logout below
            // ends abandoned encounters and clears server-side presence as well.
          }
        }
        try {
          await request('cleanup_${session.role}_sign_out',
              (abort) => session.api.signOut(abortTrigger: abort));
        } catch (_) {
          failures.add('${session.role}_sign_out');
        }
      }
      session.authentication.accessToken = '';
      session.client.client.close();
    }
    return failures;
  }
}

Future<void> main() async {
  final smoke = _Smoke();
  final result = <String, Object>{};
  try {
    await smoke.run();
    result.addAll({
      'result': 'passed',
      'checks': [
        'generated SDK authentication and request/response serialization',
        'online listener discovery',
        'idempotent invitation',
        'listener accepts',
        'customer ends',
        'zero charge without media',
        'same completed call in both histories',
        'claims released',
      ],
    });
  } catch (error) {
    result.addAll({
      'result': 'failed',
      'step': smoke.step,
      'code': error is _Failure
          ? error.code
          : error is sdk.ApiException
              ? 'HTTP_${error.code}'
              : 'TRANSPORT_OR_CONTRACT_FAILURE',
    });
    exitCode = 1;
  } finally {
    final cleanupFailures = await smoke.cleanup();
    if (cleanupFailures.isNotEmpty) {
      result['result'] = 'failed';
      result['cleanupFailures'] = cleanupFailures;
      exitCode = 1;
    }
  }
  // Only UUID-shaped diagnostic identifiers are emitted; never log credentials,
  // arbitrary response bodies, exception messages or generated model objects.
  final callId = smoke.callId;
  if (callId != null &&
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(callId)) {
    result['callId'] = callId;
  }
  result['mediaVerification'] =
      'NOT performed: two phones and Agora test credentials required';
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
}
