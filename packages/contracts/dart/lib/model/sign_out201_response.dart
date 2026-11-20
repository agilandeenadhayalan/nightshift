//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class SignOut201Response {
  /// Returns a new [SignOut201Response] instance.
  SignOut201Response({
    required this.signedOut,
  });

  bool signedOut;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SignOut201Response &&
    other.signedOut == signedOut;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (signedOut.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'SignOut201Response[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'signedOut'] = this.signedOut;
    return json;
  }

  /// Returns a new [SignOut201Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SignOut201Response? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid SignOut201Response object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'signedOut')) {
        throw const FormatException('Missing SignOut201Response.signedOut');
      }
      if (json[r'signedOut'] == null) {
        throw const FormatException('Null SignOut201Response.signedOut');
      }
      if (json[r'signedOut'] != null && json[r'signedOut'] is! bool) {
        throw const FormatException('Invalid SignOut201Response.signedOut boolean');
      }

      return SignOut201Response(
        signedOut: mapValueOfType<bool>(json, r'signedOut')!,
      );
    }
    return null;
  }

  static List<SignOut201Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SignOut201Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SignOut201Response.fromJson(row);
        if (value == null) throw const FormatException('Invalid SignOut201Response list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SignOut201Response> mapFromJson(dynamic json) {
    final map = <String, SignOut201Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SignOut201Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SignOut201Response-objects as value to a dart map
  static Map<String, List<SignOut201Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SignOut201Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SignOut201Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'signedOut',
  };
}

