//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class FirebasePhoneAdmission {
  /// Returns a new [FirebasePhoneAdmission] instance.
  FirebasePhoneAdmission({
    required this.attemptId,
    required this.expiresAt,
    required this.retryAt,
  });

  String attemptId;

  DateTime expiresAt;

  DateTime retryAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FirebasePhoneAdmission &&
    other.attemptId == attemptId &&
    other.expiresAt == expiresAt &&
    other.retryAt == retryAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (attemptId.hashCode) +
    (expiresAt.hashCode) +
    (retryAt.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'FirebasePhoneAdmission[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'attemptId'] = this.attemptId;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'retryAt'] = this.retryAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [FirebasePhoneAdmission] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FirebasePhoneAdmission? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid FirebasePhoneAdmission object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'attemptId')) {
        throw const FormatException('Missing FirebasePhoneAdmission.attemptId');
      }
      if (json[r'attemptId'] == null) {
        throw const FormatException('Null FirebasePhoneAdmission.attemptId');
      }
      if (!json.containsKey(r'expiresAt')) {
        throw const FormatException('Missing FirebasePhoneAdmission.expiresAt');
      }
      if (json[r'expiresAt'] == null) {
        throw const FormatException('Null FirebasePhoneAdmission.expiresAt');
      }
      if (json[r'expiresAt'] != null && (json[r'expiresAt'] is! String || DateTime.tryParse(json[r'expiresAt'] as String) == null)) {
        throw const FormatException('Invalid FirebasePhoneAdmission.expiresAt');
      }
      if (!json.containsKey(r'retryAt')) {
        throw const FormatException('Missing FirebasePhoneAdmission.retryAt');
      }
      if (json[r'retryAt'] == null) {
        throw const FormatException('Null FirebasePhoneAdmission.retryAt');
      }
      if (json[r'retryAt'] != null && (json[r'retryAt'] is! String || DateTime.tryParse(json[r'retryAt'] as String) == null)) {
        throw const FormatException('Invalid FirebasePhoneAdmission.retryAt');
      }

      return FirebasePhoneAdmission(
        attemptId: mapValueOfType<String>(json, r'attemptId')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        retryAt: mapDateTime(json, r'retryAt', r'')!,
      );
    }
    return null;
  }

  static List<FirebasePhoneAdmission> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FirebasePhoneAdmission>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FirebasePhoneAdmission.fromJson(row);
        if (value == null) throw const FormatException('Invalid FirebasePhoneAdmission list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FirebasePhoneAdmission> mapFromJson(dynamic json) {
    final map = <String, FirebasePhoneAdmission>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FirebasePhoneAdmission.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FirebasePhoneAdmission-objects as value to a dart map
  static Map<String, List<FirebasePhoneAdmission>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<FirebasePhoneAdmission>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FirebasePhoneAdmission.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'attemptId',
    'expiresAt',
    'retryAt',
  };
}

