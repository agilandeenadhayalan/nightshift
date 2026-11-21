//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class PushRegistration {
  /// Returns a new [PushRegistration] instance.
  PushRegistration({
    required this.id,
    required this.version,
    required this.bindingId,
    required this.targetKind,
    required this.state,
    required this.backgroundInvitations,
    required this.leaseExpiresAt,
    required this.serverTime,
    required this.testOnly,
  });

  String id;

  /// Minimum value: 1
  int version;

  String bindingId;

  PushRegistrationTargetKindEnum targetKind;

  PushRegistrationStateEnum state;

  bool backgroundInvitations;

  DateTime? leaseExpiresAt;

  DateTime serverTime;

  PushRegistrationTestOnlyEnum testOnly;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PushRegistration &&
    other.id == id &&
    other.version == version &&
    other.bindingId == bindingId &&
    other.targetKind == targetKind &&
    other.state == state &&
    other.backgroundInvitations == backgroundInvitations &&
    other.leaseExpiresAt == leaseExpiresAt &&
    other.serverTime == serverTime &&
    other.testOnly == testOnly;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (version.hashCode) +
    (bindingId.hashCode) +
    (targetKind.hashCode) +
    (state.hashCode) +
    (backgroundInvitations.hashCode) +
    (leaseExpiresAt == null ? 0 : leaseExpiresAt!.hashCode) +
    (serverTime.hashCode) +
    (testOnly.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'PushRegistration[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'version'] = this.version;
      json[r'bindingId'] = this.bindingId;
      json[r'targetKind'] = this.targetKind;
      json[r'state'] = this.state;
      json[r'backgroundInvitations'] = this.backgroundInvitations;
    if (this.leaseExpiresAt != null) {
      json[r'leaseExpiresAt'] = this.leaseExpiresAt!.toUtc().toIso8601String();
    } else {
      json[r'leaseExpiresAt'] = null;
    }
      json[r'serverTime'] = this.serverTime.toUtc().toIso8601String();
      json[r'testOnly'] = this.testOnly;
    return json;
  }

  /// Returns a new [PushRegistration] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PushRegistration? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid PushRegistration object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing PushRegistration.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null PushRegistration.id');
      }
      if (!json.containsKey(r'version')) {
        throw const FormatException('Missing PushRegistration.version');
      }
      if (json[r'version'] == null) {
        throw const FormatException('Null PushRegistration.version');
      }
      if (json[r'version'] != null && json[r'version'] is! int) {
        throw const FormatException('Invalid PushRegistration.version integer');
      }
      if (!json.containsKey(r'bindingId')) {
        throw const FormatException('Missing PushRegistration.bindingId');
      }
      if (json[r'bindingId'] == null) {
        throw const FormatException('Null PushRegistration.bindingId');
      }
      if (!json.containsKey(r'targetKind')) {
        throw const FormatException('Missing PushRegistration.targetKind');
      }
      if (json[r'targetKind'] == null) {
        throw const FormatException('Null PushRegistration.targetKind');
      }
      if (!json.containsKey(r'state')) {
        throw const FormatException('Missing PushRegistration.state');
      }
      if (json[r'state'] == null) {
        throw const FormatException('Null PushRegistration.state');
      }
      if (!json.containsKey(r'backgroundInvitations')) {
        throw const FormatException('Missing PushRegistration.backgroundInvitations');
      }
      if (json[r'backgroundInvitations'] == null) {
        throw const FormatException('Null PushRegistration.backgroundInvitations');
      }
      if (json[r'backgroundInvitations'] != null && json[r'backgroundInvitations'] is! bool) {
        throw const FormatException('Invalid PushRegistration.backgroundInvitations boolean');
      }
      if (!json.containsKey(r'leaseExpiresAt')) {
        throw const FormatException('Missing PushRegistration.leaseExpiresAt');
      }
      if (json[r'leaseExpiresAt'] != null && (json[r'leaseExpiresAt'] is! String || DateTime.tryParse(json[r'leaseExpiresAt'] as String) == null)) {
        throw const FormatException('Invalid PushRegistration.leaseExpiresAt');
      }
      if (!json.containsKey(r'serverTime')) {
        throw const FormatException('Missing PushRegistration.serverTime');
      }
      if (json[r'serverTime'] == null) {
        throw const FormatException('Null PushRegistration.serverTime');
      }
      if (json[r'serverTime'] != null && (json[r'serverTime'] is! String || DateTime.tryParse(json[r'serverTime'] as String) == null)) {
        throw const FormatException('Invalid PushRegistration.serverTime');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing PushRegistration.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null PushRegistration.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid PushRegistration.testOnly boolean');
      }

      return PushRegistration(
        id: mapValueOfType<String>(json, r'id')!,
        version: mapValueOfType<int>(json, r'version')!,
        bindingId: mapValueOfType<String>(json, r'bindingId')!,
        targetKind: PushRegistrationTargetKindEnum.fromJson(json[r'targetKind'])!,
        state: PushRegistrationStateEnum.fromJson(json[r'state'])!,
        backgroundInvitations: mapValueOfType<bool>(json, r'backgroundInvitations')!,
        leaseExpiresAt: mapDateTime(json, r'leaseExpiresAt', r''),
        serverTime: mapDateTime(json, r'serverTime', r'')!,
        testOnly: PushRegistrationTestOnlyEnum.fromJson(json[r'testOnly'])!,
      );
    }
    return null;
  }

  static List<PushRegistration> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PushRegistration>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PushRegistration.fromJson(row);
        if (value == null) throw const FormatException('Invalid PushRegistration list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PushRegistration> mapFromJson(dynamic json) {
    final map = <String, PushRegistration>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PushRegistration.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PushRegistration-objects as value to a dart map
  static Map<String, List<PushRegistration>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PushRegistration>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PushRegistration.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'version',
    'bindingId',
    'targetKind',
    'state',
    'backgroundInvitations',
    'leaseExpiresAt',
    'serverTime',
    'testOnly',
  };
}


enum PushRegistrationTargetKindEnum {
  fcmToken._(r'fcm_token'),
  ;

  /// Instantiate a new enum with the provided value.
  const PushRegistrationTargetKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [PushRegistrationTargetKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static PushRegistrationTargetKindEnum? fromJson(dynamic value) => PushRegistrationTargetKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [PushRegistrationTargetKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<PushRegistrationTargetKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PushRegistrationTargetKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PushRegistrationTargetKindEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PushRegistrationTargetKindEnum] to String,
/// and [decode] dynamic data back to [PushRegistrationTargetKindEnum].
class PushRegistrationTargetKindEnumTypeTransformer {
  factory PushRegistrationTargetKindEnumTypeTransformer() => _instance ??= const PushRegistrationTargetKindEnumTypeTransformer._();

  const PushRegistrationTargetKindEnumTypeTransformer._();

  String encode(PushRegistrationTargetKindEnum data) => data._value;

  /// Returns the instance of [PushRegistrationTargetKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PushRegistrationTargetKindEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is PushRegistrationTargetKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'fcm_token': return PushRegistrationTargetKindEnum.fcmToken;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static PushRegistrationTargetKindEnumTypeTransformer? _instance;
}



enum PushRegistrationStateEnum {
  prepared._(r'prepared'),
  active._(r'active'),
  revoked._(r'revoked'),
  expired._(r'expired'),
  ;

  /// Instantiate a new enum with the provided value.
  const PushRegistrationStateEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [PushRegistrationStateEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static PushRegistrationStateEnum? fromJson(dynamic value) => PushRegistrationStateEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [PushRegistrationStateEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<PushRegistrationStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PushRegistrationStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PushRegistrationStateEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PushRegistrationStateEnum] to String,
/// and [decode] dynamic data back to [PushRegistrationStateEnum].
class PushRegistrationStateEnumTypeTransformer {
  factory PushRegistrationStateEnumTypeTransformer() => _instance ??= const PushRegistrationStateEnumTypeTransformer._();

  const PushRegistrationStateEnumTypeTransformer._();

  String encode(PushRegistrationStateEnum data) => data._value;

  /// Returns the instance of [PushRegistrationStateEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PushRegistrationStateEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is PushRegistrationStateEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'prepared': return PushRegistrationStateEnum.prepared;
        case r'active': return PushRegistrationStateEnum.active;
        case r'revoked': return PushRegistrationStateEnum.revoked;
        case r'expired': return PushRegistrationStateEnum.expired;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static PushRegistrationStateEnumTypeTransformer? _instance;
}



enum PushRegistrationTestOnlyEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const PushRegistrationTestOnlyEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [PushRegistrationTestOnlyEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static PushRegistrationTestOnlyEnum? fromJson(dynamic value) => PushRegistrationTestOnlyEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [PushRegistrationTestOnlyEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<PushRegistrationTestOnlyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PushRegistrationTestOnlyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PushRegistrationTestOnlyEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PushRegistrationTestOnlyEnum] to bool,
/// and [decode] dynamic data back to [PushRegistrationTestOnlyEnum].
class PushRegistrationTestOnlyEnumTypeTransformer {
  factory PushRegistrationTestOnlyEnumTypeTransformer() => _instance ??= const PushRegistrationTestOnlyEnumTypeTransformer._();

  const PushRegistrationTestOnlyEnumTypeTransformer._();

  bool encode(PushRegistrationTestOnlyEnum data) => data._value;

  /// Returns the instance of [PushRegistrationTestOnlyEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PushRegistrationTestOnlyEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is PushRegistrationTestOnlyEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return PushRegistrationTestOnlyEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static PushRegistrationTestOnlyEnumTypeTransformer? _instance;
}


