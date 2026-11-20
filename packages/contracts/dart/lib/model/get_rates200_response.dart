//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class GetRates200Response {
  /// Returns a new [GetRates200Response] instance.
  GetRates200Response({
    this.items = const [],
  });

  List<Rate> items;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GetRates200Response &&
    _deepEquality.equals(other.items, items);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (items.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'GetRates200Response[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'items'] = this.items;
    return json;
  }

  /// Returns a new [GetRates200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GetRates200Response? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid GetRates200Response object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'items')) {
        throw const FormatException('Missing GetRates200Response.items');
      }
      if (json[r'items'] == null) {
        throw const FormatException('Null GetRates200Response.items');
      }
      if (json[r'items'] != null && json[r'items'] is! List) {
        throw const FormatException('Invalid GetRates200Response.items');
      }

      return GetRates200Response(
        items: Rate.listFromJson(json[r'items']),
      );
    }
    return null;
  }

  static List<GetRates200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GetRates200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GetRates200Response.fromJson(row);
        if (value == null) throw const FormatException('Invalid GetRates200Response list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GetRates200Response> mapFromJson(dynamic json) {
    final map = <String, GetRates200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GetRates200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GetRates200Response-objects as value to a dart map
  static Map<String, List<GetRates200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GetRates200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GetRates200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
  };
}

