//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class PhoneIdentity {
  /// Returns a new [PhoneIdentity] instance.
  PhoneIdentity({
    required this.userId,
    required this.needsOnboarding,
  });

  String userId;

  bool needsOnboarding;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PhoneIdentity &&
    other.userId == userId &&
    other.needsOnboarding == needsOnboarding;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (userId.hashCode) +
    (needsOnboarding.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'PhoneIdentity[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'userId'] = this.userId;
      json[r'needsOnboarding'] = this.needsOnboarding;
    return json;
  }

  /// Returns a new [PhoneIdentity] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PhoneIdentity? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid PhoneIdentity object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'userId')) {
        throw const FormatException('Missing PhoneIdentity.userId');
      }
      if (json[r'userId'] == null) {
        throw const FormatException('Null PhoneIdentity.userId');
      }
      if (!json.containsKey(r'needsOnboarding')) {
        throw const FormatException('Missing PhoneIdentity.needsOnboarding');
      }
      if (json[r'needsOnboarding'] == null) {
        throw const FormatException('Null PhoneIdentity.needsOnboarding');
      }
      if (json[r'needsOnboarding'] != null && json[r'needsOnboarding'] is! bool) {
        throw const FormatException('Invalid PhoneIdentity.needsOnboarding boolean');
      }

      return PhoneIdentity(
        userId: mapValueOfType<String>(json, r'userId')!,
        needsOnboarding: mapValueOfType<bool>(json, r'needsOnboarding')!,
      );
    }
    return null;
  }

  static List<PhoneIdentity> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PhoneIdentity>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PhoneIdentity.fromJson(row);
        if (value == null) throw const FormatException('Invalid PhoneIdentity list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PhoneIdentity> mapFromJson(dynamic json) {
    final map = <String, PhoneIdentity>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PhoneIdentity.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PhoneIdentity-objects as value to a dart map
  static Map<String, List<PhoneIdentity>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PhoneIdentity>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PhoneIdentity.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'userId',
    'needsOnboarding',
  };
}

