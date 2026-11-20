//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class OnboardingState {
  /// Returns a new [OnboardingState] instance.
  OnboardingState({
    required this.required_,
    required this.profile,
  });

  bool required_;

  OnboardingProfile profile;

  @override
  bool operator ==(Object other) => identical(this, other) || other is OnboardingState &&
    other.required_ == required_ &&
    other.profile == profile;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (required_.hashCode) +
    (profile.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'OnboardingState[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'required'] = this.required_;
      json[r'profile'] = this.profile;
    return json;
  }

  /// Returns a new [OnboardingState] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static OnboardingState? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid OnboardingState object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'required')) {
        throw const FormatException('Missing OnboardingState.required');
      }
      if (json[r'required'] == null) {
        throw const FormatException('Null OnboardingState.required');
      }
      if (json[r'required'] != null && json[r'required'] is! bool) {
        throw const FormatException('Invalid OnboardingState.required boolean');
      }
      if (!json.containsKey(r'profile')) {
        throw const FormatException('Missing OnboardingState.profile');
      }
      if (json[r'profile'] == null) {
        throw const FormatException('Null OnboardingState.profile');
      }

      return OnboardingState(
        required_: mapValueOfType<bool>(json, r'required')!,
        profile: OnboardingProfile.fromJson(json[r'profile'])!,
      );
    }
    return null;
  }

  static List<OnboardingState> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OnboardingState>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OnboardingState.fromJson(row);
        if (value == null) throw const FormatException('Invalid OnboardingState list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, OnboardingState> mapFromJson(dynamic json) {
    final map = <String, OnboardingState>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = OnboardingState.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of OnboardingState-objects as value to a dart map
  static Map<String, List<OnboardingState>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<OnboardingState>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = OnboardingState.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'required',
    'profile',
  };
}

