import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models.dart';
import 'review_sample_picker.dart';

/// Private drafts and sample bytes belong to one session and remain in memory.
class ListenerApplication extends ChangeNotifier {
  ListenerApplication(
      {required this.api,
      required this.currentUserId,
      ReviewSamplePicker? picker})
      : picker = picker ?? NativeReviewSamplePicker();
  final NightShiftApi api;
  final String? Function() currentUserId;
  final ReviewSamplePicker picker;
  Json? application;
  Json? reviewOutcome;
  String? reviewErrorCode;
  String bio = '';
  Set<String> topics = {}, languages = {'ta'};
  bool consent = false, busy = false, loaded = false, dirty = false;
  String? errorCode;
  bool uncertain = false;
  ReviewSample? sample;
  Json? _grant;
  Json? _pendingCreate;
  String? _owner, _origin;
  String _createKey = newId(), _submitKey = newId(), _withdrawKey = newId();
  String? _grantKey;
  int _generation = 0;
  bool _disposed = false;
  bool get editable =>
      application == null ||
      ['draft', 'needs_information'].contains(application!['state']);
  bool get canSubmit =>
      !busy &&
      !uncertain &&
      !dirty &&
      sample == null &&
      consent &&
      application != null &&
      editable &&
      application!['voiceSampleUploadId'] != null &&
      bio.trim().isNotEmpty &&
      topics.isNotEmpty;
  bool get canWithdraw =>
      !busy &&
      !uncertain &&
      application != null &&
      (['draft', 'needs_information', 'submitted']
              .contains(application!['state']) ||
          application!['voiceSampleConsent'] == true ||
          application!['voiceSampleUploadId'] != null);
  bool get canEdit =>
      loaded && !busy && editable && !uncertain && _pendingCreate == null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation) =>
      !_disposed &&
      generation == _generation &&
      _owner != null &&
      currentUserId() == _owner &&
      api.baseUrl == _origin;
  Future<Json> _request(int generation, String method, String path,
          {Json? body, String? key, ReviewSample? upload, String? token}) =>
      api.privateRequest(method, path,
          origin: _origin!,
          isCurrent: () => _current(generation),
          body: body,
          idempotencyKey: key,
          sample: upload?.bytes,
          uploadToken: token);
  void _accept(Json? result) {
    // A review may advance before a lost submit response is recovered. A new
    // needs-information revision also closes that earlier idempotency cycle.
    // An unchanged draft/review revision retains its key for an explicit retry.
    final nextReviewRound = result?['state'] == 'needs_information' &&
        ['state', 'updatedAt', 'submittedAt', 'decidedAt']
            .any((field) => application?[field] != result?[field]);
    if (result?['state'] == 'submitted' || nextReviewRound) {
      _submitKey = newId();
    }
    application = result;
    reviewOutcome = null;
    reviewErrorCode = null;
    if (result != null) _pendingCreate = null;
    bio = result?['bio'] as String? ?? '';
    topics = ((result?['topics'] as List?) ?? []).cast<String>().toSet();
    languages =
        ((result?['languages'] as List?) ?? ['ta']).cast<String>().toSet();
    consent = result?['voiceSampleConsent'] == true;
    if (!consent) {
      sample = null;
      _grant = null;
      _grantKey = null;
    }
    dirty = false;
    loaded = true;
  }

  void clearPrivateView({bool notify = true}) {
    _generation++;
    unawaited(picker.cancel());
    _owner = _origin = null;
    application = _grant = _pendingCreate = null;
    reviewOutcome = null;
    reviewErrorCode = null;
    sample = null;
    bio = '';
    topics = {};
    languages = {'ta'};
    consent = busy = loaded = dirty = uncertain = false;
    errorCode = _grantKey = null;
    _createKey = newId();
    _submitKey = newId();
    _withdrawKey = newId();
    if (notify) _notify();
  }

  Future<void> load() async {
    if (busy) return;
    final owner = currentUserId();
    if (owner == null) return;
    if (_owner != owner || _origin != api.baseUrl) {
      clearPrivateView(notify: false);
    }
    _owner = owner;
    _origin = api.baseUrl;
    final generation = _generation;
    busy = true;
    errorCode = null;
    reviewOutcome = null;
    reviewErrorCode = null;
    _notify();
    try {
      final result =
          await _request(generation, 'GET', '/me/listener-application');
      if (!_current(generation)) return;
      final found = result['application'] as Json?;
      if (found != null || _pendingCreate == null) _accept(found);
      loaded = true;
      uncertain = false;
      if ((_grant != null &&
              application?['voiceSampleUploadId'] == _grant!['uploadId']) ||
          !editable) {
        sample = null;
        _grant = null;
        _grantKey = null;
      }
      await _loadReview(generation);
    } catch (e) {
      if (_current(generation)) {
        errorCode = e is ApiFailure ? e.code : 'INVALID_RESPONSE';
      }
    } finally {
      if (_current(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _loadReview(int generation) async {
    if (!_current(generation) ||
        !['approved', 'rejected', 'needs_information']
            .contains(application?['state'])) {
      return;
    }
    final id = application!['id'], status = application!['state'];
    try {
      final result =
          await _request(generation, 'GET', '/me/listener-application/review');
      if (!_current(generation) ||
          application?['id'] != id ||
          application?['state'] != status) {
        return;
      }
      final review = result['review'];
      if (result['applicationId'] != id ||
          result['state'] != status ||
          (review != null &&
              (review is! Json ||
                  review['applicationId'] != id ||
                  review['outcome'] != status))) {
        reviewErrorCode = 'APPLICATION_REVIEW_CHANGED';
        return;
      }
      reviewOutcome = review as Json?;
    } catch (_) {
      if (_current(generation)) {
        reviewErrorCode = 'APPLICATION_REVIEW_UNAVAILABLE';
      }
    }
  }

  void edit(
      {String? newBio,
      Set<String>? newTopics,
      Set<String>? newLanguages,
      bool? newConsent}) {
    if (!canEdit) return;
    if (newBio != null) bio = newBio;
    if (newTopics != null) topics = {...newTopics};
    if (newLanguages != null) languages = {...newLanguages};
    if (newConsent != null) {
      consent = newConsent;
      if (!consent) {
        sample = null;
        _grant = null;
        _grantKey = null;
      }
    }
    dirty = true;
    errorCode = null;
    _notify();
  }

  Future<void> _mutate(Future<void> Function(int) action) async {
    if (busy || !loaded || _owner != currentUserId()) return;
    final generation = _generation;
    busy = true;
    errorCode = null;
    _notify();
    try {
      final previous = application;
      await action(generation);
      if (!identical(previous, application)) await _loadReview(generation);
    } catch (e) {
      if (!_current(generation)) return;
      final code = e is ApiFailure ? e.code : 'INVALID_RESPONSE';
      if (code == 'UPLOAD_EXPIRED') {
        _grant = null;
        _grantKey = newId();
      }
      uncertain = e is! ApiFailure ||
          (e.status == 0 &&
              !['PRIVATE_SESSION_CHANGED', 'PRIVATE_ORIGIN_REQUIRED']
                  .contains(e.code)) ||
          e.status == 401 ||
          e.status >= 500;
      if (!uncertain && application == null) _pendingCreate = null;
      errorCode = uncertain ? 'APPLICATION_OUTCOME_UNKNOWN' : code;
    } finally {
      if (_current(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> save() => _mutate((generation) async {
        if (!editable || uncertain) return;
        final body = _pendingCreate ??
            <String, dynamic>{
              'bio': bio.trim(),
              'topics': topics.toList(),
              'languages': languages.toList(),
              'voiceSampleConsent': consent,
              'consentVersion': 'listener-review-v1'
            };
        final id = application?['id'];
        if (id == null) _pendingCreate = body;
        final result = await _request(
            generation,
            id == null ? 'POST' : 'PUT',
            id == null
                ? '/listener-applications'
                : '/listener-applications/$id',
            body: body,
            key: id == null ? _createKey : null);
        if (_current(generation)) _accept(result);
      });
  Future<void> chooseSample() async {
    if (busy ||
        !loaded ||
        !editable ||
        !consent ||
        dirty ||
        uncertain ||
        application == null) {
      return;
    }
    final generation = _generation;
    busy = true;
    errorCode = null;
    _notify();
    try {
      final bytes = await picker.pick();
      if (!_current(generation) || bytes == null) return;
      sample = ReviewSample.validate(bytes);
      _grant = null;
      _grantKey = newId();
    } catch (e) {
      if (_current(generation)) {
        errorCode = e is ApiFailure ? e.code : 'SAMPLE_SELECTION_FAILED';
      }
    } finally {
      if (_current(generation)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> upload() => _mutate((generation) async {
        final selected = sample, id = application?['id'];
        if (selected == null ||
            id == null ||
            !consent ||
            dirty ||
            !editable ||
            uncertain) {
          return;
        }
        if (_grant != null &&
            DateTime.parse(_grant!['expiresAt'] as String)
                .isBefore(DateTime.now())) {
          _grant = null;
          _grantKey = newId();
        }
        final grant = _grant ??
            await _request(
                generation, 'POST', '/listener-applications/$id/uploads',
                key: _grantKey ??= newId(),
                body: {
                  'contentType': 'audio/wav',
                  'byteLength': selected.bytes.length,
                  'sha256': sha256.convert(selected.bytes).toString()
                });
        if (!_current(generation)) return;
        _grant = grant;
        final result = await _request(generation, 'PUT',
            '/listener-applications/$id/uploads/${_grant!['uploadId']}',
            upload: selected, token: _grant!['uploadToken'] as String);
        if (!_current(generation)) return;
        _accept(result);
        sample = null;
        _grant = null;
        _grantKey = null;
      });
  Future<void> submit() => _mutate((generation) async {
        // _mutate marks busy before entering; validate all other submission guards.
        if (uncertain ||
            sample != null ||
            dirty ||
            !consent ||
            !editable ||
            application == null ||
            application!['voiceSampleUploadId'] == null ||
            bio.trim().isEmpty ||
            topics.isEmpty) {
          return;
        }
        final result = await _request(generation, 'POST',
            '/listener-applications/${application!['id']}/submit',
            key: _submitKey);
        if (_current(generation)) {
          _accept(result);
          sample = null;
          _grant = null;
        }
      });
  Future<void> withdraw({required bool confirmed}) =>
      _mutate((generation) async {
        if (!confirmed || uncertain || application == null) return;
        final result = await _request(generation, 'POST',
            '/listener-applications/${application!['id']}/withdraw',
            key: _withdrawKey);
        if (_current(generation)) {
          _accept(result);
          sample = null;
          _grant = null;
        }
      });
  @override
  void dispose() {
    _disposed = true;
    clearPrivateView(notify: false);
    super.dispose();
  }
}
