// Real HTTP and raw WAV bytes through the generated SDK. Run only with the
// isolated synthetic-identity server from scripts/smoke-account-client.cjs.
// This is not evidence of Firebase/MSG91 delivery or identity verification.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:nightshift_api/api.dart' as sdk;

class _Failure implements Exception {
  const _Failure(this.code);
  final String code;
}

void _check(bool condition, String code) {
  if (!condition) throw _Failure(code);
}

String _key() => List.generate(32,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();

Uint8List _wave() {
  // Two seconds of synthetic silence: no real person's voice or metadata.
  final bytes = Uint8List(44 + 32000), data = ByteData(44 + 32000);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(4, bytes.length - 8, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  data.setUint32(40, 32000, Endian.little);
  for (final range in [
    [4, 8],
    [16, 36],
    [40, 44]
  ]) {
    bytes.setRange(range[0], range[1],
        data.buffer.asUint8List().sublist(range[0], range[1]));
  }
  return bytes;
}

class _Smoke {
  String step = 'configuration';
  sdk.ApiClient? client;

  Future<T> request<T>(
      String name, Future<T?> Function(Future<void>) operation) async {
    step = name;
    final abort = Completer<void>();
    final value = await operation(abort.future)
        .timeout(const Duration(seconds: 10), onTimeout: () {
      abort.complete();
      throw const _Failure('REQUEST_TIMEOUT');
    });
    if (value == null) throw const _Failure('EMPTY_RESPONSE');
    return value;
  }

  Future<void> run() async {
    final env = Platform.environment;
    final uri = Uri.tryParse(env['API_BASE_URL'] ?? '');
    _check(
        env['ACCOUNT_SMOKE_ISOLATED'] == 'true' &&
            uri != null &&
            uri.scheme == 'http' &&
            uri.host == '127.0.0.1' &&
            uri.userInfo.isEmpty &&
            uri.path.isEmpty &&
            uri.query.isEmpty &&
            uri.fragment.isEmpty,
        'ISOLATED_LOOPBACK_SERVER_REQUIRED');
    final bearer = sdk.HttpBearerAuth();
    client = sdk.ApiClient(basePath: uri.toString(), authentication: bearer);
    final api = sdk.DefaultApi(client);
    final session = await request(
        'exchange',
        (abort) => api.exchangePhoneSession(
            sdk.PhoneSessionRequest(
                idToken: env['ACCOUNT_SMOKE_TOKEN']!,
                deviceId: 'generated-account-smoke'),
            abortTrigger: abort));
    _check(
        session.needsOnboarding &&
            !session.user.listenerApproved &&
            session.testOnly.toJson() == true,
        'RESTRICTED_NEW_CUSTOMER_REQUIRED');
    bearer.accessToken = session.token;
    final initial = await request('restricted_onboarding',
        (abort) => api.getOnboarding(abortTrigger: abort));
    _check(initial.required_, 'ONBOARDING_REQUIRED');
    final completed = await request(
        'complete_onboarding',
        (abort) => api.completeOnboarding(
            sdk.CompleteOnboardingRequest.fromJson({
              'displayName': 'Synthetic Star',
              'avatarCode': 'star',
              'interfaceLanguage': 'ta',
              'languages': ['ta', 'en'],
              'dateOfBirth': '2000-01-01',
              'consentVersion': 'adult-onboarding-v1',
            })!,
            abortTrigger: abort));
    _check(
        !completed.required_ &&
            completed.profile.interfaceLanguage.toJson() == 'ta',
        'PROFILE_MISMATCH');
    final me = await request(
        'public_alias', (abort) => api.getMe(abortTrigger: abort));
    _check(me.displayName != 'Synthetic Star' && !me.listenerApproved,
        'UNREVIEWED_PROFILE_PUBLISHED');
    final input = sdk.ListenerApplicationInput.fromJson({
      'bio': 'Synthetic application for generated client verification.',
      'topics': ['everyday'],
      'languages': ['ta', 'en'],
      'voiceSampleConsent': true,
      'consentVersion': 'listener-review-v1',
    })!;
    final application = await request(
        'draft',
        (abort) =>
            api.createListenerApplication(_key(), input, abortTrigger: abort));
    final bytes = _wave();
    final upload = await request(
        'upload_lease',
        (abort) => api.createReviewUpload(
            application.id,
            _key(),
            sdk.ReviewUploadRequest.fromJson({
              'contentType': 'audio/wav',
              'byteLength': bytes.length,
              'sha256': sha256.convert(bytes).toString(),
            })!,
            abortTrigger: abort));
    final saved = await request(
        'raw_upload',
        (abort) => api.uploadListenerSample(application.id, upload.uploadId,
            upload.uploadToken, http.MultipartFile.fromBytes('body', bytes),
            abortTrigger: abort));
    _check(saved.voiceSampleUploadId == upload.uploadId, 'UPLOAD_NOT_BOUND');
    final downloaded = await request(
        'private_download',
        (abort) => api.readListenerSampleWithHttpInfo(
            application.id, upload.uploadId,
            abortTrigger: abort));
    _check(
        downloaded.statusCode == 200 &&
            sha256.convert(downloaded.bodyBytes).toString() ==
                sha256.convert(bytes).toString(),
        'PRIVATE_BYTES_MISMATCH');
    final submitKey = _key();
    final submitted = await request(
        'submit',
        (abort) => api.submitListenerApplication(application.id, submitKey,
            abortTrigger: abort));
    final duplicate = await request(
        'submit_retry',
        (abort) => api.submitListenerApplication(application.id, submitKey,
            abortTrigger: abort));
    _check(
        submitted.state.toJson() == 'submitted' && duplicate.id == submitted.id,
        'SUBMISSION_IDEMPOTENCY_FAILED');
    final consent = await request('consent_history',
        (abort) => api.getConsentHistory(abortTrigger: abort));
    _check(
        consent.items
            .any((event) => event.purpose == 'listener-review-material'),
        'REVIEW_CONSENT_MISSING');
    final notice = await request('deletion_notice',
        (abort) => api.getDeletionNotice(abortTrigger: abort));
    final token = _key();
    final deleted = await request(
        'delete_synthetic_account',
        (abort) => api.requestAccountDeletion(
            sdk.DeletionRequest.fromJson({
                  'noticeVersion': notice.noticeVersion.toJson(),
              'confirm': true,
              'receiptToken': token,
            })!,
            abortTrigger: abort));
    _check(
        deleted.personalDataDeletedAt != null &&
            deleted.holds.isEmpty &&
            deleted.retentionReviewRequired.toJson() == true,
        'PRIVATE_CLEANUP_INCOMPLETE');
    bearer.accessToken = '';
    final recovered = await request(
        'signed_out_receipt',
        (abort) => api.getDeletionReceipt(
            sdk.DeletionReceiptRequest(receiptToken: token),
            abortTrigger: abort));
    _check(
        recovered.requestId == deleted.requestId &&
            recovered.status.toJson() == 'review_required',
        'RECEIPT_RECOVERY_FAILED');
    stdout.writeln(jsonEncode({
      'accountClientSmoke': 'passed',
      'identity': 'synthetic',
      'realSms': false,
      'privateWavRoundTrip': true,
      'onboarding': true,
      'deletionReceiptRecovery': true
    }));
  }
}

Future<void> main() async {
  final smoke = _Smoke();
  try {
    await smoke.run();
  } catch (error) {
    stderr.writeln(jsonEncode({
      'accountClientSmoke': 'failed',
      'step': smoke.step,
      'code': error is _Failure ? error.code : 'REQUEST_OR_CONTRACT_FAILURE'
    }));
    exitCode = 1;
  } finally {
    smoke.client?.client.close();
  }
}
