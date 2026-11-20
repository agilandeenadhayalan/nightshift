//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class AcceptCallRequest {
  /// Returns a new [AcceptCallRequest] instance.
  AcceptCallRequest({
    required this.expectedVersion,
    this.videoConsent,
  });

  int expectedVersion;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? videoConsent;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AcceptCallRequest &&
    other.expectedVersion == expectedVersion &&
    other.videoConsent == videoConsent;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedVersion.hashCode) +
    (videoConsent == null ? 0 : videoConsent!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'AcceptCallRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expectedVersion'] = this.expectedVersion;
    if (this.videoConsent != null) {
      json[r'videoConsent'] = this.videoConsent;
    }
    return json;
  }

  /// Returns a new [AcceptCallRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AcceptCallRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid AcceptCallRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'expectedVersion')) {
        throw const FormatException('Missing AcceptCallRequest.expectedVersion');
      }
      if (json[r'expectedVersion'] == null) {
        throw const FormatException('Null AcceptCallRequest.expectedVersion');
      }
      if (json[r'expectedVersion'] != null && json[r'expectedVersion'] is! int) {
        throw const FormatException('Invalid AcceptCallRequest.expectedVersion integer');
      }
      if (json[r'videoConsent'] != null && json[r'videoConsent'] is! bool) {
        throw const FormatException('Invalid AcceptCallRequest.videoConsent boolean');
      }

      return AcceptCallRequest(
        expectedVersion: mapValueOfType<int>(json, r'expectedVersion')!,
        videoConsent: mapValueOfType<bool>(json, r'videoConsent'),
      );
    }
    return null;
  }

  static List<AcceptCallRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AcceptCallRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AcceptCallRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid AcceptCallRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AcceptCallRequest> mapFromJson(dynamic json) {
    final map = <String, AcceptCallRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AcceptCallRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AcceptCallRequest-objects as value to a dart map
  static Map<String, List<AcceptCallRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AcceptCallRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AcceptCallRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expectedVersion',
  };
}

