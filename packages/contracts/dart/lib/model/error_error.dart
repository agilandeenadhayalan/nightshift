//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ErrorError {
  /// Returns a new [ErrorError] instance.
  ErrorError({
    required this.code,
    required this.message,
  });

  String code;

  String message;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ErrorError &&
    other.code == code &&
    other.message == message;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (code.hashCode) +
    (message.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ErrorError[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'code'] = this.code;
      json[r'message'] = this.message;
    return json;
  }

  /// Returns a new [ErrorError] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ErrorError? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ErrorError object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'code')) {
        throw const FormatException('Missing ErrorError.code');
      }
      if (json[r'code'] == null) {
        throw const FormatException('Null ErrorError.code');
      }
      if (!json.containsKey(r'message')) {
        throw const FormatException('Missing ErrorError.message');
      }
      if (json[r'message'] == null) {
        throw const FormatException('Null ErrorError.message');
      }

      return ErrorError(
        code: mapValueOfType<String>(json, r'code')!,
        message: mapValueOfType<String>(json, r'message')!,
      );
    }
    return null;
  }

  static List<ErrorError> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ErrorError>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ErrorError.fromJson(row);
        if (value == null) throw const FormatException('Invalid ErrorError list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ErrorError> mapFromJson(dynamic json) {
    final map = <String, ErrorError>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ErrorError.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ErrorError-objects as value to a dart map
  static Map<String, List<ErrorError>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ErrorError>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ErrorError.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'code',
    'message',
  };
}

