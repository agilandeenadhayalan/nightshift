//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class OnboardingProfile {
  /// Returns a new [OnboardingProfile] instance.
  OnboardingProfile({
    required this.displayName,
    required this.avatarCode,
    required this.interfaceLanguage,
    this.languages = const {},
    required this.dateOfBirth,
  });

  String displayName;

  OnboardingProfileAvatarCodeEnum avatarCode;

  OnboardingProfileInterfaceLanguageEnum interfaceLanguage;

  Set<OnboardingProfileLanguagesEnum> languages;

  DateTime? dateOfBirth;

  @override
  bool operator ==(Object other) => identical(this, other) || other is OnboardingProfile &&
    other.displayName == displayName &&
    other.avatarCode == avatarCode &&
    other.interfaceLanguage == interfaceLanguage &&
    _deepEquality.equals(other.languages, languages) &&
    other.dateOfBirth == dateOfBirth;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (displayName.hashCode) +
    (avatarCode.hashCode) +
    (interfaceLanguage.hashCode) +
    (languages.hashCode) +
    (dateOfBirth == null ? 0 : dateOfBirth!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'OnboardingProfile[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'displayName'] = this.displayName;
      json[r'avatarCode'] = this.avatarCode;
      json[r'interfaceLanguage'] = this.interfaceLanguage;
      json[r'languages'] = this.languages.toList(growable: false);
    if (this.dateOfBirth != null) {
      json[r'dateOfBirth'] = _dateFormatter.format(this.dateOfBirth!);
    } else {
      json[r'dateOfBirth'] = null;
    }
    return json;
  }

  /// Returns a new [OnboardingProfile] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static OnboardingProfile? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid OnboardingProfile object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'displayName')) {
        throw const FormatException('Missing OnboardingProfile.displayName');
      }
      if (json[r'displayName'] == null) {
        throw const FormatException('Null OnboardingProfile.displayName');
      }
      if (!json.containsKey(r'avatarCode')) {
        throw const FormatException('Missing OnboardingProfile.avatarCode');
      }
      if (json[r'avatarCode'] == null) {
        throw const FormatException('Null OnboardingProfile.avatarCode');
      }
      if (!json.containsKey(r'interfaceLanguage')) {
        throw const FormatException('Missing OnboardingProfile.interfaceLanguage');
      }
      if (json[r'interfaceLanguage'] == null) {
        throw const FormatException('Null OnboardingProfile.interfaceLanguage');
      }
      if (!json.containsKey(r'languages')) {
        throw const FormatException('Missing OnboardingProfile.languages');
      }
      if (json[r'languages'] == null) {
        throw const FormatException('Null OnboardingProfile.languages');
      }
      if (json[r'languages'] != null && json[r'languages'] is! List) {
        throw const FormatException('Invalid OnboardingProfile.languages');
      }
      if (!json.containsKey(r'dateOfBirth')) {
        throw const FormatException('Missing OnboardingProfile.dateOfBirth');
      }

      return OnboardingProfile(
        displayName: mapValueOfType<String>(json, r'displayName')!,
        avatarCode: OnboardingProfileAvatarCodeEnum.fromJson(json[r'avatarCode'])!,
        interfaceLanguage: OnboardingProfileInterfaceLanguageEnum.fromJson(json[r'interfaceLanguage'])!,
        languages: OnboardingProfileLanguagesEnum.listFromJson(json[r'languages']).toSet(),
        dateOfBirth: mapDateTime(json, r'dateOfBirth', r''),
      );
    }
    return null;
  }

  static List<OnboardingProfile> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OnboardingProfile>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OnboardingProfile.fromJson(row);
        if (value == null) throw const FormatException('Invalid OnboardingProfile list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, OnboardingProfile> mapFromJson(dynamic json) {
    final map = <String, OnboardingProfile>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = OnboardingProfile.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of OnboardingProfile-objects as value to a dart map
  static Map<String, List<OnboardingProfile>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<OnboardingProfile>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = OnboardingProfile.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'displayName',
    'avatarCode',
    'interfaceLanguage',
    'languages',
    'dateOfBirth',
  };
}


enum OnboardingProfileAvatarCodeEnum {
  moon._(r'moon'),
  star._(r'star'),
  leaf._(r'leaf'),
  wave._(r'wave'),
  ;

  /// Instantiate a new enum with the provided value.
  const OnboardingProfileAvatarCodeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [OnboardingProfileAvatarCodeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static OnboardingProfileAvatarCodeEnum? fromJson(dynamic value) => OnboardingProfileAvatarCodeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [OnboardingProfileAvatarCodeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<OnboardingProfileAvatarCodeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OnboardingProfileAvatarCodeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OnboardingProfileAvatarCodeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [OnboardingProfileAvatarCodeEnum] to String,
/// and [decode] dynamic data back to [OnboardingProfileAvatarCodeEnum].
class OnboardingProfileAvatarCodeEnumTypeTransformer {
  factory OnboardingProfileAvatarCodeEnumTypeTransformer() => _instance ??= const OnboardingProfileAvatarCodeEnumTypeTransformer._();

  const OnboardingProfileAvatarCodeEnumTypeTransformer._();

  String encode(OnboardingProfileAvatarCodeEnum data) => data._value;

  /// Returns the instance of [OnboardingProfileAvatarCodeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  OnboardingProfileAvatarCodeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is OnboardingProfileAvatarCodeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'moon': return OnboardingProfileAvatarCodeEnum.moon;
        case r'star': return OnboardingProfileAvatarCodeEnum.star;
        case r'leaf': return OnboardingProfileAvatarCodeEnum.leaf;
        case r'wave': return OnboardingProfileAvatarCodeEnum.wave;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static OnboardingProfileAvatarCodeEnumTypeTransformer? _instance;
}



enum OnboardingProfileInterfaceLanguageEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const OnboardingProfileInterfaceLanguageEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [OnboardingProfileInterfaceLanguageEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static OnboardingProfileInterfaceLanguageEnum? fromJson(dynamic value) => OnboardingProfileInterfaceLanguageEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [OnboardingProfileInterfaceLanguageEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<OnboardingProfileInterfaceLanguageEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OnboardingProfileInterfaceLanguageEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OnboardingProfileInterfaceLanguageEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [OnboardingProfileInterfaceLanguageEnum] to String,
/// and [decode] dynamic data back to [OnboardingProfileInterfaceLanguageEnum].
class OnboardingProfileInterfaceLanguageEnumTypeTransformer {
  factory OnboardingProfileInterfaceLanguageEnumTypeTransformer() => _instance ??= const OnboardingProfileInterfaceLanguageEnumTypeTransformer._();

  const OnboardingProfileInterfaceLanguageEnumTypeTransformer._();

  String encode(OnboardingProfileInterfaceLanguageEnum data) => data._value;

  /// Returns the instance of [OnboardingProfileInterfaceLanguageEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  OnboardingProfileInterfaceLanguageEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is OnboardingProfileInterfaceLanguageEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return OnboardingProfileInterfaceLanguageEnum.ta;
        case r'en': return OnboardingProfileInterfaceLanguageEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static OnboardingProfileInterfaceLanguageEnumTypeTransformer? _instance;
}



enum OnboardingProfileLanguagesEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const OnboardingProfileLanguagesEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [OnboardingProfileLanguagesEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static OnboardingProfileLanguagesEnum? fromJson(dynamic value) => OnboardingProfileLanguagesEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [OnboardingProfileLanguagesEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<OnboardingProfileLanguagesEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OnboardingProfileLanguagesEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OnboardingProfileLanguagesEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [OnboardingProfileLanguagesEnum] to String,
/// and [decode] dynamic data back to [OnboardingProfileLanguagesEnum].
class OnboardingProfileLanguagesEnumTypeTransformer {
  factory OnboardingProfileLanguagesEnumTypeTransformer() => _instance ??= const OnboardingProfileLanguagesEnumTypeTransformer._();

  const OnboardingProfileLanguagesEnumTypeTransformer._();

  String encode(OnboardingProfileLanguagesEnum data) => data._value;

  /// Returns the instance of [OnboardingProfileLanguagesEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  OnboardingProfileLanguagesEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is OnboardingProfileLanguagesEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return OnboardingProfileLanguagesEnum.ta;
        case r'en': return OnboardingProfileLanguagesEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static OnboardingProfileLanguagesEnumTypeTransformer? _instance;
}


