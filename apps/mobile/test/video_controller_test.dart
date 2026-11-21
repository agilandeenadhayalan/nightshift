import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

Future<void> settleVideo() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeApi api;
  late FakeVideo media;
  late AppController controller;
  final listener = ListenerProfile.fromJson({
    'id': 'listener-id',
    'displayName': 'Test Listener',
    'languages': ['en'],
    'available': true,
    'online': true,
    'reachability': 'foreground',
    'rate': rateJson(),
    'videoRate': rateJson(video: true),
  });
  setUp(() async {
    api = FakeApi();
    media = FakeVideo();
    controller = AppController(
        api: api, audio: media, store: MemoryStore(), startTimers: false);
    await controller.initialize();
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.requests.clear();
  });
  tearDown(() => controller.dispose());

  test(
      'restored accepted video never requests a token or camera without consent',
      () async {
    api.call = callJson(state: 'connecting', video: true);
    await controller.refresh();
    await settleVideo();
    expect(controller.needsVideoConsent, isTrue);
    expect(media.videoJoinCount, 0);
    expect(media.cameraEnabled, isFalse);
    expect(
        api.requests.any((r) => (r['path'] as String).endsWith('/rtc-token')),
        isFalse);
    await controller.prepareVideoPreview();
    expect(media.previewing, isTrue);
    expect(media.videoJoinCount, 0);
    await controller.closeVideoPreview();
    await controller.joinConsentedVideo();
    expect(controller.needsVideoConsent, isFalse);
    expect(media.videoJoinCount, 1);
  });

  test(
      'outgoing video requires explicit consent and uses the supplied video quote',
      () async {
    await controller.startCall(listener, video: true);
    expect(controller.errorCode, 'VIDEO_CONSENT_REQUIRED');
    expect(
        api.requests.any((r) => r['path'] == '/calls' && r['method'] == 'POST'),
        isFalse);
    await controller.startCall(listener, video: true, cameraConsent: true);
    final create = api.requests
        .singleWhere((r) => r['path'] == '/calls' && r['method'] == 'POST');
    expect(create['body'], {
      'listenerId': 'listener-id',
      'quoteId': 'test-video-v1',
      'mediaType': 'video',
      'videoConsent': true
    });
    expect(media.videoJoinCount, 0);
    expect(media.cameraEnabled, isFalse);
    api.call = callJson(state: 'connecting', video: true);
    await controller.refresh();
    await settleVideo();
    expect(media.videoJoinCount, 1);
  });

  test('video acceptance requires consent and transmits it to the server',
      () async {
    api.call = callJson(video: true);
    await controller.refresh();
    await controller.transition('accept');
    expect(controller.errorCode, 'VIDEO_CONSENT_REQUIRED');
    expect(api.requests.any((r) => (r['path'] as String).endsWith('/accept')),
        isFalse);
    await controller.transition('accept', cameraConsent: true);
    await settleVideo();
    final accept = api.requests
        .singleWhere((r) => (r['path'] as String).endsWith('/accept'));
    expect((accept['body'] as Json)['videoConsent'], isTrue);
    expect(media.videoJoinCount, 1);
  });

  test('cancelled preview configuration cannot open a camera later', () async {
    final config = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path == '/rtc/config' ? config.future : null;
    final preparing = controller.prepareVideoPreview();
    await settleVideo();
    await controller.closeVideoPreview();
    config.complete({'appId': 'app', 'videoEnabled': true, 'testOnly': true});
    await preparing;
    expect(media.previewStarts, 0);
    expect(media.cameraEnabled, isFalse);
    expect(controller.videoPreviewBusy, isFalse);
  });

  test('background during asynchronous preview cannot reacquire camera',
      () async {
    final pending = Completer<void>();
    media.previewDelay = pending.future;
    final preparing = controller.prepareVideoPreview();
    await settleVideo();
    await controller.setForeground(false);
    pending.complete();
    await preparing;
    expect(media.cameraEnabled, isFalse);
    expect(media.previewing, isFalse);
  });

  test('preview camera denial is recoverable and sends no invitation',
      () async {
    media.cameraDenied = true;
    await controller.prepareVideoPreview();
    expect(controller.videoPreviewError, 'CAMERA_DENIED');
    expect(media.cameraEnabled, isFalse);
    expect(api.requests.any((r) => r['path'] == '/calls'), isFalse);
    media.cameraDenied = false;
    await controller.prepareVideoPreview();
    expect(controller.videoPreviewError, isNull);
    expect(media.previewing, isTrue);
  });

  test('disabled video configuration never starts preview', () async {
    api.videoEnabled = false;
    await controller.prepareVideoPreview();
    expect(controller.videoPreviewError, 'VIDEO_UNAVAILABLE');
    expect(media.previewStarts, 0);
  });

  test('late preview camera failure is visible even without an active call',
      () async {
    await controller.prepareVideoPreview();
    media.onFailure?.call('RTC_CAMERA_FAILED');
    await settleVideo();
    expect(controller.videoPreviewError, 'VIDEO_FAILED');
    expect(media.cameraEnabled, isFalse);
    expect(controller.activeCall, isNull);
  });

  test(
      'video health requires remote frames and camera off reports loss immediately',
      () async {
    await controller.startCall(listener, video: true, cameraConsent: true);
    api.call = callJson(state: 'connected', video: true);
    await controller.refresh();
    await settleVideo();
    media.ready = true;
    media.videoReady = false;
    await controller.reportMedia();
    Json lastMedia() => api.requests
            .lastWhere((r) => (r['path'] as String).endsWith('/media'))['body']
        as Json;
    expect(lastMedia(), {'ready': true, 'videoReady': false});
    media.videoReady = true;
    await controller.reportMedia();
    expect(lastMedia()['videoReady'], isTrue);
    await controller.setCameraEnabled(false);
    await settleVideo();
    expect(media.cameraEnabled, isFalse);
    expect(lastMedia()['videoReady'], isFalse);
  });

  test(
      'audio fallback releases camera before a delayed end and does not silently reinvite',
      () async {
    await controller.startCall(listener, video: true, cameraConsent: true);
    api.call = callJson(state: 'connected', video: true);
    await controller.refresh();
    await settleVideo();
    final ended = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path.endsWith('/end') ? ended.future : null;
    api.requests.clear();
    final fallback = controller.endVideoForAudio();
    await settleVideo();
    expect(media.cameraEnabled, isFalse);
    expect(controller.endingLocally, isTrue);
    expect(
        api.requests.any((r) => r['path'] == '/calls' && r['method'] == 'POST'),
        isFalse);
    api.call = null;
    ended.complete(callJson(state: 'ended', video: true));
    await fallback;
    expect(controller.activeCall, isNull);
    expect(controller.lastCall!.isVideo, isTrue);
  });

  test('a delayed video token cannot join after local end', () async {
    api.call = callJson(state: 'connected', video: true);
    await controller.refresh();
    final token = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path.endsWith('/rtc-token') ? token.future : null;
    final joining = controller.joinConsentedVideo();
    await settleVideo();
    await controller.transition('end');
    token.complete({
      'appId': 'app',
      'channel': 'channel',
      'token': 'test-token',
      'uid': 1,
      'remoteUid': 2,
      'mediaType': 'video'
    });
    await joining;
    expect(media.videoJoinCount, 0);
    expect(media.cameraEnabled, isFalse);
    expect(controller.activeCall, isNull);
  });

  test(
      'new media fields preserve legacy audio but reject mislabeled video prices',
      () {
    expect(CallSession.fromJson(callJson()).isVideo, isFalse);
    expect(
        CallSession.fromJson(callJson(video: true)).rate.coinsPerMinute, 120);
    expect(() => CallSession.fromJson({...callJson(), 'mediaType': 'video'}),
        throwsFormatException);
    final missingRate = callJson(video: true)..remove('rate');
    expect(() => CallSession.fromJson(missingRate), throwsFormatException);
    expect(() => CallSession.fromJson({...callJson(), 'rate': 'invalid'}),
        throwsFormatException);
    final profile = {
      'id': 'listener',
      'displayName': 'Listener',
      'languages': ['en'],
      'available': true,
      'rate': rateJson(),
      'videoRate': rateJson()
    };
    expect(() => ListenerProfile.fromJson(profile), throwsFormatException);
    expect(
        () => ListenerProfile.fromJson({
              ...profile,
              'rate': rateJson(video: true),
              'videoRate': rateJson(video: true)
            }),
        throwsFormatException);
  });

  test(
      'End interrupts a delayed camera operation without later capture restart',
      () async {
    await controller.startCall(listener, video: true, cameraConsent: true);
    api.call = callJson(state: 'connected', video: true);
    await controller.refresh();
    await settleVideo();
    await controller.setCameraEnabled(false);
    final camera = Completer<void>();
    media.cameraDelay = camera.future;
    final enabling = controller.setCameraEnabled(true);
    await settleVideo();
    expect(controller.busy, isTrue);
    await controller.transition('end');
    expect(controller.activeCall, isNull);
    expect(media.cameraEnabled, isFalse);
    camera.complete();
    await enabling;
    expect(media.cameraEnabled, isFalse);
    expect(controller.activeCall, isNull);
  });

  test('failed video creation releases an existing preview', () async {
    await controller.prepareVideoPreview();
    api.interceptor = (method, path, body) async {
      if (method == 'POST' && path == '/calls') {
        throw const ApiFailure('LISTENER_BUSY', 'Busy');
      }
      return null;
    };
    await controller.startCall(listener, video: true, cameraConsent: true);
    expect(controller.errorCode, 'LISTENER_BUSY');
    expect(media.cameraEnabled, isFalse);
    expect(controller.activeCall, isNull);
  });

  test('an old video join completing after End cannot stop a later call camera',
      () async {
    await controller.startCall(listener, video: true, cameraConsent: true);
    final oldJoin = Completer<void>();
    media.videoJoinDelay = oldJoin.future;
    api.call = callJson(state: 'connecting', video: true);
    await controller.refresh();
    await settleVideo();
    await controller.transition('end');
    media.videoJoinDelay = null;
    api.call = {
      ...callJson(state: 'connecting', video: true),
      'id': 'next-call'
    };
    await controller.refresh();
    await controller.joinConsentedVideo();
    expect(media.cameraEnabled, isTrue);
    expect(controller.activeCall!.id, 'next-call');
    oldJoin.complete();
    await settleVideo();
    expect(media.cameraEnabled, isTrue);
    expect(controller.activeCall!.id, 'next-call');
  });
}
