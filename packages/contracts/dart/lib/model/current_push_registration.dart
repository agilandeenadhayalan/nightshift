//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class CurrentPushRegistration {
  /// Returns a new [CurrentPushRegistration] instance.
  CurrentPushRegistration({
    required this.registration,
  });

  PushRegistration? registration;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CurrentPushRegistration &&
    other.registration == registration;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (registration == null ? 0 : registration!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'CurrentPushRegistration[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.registration != null) {
      json[r'registration'] = this.registration;
    } else {
      json[r'registration'] = null;
    }
    return json;
  }

  /// Returns a new [CurrentPushRegistration] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CurrentPushRegistration? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid CurrentPushRegistration object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'registration')) {
        throw const FormatException('Missing CurrentPushRegistration.registration');
      }

      return CurrentPushRegistration(
        registration: PushRegistration.fromJson(json[r'registration']),
      );
    }
    return null;
  }

  static List<CurrentPushRegistration> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CurrentPushRegistration>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CurrentPushRegistration.fromJson(row);
        if (value == null) throw const FormatException('Invalid CurrentPushRegistration list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CurrentPushRegistration> mapFromJson(dynamic json) {
    final map = <String, CurrentPushRegistration>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CurrentPushRegistration.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CurrentPushRegistration-objects as value to a dart map
  static Map<String, List<CurrentPushRegistration>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CurrentPushRegistration>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CurrentPushRegistration.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'registration',
  };
}

