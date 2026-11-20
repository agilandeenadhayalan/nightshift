//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class DirectoryInvalidated {
  /// Returns a new [DirectoryInvalidated] instance.
  DirectoryInvalidated({
    required this.viewEpoch,
    required this.code,
  });

  String viewEpoch;

  String code;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DirectoryInvalidated &&
    other.viewEpoch == viewEpoch &&
    other.code == code;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (viewEpoch.hashCode) +
    (code.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'DirectoryInvalidated[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'viewEpoch'] = this.viewEpoch;
      json[r'code'] = this.code;
    return json;
  }

  /// Returns a new [DirectoryInvalidated] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DirectoryInvalidated? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid DirectoryInvalidated object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'viewEpoch')) {
        throw const FormatException('Missing DirectoryInvalidated.viewEpoch');
      }
      if (json[r'viewEpoch'] == null) {
        throw const FormatException('Null DirectoryInvalidated.viewEpoch');
      }
      if (!json.containsKey(r'code')) {
        throw const FormatException('Missing DirectoryInvalidated.code');
      }
      if (json[r'code'] == null) {
        throw const FormatException('Null DirectoryInvalidated.code');
      }

      return DirectoryInvalidated(
        viewEpoch: mapValueOfType<String>(json, r'viewEpoch')!,
        code: mapValueOfType<String>(json, r'code')!,
      );
    }
    return null;
  }

  static List<DirectoryInvalidated> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DirectoryInvalidated>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DirectoryInvalidated.fromJson(row);
        if (value == null) throw const FormatException('Invalid DirectoryInvalidated list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DirectoryInvalidated> mapFromJson(dynamic json) {
    final map = <String, DirectoryInvalidated>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DirectoryInvalidated.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DirectoryInvalidated-objects as value to a dart map
  static Map<String, List<DirectoryInvalidated>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DirectoryInvalidated>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DirectoryInvalidated.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'viewEpoch',
    'code',
  };
}

