//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class OtpRequest {
  /// Returns a new [OtpRequest] instance.
  OtpRequest({
    required this.phone,
    required this.deviceId,
    required this.consentVersion,
  });

  String phone;

  String deviceId;

  String consentVersion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is OtpRequest &&
    other.phone == phone &&
    other.deviceId == deviceId &&
    other.consentVersion == consentVersion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (phone.hashCode) +
    (deviceId.hashCode) +
    (consentVersion.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'OtpRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'phone'] = this.phone;
      json[r'deviceId'] = this.deviceId;
      json[r'consentVersion'] = this.consentVersion;
    return json;
  }

  /// Returns a new [OtpRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static OtpRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid OtpRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'phone')) {
        throw const FormatException('Missing OtpRequest.phone');
      }
      if (json[r'phone'] == null) {
        throw const FormatException('Null OtpRequest.phone');
      }
      if (!json.containsKey(r'deviceId')) {
        throw const FormatException('Missing OtpRequest.deviceId');
      }
      if (json[r'deviceId'] == null) {
        throw const FormatException('Null OtpRequest.deviceId');
      }
      if (!json.containsKey(r'consentVersion')) {
        throw const FormatException('Missing OtpRequest.consentVersion');
      }
      if (json[r'consentVersion'] == null) {
        throw const FormatException('Null OtpRequest.consentVersion');
      }

      return OtpRequest(
        phone: mapValueOfType<String>(json, r'phone')!,
        deviceId: mapValueOfType<String>(json, r'deviceId')!,
        consentVersion: mapValueOfType<String>(json, r'consentVersion')!,
      );
    }
    return null;
  }

  static List<OtpRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OtpRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OtpRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid OtpRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, OtpRequest> mapFromJson(dynamic json) {
    final map = <String, OtpRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = OtpRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of OtpRequest-objects as value to a dart map
  static Map<String, List<OtpRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<OtpRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = OtpRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'phone',
    'deviceId',
    'consentVersion',
  };
}

