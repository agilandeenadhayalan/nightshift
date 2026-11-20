//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ReportMediaReadyRequest {
  /// Returns a new [ReportMediaReadyRequest] instance.
  ReportMediaReadyRequest({
    required this.ready,
    this.videoReady,
  });

  bool ready;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? videoReady;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReportMediaReadyRequest &&
    other.ready == ready &&
    other.videoReady == videoReady;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (ready.hashCode) +
    (videoReady == null ? 0 : videoReady!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ReportMediaReadyRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'ready'] = this.ready;
    if (this.videoReady != null) {
      json[r'videoReady'] = this.videoReady;
    }
    return json;
  }

  /// Returns a new [ReportMediaReadyRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportMediaReadyRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ReportMediaReadyRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'ready')) {
        throw const FormatException('Missing ReportMediaReadyRequest.ready');
      }
      if (json[r'ready'] == null) {
        throw const FormatException('Null ReportMediaReadyRequest.ready');
      }
      if (json[r'ready'] != null && json[r'ready'] is! bool) {
        throw const FormatException('Invalid ReportMediaReadyRequest.ready boolean');
      }
      if (json[r'videoReady'] != null && json[r'videoReady'] is! bool) {
        throw const FormatException('Invalid ReportMediaReadyRequest.videoReady boolean');
      }

      return ReportMediaReadyRequest(
        ready: mapValueOfType<bool>(json, r'ready')!,
        videoReady: mapValueOfType<bool>(json, r'videoReady'),
      );
    }
    return null;
  }

  static List<ReportMediaReadyRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportMediaReadyRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportMediaReadyRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid ReportMediaReadyRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportMediaReadyRequest> mapFromJson(dynamic json) {
    final map = <String, ReportMediaReadyRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportMediaReadyRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportMediaReadyRequest-objects as value to a dart map
  static Map<String, List<ReportMediaReadyRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReportMediaReadyRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportMediaReadyRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'ready',
  };
}

