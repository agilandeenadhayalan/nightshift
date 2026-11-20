//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ListenerApplicationInput {
  /// Returns a new [ListenerApplicationInput] instance.
  ListenerApplicationInput({
    required this.bio,
    this.topics = const {},
    this.languages = const {},
    required this.voiceSampleConsent,
    required this.consentVersion,
  });

  String bio;

  Set<ListenerApplicationInputTopicsEnum> topics;

  Set<ListenerApplicationInputLanguagesEnum> languages;

  bool voiceSampleConsent;

  ListenerApplicationInputConsentVersionEnum consentVersion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListenerApplicationInput &&
    other.bio == bio &&
    _deepEquality.equals(other.topics, topics) &&
    _deepEquality.equals(other.languages, languages) &&
    other.voiceSampleConsent == voiceSampleConsent &&
    other.consentVersion == consentVersion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (bio.hashCode) +
    (topics.hashCode) +
    (languages.hashCode) +
    (voiceSampleConsent.hashCode) +
    (consentVersion.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ListenerApplicationInput[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'bio'] = this.bio;
      json[r'topics'] = this.topics.toList(growable: false);
      json[r'languages'] = this.languages.toList(growable: false);
      json[r'voiceSampleConsent'] = this.voiceSampleConsent;
      json[r'consentVersion'] = this.consentVersion;
    return json;
  }

  /// Returns a new [ListenerApplicationInput] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListenerApplicationInput? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ListenerApplicationInput object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'bio')) {
        throw const FormatException('Missing ListenerApplicationInput.bio');
      }
      if (json[r'bio'] == null) {
        throw const FormatException('Null ListenerApplicationInput.bio');
      }
      if (!json.containsKey(r'topics')) {
        throw const FormatException('Missing ListenerApplicationInput.topics');
      }
      if (json[r'topics'] == null) {
        throw const FormatException('Null ListenerApplicationInput.topics');
      }
      if (json[r'topics'] != null && json[r'topics'] is! List) {
        throw const FormatException('Invalid ListenerApplicationInput.topics');
      }
      if (!json.containsKey(r'languages')) {
        throw const FormatException('Missing ListenerApplicationInput.languages');
      }
      if (json[r'languages'] == null) {
        throw const FormatException('Null ListenerApplicationInput.languages');
      }
      if (json[r'languages'] != null && json[r'languages'] is! List) {
        throw const FormatException('Invalid ListenerApplicationInput.languages');
      }
      if (!json.containsKey(r'voiceSampleConsent')) {
        throw const FormatException('Missing ListenerApplicationInput.voiceSampleConsent');
      }
      if (json[r'voiceSampleConsent'] == null) {
        throw const FormatException('Null ListenerApplicationInput.voiceSampleConsent');
      }
      if (json[r'voiceSampleConsent'] != null && json[r'voiceSampleConsent'] is! bool) {
        throw const FormatException('Invalid ListenerApplicationInput.voiceSampleConsent boolean');
      }
      if (!json.containsKey(r'consentVersion')) {
        throw const FormatException('Missing ListenerApplicationInput.consentVersion');
      }
      if (json[r'consentVersion'] == null) {
        throw const FormatException('Null ListenerApplicationInput.consentVersion');
      }

      return ListenerApplicationInput(
        bio: mapValueOfType<String>(json, r'bio')!,
        topics: ListenerApplicationInputTopicsEnum.listFromJson(json[r'topics']).toSet(),
        languages: ListenerApplicationInputLanguagesEnum.listFromJson(json[r'languages']).toSet(),
        voiceSampleConsent: mapValueOfType<bool>(json, r'voiceSampleConsent')!,
        consentVersion: ListenerApplicationInputConsentVersionEnum.fromJson(json[r'consentVersion'])!,
      );
    }
    return null;
  }

  static List<ListenerApplicationInput> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerApplicationInput>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerApplicationInput.fromJson(row);
        if (value == null) throw const FormatException('Invalid ListenerApplicationInput list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListenerApplicationInput> mapFromJson(dynamic json) {
    final map = <String, ListenerApplicationInput>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListenerApplicationInput.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListenerApplicationInput-objects as value to a dart map
  static Map<String, List<ListenerApplicationInput>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListenerApplicationInput>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListenerApplicationInput.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'bio',
    'topics',
    'languages',
    'voiceSampleConsent',
    'consentVersion',
  };
}


enum ListenerApplicationInputTopicsEnum {
  everyday._(r'everyday'),
  work._(r'work'),
  study._(r'study'),
  hobbies._(r'hobbies'),
  languagePractice._(r'language-practice'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerApplicationInputTopicsEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerApplicationInputTopicsEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerApplicationInputTopicsEnum? fromJson(dynamic value) => ListenerApplicationInputTopicsEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerApplicationInputTopicsEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerApplicationInputTopicsEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerApplicationInputTopicsEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerApplicationInputTopicsEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerApplicationInputTopicsEnum] to String,
/// and [decode] dynamic data back to [ListenerApplicationInputTopicsEnum].
class ListenerApplicationInputTopicsEnumTypeTransformer {
  factory ListenerApplicationInputTopicsEnumTypeTransformer() => _instance ??= const ListenerApplicationInputTopicsEnumTypeTransformer._();

  const ListenerApplicationInputTopicsEnumTypeTransformer._();

  String encode(ListenerApplicationInputTopicsEnum data) => data._value;

  /// Returns the instance of [ListenerApplicationInputTopicsEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerApplicationInputTopicsEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerApplicationInputTopicsEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'everyday': return ListenerApplicationInputTopicsEnum.everyday;
        case r'work': return ListenerApplicationInputTopicsEnum.work;
        case r'study': return ListenerApplicationInputTopicsEnum.study;
        case r'hobbies': return ListenerApplicationInputTopicsEnum.hobbies;
        case r'language-practice': return ListenerApplicationInputTopicsEnum.languagePractice;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerApplicationInputTopicsEnumTypeTransformer? _instance;
}



enum ListenerApplicationInputLanguagesEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerApplicationInputLanguagesEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerApplicationInputLanguagesEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerApplicationInputLanguagesEnum? fromJson(dynamic value) => ListenerApplicationInputLanguagesEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerApplicationInputLanguagesEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerApplicationInputLanguagesEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerApplicationInputLanguagesEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerApplicationInputLanguagesEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerApplicationInputLanguagesEnum] to String,
/// and [decode] dynamic data back to [ListenerApplicationInputLanguagesEnum].
class ListenerApplicationInputLanguagesEnumTypeTransformer {
  factory ListenerApplicationInputLanguagesEnumTypeTransformer() => _instance ??= const ListenerApplicationInputLanguagesEnumTypeTransformer._();

  const ListenerApplicationInputLanguagesEnumTypeTransformer._();

  String encode(ListenerApplicationInputLanguagesEnum data) => data._value;

  /// Returns the instance of [ListenerApplicationInputLanguagesEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerApplicationInputLanguagesEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerApplicationInputLanguagesEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return ListenerApplicationInputLanguagesEnum.ta;
        case r'en': return ListenerApplicationInputLanguagesEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerApplicationInputLanguagesEnumTypeTransformer? _instance;
}



enum ListenerApplicationInputConsentVersionEnum {
  listenerReviewV1._(r'listener-review-v1'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerApplicationInputConsentVersionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerApplicationInputConsentVersionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerApplicationInputConsentVersionEnum? fromJson(dynamic value) => ListenerApplicationInputConsentVersionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerApplicationInputConsentVersionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerApplicationInputConsentVersionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerApplicationInputConsentVersionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerApplicationInputConsentVersionEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerApplicationInputConsentVersionEnum] to String,
/// and [decode] dynamic data back to [ListenerApplicationInputConsentVersionEnum].
class ListenerApplicationInputConsentVersionEnumTypeTransformer {
  factory ListenerApplicationInputConsentVersionEnumTypeTransformer() => _instance ??= const ListenerApplicationInputConsentVersionEnumTypeTransformer._();

  const ListenerApplicationInputConsentVersionEnumTypeTransformer._();

  String encode(ListenerApplicationInputConsentVersionEnum data) => data._value;

  /// Returns the instance of [ListenerApplicationInputConsentVersionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerApplicationInputConsentVersionEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerApplicationInputConsentVersionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'listener-review-v1': return ListenerApplicationInputConsentVersionEnum.listenerReviewV1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerApplicationInputConsentVersionEnumTypeTransformer? _instance;
}


