//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class DirectoryUpdate {
  /// Returns a new [DirectoryUpdate] instance.
  DirectoryUpdate({
    required this.viewEpoch,
    required this.language,
    required this.serverTime,
    this.items = const [],
    this.removedIds = const [],
  });

  String viewEpoch;

  DirectoryUpdateLanguageEnum language;

  DateTime serverTime;

  List<Listener> items;

  List<String> removedIds;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DirectoryUpdate &&
    other.viewEpoch == viewEpoch &&
    other.language == language &&
    other.serverTime == serverTime &&
    _deepEquality.equals(other.items, items) &&
    _deepEquality.equals(other.removedIds, removedIds);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (viewEpoch.hashCode) +
    (language.hashCode) +
    (serverTime.hashCode) +
    (items.hashCode) +
    (removedIds.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'DirectoryUpdate[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'viewEpoch'] = this.viewEpoch;
      json[r'language'] = this.language;
      json[r'serverTime'] = this.serverTime.toUtc().toIso8601String();
      json[r'items'] = this.items;
      json[r'removedIds'] = this.removedIds;
    return json;
  }

  /// Returns a new [DirectoryUpdate] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DirectoryUpdate? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid DirectoryUpdate object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'viewEpoch')) {
        throw const FormatException('Missing DirectoryUpdate.viewEpoch');
      }
      if (json[r'viewEpoch'] == null) {
        throw const FormatException('Null DirectoryUpdate.viewEpoch');
      }
      if (!json.containsKey(r'language')) {
        throw const FormatException('Missing DirectoryUpdate.language');
      }
      if (json[r'language'] == null) {
        throw const FormatException('Null DirectoryUpdate.language');
      }
      if (!json.containsKey(r'serverTime')) {
        throw const FormatException('Missing DirectoryUpdate.serverTime');
      }
      if (json[r'serverTime'] == null) {
        throw const FormatException('Null DirectoryUpdate.serverTime');
      }
      if (json[r'serverTime'] != null && (json[r'serverTime'] is! String || DateTime.tryParse(json[r'serverTime'] as String) == null)) {
        throw const FormatException('Invalid DirectoryUpdate.serverTime');
      }
      if (!json.containsKey(r'items')) {
        throw const FormatException('Missing DirectoryUpdate.items');
      }
      if (json[r'items'] == null) {
        throw const FormatException('Null DirectoryUpdate.items');
      }
      if (json[r'items'] != null && json[r'items'] is! List) {
        throw const FormatException('Invalid DirectoryUpdate.items');
      }
      if (!json.containsKey(r'removedIds')) {
        throw const FormatException('Missing DirectoryUpdate.removedIds');
      }
      if (json[r'removedIds'] == null) {
        throw const FormatException('Null DirectoryUpdate.removedIds');
      }
      if (json[r'removedIds'] != null && json[r'removedIds'] is! List) {
        throw const FormatException('Invalid DirectoryUpdate.removedIds');
      }

      return DirectoryUpdate(
        viewEpoch: mapValueOfType<String>(json, r'viewEpoch')!,
        language: DirectoryUpdateLanguageEnum.fromJson(json[r'language'])!,
        serverTime: mapDateTime(json, r'serverTime', r'')!,
        items: Listener.listFromJson(json[r'items']),
        removedIds: json[r'removedIds'] is Iterable
            ? (json[r'removedIds'] as Iterable).cast<String>().toList(growable: false)
            : const [],
      );
    }
    return null;
  }

  static List<DirectoryUpdate> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DirectoryUpdate>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DirectoryUpdate.fromJson(row);
        if (value == null) throw const FormatException('Invalid DirectoryUpdate list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DirectoryUpdate> mapFromJson(dynamic json) {
    final map = <String, DirectoryUpdate>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DirectoryUpdate.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DirectoryUpdate-objects as value to a dart map
  static Map<String, List<DirectoryUpdate>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DirectoryUpdate>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DirectoryUpdate.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'viewEpoch',
    'language',
    'serverTime',
    'items',
    'removedIds',
  };
}


enum DirectoryUpdateLanguageEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const DirectoryUpdateLanguageEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [DirectoryUpdateLanguageEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DirectoryUpdateLanguageEnum? fromJson(dynamic value) => DirectoryUpdateLanguageEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DirectoryUpdateLanguageEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DirectoryUpdateLanguageEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DirectoryUpdateLanguageEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DirectoryUpdateLanguageEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DirectoryUpdateLanguageEnum] to String,
/// and [decode] dynamic data back to [DirectoryUpdateLanguageEnum].
class DirectoryUpdateLanguageEnumTypeTransformer {
  factory DirectoryUpdateLanguageEnumTypeTransformer() => _instance ??= const DirectoryUpdateLanguageEnumTypeTransformer._();

  const DirectoryUpdateLanguageEnumTypeTransformer._();

  String encode(DirectoryUpdateLanguageEnum data) => data._value;

  /// Returns the instance of [DirectoryUpdateLanguageEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DirectoryUpdateLanguageEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DirectoryUpdateLanguageEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return DirectoryUpdateLanguageEnum.ta;
        case r'en': return DirectoryUpdateLanguageEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DirectoryUpdateLanguageEnumTypeTransformer? _instance;
}


