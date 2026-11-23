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
  male01._(r'male_01'),
  male02._(r'male_02'),
  male03._(r'male_03'),
  male04._(r'male_04'),
  male05._(r'male_05'),
  male06._(r'male_06'),
  male07._(r'male_07'),
  male08._(r'male_08'),
  male09._(r'male_09'),
  male10._(r'male_10'),
  male11._(r'male_11'),
  male12._(r'male_12'),
  male13._(r'male_13'),
  male14._(r'male_14'),
  male15._(r'male_15'),
  male16._(r'male_16'),
  male17._(r'male_17'),
  male18._(r'male_18'),
  male19._(r'male_19'),
  male20._(r'male_20'),
  male21._(r'male_21'),
  male22._(r'male_22'),
  male23._(r'male_23'),
  male24._(r'male_24'),
  male25._(r'male_25'),
  male26._(r'male_26'),
  male27._(r'male_27'),
  male28._(r'male_28'),
  male29._(r'male_29'),
  male30._(r'male_30'),
  female01._(r'female_01'),
  female02._(r'female_02'),
  female03._(r'female_03'),
  female04._(r'female_04'),
  female05._(r'female_05'),
  female06._(r'female_06'),
  female07._(r'female_07'),
  female08._(r'female_08'),
  female09._(r'female_09'),
  female10._(r'female_10'),
  female11._(r'female_11'),
  female12._(r'female_12'),
  female13._(r'female_13'),
  female14._(r'female_14'),
  female15._(r'female_15'),
  female16._(r'female_16'),
  female17._(r'female_17'),
  female18._(r'female_18'),
  female19._(r'female_19'),
  female20._(r'female_20'),
  female21._(r'female_21'),
  female22._(r'female_22'),
  female23._(r'female_23'),
  female24._(r'female_24'),
  female25._(r'female_25'),
  female26._(r'female_26'),
  female27._(r'female_27'),
  female28._(r'female_28'),
  female29._(r'female_29'),
  female30._(r'female_30'),
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
        case r'male_01': return OnboardingProfileAvatarCodeEnum.male01;
        case r'male_02': return OnboardingProfileAvatarCodeEnum.male02;
        case r'male_03': return OnboardingProfileAvatarCodeEnum.male03;
        case r'male_04': return OnboardingProfileAvatarCodeEnum.male04;
        case r'male_05': return OnboardingProfileAvatarCodeEnum.male05;
        case r'male_06': return OnboardingProfileAvatarCodeEnum.male06;
        case r'male_07': return OnboardingProfileAvatarCodeEnum.male07;
        case r'male_08': return OnboardingProfileAvatarCodeEnum.male08;
        case r'male_09': return OnboardingProfileAvatarCodeEnum.male09;
        case r'male_10': return OnboardingProfileAvatarCodeEnum.male10;
        case r'male_11': return OnboardingProfileAvatarCodeEnum.male11;
        case r'male_12': return OnboardingProfileAvatarCodeEnum.male12;
        case r'male_13': return OnboardingProfileAvatarCodeEnum.male13;
        case r'male_14': return OnboardingProfileAvatarCodeEnum.male14;
        case r'male_15': return OnboardingProfileAvatarCodeEnum.male15;
        case r'male_16': return OnboardingProfileAvatarCodeEnum.male16;
        case r'male_17': return OnboardingProfileAvatarCodeEnum.male17;
        case r'male_18': return OnboardingProfileAvatarCodeEnum.male18;
        case r'male_19': return OnboardingProfileAvatarCodeEnum.male19;
        case r'male_20': return OnboardingProfileAvatarCodeEnum.male20;
        case r'male_21': return OnboardingProfileAvatarCodeEnum.male21;
        case r'male_22': return OnboardingProfileAvatarCodeEnum.male22;
        case r'male_23': return OnboardingProfileAvatarCodeEnum.male23;
        case r'male_24': return OnboardingProfileAvatarCodeEnum.male24;
        case r'male_25': return OnboardingProfileAvatarCodeEnum.male25;
        case r'male_26': return OnboardingProfileAvatarCodeEnum.male26;
        case r'male_27': return OnboardingProfileAvatarCodeEnum.male27;
        case r'male_28': return OnboardingProfileAvatarCodeEnum.male28;
        case r'male_29': return OnboardingProfileAvatarCodeEnum.male29;
        case r'male_30': return OnboardingProfileAvatarCodeEnum.male30;
        case r'female_01': return OnboardingProfileAvatarCodeEnum.female01;
        case r'female_02': return OnboardingProfileAvatarCodeEnum.female02;
        case r'female_03': return OnboardingProfileAvatarCodeEnum.female03;
        case r'female_04': return OnboardingProfileAvatarCodeEnum.female04;
        case r'female_05': return OnboardingProfileAvatarCodeEnum.female05;
        case r'female_06': return OnboardingProfileAvatarCodeEnum.female06;
        case r'female_07': return OnboardingProfileAvatarCodeEnum.female07;
        case r'female_08': return OnboardingProfileAvatarCodeEnum.female08;
        case r'female_09': return OnboardingProfileAvatarCodeEnum.female09;
        case r'female_10': return OnboardingProfileAvatarCodeEnum.female10;
        case r'female_11': return OnboardingProfileAvatarCodeEnum.female11;
        case r'female_12': return OnboardingProfileAvatarCodeEnum.female12;
        case r'female_13': return OnboardingProfileAvatarCodeEnum.female13;
        case r'female_14': return OnboardingProfileAvatarCodeEnum.female14;
        case r'female_15': return OnboardingProfileAvatarCodeEnum.female15;
        case r'female_16': return OnboardingProfileAvatarCodeEnum.female16;
        case r'female_17': return OnboardingProfileAvatarCodeEnum.female17;
        case r'female_18': return OnboardingProfileAvatarCodeEnum.female18;
        case r'female_19': return OnboardingProfileAvatarCodeEnum.female19;
        case r'female_20': return OnboardingProfileAvatarCodeEnum.female20;
        case r'female_21': return OnboardingProfileAvatarCodeEnum.female21;
        case r'female_22': return OnboardingProfileAvatarCodeEnum.female22;
        case r'female_23': return OnboardingProfileAvatarCodeEnum.female23;
        case r'female_24': return OnboardingProfileAvatarCodeEnum.female24;
        case r'female_25': return OnboardingProfileAvatarCodeEnum.female25;
        case r'female_26': return OnboardingProfileAvatarCodeEnum.female26;
        case r'female_27': return OnboardingProfileAvatarCodeEnum.female27;
        case r'female_28': return OnboardingProfileAvatarCodeEnum.female28;
        case r'female_29': return OnboardingProfileAvatarCodeEnum.female29;
        case r'female_30': return OnboardingProfileAvatarCodeEnum.female30;
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


