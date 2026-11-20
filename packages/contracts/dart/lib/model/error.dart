//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class Error {
  /// Returns a new [Error] instance.
  Error({
    required this.error,
    required this.requestId,
  });

  ErrorError error;

  String requestId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Error &&
    other.error == error &&
    other.requestId == requestId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (error.hashCode) +
    (requestId.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'Error[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'error'] = this.error;
      json[r'requestId'] = this.requestId;
    return json;
  }

  /// Returns a new [Error] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Error? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid Error object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'error')) {
        throw const FormatException('Missing Error.error');
      }
      if (json[r'error'] == null) {
        throw const FormatException('Null Error.error');
      }
      if (!json.containsKey(r'requestId')) {
        throw const FormatException('Missing Error.requestId');
      }
      if (json[r'requestId'] == null) {
        throw const FormatException('Null Error.requestId');
      }

      return Error(
        error: ErrorError.fromJson(json[r'error'])!,
        requestId: mapValueOfType<String>(json, r'requestId')!,
      );
    }
    return null;
  }

  static List<Error> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Error>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Error.fromJson(row);
        if (value == null) throw const FormatException('Invalid Error list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Error> mapFromJson(dynamic json) {
    final map = <String, Error>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Error.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Error-objects as value to a dart map
  static Map<String, List<Error>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Error>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Error.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'error',
    'requestId',
  };
}

