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
  });

  String id;

  String displayName;

  List<UserLanguagesEnum> languages;

  UserModeEnum mode;

  bool listenerApproved;

  bool online;

  @override
  bool operator ==(Object other) => identical(this, other) || other is User &&
    other.id == id &&
    other.displayName == displayName &&
    _deepEquality.equals(other.languages, languages) &&
    other.mode == mode &&
    other.listenerApproved == listenerApproved &&
    other.online == online;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (displayName.hashCode) +
    (languages.hashCode) +
    (mode.hashCode) +
    (listenerApproved.hashCode) +
    (online.hashCode);

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


