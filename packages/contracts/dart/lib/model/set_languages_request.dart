//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class SetLanguagesRequest {
  /// Returns a new [SetLanguagesRequest] instance.
  SetLanguagesRequest({
    this.languages = const [],
  });

  List<SetLanguagesRequestLanguagesEnum> languages;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SetLanguagesRequest &&
    _deepEquality.equals(other.languages, languages);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (languages.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'SetLanguagesRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'languages'] = this.languages;
    return json;
  }

  /// Returns a new [SetLanguagesRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SetLanguagesRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid SetLanguagesRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'languages')) {
        throw const FormatException('Missing SetLanguagesRequest.languages');
      }
      if (json[r'languages'] == null) {
        throw const FormatException('Null SetLanguagesRequest.languages');
      }
      if (json[r'languages'] != null && json[r'languages'] is! List) {
        throw const FormatException('Invalid SetLanguagesRequest.languages');
      }

      return SetLanguagesRequest(
        languages: SetLanguagesRequestLanguagesEnum.listFromJson(json[r'languages']),
      );
    }
    return null;
  }

  static List<SetLanguagesRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SetLanguagesRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SetLanguagesRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid SetLanguagesRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SetLanguagesRequest> mapFromJson(dynamic json) {
    final map = <String, SetLanguagesRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SetLanguagesRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SetLanguagesRequest-objects as value to a dart map
  static Map<String, List<SetLanguagesRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SetLanguagesRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SetLanguagesRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'languages',
  };
}


enum SetLanguagesRequestLanguagesEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const SetLanguagesRequestLanguagesEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [SetLanguagesRequestLanguagesEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static SetLanguagesRequestLanguagesEnum? fromJson(dynamic value) => SetLanguagesRequestLanguagesEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [SetLanguagesRequestLanguagesEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<SetLanguagesRequestLanguagesEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SetLanguagesRequestLanguagesEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SetLanguagesRequestLanguagesEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SetLanguagesRequestLanguagesEnum] to String,
/// and [decode] dynamic data back to [SetLanguagesRequestLanguagesEnum].
class SetLanguagesRequestLanguagesEnumTypeTransformer {
  factory SetLanguagesRequestLanguagesEnumTypeTransformer() => _instance ??= const SetLanguagesRequestLanguagesEnumTypeTransformer._();

  const SetLanguagesRequestLanguagesEnumTypeTransformer._();

  String encode(SetLanguagesRequestLanguagesEnum data) => data._value;

  /// Returns the instance of [SetLanguagesRequestLanguagesEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SetLanguagesRequestLanguagesEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is SetLanguagesRequestLanguagesEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return SetLanguagesRequestLanguagesEnum.ta;
        case r'en': return SetLanguagesRequestLanguagesEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static SetLanguagesRequestLanguagesEnumTypeTransformer? _instance;
}


