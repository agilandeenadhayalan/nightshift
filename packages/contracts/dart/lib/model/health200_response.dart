//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class Health200Response {
  /// Returns a new [Health200Response] instance.
  Health200Response({
    required this.status,
    required this.service,
    required this.testOnly,
  });

  String status;

  String service;

  bool testOnly;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Health200Response &&
    other.status == status &&
    other.service == service &&
    other.testOnly == testOnly;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (status.hashCode) +
    (service.hashCode) +
    (testOnly.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'Health200Response[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'status'] = this.status;
      json[r'service'] = this.service;
      json[r'testOnly'] = this.testOnly;
    return json;
  }

  /// Returns a new [Health200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Health200Response? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid Health200Response object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'status')) {
        throw const FormatException('Missing Health200Response.status');
      }
      if (json[r'status'] == null) {
        throw const FormatException('Null Health200Response.status');
      }
      if (!json.containsKey(r'service')) {
        throw const FormatException('Missing Health200Response.service');
      }
      if (json[r'service'] == null) {
        throw const FormatException('Null Health200Response.service');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing Health200Response.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null Health200Response.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid Health200Response.testOnly boolean');
      }

      return Health200Response(
        status: mapValueOfType<String>(json, r'status')!,
        service: mapValueOfType<String>(json, r'service')!,
        testOnly: mapValueOfType<bool>(json, r'testOnly')!,
      );
    }
    return null;
  }

  static List<Health200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Health200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Health200Response.fromJson(row);
        if (value == null) throw const FormatException('Invalid Health200Response list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Health200Response> mapFromJson(dynamic json) {
    final map = <String, Health200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Health200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Health200Response-objects as value to a dart map
  static Map<String, List<Health200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Health200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Health200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'status',
    'service',
    'testOnly',
  };
}

