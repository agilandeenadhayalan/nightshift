//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class Login {
  /// Returns a new [Login] instance.
  Login({
    required this.token,
    required this.expiresAt,
    required this.user,
    required this.testOnly,
  });

  String token;

  DateTime expiresAt;

  User user;

  LoginTestOnlyEnum testOnly;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Login &&
    other.token == token &&
    other.expiresAt == expiresAt &&
    other.user == user &&
    other.testOnly == testOnly;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (token.hashCode) +
    (expiresAt.hashCode) +
    (user.hashCode) +
    (testOnly.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'Login[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'token'] = this.token;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'user'] = this.user;
      json[r'testOnly'] = this.testOnly;
    return json;
  }

  /// Returns a new [Login] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Login? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid Login object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'token')) {
        throw const FormatException('Missing Login.token');
      }
      if (json[r'token'] == null) {
        throw const FormatException('Null Login.token');
      }
      if (!json.containsKey(r'expiresAt')) {
        throw const FormatException('Missing Login.expiresAt');
      }
      if (json[r'expiresAt'] == null) {
        throw const FormatException('Null Login.expiresAt');
      }
      if (json[r'expiresAt'] != null && (json[r'expiresAt'] is! String || DateTime.tryParse(json[r'expiresAt'] as String) == null)) {
        throw const FormatException('Invalid Login.expiresAt');
      }
      if (!json.containsKey(r'user')) {
        throw const FormatException('Missing Login.user');
      }
      if (json[r'user'] == null) {
        throw const FormatException('Null Login.user');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing Login.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null Login.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid Login.testOnly boolean');
      }

      return Login(
        token: mapValueOfType<String>(json, r'token')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        user: User.fromJson(json[r'user'])!,
        testOnly: LoginTestOnlyEnum.fromJson(json[r'testOnly'])!,
      );
    }
    return null;
  }

  static List<Login> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Login>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Login.fromJson(row);
        if (value == null) throw const FormatException('Invalid Login list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Login> mapFromJson(dynamic json) {
    final map = <String, Login>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Login.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Login-objects as value to a dart map
  static Map<String, List<Login>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Login>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Login.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'token',
    'expiresAt',
    'user',
    'testOnly',
  };
}


enum LoginTestOnlyEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const LoginTestOnlyEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [LoginTestOnlyEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static LoginTestOnlyEnum? fromJson(dynamic value) => LoginTestOnlyEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [LoginTestOnlyEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<LoginTestOnlyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LoginTestOnlyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LoginTestOnlyEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [LoginTestOnlyEnum] to bool,
/// and [decode] dynamic data back to [LoginTestOnlyEnum].
class LoginTestOnlyEnumTypeTransformer {
  factory LoginTestOnlyEnumTypeTransformer() => _instance ??= const LoginTestOnlyEnumTypeTransformer._();

  const LoginTestOnlyEnumTypeTransformer._();

  bool encode(LoginTestOnlyEnum data) => data._value;

  /// Returns the instance of [LoginTestOnlyEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  LoginTestOnlyEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is LoginTestOnlyEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return LoginTestOnlyEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static LoginTestOnlyEnumTypeTransformer? _instance;
}


