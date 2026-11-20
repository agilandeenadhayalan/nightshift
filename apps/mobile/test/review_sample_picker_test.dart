import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/review_sample_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nightshift/private_review_sample');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('cancel signals native pending selection and ignores its late bytes',
      () async {
    final selected = Completer<Uint8List?>();
    var cancels = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'cancel') {
        cancels++;
        return null;
      }
      return selected.future;
    });
    final picker = NativeReviewSamplePicker();
    final pending = picker.pick();
    await picker.cancel();
    selected.complete(Uint8List.fromList([1, 2, 3]));
    expect(await pending, isNull);
    expect(cancels, 1);
    await picker.cancel();
    expect(cancels, 1);
  });
  test(
      'native picker sends no private arguments and returns bytes or cancellation',
      () async {
    var cancelled = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'chooseWav');
      expect(call.arguments, isNull);
      return cancelled ? null : Uint8List.fromList([1, 2, 3]);
    });
    final picker = NativeReviewSamplePicker();
    expect(await picker.pick(), [1, 2, 3]);
    cancelled = true;
    expect(await picker.pick(), isNull);
  });
  test('native and Dart size limits use the safe upload limit code', () async {
    var native = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (native) {
        throw PlatformException(code: 'UPLOAD_LIMIT', message: 'private-uri');
      }
      return Uint8List(ReviewSample.maxBytes + 1);
    });
    final picker = NativeReviewSamplePicker();
    for (final value in [true, false]) {
      native = value;
      await expectLater(
          picker.pick(),
          throwsA(
              isA<ApiFailure>().having((e) => e.code, 'code', 'UPLOAD_LIMIT')));
    }
  });
  test('provider failure and unsupported platform never reveal details',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
          code: 'PROVIDER_DENIED',
          message: '/private/filename.wav',
          details: 'content://private');
    });
    await expectLater(
        NativeReviewSamplePicker().pick(),
        throwsA(isA<ApiFailure>().having((e) => e.message, 'safe message',
            'The sample could not be selected.')));
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
        NativeReviewSamplePicker().pick(),
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'SAMPLE_SELECTION_FAILED')));
  });
}
