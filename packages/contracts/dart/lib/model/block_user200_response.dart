//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class BlockUser200Response {
  /// Returns a new [BlockUser200Response] instance.
  BlockUser200Response({
    required this.blocked,
  });

  bool blocked;

  @override
  bool operator ==(Object other) => identical(this, other) || other is BlockUser200Response &&
    other.blocked == blocked;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (blocked.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'BlockUser200Response[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'blocked'] = this.blocked;
    return json;
  }

  /// Returns a new [BlockUser200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BlockUser200Response? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid BlockUser200Response object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'blocked')) {
        throw const FormatException('Missing BlockUser200Response.blocked');
      }
      if (json[r'blocked'] == null) {
        throw const FormatException('Null BlockUser200Response.blocked');
      }
      if (json[r'blocked'] != null && json[r'blocked'] is! bool) {
        throw const FormatException('Invalid BlockUser200Response.blocked boolean');
      }

      return BlockUser200Response(
        blocked: mapValueOfType<bool>(json, r'blocked')!,
      );
    }
    return null;
  }

  static List<BlockUser200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BlockUser200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BlockUser200Response.fromJson(row);
        if (value == null) throw const FormatException('Invalid BlockUser200Response list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BlockUser200Response> mapFromJson(dynamic json) {
    final map = <String, BlockUser200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = BlockUser200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BlockUser200Response-objects as value to a dart map
  static Map<String, List<BlockUser200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<BlockUser200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BlockUser200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'blocked',
  };
}

