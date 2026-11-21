//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class PreparePushRegistration {
  /// Returns a new [PreparePushRegistration] instance.
  PreparePushRegistration({
    required this.targetKind,
    required this.token,
    required this.expectedVersion,
  });

  PreparePushRegistrationTargetKindEnum targetKind;

  String token;

  /// Minimum value: 1
  int? expectedVersion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PreparePushRegistration &&
    other.targetKind == targetKind &&
    other.token == token &&
    other.expectedVersion == expectedVersion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (targetKind.hashCode) +
    (token.hashCode) +
    (expectedVersion == null ? 0 : expectedVersion!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'PreparePushRegistration[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'targetKind'] = this.targetKind;
      json[r'token'] = this.token;
    if (this.expectedVersion != null) {
      json[r'expectedVersion'] = this.expectedVersion;
    } else {
      json[r'expectedVersion'] = null;
    }
    return json;
  }

  /// Returns a new [PreparePushRegistration] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PreparePushRegistration? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid PreparePushRegistration object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'targetKind')) {
        throw const FormatException('Missing PreparePushRegistration.targetKind');
      }
      if (json[r'targetKind'] == null) {
        throw const FormatException('Null PreparePushRegistration.targetKind');
      }
      if (!json.containsKey(r'token')) {
        throw const FormatException('Missing PreparePushRegistration.token');
      }
      if (json[r'token'] == null) {
        throw const FormatException('Null PreparePushRegistration.token');
      }
      if (!json.containsKey(r'expectedVersion')) {
        throw const FormatException('Missing PreparePushRegistration.expectedVersion');
      }
      if (json[r'expectedVersion'] != null && json[r'expectedVersion'] is! int) {
        throw const FormatException('Invalid PreparePushRegistration.expectedVersion integer');
      }

      return PreparePushRegistration(
        targetKind: PreparePushRegistrationTargetKindEnum.fromJson(json[r'targetKind'])!,
        token: mapValueOfType<String>(json, r'token')!,
        expectedVersion: mapValueOfType<int>(json, r'expectedVersion'),
      );
    }
    return null;
  }

  static List<PreparePushRegistration> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PreparePushRegistration>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PreparePushRegistration.fromJson(row);
        if (value == null) throw const FormatException('Invalid PreparePushRegistration list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PreparePushRegistration> mapFromJson(dynamic json) {
    final map = <String, PreparePushRegistration>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PreparePushRegistration.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PreparePushRegistration-objects as value to a dart map
  static Map<String, List<PreparePushRegistration>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PreparePushRegistration>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PreparePushRegistration.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'targetKind',
    'token',
    'expectedVersion',
  };
}


enum PreparePushRegistrationTargetKindEnum {
  fcmToken._(r'fcm_token'),
  ;

  /// Instantiate a new enum with the provided value.
  const PreparePushRegistrationTargetKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [PreparePushRegistrationTargetKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static PreparePushRegistrationTargetKindEnum? fromJson(dynamic value) => PreparePushRegistrationTargetKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [PreparePushRegistrationTargetKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<PreparePushRegistrationTargetKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PreparePushRegistrationTargetKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PreparePushRegistrationTargetKindEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PreparePushRegistrationTargetKindEnum] to String,
/// and [decode] dynamic data back to [PreparePushRegistrationTargetKindEnum].
class PreparePushRegistrationTargetKindEnumTypeTransformer {
  factory PreparePushRegistrationTargetKindEnumTypeTransformer() => _instance ??= const PreparePushRegistrationTargetKindEnumTypeTransformer._();

  const PreparePushRegistrationTargetKindEnumTypeTransformer._();

  String encode(PreparePushRegistrationTargetKindEnum data) => data._value;

  /// Returns the instance of [PreparePushRegistrationTargetKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PreparePushRegistrationTargetKindEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is PreparePushRegistrationTargetKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'fcm_token': return PreparePushRegistrationTargetKindEnum.fcmToken;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static PreparePushRegistrationTargetKindEnumTypeTransformer? _instance;
}


