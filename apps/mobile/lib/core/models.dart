typedef Json = Map<String, dynamic>;

int number(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

enum AppMode { customer, listener }

class UserProfile {
  const UserProfile(
      {required this.id,
      required this.name,
      required this.mode,
      required this.listenerApproved,
      required this.online,
      required this.languages});
  factory UserProfile.fromJson(Json json) => UserProfile(
        id: json['id'] as String,
        name: json['displayName'] as String,
        mode: json['mode'] == 'listener' ? AppMode.listener : AppMode.customer,
        listenerApproved: json['listenerApproved'] == true,
        online: json['online'] == true,
        languages: List<String>.from(json['languages'] ?? ['ta', 'en']),
      );
  final String id, name;
  final AppMode mode;
  final bool listenerApproved, online;
  final List<String> languages;
}

class ListenerProfile {
  const ListenerProfile(
      {required this.id,
      required this.name,
      required this.languages,
      required this.available});
  factory ListenerProfile.fromJson(Json json) => ListenerProfile(
        id: json['id'] as String,
        name: json['displayName'] as String,
        languages: List<String>.from(json['languages'] ?? []),
        available: json['available'] == true ||
            json['status'] == 'available' ||
            (!json.containsKey('available') &&
                json['online'] == true &&
                json['busy'] != true),
      );
  final String id, name;
  final List<String> languages;
  final bool available;
}

class CallSession {
  const CallSession(
      {required this.id,
      required this.customerId,
      required this.listenerId,
      required this.customerName,
      required this.listenerName,
      required this.state,
      required this.version,
      required this.connectedMs,
      required this.chargeMicrocredits,
      required this.earningPaise,
      required this.createdAt,
      this.endedAt,
      this.reason,
      required this.maxDurationSeconds});
  factory CallSession.fromJson(Json json) => CallSession(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        listenerId: json['listenerId'] as String,
        customerName: json['customerName'] as String? ?? 'Customer',
        listenerName: json['listenerName'] as String? ?? 'Listener',
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
      );
  final String id, customerId, listenerId, customerName, listenerName, state;
  final String? reason;
  final int version,
      connectedMs,
      chargeMicrocredits,
      earningPaise,
      maxDurationSeconds;
  final DateTime createdAt;
  final DateTime? endedAt;
  bool get ended => state == 'ended';
  bool get ringing => state == 'ringing';
  String otherName(String userId) =>
      customerId == userId ? listenerName : customerName;
}

class RtcCredentials {
  RtcCredentials.fromJson(Json json)
      : appId = json['appId'] as String,
        channel = json['channel'] as String,
        token = json['token'] as String,
        uid = number(json['uid']),
        remoteUid = number(json['remoteUid']);
  final String appId, channel, token;
  final int uid, remoteUid;
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
