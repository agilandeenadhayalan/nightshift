import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models.dart';
import 'session_store.dart';

class SavedDeletionReceiptChoice {
  const SavedDeletionReceiptChoice(this.index, this.serviceHost);
  final int index;
  final String serviceHost;
}

/// Keeps a deletion receipt separate from credentials, so a lost HTTP response
/// remains recoverable after the server revokes the requesting session.
class AccountPrivacy extends ChangeNotifier {
  AccountPrivacy(
      {required this.api,
      required this.store,
      required this.backendUrl,
      required this.currentUserId,
      required this.onDeleted,
      NightShiftApi? receiptApi})
      : _receiptApi = receiptApi ?? NightShiftApi();
  final NightShiftApi api, _receiptApi;
  final SessionStore store;
  final String backendUrl;
  final String? Function() currentUserId;
  final Future<void> Function(String) onDeleted;
  Json? notice, _receipt;
  List<Json> consents = [];
  String? errorCode;
  bool busy = false, loaded = false, _disposed = false, _unreadable = false;
  List<Json> _savedReceipts = [];
  String? _selectedToken, _receiptToken, _receiptOwner;
  Future<void>? _initialization;
  int _generation = 0;
  List<Json> get _visibleReceipts {
    final owner = currentUserId();
    return _savedReceipts
        .where((saved) => owner == null || saved['ownerId'] == owner)
        .toList();
  }

  Json? get _saved {
    final visible = _visibleReceipts;
    if (visible.isEmpty) return null;
    for (final saved in visible) {
      if (saved['receiptToken'] == _selectedToken) return saved;
    }
    // A newly signed-in owner starts with their current service's receipt.
    for (final saved in visible.reversed) {
      if (saved['origin'] == backendUrl) return saved;
    }
    return visible.last;
  }

  bool get hasSavedReceipt => _unreadable || _visibleReceipts.isNotEmpty;
  List<SavedDeletionReceiptChoice> get savedReceiptChoices => [
        for (final saved in _visibleReceipts)
          SavedDeletionReceiptChoice(_savedReceipts.indexOf(saved),
              Uri.tryParse(saved['origin'] as String)?.host ?? '')
      ];
  int? get selectedReceiptIndex =>
      _saved == null ? null : _savedReceipts.indexOf(_saved!);

  Json? get receipt {
    final owner = currentUserId();
    if (owner != null && owner != _receiptOwner) return null;
    return _receiptToken == _saved?['receiptToken'] ? _receipt : null;
  }

  set receipt(Json? value) {
    _receipt = value;
    _receiptToken = _saved?['receiptToken'];
    _receiptOwner = _saved?['ownerId'] as String? ?? currentUserId();
  }

  void selectReceipt(int index) {
    if (busy ||
        index < 0 ||
        index >= _savedReceipts.length ||
        !_visibleReceipts.contains(_savedReceipts[index])) {
      return;
    }
    _selectedToken = _savedReceipts[index]['receiptToken'] as String;
    _receipt = null;
    errorCode = null;
    _notify();
  }

  bool get canDelete => !busy && notice != null && currentUserId() != null;
  bool get _validOrigin {
    final uri = Uri.tryParse(backendUrl);
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty &&
        (uri.scheme == 'https' ||
            (!kReleaseMode &&
                uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '::1', '10.0.2.2']
                    .contains(uri.host)));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initialization ??= _readReceipts();

  Future<void> _readReceipts() async {
    try {
      final raw = await store.read('deletionReceipt');
      if (_disposed || raw == null) return;
      final value = jsonDecode(raw);
      final legacy = value is Json && value['version'] == null;
      final records = legacy
          ? [value]
          : value is Json && value['version'] == 2 && value['receipts'] is List
              ? value['receipts'] as List
              : throw const FormatException();
      final parsed = <Json>[];
      for (final record in records) {
        if (record is! Json ||
            record['receiptToken'] is! String ||
            !RegExp(r'^[0-9a-f]{64}$')
                .hasMatch(record['receiptToken'] as String) ||
            record['origin'] is! String ||
            (record['origin'] as String).isEmpty ||
            record['ownerId'] is! String ||
            (record['ownerId'] as String).isEmpty) {
          throw const FormatException();
        }
        parsed.add(Map<String, dynamic>.from(record));
      }
      _savedReceipts = parsed;
      if (legacy) {
        // Keep the existing secure-storage key; replace only after all original
        // capability fields are valid. A failed migration cannot erase them.
        await store.write(
            'deletionReceipt', jsonEncode({'version': 2, 'receipts': parsed}));
      }
      if (_disposed) return;
    } catch (_) {
      _unreadable = true;
      errorCode = 'DELETION_RECEIPT_UNREADABLE';
    } finally {
      _notify();
    }
  }

  void clearPrivateView() {
    _generation++;
    consents = [];
    notice = null;
    loaded = false;
    _notify();
  }

  Future<void> load() async {
    if (busy) return;
    final userId = currentUserId(), generation = ++_generation;
    if (userId == null) return;
    busy = true;
    errorCode = null;
    _notify();
    try {
      final result = await Future.wait([
        api.request('GET', '/me/consents'),
        api.request('GET', '/me/deletion-notice')
      ]);
      if (_disposed || generation != _generation || userId != currentUserId()) {
        return;
      }
      consents = (result[0]['items'] as List).map((x) => x as Json).toList();
      notice = result[1];
      loaded = true;
    } catch (e) {
      if (generation == _generation) {
        errorCode = e is ApiFailure ? e.code : 'INVALID_RESPONSE';
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> submit(
      {required bool confirmed, required String expectedOwnerId}) async {
    await initialize();
    if (_disposed) return;
    if (busy) return;
    if (!confirmed) {
      errorCode = 'DELETION_CONFIRMATION_REQUIRED';
      _notify();
      return;
    }
    final owner = currentUserId();
    if (owner != expectedOwnerId) {
      errorCode = 'PRIVATE_SESSION_CHANGED';
      _notify();
      return;
    }
    if (owner == null || notice == null) {
      errorCode = 'UNAUTHENTICATED';
      _notify();
      return;
    }
    if (!_validOrigin || api.baseUrl != backendUrl) {
      errorCode = 'DELETION_ORIGIN_CHANGED';
      _notify();
      return;
    }
    if (_unreadable) {
      errorCode = 'DELETION_RECEIPT_UNREADABLE';
      _notify();
      return;
    }
    busy = true;
    errorCode = null;
    _notify();
    final generation = _generation;
    try {
      Json? requestReceipt;
      for (final saved in _savedReceipts.reversed) {
        if (saved['ownerId'] == owner && saved['origin'] == backendUrl) {
          requestReceipt = saved;
          break;
        }
      }
      if (requestReceipt == null) {
        final random = Random.secure();
        final token = List.generate(32,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
        final candidate = <String, dynamic>{
          'receiptToken': token,
          'origin': backendUrl,
          'ownerId': owner
        };
        // Persistence must succeed before sending an irreversible command.
        final next = [..._savedReceipts, candidate];
        await store.write(
            'deletionReceipt', jsonEncode({'version': 2, 'receipts': next}));
        _savedReceipts = next;
        requestReceipt = candidate;
      }
      _selectedToken = requestReceipt['receiptToken'] as String;
      if (_disposed || owner != currentUserId() || api.baseUrl != backendUrl) {
        return;
      }
      final result = await api.privateRequest('POST', '/me/deletion-requests',
          origin: backendUrl,
          isCurrent: () =>
              !_disposed &&
              generation == _generation &&
              currentUserId() == owner,
          body: {
            'noticeVersion': notice!['noticeVersion'],
            'confirm': true,
            'receiptToken': requestReceipt['receiptToken'],
          });
      if (_disposed) return;
      _receipt = result;
      _receiptToken = requestReceipt['receiptToken'] as String;
      _receiptOwner = owner;
      await onDeleted(owner);
    } catch (e) {
      // A lost response or newly revoked session may follow a committed delete.
      // Recover its receipt instead of treating uncertainty as a safe retry.
      errorCode = e is ApiFailure && [400, 403, 409].contains(e.status)
          ? e.code
          : 'DELETION_STATUS_UNKNOWN';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> recoverStatus() async {
    await initialize();
    if (_disposed) return;
    if (busy) return;
    final saved = _saved;
    if (saved == null) {
      errorCode = 'DELETION_RECEIPT_UNREADABLE';
      _notify();
      return;
    }
    if (!_validOrigin || saved['origin'] != backendUrl) {
      errorCode = 'DELETION_ORIGIN_CHANGED';
      _notify();
      return;
    }
    busy = true;
    errorCode = null;
    _notify();
    try {
      // This transport never carries the current user's bearer token.
      _receiptApi.token = null;
      _receiptApi.baseUrl = saved['origin'] as String;
      final result = await _receiptApi.request(
          'POST', '/account-deletion/status',
          body: {'receiptToken': saved['receiptToken']});
      if (_disposed) return;
      _receipt = result;
      _receiptToken = saved['receiptToken'] as String;
      _receiptOwner = saved['ownerId'] as String;
      if (currentUserId() == saved['ownerId']) {
        await onDeleted(saved['ownerId'] as String);
      }
    } catch (e) {
      errorCode = e is ApiFailure ? e.code : 'DELETION_STATUS_UNKNOWN';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _receiptApi.close();
    super.dispose();
  }
}
