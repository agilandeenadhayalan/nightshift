//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class PhoneSession {
  /// Returns a new [PhoneSession] instance.
  PhoneSession({
    required this.token,
    required this.expiresAt,
    required this.user,
    required this.needsOnboarding,
    required this.testOnly,
  });

  String token;

  DateTime expiresAt;

  User user;

  bool needsOnboarding;

  PhoneSessionTestOnlyEnum testOnly;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PhoneSession &&
    other.token == token &&
    other.expiresAt == expiresAt &&
    other.user == user &&
    other.needsOnboarding == needsOnboarding &&
    other.testOnly == testOnly;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (token.hashCode) +
    (expiresAt.hashCode) +
    (user.hashCode) +
    (needsOnboarding.hashCode) +
    (testOnly.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'PhoneSession[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'token'] = this.token;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'user'] = this.user;
      json[r'needsOnboarding'] = this.needsOnboarding;
      json[r'testOnly'] = this.testOnly;
    return json;
  }

  /// Returns a new [PhoneSession] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PhoneSession? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid PhoneSession object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'token')) {
        throw const FormatException('Missing PhoneSession.token');
      }
      if (json[r'token'] == null) {
        throw const FormatException('Null PhoneSession.token');
      }
      if (!json.containsKey(r'expiresAt')) {
        throw const FormatException('Missing PhoneSession.expiresAt');
      }
      if (json[r'expiresAt'] == null) {
        throw const FormatException('Null PhoneSession.expiresAt');
      }
      if (json[r'expiresAt'] != null && (json[r'expiresAt'] is! String || DateTime.tryParse(json[r'expiresAt'] as String) == null)) {
        throw const FormatException('Invalid PhoneSession.expiresAt');
      }
      if (!json.containsKey(r'user')) {
        throw const FormatException('Missing PhoneSession.user');
      }
      if (json[r'user'] == null) {
        throw const FormatException('Null PhoneSession.user');
      }
      if (!json.containsKey(r'needsOnboarding')) {
        throw const FormatException('Missing PhoneSession.needsOnboarding');
      }
      if (json[r'needsOnboarding'] == null) {
        throw const FormatException('Null PhoneSession.needsOnboarding');
      }
      if (json[r'needsOnboarding'] != null && json[r'needsOnboarding'] is! bool) {
        throw const FormatException('Invalid PhoneSession.needsOnboarding boolean');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing PhoneSession.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null PhoneSession.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid PhoneSession.testOnly boolean');
      }

      return PhoneSession(
        token: mapValueOfType<String>(json, r'token')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        user: User.fromJson(json[r'user'])!,
        needsOnboarding: mapValueOfType<bool>(json, r'needsOnboarding')!,
        testOnly: PhoneSessionTestOnlyEnum.fromJson(json[r'testOnly'])!,
      );
    }
    return null;
  }

  static List<PhoneSession> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PhoneSession>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PhoneSession.fromJson(row);
        if (value == null) throw const FormatException('Invalid PhoneSession list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PhoneSession> mapFromJson(dynamic json) {
    final map = <String, PhoneSession>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PhoneSession.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PhoneSession-objects as value to a dart map
  static Map<String, List<PhoneSession>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PhoneSession>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PhoneSession.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'token',
    'expiresAt',
    'user',
    'needsOnboarding',
    'testOnly',
  };
}


enum PhoneSessionTestOnlyEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const PhoneSessionTestOnlyEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [PhoneSessionTestOnlyEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static PhoneSessionTestOnlyEnum? fromJson(dynamic value) => PhoneSessionTestOnlyEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [PhoneSessionTestOnlyEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<PhoneSessionTestOnlyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PhoneSessionTestOnlyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PhoneSessionTestOnlyEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PhoneSessionTestOnlyEnum] to bool,
/// and [decode] dynamic data back to [PhoneSessionTestOnlyEnum].
class PhoneSessionTestOnlyEnumTypeTransformer {
  factory PhoneSessionTestOnlyEnumTypeTransformer() => _instance ??= const PhoneSessionTestOnlyEnumTypeTransformer._();

  const PhoneSessionTestOnlyEnumTypeTransformer._();

  bool encode(PhoneSessionTestOnlyEnum data) => data._value;

  /// Returns the instance of [PhoneSessionTestOnlyEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PhoneSessionTestOnlyEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is PhoneSessionTestOnlyEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return PhoneSessionTestOnlyEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static PhoneSessionTestOnlyEnumTypeTransformer? _instance;
}


