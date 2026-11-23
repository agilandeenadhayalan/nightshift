//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class CompleteOnboardingRequest {
  /// Returns a new [CompleteOnboardingRequest] instance.
  CompleteOnboardingRequest({
    required this.displayName,
    required this.avatarCode,
    required this.interfaceLanguage,
    this.languages = const {},
    required this.dateOfBirth,
    required this.consentVersion,
  });

  String displayName;

  CompleteOnboardingRequestAvatarCodeEnum avatarCode;

  CompleteOnboardingRequestInterfaceLanguageEnum interfaceLanguage;

  Set<CompleteOnboardingRequestLanguagesEnum> languages;

  DateTime dateOfBirth;

  CompleteOnboardingRequestConsentVersionEnum consentVersion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CompleteOnboardingRequest &&
    other.displayName == displayName &&
    other.avatarCode == avatarCode &&
    other.interfaceLanguage == interfaceLanguage &&
    _deepEquality.equals(other.languages, languages) &&
    other.dateOfBirth == dateOfBirth &&
    other.consentVersion == consentVersion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (displayName.hashCode) +
    (avatarCode.hashCode) +
    (interfaceLanguage.hashCode) +
    (languages.hashCode) +
    (dateOfBirth.hashCode) +
    (consentVersion.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'CompleteOnboardingRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'displayName'] = this.displayName;
      json[r'avatarCode'] = this.avatarCode;
      json[r'interfaceLanguage'] = this.interfaceLanguage;
      json[r'languages'] = this.languages.toList(growable: false);
      json[r'dateOfBirth'] = _dateFormatter.format(this.dateOfBirth);
      json[r'consentVersion'] = this.consentVersion;
    return json;
  }

  /// Returns a new [CompleteOnboardingRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CompleteOnboardingRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid CompleteOnboardingRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'displayName')) {
        throw const FormatException('Missing CompleteOnboardingRequest.displayName');
      }
      if (json[r'displayName'] == null) {
        throw const FormatException('Null CompleteOnboardingRequest.displayName');
      }
      if (!json.containsKey(r'avatarCode')) {
        throw const FormatException('Missing CompleteOnboardingRequest.avatarCode');
      }
      if (json[r'avatarCode'] == null) {
        throw const FormatException('Null CompleteOnboardingRequest.avatarCode');
      }
      if (!json.containsKey(r'interfaceLanguage')) {
        throw const FormatException('Missing CompleteOnboardingRequest.interfaceLanguage');
      }
      if (json[r'interfaceLanguage'] == null) {
        throw const FormatException('Null CompleteOnboardingRequest.interfaceLanguage');
      }
      if (!json.containsKey(r'languages')) {
        throw const FormatException('Missing CompleteOnboardingRequest.languages');
      }
      if (json[r'languages'] == null) {
        throw const FormatException('Null CompleteOnboardingRequest.languages');
      }
      if (json[r'languages'] != null && json[r'languages'] is! List) {
        throw const FormatException('Invalid CompleteOnboardingRequest.languages');
      }
      if (!json.containsKey(r'dateOfBirth')) {
        throw const FormatException('Missing CompleteOnboardingRequest.dateOfBirth');
      }
      if (json[r'dateOfBirth'] == null) {
        throw const FormatException('Null CompleteOnboardingRequest.dateOfBirth');
      }
      if (!json.containsKey(r'consentVersion')) {
        throw const FormatException('Missing CompleteOnboardingRequest.consentVersion');
      }
      if (json[r'consentVersion'] == null) {
        throw const FormatException('Null CompleteOnboardingRequest.consentVersion');
      }

      return CompleteOnboardingRequest(
        displayName: mapValueOfType<String>(json, r'displayName')!,
        avatarCode: CompleteOnboardingRequestAvatarCodeEnum.fromJson(json[r'avatarCode'])!,
        interfaceLanguage: CompleteOnboardingRequestInterfaceLanguageEnum.fromJson(json[r'interfaceLanguage'])!,
        languages: CompleteOnboardingRequestLanguagesEnum.listFromJson(json[r'languages']).toSet(),
        dateOfBirth: mapDateTime(json, r'dateOfBirth', r'')!,
        consentVersion: CompleteOnboardingRequestConsentVersionEnum.fromJson(json[r'consentVersion'])!,
      );
    }
    return null;
  }

  static List<CompleteOnboardingRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CompleteOnboardingRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CompleteOnboardingRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid CompleteOnboardingRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CompleteOnboardingRequest> mapFromJson(dynamic json) {
    final map = <String, CompleteOnboardingRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CompleteOnboardingRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CompleteOnboardingRequest-objects as value to a dart map
  static Map<String, List<CompleteOnboardingRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CompleteOnboardingRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CompleteOnboardingRequest.listFromJson(entry.value, growable: growable,);
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
    'consentVersion',
  };
}


enum CompleteOnboardingRequestAvatarCodeEnum {
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
  const CompleteOnboardingRequestAvatarCodeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CompleteOnboardingRequestAvatarCodeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CompleteOnboardingRequestAvatarCodeEnum? fromJson(dynamic value) => CompleteOnboardingRequestAvatarCodeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CompleteOnboardingRequestAvatarCodeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CompleteOnboardingRequestAvatarCodeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CompleteOnboardingRequestAvatarCodeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CompleteOnboardingRequestAvatarCodeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CompleteOnboardingRequestAvatarCodeEnum] to String,
/// and [decode] dynamic data back to [CompleteOnboardingRequestAvatarCodeEnum].
class CompleteOnboardingRequestAvatarCodeEnumTypeTransformer {
  factory CompleteOnboardingRequestAvatarCodeEnumTypeTransformer() => _instance ??= const CompleteOnboardingRequestAvatarCodeEnumTypeTransformer._();

  const CompleteOnboardingRequestAvatarCodeEnumTypeTransformer._();

  String encode(CompleteOnboardingRequestAvatarCodeEnum data) => data._value;

  /// Returns the instance of [CompleteOnboardingRequestAvatarCodeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CompleteOnboardingRequestAvatarCodeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CompleteOnboardingRequestAvatarCodeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'moon': return CompleteOnboardingRequestAvatarCodeEnum.moon;
        case r'star': return CompleteOnboardingRequestAvatarCodeEnum.star;
        case r'leaf': return CompleteOnboardingRequestAvatarCodeEnum.leaf;
        case r'wave': return CompleteOnboardingRequestAvatarCodeEnum.wave;
        case r'male_01': return CompleteOnboardingRequestAvatarCodeEnum.male01;
        case r'male_02': return CompleteOnboardingRequestAvatarCodeEnum.male02;
        case r'male_03': return CompleteOnboardingRequestAvatarCodeEnum.male03;
        case r'male_04': return CompleteOnboardingRequestAvatarCodeEnum.male04;
        case r'male_05': return CompleteOnboardingRequestAvatarCodeEnum.male05;
        case r'male_06': return CompleteOnboardingRequestAvatarCodeEnum.male06;
        case r'male_07': return CompleteOnboardingRequestAvatarCodeEnum.male07;
        case r'male_08': return CompleteOnboardingRequestAvatarCodeEnum.male08;
        case r'male_09': return CompleteOnboardingRequestAvatarCodeEnum.male09;
        case r'male_10': return CompleteOnboardingRequestAvatarCodeEnum.male10;
        case r'male_11': return CompleteOnboardingRequestAvatarCodeEnum.male11;
        case r'male_12': return CompleteOnboardingRequestAvatarCodeEnum.male12;
        case r'male_13': return CompleteOnboardingRequestAvatarCodeEnum.male13;
        case r'male_14': return CompleteOnboardingRequestAvatarCodeEnum.male14;
        case r'male_15': return CompleteOnboardingRequestAvatarCodeEnum.male15;
        case r'male_16': return CompleteOnboardingRequestAvatarCodeEnum.male16;
        case r'male_17': return CompleteOnboardingRequestAvatarCodeEnum.male17;
        case r'male_18': return CompleteOnboardingRequestAvatarCodeEnum.male18;
        case r'male_19': return CompleteOnboardingRequestAvatarCodeEnum.male19;
        case r'male_20': return CompleteOnboardingRequestAvatarCodeEnum.male20;
        case r'male_21': return CompleteOnboardingRequestAvatarCodeEnum.male21;
        case r'male_22': return CompleteOnboardingRequestAvatarCodeEnum.male22;
        case r'male_23': return CompleteOnboardingRequestAvatarCodeEnum.male23;
        case r'male_24': return CompleteOnboardingRequestAvatarCodeEnum.male24;
        case r'male_25': return CompleteOnboardingRequestAvatarCodeEnum.male25;
        case r'male_26': return CompleteOnboardingRequestAvatarCodeEnum.male26;
        case r'male_27': return CompleteOnboardingRequestAvatarCodeEnum.male27;
        case r'male_28': return CompleteOnboardingRequestAvatarCodeEnum.male28;
        case r'male_29': return CompleteOnboardingRequestAvatarCodeEnum.male29;
        case r'male_30': return CompleteOnboardingRequestAvatarCodeEnum.male30;
        case r'female_01': return CompleteOnboardingRequestAvatarCodeEnum.female01;
        case r'female_02': return CompleteOnboardingRequestAvatarCodeEnum.female02;
        case r'female_03': return CompleteOnboardingRequestAvatarCodeEnum.female03;
        case r'female_04': return CompleteOnboardingRequestAvatarCodeEnum.female04;
        case r'female_05': return CompleteOnboardingRequestAvatarCodeEnum.female05;
        case r'female_06': return CompleteOnboardingRequestAvatarCodeEnum.female06;
        case r'female_07': return CompleteOnboardingRequestAvatarCodeEnum.female07;
        case r'female_08': return CompleteOnboardingRequestAvatarCodeEnum.female08;
        case r'female_09': return CompleteOnboardingRequestAvatarCodeEnum.female09;
        case r'female_10': return CompleteOnboardingRequestAvatarCodeEnum.female10;
        case r'female_11': return CompleteOnboardingRequestAvatarCodeEnum.female11;
        case r'female_12': return CompleteOnboardingRequestAvatarCodeEnum.female12;
        case r'female_13': return CompleteOnboardingRequestAvatarCodeEnum.female13;
        case r'female_14': return CompleteOnboardingRequestAvatarCodeEnum.female14;
        case r'female_15': return CompleteOnboardingRequestAvatarCodeEnum.female15;
        case r'female_16': return CompleteOnboardingRequestAvatarCodeEnum.female16;
        case r'female_17': return CompleteOnboardingRequestAvatarCodeEnum.female17;
        case r'female_18': return CompleteOnboardingRequestAvatarCodeEnum.female18;
        case r'female_19': return CompleteOnboardingRequestAvatarCodeEnum.female19;
        case r'female_20': return CompleteOnboardingRequestAvatarCodeEnum.female20;
        case r'female_21': return CompleteOnboardingRequestAvatarCodeEnum.female21;
        case r'female_22': return CompleteOnboardingRequestAvatarCodeEnum.female22;
        case r'female_23': return CompleteOnboardingRequestAvatarCodeEnum.female23;
        case r'female_24': return CompleteOnboardingRequestAvatarCodeEnum.female24;
        case r'female_25': return CompleteOnboardingRequestAvatarCodeEnum.female25;
        case r'female_26': return CompleteOnboardingRequestAvatarCodeEnum.female26;
        case r'female_27': return CompleteOnboardingRequestAvatarCodeEnum.female27;
        case r'female_28': return CompleteOnboardingRequestAvatarCodeEnum.female28;
        case r'female_29': return CompleteOnboardingRequestAvatarCodeEnum.female29;
        case r'female_30': return CompleteOnboardingRequestAvatarCodeEnum.female30;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CompleteOnboardingRequestAvatarCodeEnumTypeTransformer? _instance;
}



enum CompleteOnboardingRequestInterfaceLanguageEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const CompleteOnboardingRequestInterfaceLanguageEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CompleteOnboardingRequestInterfaceLanguageEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CompleteOnboardingRequestInterfaceLanguageEnum? fromJson(dynamic value) => CompleteOnboardingRequestInterfaceLanguageEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CompleteOnboardingRequestInterfaceLanguageEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CompleteOnboardingRequestInterfaceLanguageEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CompleteOnboardingRequestInterfaceLanguageEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CompleteOnboardingRequestInterfaceLanguageEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CompleteOnboardingRequestInterfaceLanguageEnum] to String,
/// and [decode] dynamic data back to [CompleteOnboardingRequestInterfaceLanguageEnum].
class CompleteOnboardingRequestInterfaceLanguageEnumTypeTransformer {
  factory CompleteOnboardingRequestInterfaceLanguageEnumTypeTransformer() => _instance ??= const CompleteOnboardingRequestInterfaceLanguageEnumTypeTransformer._();

  const CompleteOnboardingRequestInterfaceLanguageEnumTypeTransformer._();

  String encode(CompleteOnboardingRequestInterfaceLanguageEnum data) => data._value;

  /// Returns the instance of [CompleteOnboardingRequestInterfaceLanguageEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CompleteOnboardingRequestInterfaceLanguageEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CompleteOnboardingRequestInterfaceLanguageEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return CompleteOnboardingRequestInterfaceLanguageEnum.ta;
        case r'en': return CompleteOnboardingRequestInterfaceLanguageEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CompleteOnboardingRequestInterfaceLanguageEnumTypeTransformer? _instance;
}



enum CompleteOnboardingRequestLanguagesEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const CompleteOnboardingRequestLanguagesEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CompleteOnboardingRequestLanguagesEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CompleteOnboardingRequestLanguagesEnum? fromJson(dynamic value) => CompleteOnboardingRequestLanguagesEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CompleteOnboardingRequestLanguagesEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CompleteOnboardingRequestLanguagesEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CompleteOnboardingRequestLanguagesEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CompleteOnboardingRequestLanguagesEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CompleteOnboardingRequestLanguagesEnum] to String,
/// and [decode] dynamic data back to [CompleteOnboardingRequestLanguagesEnum].
class CompleteOnboardingRequestLanguagesEnumTypeTransformer {
  factory CompleteOnboardingRequestLanguagesEnumTypeTransformer() => _instance ??= const CompleteOnboardingRequestLanguagesEnumTypeTransformer._();

  const CompleteOnboardingRequestLanguagesEnumTypeTransformer._();

  String encode(CompleteOnboardingRequestLanguagesEnum data) => data._value;

  /// Returns the instance of [CompleteOnboardingRequestLanguagesEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CompleteOnboardingRequestLanguagesEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CompleteOnboardingRequestLanguagesEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return CompleteOnboardingRequestLanguagesEnum.ta;
        case r'en': return CompleteOnboardingRequestLanguagesEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CompleteOnboardingRequestLanguagesEnumTypeTransformer? _instance;
}



enum CompleteOnboardingRequestConsentVersionEnum {
  adultOnboardingV1._(r'adult-onboarding-v1'),
  ;

  /// Instantiate a new enum with the provided value.
  const CompleteOnboardingRequestConsentVersionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CompleteOnboardingRequestConsentVersionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CompleteOnboardingRequestConsentVersionEnum? fromJson(dynamic value) => CompleteOnboardingRequestConsentVersionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CompleteOnboardingRequestConsentVersionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CompleteOnboardingRequestConsentVersionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CompleteOnboardingRequestConsentVersionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CompleteOnboardingRequestConsentVersionEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CompleteOnboardingRequestConsentVersionEnum] to String,
/// and [decode] dynamic data back to [CompleteOnboardingRequestConsentVersionEnum].
class CompleteOnboardingRequestConsentVersionEnumTypeTransformer {
  factory CompleteOnboardingRequestConsentVersionEnumTypeTransformer() => _instance ??= const CompleteOnboardingRequestConsentVersionEnumTypeTransformer._();

  const CompleteOnboardingRequestConsentVersionEnumTypeTransformer._();

  String encode(CompleteOnboardingRequestConsentVersionEnum data) => data._value;

  /// Returns the instance of [CompleteOnboardingRequestConsentVersionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CompleteOnboardingRequestConsentVersionEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CompleteOnboardingRequestConsentVersionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'adult-onboarding-v1': return CompleteOnboardingRequestConsentVersionEnum.adultOnboardingV1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CompleteOnboardingRequestConsentVersionEnumTypeTransformer? _instance;
}


