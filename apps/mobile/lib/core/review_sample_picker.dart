import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'api.dart';

abstract class ReviewSamplePicker {
  Future<Uint8List?> pick();
  Future<void> cancel() async {}
}

class NativeReviewSamplePicker extends ReviewSamplePicker {
  static const _channel = MethodChannel('nightshift/private_review_sample');
  int _sequence = 0;
  int? _pending;
  @override
  Future<void> cancel() async {
    if (_pending == null) return;
    _pending = null;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException {
      // Cancellation is best effort; the owning generation also rejects results.
    } on MissingPluginException {
      // Other platforms have no native selection in progress.
    }
  }

  @override
  Future<Uint8List?> pick() async {
    final request = ++_sequence;
    _pending = request;
    try {
      // Android reads the selected ContentResolver stream with a strict bound.
      // It never copies the document to app cache or returns a filename/URI.
      final bytes = await _channel.invokeMethod<Uint8List>('chooseWav');
      if (_pending != request) return null;
      if (bytes != null && bytes.length > ReviewSample.maxBytes) {
        throw const ApiFailure('UPLOAD_LIMIT', 'Sample is too large.');
      }
      return bytes;
    } on PlatformException catch (error) {
      throw ApiFailure(
          error.code == 'UPLOAD_LIMIT'
              ? 'UPLOAD_LIMIT'
              : 'SAMPLE_SELECTION_FAILED',
          'The sample could not be selected.');
    } on MissingPluginException {
      throw const ApiFailure(
          'SAMPLE_SELECTION_FAILED', 'The sample could not be selected.');
    } finally {
      if (_pending == request) _pending = null;
    }
  }
}

class ReviewSample {
  ReviewSample._(this.bytes, this.seconds);
  static const maxBytes = 2097152;
  final Uint8List bytes;
  final double seconds;
  factory ReviewSample.validate(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const ApiFailure('UPLOAD_LIMIT', 'Sample is too large.');
    }
    bool label(int at, String value) =>
        String.fromCharCodes(bytes.sublist(at, at + value.length)) == value;
    if (bytes.length < 44) {
      throw const ApiFailure('INVALID_WAV', 'Unsupported sample.');
    }
    final data = ByteData.sublistView(bytes);
    final channels = data.getUint16(22, Endian.little);
    final rate = data.getUint32(24, Endian.little);
    final length = data.getUint32(40, Endian.little);
    if (!label(0, 'RIFF') ||
        !label(8, 'WAVE') ||
        !label(12, 'fmt ') ||
        !label(36, 'data') ||
        data.getUint32(4, Endian.little) != bytes.length - 8 ||
        data.getUint32(16, Endian.little) != 16 ||
        data.getUint16(20, Endian.little) != 1 ||
        ![1, 2].contains(channels) ||
        rate < 8000 ||
        rate > 48000 ||
        data.getUint16(34, Endian.little) != 16 ||
        data.getUint16(32, Endian.little) != channels * 2 ||
        data.getUint32(28, Endian.little) != rate * channels * 2 ||
        length != bytes.length - 44 ||
        length % (channels * 2) != 0) {
      throw const ApiFailure('INVALID_WAV', 'Unsupported sample.');
    }
    final seconds = length / (rate * channels * 2);
    if (seconds < 2 || seconds > 60) {
      throw const ApiFailure('INVALID_WAV', 'Unsupported sample duration.');
    }
    return ReviewSample._(bytes, seconds);
  }
  @override
  String toString() => 'ReviewSample[private]';
}
