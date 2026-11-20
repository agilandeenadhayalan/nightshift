//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class OtpVerifyRequest {
  /// Returns a new [OtpVerifyRequest] instance.
  OtpVerifyRequest({
    required this.challengeId,
    required this.phone,
    required this.code,
    required this.deviceId,
  });

  String challengeId;

  String phone;

  String code;

  String deviceId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is OtpVerifyRequest &&
    other.challengeId == challengeId &&
    other.phone == phone &&
    other.code == code &&
    other.deviceId == deviceId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (challengeId.hashCode) +
    (phone.hashCode) +
    (code.hashCode) +
    (deviceId.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'OtpVerifyRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'challengeId'] = this.challengeId;
      json[r'phone'] = this.phone;
      json[r'code'] = this.code;
      json[r'deviceId'] = this.deviceId;
    return json;
  }

  /// Returns a new [OtpVerifyRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static OtpVerifyRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid OtpVerifyRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'challengeId')) {
        throw const FormatException('Missing OtpVerifyRequest.challengeId');
      }
      if (json[r'challengeId'] == null) {
        throw const FormatException('Null OtpVerifyRequest.challengeId');
      }
      if (!json.containsKey(r'phone')) {
        throw const FormatException('Missing OtpVerifyRequest.phone');
      }
      if (json[r'phone'] == null) {
        throw const FormatException('Null OtpVerifyRequest.phone');
      }
      if (!json.containsKey(r'code')) {
        throw const FormatException('Missing OtpVerifyRequest.code');
      }
      if (json[r'code'] == null) {
        throw const FormatException('Null OtpVerifyRequest.code');
      }
      if (!json.containsKey(r'deviceId')) {
        throw const FormatException('Missing OtpVerifyRequest.deviceId');
      }
      if (json[r'deviceId'] == null) {
        throw const FormatException('Null OtpVerifyRequest.deviceId');
      }

      return OtpVerifyRequest(
        challengeId: mapValueOfType<String>(json, r'challengeId')!,
        phone: mapValueOfType<String>(json, r'phone')!,
        code: mapValueOfType<String>(json, r'code')!,
        deviceId: mapValueOfType<String>(json, r'deviceId')!,
      );
    }
    return null;
  }

  static List<OtpVerifyRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OtpVerifyRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OtpVerifyRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid OtpVerifyRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, OtpVerifyRequest> mapFromJson(dynamic json) {
    final map = <String, OtpVerifyRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = OtpVerifyRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of OtpVerifyRequest-objects as value to a dart map
  static Map<String, List<OtpVerifyRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<OtpVerifyRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = OtpVerifyRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'challengeId',
    'phone',
    'code',
    'deviceId',
  };
}

