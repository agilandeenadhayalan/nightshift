import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models.dart';
import 'directory_events.dart';

enum DirectoryKind { discover, favorites }

class DirectoryPage {
  List<String> ids = [];
  String? cursor, epoch;
  DateTime? expires, refreshed;
  bool loaded = false,
      loading = false,
      truncated = false,
      pendingRefresh = false;
  ApiFailure? error;
  bool invalidated = false;
  void Function()? pendingInstall;
  int revision = 0;
}

/// Order belongs to a server view epoch; live state is updated without sorting.
/// Every asynchronous result is fenced to the initiating account and filter.
class Discovery extends ChangeNotifier {
  Discovery(
      {required this.api,
      required this.identity,
      required this.enabled,
      this.events,
      DateTime Function()? now,
      bool startTimer = true})
      : now = now ?? DateTime.now {
    if (startTimer) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }
  final NightShiftApi api;
  final Object? Function() identity;
  final bool Function() enabled;
  final DirectoryEvents? events;
  final DateTime Function() now;
  final pages = {
    for (final kind in DirectoryKind.values) kind: DirectoryPage()
  };
  final Map<String, ListenerProfile> _cards = {};
  final Map<String, DateTime> _received = {}, _serverTimes = {};
  final Set<String> _removed = {}, _blocked = {};
  final Map<String, bool> _favoriteOverrides = {};
  final Set<String> favoriteBusy = {};
  final Map<String, bool> favoriteRetry = {};
  ApiFailure? favoriteError;
  String language = 'ta';
  bool availableOnly = false, connected = false, tracking = false;
  bool scrolling = false, atTop = true, _disposed = false;
  DirectoryKind? active;
  List<String> visibleIds = [], recentIds = [];
  Object? _owner;
  String? _origin, _token;
  int _generation = 0, _subscription = 0, _recentRequest = 0;
  bool _recentLoading = false;
  DateTime? _recentUpdated;
  Timer? _timer;
  DirectoryPage page(DirectoryKind kind) => pages[kind]!;
  ListenerProfile? lookup(String id) =>
      _removed.contains(id) ? null : _cards[id];
  bool removed(String id) => _removed.contains(id);
  bool observed(String id) => _cards.containsKey(id) || _removed.contains(id);
  bool fresh(String id) =>
      enabled() &&
      _received[id] != null &&
      now().difference(_received[id]!) < const Duration(seconds: 30);
  bool callable(String id) =>
      fresh(id) && lookup(id)?.available == true && lookup(id)?.busy == false;
  List<ListenerProfile> items(DirectoryKind kind) =>
      page(kind).ids.map(lookup).whereType<ListenerProfile>().toList();

  void reconcile() {
    if (_disposed) return;
    if (_owner != identity() || _origin != api.baseUrl) {
      reset();
      _owner = identity();
      _origin = api.baseUrl;
    }
    if (!enabled()) {
      _received.clear();
      if (_token != null) {
        events?.close();
        _token = null;
        connected = false;
        _received.clear();
      }
      return;
    }
    if (active != null && _token != api.token) _connect();
  }

  void reset({bool preserveLocalIntent = false}) {
    if (!preserveLocalIntent) {
      _blocked.clear();
      _favoriteOverrides.clear();
    }
    _generation++;
    _subscription++;
    _recentRequest++;
    events?.close();
    _token = null;
    connected = false;
    for (final kind in DirectoryKind.values) {
      pages[kind] = DirectoryPage();
    }
    _cards.clear();
    _received.clear();
    _serverTimes.clear();
    _removed.clear();
    favoriteBusy.clear();
    favoriteRetry.clear();
    favoriteError = null;
    visibleIds = [];
    recentIds = [];
    _recentLoading = false;
    _recentUpdated = null;
  }

  void activate(DirectoryKind? kind) {
    if (_disposed) return;
    reconcile();
    active = kind;
    if (kind != null) tracking = true;
    scrolling = false;
    atTop = true;
    visibleIds = [];
    _subscription++;
    if (kind == null) {
      events?.close();
      _token = null;
      connected = false;
      return;
    }
    _connect();
    if (!page(kind).loaded && !page(kind).loading) unawaited(load(kind));
  }

  void _connect() {
    if (!enabled() || api.token == null || active == null) return;
    if (_token == api.token) {
      _subscribe();
      return;
    }
    _token = api.token;
    final generation = _generation, owner = identity(), token = _token;
    final origin = api.baseUrl;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        owner == identity() &&
        origin == api.baseUrl &&
        token == api.token &&
        enabled();
    events?.connect(
        origin: origin,
        token: token!,
        onUpdate: (event) {
          if (current()) applyEvent(event);
        },
        onConnection: (value) {
          if (!current()) return;
          connected = value;
          if (value) {
            _subscribe();
          } else {
            for (final id in visibleIds) {
              _received.remove(id);
            }
          }
          _notify();
        });
  }

  Future<void> filter({String? language, bool? availableOnly}) async {
    final nextLanguage = language ?? this.language;
    final nextOnly = availableOnly ?? this.availableOnly;
    if (nextLanguage == this.language && nextOnly == this.availableOnly) return;
    this.language = nextLanguage;
    this.availableOnly = nextOnly;
    reset(preserveLocalIntent: true);
    _owner = identity();
    _origin = api.baseUrl;
    _notify();
    if (active != null) {
      _connect();
      await load(active!);
    }
  }

  void viewport(List<String> ids,
      {required bool scrolling, required bool atTop}) {
    this.scrolling = scrolling;
    this.atTop = atTop;
    final next = ids.toSet().take(40).toList();
    if (!listEquals(next, visibleIds)) {
      visibleIds = next;
      _subscribe();
    }
    final kind = active;
    if (!scrolling && atTop && kind != null && page(kind).pendingRefresh) {
      final install = page(kind).pendingInstall;
      if (install != null) {
        install();
        _notify();
      } else {
        unawaited(load(kind));
      }
    }
  }

  void _subscribe() {
    final kind = active;
    if (kind == null || !enabled()) return;
    final epoch = page(kind).epoch;
    final generation = _generation, subscription = ++_subscription;
    events?.subscribe({
      'viewEpoch': epoch,
      'language': language,
      'visibleIds': epoch == null ? <String>[] : visibleIds
    }, (ack) {
      if (_disposed ||
          generation != _generation ||
          subscription != _subscription) {
        return;
      }
      if (ack['ok'] != true) {
        connected = false;
        for (final id in visibleIds) {
          _received.remove(id);
        }
        page(kind).error = ApiFailure(
            ack['code'] is String ? ack['code'] as String : 'INVALID_RESPONSE',
            'Refresh availability.');
        _notify();
      }
    });
  }

  Future<void> load(DirectoryKind kind, {bool append = false}) async {
    reconcile();
    final target = page(kind);
    if (!enabled() || target.loading || (append && target.cursor == null)) {
      return;
    }
    final generation = _generation, owner = identity(), origin = api.baseUrl;
    final request = ++target.revision, cursor = append ? target.cursor : null;
    final expectedEpoch = append ? target.epoch : null;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        owner == identity() &&
        origin == api.baseUrl &&
        identical(target, page(kind)) &&
        request == target.revision;
    target.pendingInstall = null;
    target.loading = true;
    target.error = null;
    target.pendingRefresh = false;
    _notify();
    try {
      final query = Uri(queryParameters: {
        'language': language,
        'availableOnly': '$availableOnly',
        if (cursor != null) 'cursor': cursor
      }).query;
      final result = await api.request('GET',
          '/${kind == DirectoryKind.favorites ? 'favorites' : 'listeners'}?$query');
      if (!current()) return;
      final parsed = _parseItems(result['items']);
      final epoch = result['viewEpoch'] as String;
      final server = DateTime.parse(result['serverTime'] as String);
      final expiry = DateTime.parse(result['expiresAt'] as String);
      final next = result['nextCursor'] as String?;
      final truncated = result['truncated'] as bool;
      if (epoch.isEmpty ||
          (append && expectedEpoch != epoch) ||
          next == cursor && next != null ||
          expiry.isBefore(server) ||
          parsed.length > 20) {
        throw const FormatException('Invalid directory view');
      }
      final receivedAt = now();
      final localExpiry = receivedAt.add(expiry.difference(server));
      void install() {
        if (!current()) return;
        if (!now().isBefore(localExpiry)) {
          target.pendingInstall = null;
          target.pendingRefresh = false;
          target.invalidated = true;
          target.cursor = null;
          target.error = const ApiFailure(
              'DIRECTORY_VIEW_EXPIRED', 'Refresh availability.');
          for (final card in parsed) {
            _received.remove(card.id);
          }
          return;
        }
        target.invalidated = false;
        target.pendingInstall = null;
        target.pendingRefresh = false;
        final ids = <String>{if (append) ...target.ids};
        for (final card in parsed) {
          if (!_blocked.contains(card.id) &&
              (kind != DirectoryKind.favorites ||
                  _favoriteOverrides[card.id] != false)) {
            ids.add(card.id);
          }
        }
        target.ids = ids.toList();
        target.epoch = epoch;
        target.cursor = next;
        target.truncated = truncated;
        target.expires = localExpiry;
        target.refreshed = now();
        target.loaded = true;
        _accept(parsed, const [], server, receivedAt: receivedAt);
        if (active == kind) {
          visibleIds = visibleIds.where(target.ids.contains).toList();
          _subscribe();
        }
      }

      if (!append && target.loaded && active == kind && (scrolling || !atTop)) {
        target.pendingInstall = install;
        target.pendingRefresh = true;
        _accept(parsed, const [], server);
      } else {
        install();
      }
    } catch (e) {
      if (!current()) return;
      target.error = e is ApiFailure
          ? e
          : const ApiFailure(
              'INVALID_RESPONSE', 'Could not read availability.');
      if (['DIRECTORY_VIEW_EXPIRED', 'DIRECTORY_VIEW_NOT_FOUND']
          .contains(target.error!.code)) {
        target.invalidated = true;
        target.cursor = null;
        for (final id in target.ids) {
          _received.remove(id);
        }
      }
    } finally {
      if (current()) {
        target.loading = false;
        _notify();
      }
    }
  }

  List<ListenerProfile> _parseItems(dynamic raw) {
    for (final value in raw as List) {
      if (value is! Map ||
          value['available'] is! bool ||
          value['online'] is! bool ||
          value['busy'] is! bool ||
          value['favorite'] is! bool ||
          value['available'] !=
              (value['online'] == true && value['busy'] == false)) {
        throw const FormatException('Invalid live availability');
      }
    }
    final parsed = raw
        .map((v) =>
            ListenerProfile.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    if (parsed.any((v) => !v.languages.contains(language)) ||
        parsed.map((v) => v.id).toSet().length != parsed.length) {
      throw const FormatException('Invalid directory members');
    }
    return parsed;
  }

  void _validateDelta(List<ListenerProfile> cards, List<String> removed) {
    if (cards.length + removed.length > 40 ||
        removed.toSet().length != removed.length ||
        cards.any((v) => removed.contains(v.id))) {
      throw const FormatException('Invalid status members');
    }
  }

  void _accept(
      List<ListenerProfile> cards, List<String> removed, DateTime server,
      {DateTime? receivedAt}) {
    for (final id in removed) {
      if (_serverTimes[id]?.isAfter(server) == true) continue;
      _serverTimes[id] = server;
      _removed.add(id);
      _received.remove(id);
    }
    for (final card in cards) {
      if (_serverTimes[card.id]?.isAfter(server) == true) continue;
      _serverTimes[card.id] = server;
      _removed.remove(card.id);
      if (_blocked.contains(card.id)) {
        _removed.add(card.id);
        _received.remove(card.id);
        continue;
      }
      _cards[card.id] = _favoriteOverrides.containsKey(card.id)
          ? card.withFavorite(_favoriteOverrides[card.id]!)
          : card;
      if (enabled()) _received[card.id] = receivedAt ?? now();
    }
  }

  void applyEvent(Json event) {
    final kind = active;
    if (kind != null &&
        event['viewEpoch'] == page(kind).epoch &&
        event['invalidated'] == true) {
      page(kind).invalidated = true;
      page(kind).error = ApiFailure(
          event['code'] is String
              ? event['code'] as String
              : 'INVALID_RESPONSE',
          'Refresh availability.');
      for (final id in page(kind).ids) {
        _received.remove(id);
      }
      _notify();
      return;
    }
    if (kind == null ||
        page(kind).invalidated ||
        event['viewEpoch'] != page(kind).epoch ||
        event['language'] != language ||
        !enabled()) {
      return;
    }
    try {
      final cards = _parseItems(event['items']);
      final removed = List<String>.from(event['removedIds'] as List);
      _validateDelta(cards, removed);
      final allowed = visibleIds.toSet();
      final server = DateTime.parse(event['serverTime'] as String);
      if (cards.any((v) => !allowed.contains(v.id)) ||
          removed.any((v) => !allowed.contains(v))) {
        return;
      }
      _accept(cards, removed, server);
      _notify();
    } catch (_) {
      for (final id in visibleIds) {
        _received.remove(id);
      }
      connected = false;
      _notify();
    }
  }

  void watchRecents(List<String> ids) {
    if (_disposed) return;
    reconcile();
    final next = ids.toSet().take(40).toList();
    if (listEquals(next, recentIds)) return;
    if (next.isNotEmpty) tracking = true;
    recentIds = next;
    _recentRequest++;
    _recentLoading = false;
    unawaited(refreshRecents());
  }

  Future<void> refreshRecents() async {
    reconcile();
    if (!enabled() || recentIds.isEmpty || _recentLoading) return;
    final ids = List<String>.of(recentIds), generation = _generation;
    final request = ++_recentRequest, owner = identity(), origin = api.baseUrl;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        request == _recentRequest &&
        owner == identity() &&
        origin == api.baseUrl;
    _recentLoading = true;
    try {
      final result = await api.request('POST', '/listeners/status',
          body: {'language': language, 'listenerIds': ids});
      if (!current()) return;
      final cards = _parseItems(result['items']);
      final removed = List<String>.from(result['removedIds'] as List);
      _validateDelta(cards, removed);
      if (cards.any((v) => !ids.contains(v.id)) ||
          removed.any((v) => !ids.contains(v))) {
        throw const FormatException('Invalid recent members');
      }
      _accept(cards, removed, DateTime.parse(result['serverTime'] as String));
      _recentUpdated = now();
    } catch (_) {
      if (current()) {
        for (final id in ids) {
          _received.remove(id);
        }
      }
    } finally {
      if (current()) {
        _recentLoading = false;
        _notify();
      }
    }
  }

  Future<void> favorite(String id, bool value) async {
    reconcile();
    if (!enabled() || favoriteBusy.contains(id)) return;
    final generation = _generation, owner = identity(), origin = api.baseUrl;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        owner == identity() &&
        origin == api.baseUrl;
    favoriteBusy.add(id);
    favoriteError = null;
    favoriteRetry[id] = value;
    _notify();
    try {
      final result = await api.request(
          value ? 'PUT' : 'DELETE', '/favorites/${Uri.encodeComponent(id)}',
          body: {});
      if (!current()) return;
      if (result['favorite'] != value) {
        throw const FormatException('Invalid favorite');
      }
      _favoriteOverrides[id] = value;
      final card = lookup(id);
      if (card != null) _cards[id] = card.withFavorite(value);
      if (!value) {
        page(DirectoryKind.favorites).ids.remove(id);
      } else {
        page(DirectoryKind.favorites).pendingRefresh = true;
      }
      favoriteRetry.remove(id);
    } catch (e) {
      if (current()) {
        favoriteError = e is ApiFailure
            ? e
            : const ApiFailure(
                'INVALID_RESPONSE', 'Favorite could not be confirmed.');
      }
    } finally {
      if (current()) {
        favoriteBusy.remove(id);
        _notify();
      }
    }
  }

  void forget(String id) {
    _blocked.add(id);
    _removed.add(id);
    _received.remove(id);
    for (final value in pages.values) {
      value.ids.remove(id);
    }
    _notify();
  }

  void tick() {
    reconcile();
    final kind = active;
    if (!enabled()) return;
    if (kind != null) {
      final target = page(kind);
      if (target.expires != null && !now().isBefore(target.expires!)) {
        target.invalidated = true;
        target.error =
            const ApiFailure('DIRECTORY_VIEW_EXPIRED', 'Refresh availability.');
        target.cursor = null;
        for (final id in target.ids) {
          _received.remove(id);
        }
      } else if (!target.invalidated &&
          target.pendingInstall == null &&
          target.loaded &&
          target.refreshed != null &&
          now().difference(target.refreshed!) >= const Duration(seconds: 20)) {
        target.pendingRefresh = true;
        if (!scrolling && atTop && !target.loading) unawaited(load(kind));
      }
    }
    if (recentIds.isNotEmpty &&
        (_recentUpdated == null ||
            now().difference(_recentUpdated!) >= const Duration(seconds: 15))) {
      unawaited(refreshRecents());
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    events?.close();
    super.dispose();
  }
}
