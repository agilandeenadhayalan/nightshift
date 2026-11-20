//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class DirectorySubscription {
  /// Returns a new [DirectorySubscription] instance.
  DirectorySubscription({
    required this.viewEpoch,
    required this.language,
    this.visibleIds = const {},
  });

  String viewEpoch;

  DirectorySubscriptionLanguageEnum language;

  Set<String> visibleIds;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DirectorySubscription &&
    other.viewEpoch == viewEpoch &&
    other.language == language &&
    _deepEquality.equals(other.visibleIds, visibleIds);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (viewEpoch.hashCode) +
    (language.hashCode) +
    (visibleIds.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'DirectorySubscription[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'viewEpoch'] = this.viewEpoch;
      json[r'language'] = this.language;
      json[r'visibleIds'] = this.visibleIds.toList(growable: false);
    return json;
  }

  /// Returns a new [DirectorySubscription] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DirectorySubscription? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid DirectorySubscription object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'viewEpoch')) {
        throw const FormatException('Missing DirectorySubscription.viewEpoch');
      }
      if (json[r'viewEpoch'] == null) {
        throw const FormatException('Null DirectorySubscription.viewEpoch');
      }
      if (!json.containsKey(r'language')) {
        throw const FormatException('Missing DirectorySubscription.language');
      }
      if (json[r'language'] == null) {
        throw const FormatException('Null DirectorySubscription.language');
      }
      if (!json.containsKey(r'visibleIds')) {
        throw const FormatException('Missing DirectorySubscription.visibleIds');
      }
      if (json[r'visibleIds'] == null) {
        throw const FormatException('Null DirectorySubscription.visibleIds');
      }
      if (json[r'visibleIds'] != null && json[r'visibleIds'] is! List) {
        throw const FormatException('Invalid DirectorySubscription.visibleIds');
      }

      return DirectorySubscription(
        viewEpoch: mapValueOfType<String>(json, r'viewEpoch')!,
        language: DirectorySubscriptionLanguageEnum.fromJson(json[r'language'])!,
        visibleIds: json[r'visibleIds'] is Iterable
            ? (json[r'visibleIds'] as Iterable).cast<String>().toSet()
            : const {},
      );
    }
    return null;
  }

  static List<DirectorySubscription> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DirectorySubscription>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DirectorySubscription.fromJson(row);
        if (value == null) throw const FormatException('Invalid DirectorySubscription list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DirectorySubscription> mapFromJson(dynamic json) {
    final map = <String, DirectorySubscription>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DirectorySubscription.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DirectorySubscription-objects as value to a dart map
  static Map<String, List<DirectorySubscription>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DirectorySubscription>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DirectorySubscription.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'viewEpoch',
    'language',
    'visibleIds',
  };
}


enum DirectorySubscriptionLanguageEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const DirectorySubscriptionLanguageEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [DirectorySubscriptionLanguageEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DirectorySubscriptionLanguageEnum? fromJson(dynamic value) => DirectorySubscriptionLanguageEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DirectorySubscriptionLanguageEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DirectorySubscriptionLanguageEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DirectorySubscriptionLanguageEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DirectorySubscriptionLanguageEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DirectorySubscriptionLanguageEnum] to String,
/// and [decode] dynamic data back to [DirectorySubscriptionLanguageEnum].
class DirectorySubscriptionLanguageEnumTypeTransformer {
  factory DirectorySubscriptionLanguageEnumTypeTransformer() => _instance ??= const DirectorySubscriptionLanguageEnumTypeTransformer._();

  const DirectorySubscriptionLanguageEnumTypeTransformer._();

  String encode(DirectorySubscriptionLanguageEnum data) => data._value;

  /// Returns the instance of [DirectorySubscriptionLanguageEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DirectorySubscriptionLanguageEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DirectorySubscriptionLanguageEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return DirectorySubscriptionLanguageEnum.ta;
        case r'en': return DirectorySubscriptionLanguageEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DirectorySubscriptionLanguageEnumTypeTransformer? _instance;
}


