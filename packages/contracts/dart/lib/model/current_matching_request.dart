//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class CurrentMatchingRequest {
  /// Returns a new [CurrentMatchingRequest] instance.
  CurrentMatchingRequest({
    required this.request,
  });

  MatchingRequest? request;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CurrentMatchingRequest &&
    other.request == request;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (request == null ? 0 : request!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'CurrentMatchingRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.request != null) {
      json[r'request'] = this.request;
    } else {
      json[r'request'] = null;
    }
    return json;
  }

  /// Returns a new [CurrentMatchingRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CurrentMatchingRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid CurrentMatchingRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'request')) {
        throw const FormatException('Missing CurrentMatchingRequest.request');
      }

      return CurrentMatchingRequest(
        request: MatchingRequest.fromJson(json[r'request']),
      );
    }
    return null;
  }

  static List<CurrentMatchingRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CurrentMatchingRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CurrentMatchingRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid CurrentMatchingRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CurrentMatchingRequest> mapFromJson(dynamic json) {
    final map = <String, CurrentMatchingRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CurrentMatchingRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CurrentMatchingRequest-objects as value to a dart map
  static Map<String, List<CurrentMatchingRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CurrentMatchingRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CurrentMatchingRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'request',
  };
}

