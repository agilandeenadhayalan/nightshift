//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class PhoneSessionRequest {
  /// Returns a new [PhoneSessionRequest] instance.
  PhoneSessionRequest({
    required this.idToken,
    required this.deviceId,
  });

  String idToken;

  String deviceId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PhoneSessionRequest &&
    other.idToken == idToken &&
    other.deviceId == deviceId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (idToken.hashCode) +
    (deviceId.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'PhoneSessionRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'idToken'] = this.idToken;
      json[r'deviceId'] = this.deviceId;
    return json;
  }

  /// Returns a new [PhoneSessionRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PhoneSessionRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid PhoneSessionRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'idToken')) {
        throw const FormatException('Missing PhoneSessionRequest.idToken');
      }
      if (json[r'idToken'] == null) {
        throw const FormatException('Null PhoneSessionRequest.idToken');
      }
      if (!json.containsKey(r'deviceId')) {
        throw const FormatException('Missing PhoneSessionRequest.deviceId');
      }
      if (json[r'deviceId'] == null) {
        throw const FormatException('Null PhoneSessionRequest.deviceId');
      }

      return PhoneSessionRequest(
        idToken: mapValueOfType<String>(json, r'idToken')!,
        deviceId: mapValueOfType<String>(json, r'deviceId')!,
      );
    }
    return null;
  }

  static List<PhoneSessionRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PhoneSessionRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PhoneSessionRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid PhoneSessionRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PhoneSessionRequest> mapFromJson(dynamic json) {
    final map = <String, PhoneSessionRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PhoneSessionRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PhoneSessionRequest-objects as value to a dart map
  static Map<String, List<PhoneSessionRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PhoneSessionRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PhoneSessionRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'idToken',
    'deviceId',
  };
}

