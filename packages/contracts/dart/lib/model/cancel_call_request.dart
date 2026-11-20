//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class CancelCallRequest {
  /// Returns a new [CancelCallRequest] instance.
  CancelCallRequest({
    required this.expectedVersion,
  });

  int expectedVersion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CancelCallRequest &&
    other.expectedVersion == expectedVersion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedVersion.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'CancelCallRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expectedVersion'] = this.expectedVersion;
    return json;
  }

  /// Returns a new [CancelCallRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CancelCallRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid CancelCallRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'expectedVersion')) {
        throw const FormatException('Missing CancelCallRequest.expectedVersion');
      }
      if (json[r'expectedVersion'] == null) {
        throw const FormatException('Null CancelCallRequest.expectedVersion');
      }
      if (json[r'expectedVersion'] != null && json[r'expectedVersion'] is! int) {
        throw const FormatException('Invalid CancelCallRequest.expectedVersion integer');
      }

      return CancelCallRequest(
        expectedVersion: mapValueOfType<int>(json, r'expectedVersion')!,
      );
    }
    return null;
  }

  static List<CancelCallRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CancelCallRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CancelCallRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid CancelCallRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CancelCallRequest> mapFromJson(dynamic json) {
    final map = <String, CancelCallRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CancelCallRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CancelCallRequest-objects as value to a dart map
  static Map<String, List<CancelCallRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CancelCallRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CancelCallRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expectedVersion',
  };
}

