//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class SetAvailabilityRequest {
  /// Returns a new [SetAvailabilityRequest] instance.
  SetAvailabilityRequest({
    required this.online,
  });

  bool online;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SetAvailabilityRequest &&
    other.online == online;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (online.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'SetAvailabilityRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'online'] = this.online;
    return json;
  }

  /// Returns a new [SetAvailabilityRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SetAvailabilityRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid SetAvailabilityRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'online')) {
        throw const FormatException('Missing SetAvailabilityRequest.online');
      }
      if (json[r'online'] == null) {
        throw const FormatException('Null SetAvailabilityRequest.online');
      }
      if (json[r'online'] != null && json[r'online'] is! bool) {
        throw const FormatException('Invalid SetAvailabilityRequest.online boolean');
      }

      return SetAvailabilityRequest(
        online: mapValueOfType<bool>(json, r'online')!,
      );
    }
    return null;
  }

  static List<SetAvailabilityRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SetAvailabilityRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SetAvailabilityRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid SetAvailabilityRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SetAvailabilityRequest> mapFromJson(dynamic json) {
    final map = <String, SetAvailabilityRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SetAvailabilityRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SetAvailabilityRequest-objects as value to a dart map
  static Map<String, List<SetAvailabilityRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SetAvailabilityRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SetAvailabilityRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'online',
  };
}

