import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

Iterable<Json> mediaReports(FakeApi api) => api.requests
    .where((request) => (request['path'] as String).endsWith('/media'));

Future<void> withConnectedCall(WidgetTester tester,
    Future<void> Function(AppController, FakeApi, FakeAudio) run) async {
  final api = FakeApi();
  final audio = FakeAudio();
  final controller =
      AppController(api: api, audio: audio, store: MemoryStore());
  try {
    await controller.initialize();
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.call = callJson(state: 'connected');
    await controller.refresh();
    await tester.pump();
    audio.ready = true;
    api.requests.clear();

    await run(controller, api, audio);
  } finally {
    controller.dispose();
    await tester.pump();
  }
}

void main() {
  testWidgets(
      'healthy media heartbeat continues through a six-second snapshot stall',
      (tester) async {
    await withConnectedCall(tester, (controller, api, audio) async {
      final snapshot = Completer<Json>();
      api.interceptor = (method, path, body) async =>
          path.startsWith('/snapshot') ? snapshot.future : null;
      unawaited(controller.refresh());
      await tester.pump();
      for (var tick = 0; tick < 3; tick++) {
        await tester.pump(const Duration(seconds: 2));
      }

      expect(controller.snapshotLoading, isTrue);
      expect(audio.ready, isTrue);
      final reports = api.requests
          .where((request) => request['path'] == '/calls/call-id/media');
      expect(reports, hasLength(3));
      expect(
          reports
              .every((request) => (request['body'] as Json)['ready'] == true),
          isTrue);
    });
  });

  testWidgets(
      'slow media POST stays single-flight while terminal snapshot releases capture',
      (tester) async {
    await withConnectedCall(tester, (controller, api, audio) async {
      final media = Completer<Json>();
      api.interceptor = (method, path, body) async =>
          path.endsWith('/media') ? media.future : null;
      for (var tick = 0; tick < 3; tick++) {
        await tester.pump(const Duration(seconds: 2));
      }
      expect(mediaReports(api), hasLength(1));
      expect(
          api.requests.where(
              (request) => (request['path'] as String).startsWith('/snapshot')),
          hasLength(3));
      expect(controller.snapshotLoading, isFalse);
      api.call = null;
      await tester.pump(const Duration(seconds: 2));
      expect(controller.activeCall, isNull);
      expect(audio.ready, isFalse);
      media.complete({});
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(mediaReports(api), hasLength(1));
      expect(controller.activeCall, isNull);
    });
  });

  testWidgets(
      'periodic reports never infer healthy audio from a connected call',
      (tester) async {
    await withConnectedCall(tester, (controller, api, audio) async {
      audio.ready = false;
      audio.onChanged?.call();
      await tester.pump();
      expect((mediaReports(api).single['body'] as Json)['ready'], isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(mediaReports(api), hasLength(2));
      expect(
          mediaReports(api)
              .every((request) => (request['body'] as Json)['ready'] == false),
          isTrue);
    });
  });

  testWidgets('a new call cannot report health before its own media join',
      (tester) async {
    await withConnectedCall(tester, (controller, api, audio) async {
      await controller.transition('end');
      final credentials = Completer<Json>();
      api.call = {...callJson(state: 'connecting'), 'id': 'next-call'};
      api.interceptor = (method, path, body) async =>
          path.endsWith('/rtc-token') ? credentials.future : null;
      await controller.refresh();
      // A late old-engine callback must not authorize the next call's heartbeat.
      audio.ready = true;
      api.requests.clear();
      await tester.pump(const Duration(seconds: 2));
      expect(mediaReports(api), isEmpty);
    });
  });

  for (final action in ['end', 'background', 'logout']) {
    testWidgets(
        '$action stops periodic healthy reports even before server acknowledgement',
        (tester) async {
      await withConnectedCall(tester, (controller, api, audio) async {
        final ended = Completer<Json>();
        api.interceptor = (method, path, body) async =>
            path.endsWith('/end') ? ended.future : null;
        final stopping = switch (action) {
          'background' => controller.setForeground(false),
          'logout' => controller.logout(),
          _ => controller.transition('end'),
        };
        await tester.pump();
        api.requests.clear();
        for (var tick = 0; tick < 3; tick++) {
          await tester.pump(const Duration(seconds: 2));
        }
        expect(mediaReports(api), isEmpty);
        expect(audio.ready, isFalse);
        api.call = null;
        ended.complete(callJson(state: 'ended'));
        await stopping;
      });
    });
  }

  testWidgets('current media failure notifies while the snapshot is stalled',
      (tester) async {
    await withConnectedCall(tester, (controller, api, audio) async {
      final snapshot = Completer<Json>();
      final observedErrors = <String?>[];
      controller.addListener(() => observedErrors.add(controller.errorCode));
      api.interceptor = (method, path, body) async {
        if (path.startsWith('/snapshot')) return snapshot.future;
        if (path.endsWith('/media')) {
          throw const ApiFailure('OFFLINE', 'Current media request');
        }
        return null;
      };
      unawaited(controller.refresh());
      await tester.pump(const Duration(seconds: 2));
      expect(controller.snapshotLoading, isTrue);
      expect(controller.errorCode, 'OFFLINE');
      expect(observedErrors, contains('OFFLINE'));
    });
  });

  testWidgets('late media failure cannot overwrite an ended call',
      (tester) async {
    await withConnectedCall(tester, (controller, api, audio) async {
      final media = Completer<Json>();
      api.interceptor = (method, path, body) async =>
          path.endsWith('/media') ? media.future : null;
      await tester.pump(const Duration(seconds: 2));
      await controller.transition('end');
      media.completeError(const ApiFailure('OFFLINE', 'Old media request'));
      await tester.pump();
      expect(controller.activeCall, isNull);
      expect(controller.errorCode, isNull);
      expect(audio.ready, isFalse);
    });
  });

  testWidgets('late media failure cannot invalidate a replacement sign-in',
      (tester) async {
    await withConnectedCall(tester, (controller, api, audio) async {
      final media = Completer<Json>();
      api.interceptor = (method, path, body) async =>
          path.endsWith('/media') ? media.future : null;
      await tester.pump(const Duration(seconds: 2));
      await controller.logout();
      await controller.login('http://localhost:3000', 'listener', 'key');
      media.completeError(
          const ApiFailure('UNAUTHORIZED', 'Old session', status: 401));
      await tester.pump();
      expect(api.token, isNotNull);
      expect(controller.user, isNotNull);
      expect(controller.errorCode, isNull);
      expect(controller.activeCall, isNull);
    });
  });

  testWidgets('disposal cancels media heartbeats and ignores pending failures',
      (tester) async {
    final api = FakeApi();
    final audio = FakeAudio();
    final controller =
        AppController(api: api, audio: audio, store: MemoryStore());
    await controller.initialize();
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.call = callJson(state: 'connected');
    await controller.refresh();
    await tester.pump();
    audio.ready = true;
    final media = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path.endsWith('/media') ? media.future : null;
    await tester.pump(const Duration(seconds: 2));
    expect(mediaReports(api), hasLength(1));
    controller.dispose();
    media.completeError(const ApiFailure('OFFLINE', 'Disposed request'));
    await tester.pump(const Duration(seconds: 6));
    expect(mediaReports(api), hasLength(1));
    expect(controller.errorCode, isNull);
    expect(audio.ready, isFalse);
  });
}
