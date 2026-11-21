import 'api.dart';
import 'models.dart';

/// An owner-scoped command. A transport failure never changes its key/body.
class CallStopIntent {
  CallStopIntent._(this.ownerId, this.origin, this.callId, this.action,
      this.version, this.key);
  factory CallStopIntent.forCall(
          String ownerId, String origin, CallSession call) =>
      CallStopIntent._(
          ownerId,
          origin,
          call.id,
          call.ringing
              ? (call.listenerId == ownerId ? 'decline' : 'cancel')
              : 'end',
          call.version,
          newId());
  factory CallStopIntent.fromJson(Json value) {
    if (value['schemaVersion'] != 1 ||
        !['ownerId', 'origin', 'callId', 'action', 'key'].every((key) =>
            value[key] is String &&
            (value[key] as String).isNotEmpty &&
            (value[key] as String).length <= 2048) ||
        !['end', 'cancel', 'decline'].contains(value['action']) ||
        value['version'] is! int ||
        (value['version'] as int) < 1) {
      throw const FormatException('Invalid call stop intent');
    }
    return CallStopIntent._(
        value['ownerId'] as String,
        value['origin'] as String,
        value['callId'] as String,
        value['action'] as String,
        value['version'] as int,
        value['key'] as String);
  }
  final String ownerId, origin, callId, action, key;
  final int version;
  String get path => '/calls/$callId/$action';
  Json get body => {'expectedVersion': version};
  Json toJson() => {
        'schemaVersion': 1,
        'ownerId': ownerId,
        'origin': origin,
        'callId': callId,
        'action': action,
        'version': version,
        'key': key
      };
}
