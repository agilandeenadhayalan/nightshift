//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class Heartbeat201Response {
  /// Returns a new [Heartbeat201Response] instance.
  Heartbeat201Response({
    required this.serverTime,
  });

  DateTime serverTime;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Heartbeat201Response &&
    other.serverTime == serverTime;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (serverTime.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'Heartbeat201Response[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'serverTime'] = this.serverTime.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [Heartbeat201Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Heartbeat201Response? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid Heartbeat201Response object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'serverTime')) {
        throw const FormatException('Missing Heartbeat201Response.serverTime');
      }
      if (json[r'serverTime'] == null) {
        throw const FormatException('Null Heartbeat201Response.serverTime');
      }
      if (json[r'serverTime'] != null && (json[r'serverTime'] is! String || DateTime.tryParse(json[r'serverTime'] as String) == null)) {
        throw const FormatException('Invalid Heartbeat201Response.serverTime');
      }

      return Heartbeat201Response(
        serverTime: mapDateTime(json, r'serverTime', r'')!,
      );
    }
    return null;
  }

  static List<Heartbeat201Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Heartbeat201Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Heartbeat201Response.fromJson(row);
        if (value == null) throw const FormatException('Invalid Heartbeat201Response list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Heartbeat201Response> mapFromJson(dynamic json) {
    final map = <String, Heartbeat201Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Heartbeat201Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Heartbeat201Response-objects as value to a dart map
  static Map<String, List<Heartbeat201Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Heartbeat201Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Heartbeat201Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'serverTime',
  };
}

