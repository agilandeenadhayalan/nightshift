//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ConsentEvent {
  /// Returns a new [ConsentEvent] instance.
  ConsentEvent({
    required this.id,
    required this.purpose,
    required this.noticeVersion,
    required this.granted,
    required this.createdAt,
  });

  String id;

  String purpose;

  String noticeVersion;

  bool granted;

  DateTime createdAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ConsentEvent &&
    other.id == id &&
    other.purpose == purpose &&
    other.noticeVersion == noticeVersion &&
    other.granted == granted &&
    other.createdAt == createdAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (purpose.hashCode) +
    (noticeVersion.hashCode) +
    (granted.hashCode) +
    (createdAt.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ConsentEvent[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'purpose'] = this.purpose;
      json[r'noticeVersion'] = this.noticeVersion;
      json[r'granted'] = this.granted;
      json[r'createdAt'] = this.createdAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [ConsentEvent] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ConsentEvent? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ConsentEvent object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing ConsentEvent.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null ConsentEvent.id');
      }
      if (!json.containsKey(r'purpose')) {
        throw const FormatException('Missing ConsentEvent.purpose');
      }
      if (json[r'purpose'] == null) {
        throw const FormatException('Null ConsentEvent.purpose');
      }
      if (!json.containsKey(r'noticeVersion')) {
        throw const FormatException('Missing ConsentEvent.noticeVersion');
      }
      if (json[r'noticeVersion'] == null) {
        throw const FormatException('Null ConsentEvent.noticeVersion');
      }
      if (!json.containsKey(r'granted')) {
        throw const FormatException('Missing ConsentEvent.granted');
      }
      if (json[r'granted'] == null) {
        throw const FormatException('Null ConsentEvent.granted');
      }
      if (json[r'granted'] != null && json[r'granted'] is! bool) {
        throw const FormatException('Invalid ConsentEvent.granted boolean');
      }
      if (!json.containsKey(r'createdAt')) {
        throw const FormatException('Missing ConsentEvent.createdAt');
      }
      if (json[r'createdAt'] == null) {
        throw const FormatException('Null ConsentEvent.createdAt');
      }
      if (json[r'createdAt'] != null && (json[r'createdAt'] is! String || DateTime.tryParse(json[r'createdAt'] as String) == null)) {
        throw const FormatException('Invalid ConsentEvent.createdAt');
      }

      return ConsentEvent(
        id: mapValueOfType<String>(json, r'id')!,
        purpose: mapValueOfType<String>(json, r'purpose')!,
        noticeVersion: mapValueOfType<String>(json, r'noticeVersion')!,
        granted: mapValueOfType<bool>(json, r'granted')!,
        createdAt: mapDateTime(json, r'createdAt', r'')!,
      );
    }
    return null;
  }

  static List<ConsentEvent> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ConsentEvent>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ConsentEvent.fromJson(row);
        if (value == null) throw const FormatException('Invalid ConsentEvent list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ConsentEvent> mapFromJson(dynamic json) {
    final map = <String, ConsentEvent>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ConsentEvent.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ConsentEvent-objects as value to a dart map
  static Map<String, List<ConsentEvent>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ConsentEvent>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ConsentEvent.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'purpose',
    'noticeVersion',
    'granted',
    'createdAt',
  };
}

