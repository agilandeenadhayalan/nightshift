//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class FirebaseVerifyRequest {
  /// Returns a new [FirebaseVerifyRequest] instance.
  FirebaseVerifyRequest({
    required this.idToken,
  });

  String idToken;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FirebaseVerifyRequest &&
    other.idToken == idToken;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (idToken.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'FirebaseVerifyRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'idToken'] = this.idToken;
    return json;
  }

  /// Returns a new [FirebaseVerifyRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FirebaseVerifyRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid FirebaseVerifyRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'idToken')) {
        throw const FormatException('Missing FirebaseVerifyRequest.idToken');
      }
      if (json[r'idToken'] == null) {
        throw const FormatException('Null FirebaseVerifyRequest.idToken');
      }

      return FirebaseVerifyRequest(
        idToken: mapValueOfType<String>(json, r'idToken')!,
      );
    }
    return null;
  }

  static List<FirebaseVerifyRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FirebaseVerifyRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FirebaseVerifyRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid FirebaseVerifyRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FirebaseVerifyRequest> mapFromJson(dynamic json) {
    final map = <String, FirebaseVerifyRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FirebaseVerifyRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FirebaseVerifyRequest-objects as value to a dart map
  static Map<String, List<FirebaseVerifyRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<FirebaseVerifyRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FirebaseVerifyRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'idToken',
  };
}

