//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class GetTestEarnings200Response {
  /// Returns a new [GetTestEarnings200Response] instance.
  GetTestEarnings200Response({
    required this.illustrativePaise,
    required this.availablePaise,
    required this.paidPaise,
    required this.testOnly,
    required this.listenerPaisePerHour,
  });

  int illustrativePaise;

  int availablePaise;

  int paidPaise;

  bool testOnly;

  int listenerPaisePerHour;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GetTestEarnings200Response &&
    other.illustrativePaise == illustrativePaise &&
    other.availablePaise == availablePaise &&
    other.paidPaise == paidPaise &&
    other.testOnly == testOnly &&
    other.listenerPaisePerHour == listenerPaisePerHour;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (illustrativePaise.hashCode) +
    (availablePaise.hashCode) +
    (paidPaise.hashCode) +
    (testOnly.hashCode) +
    (listenerPaisePerHour.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'GetTestEarnings200Response[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'illustrativePaise'] = this.illustrativePaise;
      json[r'availablePaise'] = this.availablePaise;
      json[r'paidPaise'] = this.paidPaise;
      json[r'testOnly'] = this.testOnly;
      json[r'listenerPaisePerHour'] = this.listenerPaisePerHour;
    return json;
  }

  /// Returns a new [GetTestEarnings200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GetTestEarnings200Response? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid GetTestEarnings200Response object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'illustrativePaise')) {
        throw const FormatException('Missing GetTestEarnings200Response.illustrativePaise');
      }
      if (json[r'illustrativePaise'] == null) {
        throw const FormatException('Null GetTestEarnings200Response.illustrativePaise');
      }
      if (json[r'illustrativePaise'] != null && json[r'illustrativePaise'] is! int) {
        throw const FormatException('Invalid GetTestEarnings200Response.illustrativePaise integer');
      }
      if (!json.containsKey(r'availablePaise')) {
        throw const FormatException('Missing GetTestEarnings200Response.availablePaise');
      }
      if (json[r'availablePaise'] == null) {
        throw const FormatException('Null GetTestEarnings200Response.availablePaise');
      }
      if (json[r'availablePaise'] != null && json[r'availablePaise'] is! int) {
        throw const FormatException('Invalid GetTestEarnings200Response.availablePaise integer');
      }
      if (!json.containsKey(r'paidPaise')) {
        throw const FormatException('Missing GetTestEarnings200Response.paidPaise');
      }
      if (json[r'paidPaise'] == null) {
        throw const FormatException('Null GetTestEarnings200Response.paidPaise');
      }
      if (json[r'paidPaise'] != null && json[r'paidPaise'] is! int) {
        throw const FormatException('Invalid GetTestEarnings200Response.paidPaise integer');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing GetTestEarnings200Response.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null GetTestEarnings200Response.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid GetTestEarnings200Response.testOnly boolean');
      }
      if (!json.containsKey(r'listenerPaisePerHour')) {
        throw const FormatException('Missing GetTestEarnings200Response.listenerPaisePerHour');
      }
      if (json[r'listenerPaisePerHour'] == null) {
        throw const FormatException('Null GetTestEarnings200Response.listenerPaisePerHour');
      }
      if (json[r'listenerPaisePerHour'] != null && json[r'listenerPaisePerHour'] is! int) {
        throw const FormatException('Invalid GetTestEarnings200Response.listenerPaisePerHour integer');
      }

      return GetTestEarnings200Response(
        illustrativePaise: mapValueOfType<int>(json, r'illustrativePaise')!,
        availablePaise: mapValueOfType<int>(json, r'availablePaise')!,
        paidPaise: mapValueOfType<int>(json, r'paidPaise')!,
        testOnly: mapValueOfType<bool>(json, r'testOnly')!,
        listenerPaisePerHour: mapValueOfType<int>(json, r'listenerPaisePerHour')!,
      );
    }
    return null;
  }

  static List<GetTestEarnings200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GetTestEarnings200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GetTestEarnings200Response.fromJson(row);
        if (value == null) throw const FormatException('Invalid GetTestEarnings200Response list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GetTestEarnings200Response> mapFromJson(dynamic json) {
    final map = <String, GetTestEarnings200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GetTestEarnings200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GetTestEarnings200Response-objects as value to a dart map
  static Map<String, List<GetTestEarnings200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GetTestEarnings200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GetTestEarnings200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'illustrativePaise',
    'availablePaise',
    'paidPaise',
    'testOnly',
    'listenerPaisePerHour',
  };
}

