//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class CreateReport201Response {
  /// Returns a new [CreateReport201Response] instance.
  CreateReport201Response({
    required this.id,
    required this.status,
  });

  String id;

  String status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateReport201Response &&
    other.id == id &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (status.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'CreateReport201Response[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [CreateReport201Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateReport201Response? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid CreateReport201Response object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing CreateReport201Response.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null CreateReport201Response.id');
      }
      if (!json.containsKey(r'status')) {
        throw const FormatException('Missing CreateReport201Response.status');
      }
      if (json[r'status'] == null) {
        throw const FormatException('Null CreateReport201Response.status');
      }

      return CreateReport201Response(
        id: mapValueOfType<String>(json, r'id')!,
        status: mapValueOfType<String>(json, r'status')!,
      );
    }
    return null;
  }

  static List<CreateReport201Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateReport201Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateReport201Response.fromJson(row);
        if (value == null) throw const FormatException('Invalid CreateReport201Response list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateReport201Response> mapFromJson(dynamic json) {
    final map = <String, CreateReport201Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateReport201Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateReport201Response-objects as value to a dart map
  static Map<String, List<CreateReport201Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateReport201Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateReport201Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'status',
  };
}

