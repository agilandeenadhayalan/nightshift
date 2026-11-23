//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class User {
  /// Returns a new [User] instance.
  User({
    required this.id,
    required this.displayName,
    this.languages = const [],
    required this.mode,
    required this.listenerApproved,
    required this.online,
    this.avatarCode,
    this.availability,
  });

  String id;

  String displayName;

  List<UserLanguagesEnum> languages;

  UserModeEnum mode;

  bool listenerApproved;

  bool online;

  UserAvatarCodeEnum? avatarCode;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  ListenerAvailability? availability;

  @override
  bool operator ==(Object other) => identical(this, other) || other is User &&
    other.id == id &&
    other.displayName == displayName &&
    _deepEquality.equals(other.languages, languages) &&
    other.mode == mode &&
    other.listenerApproved == listenerApproved &&
    other.online == online &&
    other.avatarCode == avatarCode &&
    other.availability == availability;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (displayName.hashCode) +
    (languages.hashCode) +
    (mode.hashCode) +
    (listenerApproved.hashCode) +
    (online.hashCode) +
    (avatarCode == null ? 0 : avatarCode!.hashCode) +
    (availability == null ? 0 : availability!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'User[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'displayName'] = this.displayName;
      json[r'languages'] = this.languages;
      json[r'mode'] = this.mode;
      json[r'listenerApproved'] = this.listenerApproved;
      json[r'online'] = this.online;
    if (this.avatarCode != null) {
      json[r'avatarCode'] = this.avatarCode;
    }
    if (this.availability != null) {
      json[r'availability'] = this.availability;
    }
    return json;
  }

  /// Returns a new [User] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static User? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid User object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing User.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null User.id');
      }
      if (!json.containsKey(r'displayName')) {
        throw const FormatException('Missing User.displayName');
      }
      if (json[r'displayName'] == null) {
        throw const FormatException('Null User.displayName');
      }
      if (!json.containsKey(r'languages')) {
        throw const FormatException('Missing User.languages');
      }
      if (json[r'languages'] == null) {
        throw const FormatException('Null User.languages');
      }
      if (json[r'languages'] != null && json[r'languages'] is! List) {
        throw const FormatException('Invalid User.languages');
      }
      if (!json.containsKey(r'mode')) {
        throw const FormatException('Missing User.mode');
      }
      if (json[r'mode'] == null) {
        throw const FormatException('Null User.mode');
      }
      if (!json.containsKey(r'listenerApproved')) {
        throw const FormatException('Missing User.listenerApproved');
      }
      if (json[r'listenerApproved'] == null) {
        throw const FormatException('Null User.listenerApproved');
      }
      if (json[r'listenerApproved'] != null && json[r'listenerApproved'] is! bool) {
        throw const FormatException('Invalid User.listenerApproved boolean');
      }
      if (!json.containsKey(r'online')) {
        throw const FormatException('Missing User.online');
      }
      if (json[r'online'] == null) {
        throw const FormatException('Null User.online');
      }
      if (json[r'online'] != null && json[r'online'] is! bool) {
        throw const FormatException('Invalid User.online boolean');
      }

      return User(
        id: mapValueOfType<String>(json, r'id')!,
        displayName: mapValueOfType<String>(json, r'displayName')!,
        languages: UserLanguagesEnum.listFromJson(json[r'languages']),
        mode: UserModeEnum.fromJson(json[r'mode'])!,
        listenerApproved: mapValueOfType<bool>(json, r'listenerApproved')!,
        online: mapValueOfType<bool>(json, r'online')!,
        avatarCode: UserAvatarCodeEnum.fromJson(json[r'avatarCode']),
        availability: ListenerAvailability.fromJson(json[r'availability']),
      );
    }
    return null;
  }

  static List<User> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <User>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = User.fromJson(row);
        if (value == null) throw const FormatException('Invalid User list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, User> mapFromJson(dynamic json) {
    final map = <String, User>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = User.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of User-objects as value to a dart map
  static Map<String, List<User>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<User>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = User.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'displayName',
    'languages',
    'mode',
    'listenerApproved',
    'online',
  };
}


enum UserLanguagesEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const UserLanguagesEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [UserLanguagesEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static UserLanguagesEnum? fromJson(dynamic value) => UserLanguagesEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [UserLanguagesEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<UserLanguagesEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserLanguagesEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserLanguagesEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [UserLanguagesEnum] to String,
/// and [decode] dynamic data back to [UserLanguagesEnum].
class UserLanguagesEnumTypeTransformer {
  factory UserLanguagesEnumTypeTransformer() => _instance ??= const UserLanguagesEnumTypeTransformer._();

  const UserLanguagesEnumTypeTransformer._();

  String encode(UserLanguagesEnum data) => data._value;

  /// Returns the instance of [UserLanguagesEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  UserLanguagesEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is UserLanguagesEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return UserLanguagesEnum.ta;
        case r'en': return UserLanguagesEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static UserLanguagesEnumTypeTransformer? _instance;
}



enum UserModeEnum {
  customer._(r'customer'),
  listener._(r'listener'),
  ;

  /// Instantiate a new enum with the provided value.
  const UserModeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [UserModeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static UserModeEnum? fromJson(dynamic value) => UserModeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [UserModeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<UserModeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserModeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserModeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [UserModeEnum] to String,
/// and [decode] dynamic data back to [UserModeEnum].
class UserModeEnumTypeTransformer {
  factory UserModeEnumTypeTransformer() => _instance ??= const UserModeEnumTypeTransformer._();

  const UserModeEnumTypeTransformer._();

  String encode(UserModeEnum data) => data._value;

  /// Returns the instance of [UserModeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  UserModeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is UserModeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'customer': return UserModeEnum.customer;
        case r'listener': return UserModeEnum.listener;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static UserModeEnumTypeTransformer? _instance;
}



enum UserAvatarCodeEnum {
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
  const UserAvatarCodeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [UserAvatarCodeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static UserAvatarCodeEnum? fromJson(dynamic value) => UserAvatarCodeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [UserAvatarCodeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<UserAvatarCodeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserAvatarCodeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserAvatarCodeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [UserAvatarCodeEnum] to String,
/// and [decode] dynamic data back to [UserAvatarCodeEnum].
class UserAvatarCodeEnumTypeTransformer {
  factory UserAvatarCodeEnumTypeTransformer() => _instance ??= const UserAvatarCodeEnumTypeTransformer._();

  const UserAvatarCodeEnumTypeTransformer._();

  String encode(UserAvatarCodeEnum data) => data._value;

  /// Returns the instance of [UserAvatarCodeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  UserAvatarCodeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is UserAvatarCodeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'moon': return UserAvatarCodeEnum.moon;
        case r'star': return UserAvatarCodeEnum.star;
        case r'leaf': return UserAvatarCodeEnum.leaf;
        case r'wave': return UserAvatarCodeEnum.wave;
        case r'male_01': return UserAvatarCodeEnum.male01;
        case r'male_02': return UserAvatarCodeEnum.male02;
        case r'male_03': return UserAvatarCodeEnum.male03;
        case r'male_04': return UserAvatarCodeEnum.male04;
        case r'male_05': return UserAvatarCodeEnum.male05;
        case r'male_06': return UserAvatarCodeEnum.male06;
        case r'male_07': return UserAvatarCodeEnum.male07;
        case r'male_08': return UserAvatarCodeEnum.male08;
        case r'male_09': return UserAvatarCodeEnum.male09;
        case r'male_10': return UserAvatarCodeEnum.male10;
        case r'male_11': return UserAvatarCodeEnum.male11;
        case r'male_12': return UserAvatarCodeEnum.male12;
        case r'male_13': return UserAvatarCodeEnum.male13;
        case r'male_14': return UserAvatarCodeEnum.male14;
        case r'male_15': return UserAvatarCodeEnum.male15;
        case r'male_16': return UserAvatarCodeEnum.male16;
        case r'male_17': return UserAvatarCodeEnum.male17;
        case r'male_18': return UserAvatarCodeEnum.male18;
        case r'male_19': return UserAvatarCodeEnum.male19;
        case r'male_20': return UserAvatarCodeEnum.male20;
        case r'male_21': return UserAvatarCodeEnum.male21;
        case r'male_22': return UserAvatarCodeEnum.male22;
        case r'male_23': return UserAvatarCodeEnum.male23;
        case r'male_24': return UserAvatarCodeEnum.male24;
        case r'male_25': return UserAvatarCodeEnum.male25;
        case r'male_26': return UserAvatarCodeEnum.male26;
        case r'male_27': return UserAvatarCodeEnum.male27;
        case r'male_28': return UserAvatarCodeEnum.male28;
        case r'male_29': return UserAvatarCodeEnum.male29;
        case r'male_30': return UserAvatarCodeEnum.male30;
        case r'female_01': return UserAvatarCodeEnum.female01;
        case r'female_02': return UserAvatarCodeEnum.female02;
        case r'female_03': return UserAvatarCodeEnum.female03;
        case r'female_04': return UserAvatarCodeEnum.female04;
        case r'female_05': return UserAvatarCodeEnum.female05;
        case r'female_06': return UserAvatarCodeEnum.female06;
        case r'female_07': return UserAvatarCodeEnum.female07;
        case r'female_08': return UserAvatarCodeEnum.female08;
        case r'female_09': return UserAvatarCodeEnum.female09;
        case r'female_10': return UserAvatarCodeEnum.female10;
        case r'female_11': return UserAvatarCodeEnum.female11;
        case r'female_12': return UserAvatarCodeEnum.female12;
        case r'female_13': return UserAvatarCodeEnum.female13;
        case r'female_14': return UserAvatarCodeEnum.female14;
        case r'female_15': return UserAvatarCodeEnum.female15;
        case r'female_16': return UserAvatarCodeEnum.female16;
        case r'female_17': return UserAvatarCodeEnum.female17;
        case r'female_18': return UserAvatarCodeEnum.female18;
        case r'female_19': return UserAvatarCodeEnum.female19;
        case r'female_20': return UserAvatarCodeEnum.female20;
        case r'female_21': return UserAvatarCodeEnum.female21;
        case r'female_22': return UserAvatarCodeEnum.female22;
        case r'female_23': return UserAvatarCodeEnum.female23;
        case r'female_24': return UserAvatarCodeEnum.female24;
        case r'female_25': return UserAvatarCodeEnum.female25;
        case r'female_26': return UserAvatarCodeEnum.female26;
        case r'female_27': return UserAvatarCodeEnum.female27;
        case r'female_28': return UserAvatarCodeEnum.female28;
        case r'female_29': return UserAvatarCodeEnum.female29;
        case r'female_30': return UserAvatarCodeEnum.female30;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static UserAvatarCodeEnumTypeTransformer? _instance;
}


