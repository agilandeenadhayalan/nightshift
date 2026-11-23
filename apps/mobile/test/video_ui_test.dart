import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/audio.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

Json videoRateJson() => {
      ...rateJson(),
      'id': 'test-video-v1',
      'coinsPerMinute': 120,
      'microcreditsPerSecond': 120000,
    };

Json videoCallJson({String state = 'ringing'}) => {
      ...callJson(state: state),
      'mediaType': 'video',
      'rate': videoRateJson(),
    };

class UiVideo extends FakeAudio implements CallVideo {
  bool cameraDenied = false;
  int previewCount = 0, videoJoinCount = 0, cameraSwitchCount = 0;
  @override
  bool previewing = false, cameraEnabled = false, frontCamera = true;
  @override
  bool videoReady = false, lowBandwidth = false;
  @override
  VideoViewController? get localVideo => null;
  @override
  VideoViewController? get remoteVideo => null;
  @override
  Future<void> startPreview(String appId) async {
    previewCount++;
    if (cameraDenied) {
      throw const ApiFailure('CAMERA_DENIED', 'Private SDK camera message');
    }
    previewing = cameraEnabled = true;
    onChanged?.call();
  }

  @override
  Future<void> stopPreview() async {
    if (previewing) cameraEnabled = false;
    previewing = false;
    onChanged?.call();
  }

  @override
  Future<void> joinVideo(RtcCredentials credentials,
      Future<RtcCredentials> Function() renew) async {
    videoJoinCount++;
    ready = videoReady = cameraEnabled = true;
    onChanged?.call();
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraEnabled = videoReady = enabled;
    onChanged?.call();
  }

  @override
  Future<void> switchCamera() async {
    cameraSwitchCount++;
    frontCamera = !frontCamera;
    onChanged?.call();
  }

  @override
  Future<void> leave() async {
    await super.leave();
    previewing = cameraEnabled = videoReady = false;
    onChanged?.call();
  }
}

Future<(AppController, FakeApi, UiVideo)> mountVideoApp(WidgetTester tester,
    {bool listener = false,
    Json? call,
    bool enabled = true,
    String locale = 'en'}) async {
  final video = UiVideo();
  final api = FakeApi()
    ..user = userJson(listener: listener, approved: listener)
    ..call = call
    ..directory = [
      {
        'id': 'listener-id',
        'displayName': 'Test Listener',
        'languages': ['ta', 'en'],
        'available': true,
        'rate': rateJson(),
        'videoRate': enabled ? videoRateJson() : null,
      }
    ];
  api.interceptor = (method, path, body) async {
    if (path == '/rtc/config') {
      return {
        'appId': 'test-public-id',
        'videoEnabled': enabled,
        'testOnly': true
      };
    }
    if (path == '/calls' && method == 'POST') {
      expect(video.previewing, isFalse,
          reason: 'Preview must stop before an invitation is sent.');
      api.call = body?['mediaType'] == 'video'
          ? videoCallJson()
          : {...callJson(), 'id': 'new-audio-call'};
      return api.call;
    }
    if (path.endsWith('/accept')) {
      expect(video.previewing, isFalse);
      api.call = videoCallJson(state: 'connecting');
      return api.call;
    }
    return null;
  };
  final store = MemoryStore()
    ..values['token'] = 'saved-session'
    ..values['locale'] = locale;
  final controller =
      AppController(api: api, store: store, audio: video, startTimers: false);
  await controller.initialize();
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => controller)],
      child: const NightShiftApp()));
  await tester.pumpAndSettle();
  return (controller, api, video);
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 220,
        scrollable: find.byType(Scrollable).last, maxScrolls: 40);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> consentPreview(WidgetTester tester, String label) async {
  await tapVisible(tester, find.text('Preview camera'));
  await tapVisible(tester, find.byType(Checkbox));
  await tapVisible(tester, find.text(label));
}

void main() {
  testWidgets('video invitation needs explicit preview and unchecked consent',
      (tester) async {
    final (controller, api, video) = await mountVideoApp(tester);
    await tapVisible(tester, find.text('Video call'));
    expect(video.previewCount, 0);
    expect(video.videoJoinCount, 0);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start video call'))
            .onPressed,
        isNull);
    expect(find.textContaining('120 test coins / minute'), findsWidgets);
    await consentPreview(tester, 'Start video call');
    final request = api.requests
        .singleWhere((r) => r['method'] == 'POST' && r['path'] == '/calls');
    expect(request['body'], containsPair('mediaType', 'video'));
    expect(request['body'], containsPair('videoConsent', true));
    expect(controller.activeCall!.isVideo, isTrue);
    expect(video.previewing, isFalse);
    expect(video.videoJoinCount, 0);
  });

  testWidgets('canceling local preview never sends an invitation',
      (tester) async {
    final (_, api, video) = await mountVideoApp(tester);
    await tapVisible(tester, find.text('Video call'));
    await tapVisible(tester, find.text('Preview camera'));
    expect(video.previewing, isTrue);
    await tapVisible(tester, find.text('Cancel'));
    expect(video.previewing, isFalse);
    expect(video.cameraEnabled, isFalse);
    expect(
        api.requests
            .where((r) => r['method'] == 'POST' && r['path'] == '/calls'),
        isEmpty);
  });

  testWidgets('camera denial stays recoverable without exposing SDK text',
      (tester) async {
    final (_, api, video) = await mountVideoApp(tester);
    video.cameraDenied = true;
    await tapVisible(tester, find.text('Video call'));
    await tapVisible(tester, find.text('Preview camera'));
    expect(find.text('Private SDK camera message'), findsNothing);
    expect(find.textContaining('Allow camera access'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start video call'))
            .onPressed,
        isNull);
    expect(
        api.requests
            .where((r) => r['path'] == '/calls' && r['method'] == 'POST'),
        isEmpty);
  });

  testWidgets('incoming video does not start camera before preview and accept',
      (tester) async {
    final (_, api, video) =
        await mountVideoApp(tester, listener: true, call: videoCallJson());
    expect(video.previewCount, 0);
    expect(video.videoJoinCount, 0);
    await tapVisible(tester, find.text('Review video invitation'));
    expect(video.previewCount, 0);
    await consentPreview(tester, 'Accept video call');
    final request =
        api.requests.singleWhere((r) => r['path'] == '/calls/call-id/accept');
    expect(request['body'], containsPair('videoConsent', true));
    expect(video.videoJoinCount, 1);
  });

  testWidgets('restored video requires fresh preview before camera joins',
      (tester) async {
    final (controller, api, video) =
        await mountVideoApp(tester, call: videoCallJson(state: 'connected'));
    expect(controller.needsVideoConsent, isTrue);
    expect(video.previewCount, 0);
    expect(video.videoJoinCount, 0);
    await tapVisible(tester, find.text('Review camera'));
    await consentPreview(tester, 'Join video call');
    expect(video.videoJoinCount, 1);
    expect(api.requests.where((r) => (r['path'] as String).endsWith('/accept')),
        isEmpty);
  });

  testWidgets(
      'video entry stays hidden when server does not offer a video rate',
      (tester) async {
    await mountVideoApp(tester, enabled: false);
    expect(find.text('Video call'), findsNothing);
    expect(find.text('Call'), findsOneWidget);
  });

  testWidgets('camera controls preserve the disclosed video rate',
      (tester) async {
    final (_, _, video) =
        await mountVideoApp(tester, call: videoCallJson(state: 'connected'));
    await tapVisible(tester, find.text('Review camera'));
    await consentPreview(tester, 'Join video call');
    await tapVisible(tester, find.text('Switch camera'));
    expect(video.cameraSwitchCount, 1);
    expect(video.frontCamera, isFalse);
    await tapVisible(tester, find.text('Turn camera off'));
    expect(video.cameraEnabled, isFalse);
    expect(find.textContaining('test charging are paused'), findsOneWidget);
    await reveal(tester, find.text('Switch camera'));
    expect(
        tester
            .widget<OutlinedButton>(find.ancestor(
                of: find.text('Switch camera'),
                matching: find
                    .byWidgetPredicate((widget) => widget is OutlinedButton)))
            .onPressed,
        isNull);
    await tapVisible(tester, find.text('Turn camera on'));
    expect(video.cameraEnabled, isTrue);
    video.lowBandwidth = true;
    video.onChanged?.call();
    await tester.pumpAndSettle();
    expect(find.text('Reduced video quality'), findsOneWidget);
    expect(find.textContaining('rate stays 120 test coins / minute'),
        findsOneWidget);
  });

  testWidgets('audio fallback settles video then requires a new audio quote',
      (tester) async {
    final (controller, api, video) =
        await mountVideoApp(tester, call: videoCallJson(state: 'connected'));
    await tapVisible(tester, find.text('End video and use audio'));
    expect(find.textContaining('separate audio-rate confirmation'),
        findsOneWidget);
    expect(
        api.requests.where((r) => r['path'] == '/calls/call-id/end'), isEmpty);
    await tapVisible(tester, find.text('End video'));
    expect(controller.hasCall, isFalse);
    expect(video.cameraEnabled, isFalse);
    expect(api.requests.where((r) => r['path'] == '/calls/call-id/end'),
        hasLength(1));
    expect(find.textContaining('60 test coins / minute'), findsWidgets);
    expect(
        api.requests
            .where((r) => r['method'] == 'POST' && r['path'] == '/calls'),
        isEmpty);
    await tapVisible(tester, find.text('Start audio call'));
    final create = api.requests
        .singleWhere((r) => r['method'] == 'POST' && r['path'] == '/calls');
    expect(create['body'], containsPair('quoteId', 'test-audio-v1'));
    expect((create['body'] as Json)['mediaType'] ?? 'audio', 'audio');
    expect(create['body'], isNot(containsPair('videoConsent', true)));
    expect(controller.activeCall!.isVideo, isFalse);
    expect(controller.activeCall!.id, 'new-audio-call');
  });

  testWidgets('backgrounding dismisses preview without sending an invitation',
      (tester) async {
    final (controller, api, video) = await mountVideoApp(tester);
    await tapVisible(tester, find.text('Video call'));
    await tapVisible(tester, find.text('Preview camera'));
    await controller.setForeground(false);
    await tester.pumpAndSettle();
    expect(find.text('Review your camera'), findsNothing);
    expect(video.previewing, isFalse);
    expect(video.cameraEnabled, isFalse);
    expect(
        api.requests
            .where((r) => r['path'] == '/calls' && r['method'] == 'POST'),
        isEmpty);
  });

  testWidgets('expired incoming invitation dismisses preview and cannot accept',
      (tester) async {
    final (controller, api, video) =
        await mountVideoApp(tester, listener: true, call: videoCallJson());
    await tapVisible(tester, find.text('Review video invitation'));
    await tapVisible(tester, find.text('Preview camera'));
    api.call = null;
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Review your camera'), findsNothing);
    expect(video.cameraEnabled, isFalse);
    expect(api.requests.where((r) => r['path'] == '/calls/call-id/accept'),
        isEmpty);
  });

  testWidgets('history identifies settled video and audio separately',
      (tester) async {
    final (_, api, _) = await mountVideoApp(tester);
    api.historyItems = [
      videoCallJson(state: 'ended'),
      {...callJson(state: 'ended'), 'id': 'audio-history-call'}
    ];
    await tapVisible(tester, find.text('Recents'));
    expect(find.text('Video call'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Audio call'), 220,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(find.text('Audio call'), findsOneWidget);
  });

  testWidgets('Tamil video at 2x text keeps end and report reachable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() async {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    });
    final (controller, api, video) = await mountVideoApp(tester,
        call: videoCallJson(state: 'connected'), locale: 'ta');
    await tapVisible(tester, find.text('கேமராவை சரிபார்'));
    await tapVisible(tester, find.text('கேமரா முன்னோட்டம்'));
    await tapVisible(tester, find.byType(Checkbox));
    await tapVisible(tester, find.text('வீடியோ அழைப்பில் சேர்'));
    expect(video.videoJoinCount, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('அழைப்பை முடி').hitTestable(), findsOneWidget);
    expect(find.text('புகாரளி அல்லது தடு').hitTestable(), findsOneWidget);
    final busyGate = Completer<void>();
    final pendingOperation = controller.perform(() => busyGate.future);
    try {
      expect(controller.busy, isTrue);
      video.onChanged?.call();
      await tester.pump();
      final endButton = tester.widget<FilledButton>(find.ancestor(
          of: find.text('அழைப்பை முடி'),
          matching:
              find.byWidgetPredicate((widget) => widget is FilledButton)));
      expect(endButton.onPressed, isNotNull,
          reason: 'A pending camera operation cannot disable End.');
      await tester.tap(find.text('அழைப்பை முடி'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.requests.where((r) => r['path'] == '/calls/call-id/end'),
          hasLength(1));
    } finally {
      busyGate.complete();
      // Flush the fake-async microtasks before awaiting the held operation.
      await tester.pump();
      await pendingOperation;
    }
    expect(controller.busy, isFalse);
    video.onChanged?.call();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
