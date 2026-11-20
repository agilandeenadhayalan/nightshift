//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class DeclineCallRequest {
  /// Returns a new [DeclineCallRequest] instance.
  DeclineCallRequest({
    required this.expectedVersion,
  });

  int expectedVersion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DeclineCallRequest &&
    other.expectedVersion == expectedVersion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedVersion.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'DeclineCallRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expectedVersion'] = this.expectedVersion;
    return json;
  }

  /// Returns a new [DeclineCallRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DeclineCallRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid DeclineCallRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'expectedVersion')) {
        throw const FormatException('Missing DeclineCallRequest.expectedVersion');
      }
      if (json[r'expectedVersion'] == null) {
        throw const FormatException('Null DeclineCallRequest.expectedVersion');
      }
      if (json[r'expectedVersion'] != null && json[r'expectedVersion'] is! int) {
        throw const FormatException('Invalid DeclineCallRequest.expectedVersion integer');
      }

      return DeclineCallRequest(
        expectedVersion: mapValueOfType<int>(json, r'expectedVersion')!,
      );
    }
    return null;
  }

  static List<DeclineCallRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeclineCallRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeclineCallRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid DeclineCallRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DeclineCallRequest> mapFromJson(dynamic json) {
    final map = <String, DeclineCallRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DeclineCallRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DeclineCallRequest-objects as value to a dart map
  static Map<String, List<DeclineCallRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DeclineCallRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DeclineCallRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expectedVersion',
  };
}

