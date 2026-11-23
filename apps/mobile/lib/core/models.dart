typedef Json = Map<String, dynamic>;

int number(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

enum AppMode { customer, listener }

String? _avatarCode(Json json, [String field = 'avatarCode']) {
  if (!json.containsKey(field)) return null;
  final value = json[field];
  if (value is String &&
      (const ['moon', 'star', 'leaf', 'wave'].contains(value) ||
          RegExp(r'^(male|female)_(0[1-9]|[12][0-9]|30)$').hasMatch(value))) {
    return value;
  }
  throw const FormatException('Unsupported avatar code');
}

/// A server-owned test quote. The UI displays these values; it never settles calls.
class CallRate {
  const CallRate({
    this.id = 'test-audio-v1',
    this.coinsPerMinute = 60,
    this.microcreditsPerCoin = 60000,
    this.microcreditsPerSecond = 60000,
    this.freeThroughSeconds = 40,
    this.minimumChargedSeconds = 60,
    this.listenerPaisePerHour = 50000,
  });
  const CallRate.audio() : this();
  factory CallRate.fromJson(Json json) {
    int value(String key, {bool zeroAllowed = false}) {
      final result = json[key];
      if (result is! int || result < (zeroAllowed ? 0 : 1)) {
        throw FormatException('Invalid rate field: $key');
      }
      return result;
    }

    final id = json['id'];
    if (id != 'test-audio-v1' && id != 'test-video-v1') {
      throw const FormatException('Unsupported test rate');
    }
    return CallRate(
      id: id as String,
      coinsPerMinute: value('coinsPerMinute'),
      microcreditsPerCoin: value('microcreditsPerCoin'),
      microcreditsPerSecond: value('microcreditsPerSecond'),
      freeThroughSeconds: value('freeThroughSeconds', zeroAllowed: true),
      minimumChargedSeconds: value('minimumChargedSeconds'),
      listenerPaisePerHour: value('listenerPaisePerHour', zeroAllowed: true),
    );
  }
  final String id;
  final int coinsPerMinute,
      microcreditsPerCoin,
      microcreditsPerSecond,
      freeThroughSeconds,
      minimumChargedSeconds,
      listenerPaisePerHour;
}

String _callMediaType(Json json) {
  final mediaType = json['mediaType'] ?? 'audio';
  if (mediaType != 'audio' && mediaType != 'video') {
    throw const FormatException('Unsupported call media');
  }
  return mediaType as String;
}

CallRate _callRate(Json json) {
  final mediaType = _callMediaType(json);
  final raw = json['rate'];
  if (raw != null && raw is! Json) {
    throw const FormatException('Invalid call rate');
  }
  final rate = raw is Json ? CallRate.fromJson(raw) : const CallRate.audio();
  if (rate.id != 'test-$mediaType-v1') {
    throw const FormatException('Call media and rate disagree');
  }
  return rate;
}

class UserProfile {
  const UserProfile(
      {required this.id,
      required this.name,
      required this.mode,
      required this.listenerApproved,
      required this.online,
      this.avatarCode,
      required this.languages});
  factory UserProfile.fromJson(Json json) => UserProfile(
        id: json['id'] as String,
        name: json['displayName'] as String,
        avatarCode: _avatarCode(json),
        mode: json['mode'] == 'listener' ? AppMode.listener : AppMode.customer,
        listenerApproved: json['listenerApproved'] == true,
        online: json['online'] == true,
        languages: List<String>.from(json['languages'] ?? ['ta', 'en']),
      );
  final String id, name;
  final String? avatarCode;
  final AppMode mode;
  final bool listenerApproved, online;
  final List<String> languages;
}

class ListenerProfile {
  const ListenerProfile(
      {required this.id,
      required this.name,
      required this.languages,
      required this.available,
      this.busy = false,
      this.favorite = false,
      this.reachability = 'foreground',
      this.avatarCode,
      this.rate = const CallRate.audio(),
      this.videoRate});
  factory ListenerProfile.fromJson(Json json) => ListenerProfile(
        id: json['id'] as String,
        name: json['displayName'] as String,
        avatarCode: _avatarCode(json),
        languages: List<String>.from(json['languages'] ?? []),
        available: json['busy'] != true &&
            (json.containsKey('available')
                ? json['available'] == true
                : json['status'] == 'available' || json['online'] == true),
        busy: json['busy'] == true,
        favorite: json['favorite'] == true,
        reachability: json['reachability'] as String? ??
            (json['online'] == true ? 'foreground' : 'offline'),
        rate: _callRate({'rate': json['rate']}),
        videoRate: json['videoRate'] == null
            ? null
            : _callRate({'mediaType': 'video', 'rate': json['videoRate']}),
      );
  final String id, name;
  final List<String> languages;
  final bool available, busy, favorite;
  final String reachability;
  final String? avatarCode;
  ListenerProfile withFavorite(bool value) => ListenerProfile(
      id: id,
      name: name,
      avatarCode: avatarCode,
      languages: languages,
      available: available,
      busy: busy,
      favorite: value,
      reachability: reachability,
      rate: rate,
      videoRate: videoRate);
  final CallRate rate;
  final CallRate? videoRate;
}

enum CallDurationLimitReason { testCreditBalance, testDurationCap }

CallDurationLimitReason? _durationLimitReason(Json json) {
  if (!json.containsKey('durationLimitReason')) return null;
  return switch (json['durationLimitReason']) {
    'test_credit_balance' => CallDurationLimitReason.testCreditBalance,
    'test_duration_cap' => CallDurationLimitReason.testDurationCap,
    _ => throw const FormatException('Unsupported duration limit reason'),
  };
}

bool _validAllowance(Object? capSeconds, Object? connectedMs) =>
    capSeconds is int &&
    capSeconds > 0 &&
    capSeconds <= 9007199254740 &&
    connectedMs is int &&
    connectedMs >= 0 &&
    connectedMs <= 9007199254740991;

class CallSession {
  const CallSession(
      {required this.id,
      required this.customerId,
      required this.listenerId,
      required this.customerName,
      required this.listenerName,
      this.customerAvatarCode,
      this.listenerAvatarCode,
      required this.state,
      required this.version,
      required this.connectedMs,
      required this.chargeMicrocredits,
      required this.earningPaise,
      required this.createdAt,
      this.endedAt,
      this.reason,
      this.durationLimitReason,
      this.mediaType = 'audio',
      this.rate = const CallRate.audio(),
      bool allowanceFieldsValid = true,
      required this.maxDurationSeconds})
      : _allowanceFieldsValid = allowanceFieldsValid;
  factory CallSession.fromJson(Json json) => CallSession(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        listenerId: json['listenerId'] as String,
        customerName: json['customerName'] as String? ?? 'Customer',
        listenerName: json['listenerName'] as String? ?? 'Listener',
        customerAvatarCode: _avatarCode(json, 'customerAvatarCode'),
        listenerAvatarCode: _avatarCode(json, 'listenerAvatarCode'),
        state: json['state'] as String,
        version: number(json['version']),
        connectedMs: number(json['connectedMs']),
        chargeMicrocredits: number(json['chargeMicrocredits']),
        earningPaise: number(json['earningPaise']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        endedAt: json['endedAt'] == null
            ? null
            : DateTime.parse(json['endedAt'] as String),
        reason: json['reason'] as String?,
        maxDurationSeconds: number(json['maxDurationSeconds']),
        allowanceFieldsValid:
            _validAllowance(json['maxDurationSeconds'], json['connectedMs']),
        durationLimitReason: _durationLimitReason(json),
        mediaType: _callMediaType(json),
        rate: _callRate(json),
      );
  final String id, customerId, listenerId, customerName, listenerName, state;
  final String? customerAvatarCode, listenerAvatarCode;
  final String? reason;
  final CallDurationLimitReason? durationLimitReason;
  final bool _allowanceFieldsValid;
  final String mediaType;
  final CallRate rate;
  final int version,
      connectedMs,
      chargeMicrocredits,
      earningPaise,
      maxDurationSeconds;
  final DateTime createdAt;
  final DateTime? endedAt;
  bool get ended => state == 'ended';
  bool get ringing => state == 'ringing';
  bool get isVideo => mediaType == 'video';

  /// Confirmed connected-time allocation, independent of minimum charges and
  /// the client's clock. Invalid wire fields must not become a zero warning.
  int? get remainingConnectedMs {
    if (!_allowanceFieldsValid ||
        !_validAllowance(maxDurationSeconds, connectedMs)) {
      return null;
    }
    final remaining = maxDurationSeconds * 1000 - connectedMs;
    return remaining > 0 ? remaining : 0;
  }

  String otherName(String userId) =>
      customerId == userId ? listenerName : customerName;
}

class RtcCredentials {
  RtcCredentials.fromJson(Json json)
      : appId = json['appId'] as String,
        channel = json['channel'] as String,
        token = json['token'] as String,
        uid = number(json['uid']),
        remoteUid = number(json['remoteUid']),
        mediaType = _callMediaType(json);
  final String appId, channel, token;
  final int uid, remoteUid;
  final String mediaType;
  // Deliberately no toString: bearer RTC credentials must never appear in diagnostics.
}

String creditAmount(int microcredits) {
  final coins = microcredits / 60000;
  return coins == coins.roundToDouble()
      ? coins.toStringAsFixed(0)
      : coins.toStringAsFixed(2);
}

String durationLabel(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String historyDay(DateTime timestamp, DateTime now) {
  final local = timestamp.toLocal(), today = now.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  if (day == DateTime(today.year, today.month, today.day)) return 'today';
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return 'yesterday';
  }
  return 'older';
}
