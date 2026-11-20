//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class OtpProof {
  /// Returns a new [OtpProof] instance.
  OtpProof({
    required this.customToken,
    required this.userId,
    required this.needsOnboarding,
  });

  String customToken;

  String userId;

  bool needsOnboarding;

  @override
  bool operator ==(Object other) => identical(this, other) || other is OtpProof &&
    other.customToken == customToken &&
    other.userId == userId &&
    other.needsOnboarding == needsOnboarding;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (customToken.hashCode) +
    (userId.hashCode) +
    (needsOnboarding.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'OtpProof[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'customToken'] = this.customToken;
      json[r'userId'] = this.userId;
      json[r'needsOnboarding'] = this.needsOnboarding;
    return json;
  }

  /// Returns a new [OtpProof] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static OtpProof? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid OtpProof object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'customToken')) {
        throw const FormatException('Missing OtpProof.customToken');
      }
      if (json[r'customToken'] == null) {
        throw const FormatException('Null OtpProof.customToken');
      }
      if (!json.containsKey(r'userId')) {
        throw const FormatException('Missing OtpProof.userId');
      }
      if (json[r'userId'] == null) {
        throw const FormatException('Null OtpProof.userId');
      }
      if (!json.containsKey(r'needsOnboarding')) {
        throw const FormatException('Missing OtpProof.needsOnboarding');
      }
      if (json[r'needsOnboarding'] == null) {
        throw const FormatException('Null OtpProof.needsOnboarding');
      }
      if (json[r'needsOnboarding'] != null && json[r'needsOnboarding'] is! bool) {
        throw const FormatException('Invalid OtpProof.needsOnboarding boolean');
      }

      return OtpProof(
        customToken: mapValueOfType<String>(json, r'customToken')!,
        userId: mapValueOfType<String>(json, r'userId')!,
        needsOnboarding: mapValueOfType<bool>(json, r'needsOnboarding')!,
      );
    }
    return null;
  }

  static List<OtpProof> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OtpProof>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OtpProof.fromJson(row);
        if (value == null) throw const FormatException('Invalid OtpProof list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, OtpProof> mapFromJson(dynamic json) {
    final map = <String, OtpProof>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = OtpProof.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of OtpProof-objects as value to a dart map
  static Map<String, List<OtpProof>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<OtpProof>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = OtpProof.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'customToken',
    'userId',
    'needsOnboarding',
  };
}

