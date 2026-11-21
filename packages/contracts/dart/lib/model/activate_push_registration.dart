//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ActivatePushRegistration {
  /// Returns a new [ActivatePushRegistration] instance.
  ActivatePushRegistration({
    required this.registrationId,
    required this.expectedVersion,
    required this.bindingId,
    required this.notificationPermission,
    required this.backgroundInvitations,
    required this.capabilityVersion,
    required this.consentVersion,
  });

  String registrationId;

  /// Minimum value: 1
  int expectedVersion;

  String bindingId;

  ActivatePushRegistrationNotificationPermissionEnum notificationPermission;

  ActivatePushRegistrationBackgroundInvitationsEnum backgroundInvitations;

  ActivatePushRegistrationCapabilityVersionEnum capabilityVersion;

  ActivatePushRegistrationConsentVersionEnum consentVersion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ActivatePushRegistration &&
    other.registrationId == registrationId &&
    other.expectedVersion == expectedVersion &&
    other.bindingId == bindingId &&
    other.notificationPermission == notificationPermission &&
    other.backgroundInvitations == backgroundInvitations &&
    other.capabilityVersion == capabilityVersion &&
    other.consentVersion == consentVersion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (registrationId.hashCode) +
    (expectedVersion.hashCode) +
    (bindingId.hashCode) +
    (notificationPermission.hashCode) +
    (backgroundInvitations.hashCode) +
    (capabilityVersion.hashCode) +
    (consentVersion.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ActivatePushRegistration[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'registrationId'] = this.registrationId;
      json[r'expectedVersion'] = this.expectedVersion;
      json[r'bindingId'] = this.bindingId;
      json[r'notificationPermission'] = this.notificationPermission;
      json[r'backgroundInvitations'] = this.backgroundInvitations;
      json[r'capabilityVersion'] = this.capabilityVersion;
      json[r'consentVersion'] = this.consentVersion;
    return json;
  }

  /// Returns a new [ActivatePushRegistration] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ActivatePushRegistration? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ActivatePushRegistration object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'registrationId')) {
        throw const FormatException('Missing ActivatePushRegistration.registrationId');
      }
      if (json[r'registrationId'] == null) {
        throw const FormatException('Null ActivatePushRegistration.registrationId');
      }
      if (!json.containsKey(r'expectedVersion')) {
        throw const FormatException('Missing ActivatePushRegistration.expectedVersion');
      }
      if (json[r'expectedVersion'] == null) {
        throw const FormatException('Null ActivatePushRegistration.expectedVersion');
      }
      if (json[r'expectedVersion'] != null && json[r'expectedVersion'] is! int) {
        throw const FormatException('Invalid ActivatePushRegistration.expectedVersion integer');
      }
      if (!json.containsKey(r'bindingId')) {
        throw const FormatException('Missing ActivatePushRegistration.bindingId');
      }
      if (json[r'bindingId'] == null) {
        throw const FormatException('Null ActivatePushRegistration.bindingId');
      }
      if (!json.containsKey(r'notificationPermission')) {
        throw const FormatException('Missing ActivatePushRegistration.notificationPermission');
      }
      if (json[r'notificationPermission'] == null) {
        throw const FormatException('Null ActivatePushRegistration.notificationPermission');
      }
      if (!json.containsKey(r'backgroundInvitations')) {
        throw const FormatException('Missing ActivatePushRegistration.backgroundInvitations');
      }
      if (json[r'backgroundInvitations'] == null) {
        throw const FormatException('Null ActivatePushRegistration.backgroundInvitations');
      }
      if (json[r'backgroundInvitations'] != null && json[r'backgroundInvitations'] is! bool) {
        throw const FormatException('Invalid ActivatePushRegistration.backgroundInvitations boolean');
      }
      if (!json.containsKey(r'capabilityVersion')) {
        throw const FormatException('Missing ActivatePushRegistration.capabilityVersion');
      }
      if (json[r'capabilityVersion'] == null) {
        throw const FormatException('Null ActivatePushRegistration.capabilityVersion');
      }
      if (!json.containsKey(r'consentVersion')) {
        throw const FormatException('Missing ActivatePushRegistration.consentVersion');
      }
      if (json[r'consentVersion'] == null) {
        throw const FormatException('Null ActivatePushRegistration.consentVersion');
      }

      return ActivatePushRegistration(
        registrationId: mapValueOfType<String>(json, r'registrationId')!,
        expectedVersion: mapValueOfType<int>(json, r'expectedVersion')!,
        bindingId: mapValueOfType<String>(json, r'bindingId')!,
        notificationPermission: ActivatePushRegistrationNotificationPermissionEnum.fromJson(json[r'notificationPermission'])!,
        backgroundInvitations: ActivatePushRegistrationBackgroundInvitationsEnum.fromJson(json[r'backgroundInvitations'])!,
        capabilityVersion: ActivatePushRegistrationCapabilityVersionEnum.fromJson(json[r'capabilityVersion'])!,
        consentVersion: ActivatePushRegistrationConsentVersionEnum.fromJson(json[r'consentVersion'])!,
      );
    }
    return null;
  }

  static List<ActivatePushRegistration> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ActivatePushRegistration>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ActivatePushRegistration.fromJson(row);
        if (value == null) throw const FormatException('Invalid ActivatePushRegistration list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ActivatePushRegistration> mapFromJson(dynamic json) {
    final map = <String, ActivatePushRegistration>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ActivatePushRegistration.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ActivatePushRegistration-objects as value to a dart map
  static Map<String, List<ActivatePushRegistration>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ActivatePushRegistration>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ActivatePushRegistration.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'registrationId',
    'expectedVersion',
    'bindingId',
    'notificationPermission',
    'backgroundInvitations',
    'capabilityVersion',
    'consentVersion',
  };
}


enum ActivatePushRegistrationNotificationPermissionEnum {
  granted._(r'granted'),
  ;

  /// Instantiate a new enum with the provided value.
  const ActivatePushRegistrationNotificationPermissionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ActivatePushRegistrationNotificationPermissionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ActivatePushRegistrationNotificationPermissionEnum? fromJson(dynamic value) => ActivatePushRegistrationNotificationPermissionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ActivatePushRegistrationNotificationPermissionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ActivatePushRegistrationNotificationPermissionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ActivatePushRegistrationNotificationPermissionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ActivatePushRegistrationNotificationPermissionEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ActivatePushRegistrationNotificationPermissionEnum] to String,
/// and [decode] dynamic data back to [ActivatePushRegistrationNotificationPermissionEnum].
class ActivatePushRegistrationNotificationPermissionEnumTypeTransformer {
  factory ActivatePushRegistrationNotificationPermissionEnumTypeTransformer() => _instance ??= const ActivatePushRegistrationNotificationPermissionEnumTypeTransformer._();

  const ActivatePushRegistrationNotificationPermissionEnumTypeTransformer._();

  String encode(ActivatePushRegistrationNotificationPermissionEnum data) => data._value;

  /// Returns the instance of [ActivatePushRegistrationNotificationPermissionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ActivatePushRegistrationNotificationPermissionEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ActivatePushRegistrationNotificationPermissionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'granted': return ActivatePushRegistrationNotificationPermissionEnum.granted;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ActivatePushRegistrationNotificationPermissionEnumTypeTransformer? _instance;
}



enum ActivatePushRegistrationBackgroundInvitationsEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const ActivatePushRegistrationBackgroundInvitationsEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [ActivatePushRegistrationBackgroundInvitationsEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ActivatePushRegistrationBackgroundInvitationsEnum? fromJson(dynamic value) => ActivatePushRegistrationBackgroundInvitationsEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ActivatePushRegistrationBackgroundInvitationsEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ActivatePushRegistrationBackgroundInvitationsEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ActivatePushRegistrationBackgroundInvitationsEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ActivatePushRegistrationBackgroundInvitationsEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ActivatePushRegistrationBackgroundInvitationsEnum] to bool,
/// and [decode] dynamic data back to [ActivatePushRegistrationBackgroundInvitationsEnum].
class ActivatePushRegistrationBackgroundInvitationsEnumTypeTransformer {
  factory ActivatePushRegistrationBackgroundInvitationsEnumTypeTransformer() => _instance ??= const ActivatePushRegistrationBackgroundInvitationsEnumTypeTransformer._();

  const ActivatePushRegistrationBackgroundInvitationsEnumTypeTransformer._();

  bool encode(ActivatePushRegistrationBackgroundInvitationsEnum data) => data._value;

  /// Returns the instance of [ActivatePushRegistrationBackgroundInvitationsEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ActivatePushRegistrationBackgroundInvitationsEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ActivatePushRegistrationBackgroundInvitationsEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return ActivatePushRegistrationBackgroundInvitationsEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ActivatePushRegistrationBackgroundInvitationsEnumTypeTransformer? _instance;
}



enum ActivatePushRegistrationCapabilityVersionEnum {
  androidAudioInvitationsV1._(r'android-audio-invitations-v1'),
  ;

  /// Instantiate a new enum with the provided value.
  const ActivatePushRegistrationCapabilityVersionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ActivatePushRegistrationCapabilityVersionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ActivatePushRegistrationCapabilityVersionEnum? fromJson(dynamic value) => ActivatePushRegistrationCapabilityVersionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ActivatePushRegistrationCapabilityVersionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ActivatePushRegistrationCapabilityVersionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ActivatePushRegistrationCapabilityVersionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ActivatePushRegistrationCapabilityVersionEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ActivatePushRegistrationCapabilityVersionEnum] to String,
/// and [decode] dynamic data back to [ActivatePushRegistrationCapabilityVersionEnum].
class ActivatePushRegistrationCapabilityVersionEnumTypeTransformer {
  factory ActivatePushRegistrationCapabilityVersionEnumTypeTransformer() => _instance ??= const ActivatePushRegistrationCapabilityVersionEnumTypeTransformer._();

  const ActivatePushRegistrationCapabilityVersionEnumTypeTransformer._();

  String encode(ActivatePushRegistrationCapabilityVersionEnum data) => data._value;

  /// Returns the instance of [ActivatePushRegistrationCapabilityVersionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ActivatePushRegistrationCapabilityVersionEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ActivatePushRegistrationCapabilityVersionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'android-audio-invitations-v1': return ActivatePushRegistrationCapabilityVersionEnum.androidAudioInvitationsV1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ActivatePushRegistrationCapabilityVersionEnumTypeTransformer? _instance;
}



enum ActivatePushRegistrationConsentVersionEnum {
  backgroundInvitationsV1._(r'background-invitations-v1'),
  ;

  /// Instantiate a new enum with the provided value.
  const ActivatePushRegistrationConsentVersionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ActivatePushRegistrationConsentVersionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ActivatePushRegistrationConsentVersionEnum? fromJson(dynamic value) => ActivatePushRegistrationConsentVersionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ActivatePushRegistrationConsentVersionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ActivatePushRegistrationConsentVersionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ActivatePushRegistrationConsentVersionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ActivatePushRegistrationConsentVersionEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ActivatePushRegistrationConsentVersionEnum] to String,
/// and [decode] dynamic data back to [ActivatePushRegistrationConsentVersionEnum].
class ActivatePushRegistrationConsentVersionEnumTypeTransformer {
  factory ActivatePushRegistrationConsentVersionEnumTypeTransformer() => _instance ??= const ActivatePushRegistrationConsentVersionEnumTypeTransformer._();

  const ActivatePushRegistrationConsentVersionEnumTypeTransformer._();

  String encode(ActivatePushRegistrationConsentVersionEnum data) => data._value;

  /// Returns the instance of [ActivatePushRegistrationConsentVersionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ActivatePushRegistrationConsentVersionEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ActivatePushRegistrationConsentVersionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'background-invitations-v1': return ActivatePushRegistrationConsentVersionEnum.backgroundInvitationsV1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ActivatePushRegistrationConsentVersionEnumTypeTransformer? _instance;
}


