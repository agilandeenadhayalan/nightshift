//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class Snapshot {
  /// Returns a new [Snapshot] instance.
  Snapshot({
    required this.user,
    required this.activeCall,
    this.listeners = const [],
    required this.wallet,
    required this.serverTime,
  });

  User user;

  Call? activeCall;

  List<Listener> listeners;

  Wallet wallet;

  DateTime serverTime;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Snapshot &&
    other.user == user &&
    other.activeCall == activeCall &&
    _deepEquality.equals(other.listeners, listeners) &&
    other.wallet == wallet &&
    other.serverTime == serverTime;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (user.hashCode) +
    (activeCall == null ? 0 : activeCall!.hashCode) +
    (listeners.hashCode) +
    (wallet.hashCode) +
    (serverTime.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'Snapshot[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'user'] = this.user;
    if (this.activeCall != null) {
      json[r'activeCall'] = this.activeCall;
    } else {
      json[r'activeCall'] = null;
    }
      json[r'listeners'] = this.listeners;
      json[r'wallet'] = this.wallet;
      json[r'serverTime'] = this.serverTime.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [Snapshot] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Snapshot? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid Snapshot object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'user')) {
        throw const FormatException('Missing Snapshot.user');
      }
      if (json[r'user'] == null) {
        throw const FormatException('Null Snapshot.user');
      }
      if (!json.containsKey(r'activeCall')) {
        throw const FormatException('Missing Snapshot.activeCall');
      }
      if (!json.containsKey(r'listeners')) {
        throw const FormatException('Missing Snapshot.listeners');
      }
      if (json[r'listeners'] == null) {
        throw const FormatException('Null Snapshot.listeners');
      }
      if (json[r'listeners'] != null && json[r'listeners'] is! List) {
        throw const FormatException('Invalid Snapshot.listeners');
      }
      if (!json.containsKey(r'wallet')) {
        throw const FormatException('Missing Snapshot.wallet');
      }
      if (json[r'wallet'] == null) {
        throw const FormatException('Null Snapshot.wallet');
      }
      if (!json.containsKey(r'serverTime')) {
        throw const FormatException('Missing Snapshot.serverTime');
      }
      if (json[r'serverTime'] == null) {
        throw const FormatException('Null Snapshot.serverTime');
      }
      if (json[r'serverTime'] != null && (json[r'serverTime'] is! String || DateTime.tryParse(json[r'serverTime'] as String) == null)) {
        throw const FormatException('Invalid Snapshot.serverTime');
      }

      return Snapshot(
        user: User.fromJson(json[r'user'])!,
        activeCall: Call.fromJson(json[r'activeCall']),
        listeners: Listener.listFromJson(json[r'listeners']),
        wallet: Wallet.fromJson(json[r'wallet'])!,
        serverTime: mapDateTime(json, r'serverTime', r'')!,
      );
    }
    return null;
  }

  static List<Snapshot> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Snapshot>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Snapshot.fromJson(row);
        if (value == null) throw const FormatException('Invalid Snapshot list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Snapshot> mapFromJson(dynamic json) {
    final map = <String, Snapshot>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Snapshot.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Snapshot-objects as value to a dart map
  static Map<String, List<Snapshot>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Snapshot>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Snapshot.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'user',
    'activeCall',
    'listeners',
    'wallet',
    'serverTime',
  };
}

