//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class CallInvitationPush {
  /// Returns a new [CallInvitationPush] instance.
  CallInvitationPush({
    required this.schemaVersion,
    required this.type,
    required this.callId,
    required this.eventId,
    required this.callVersion,
    required this.expiresAt,
    required this.registrationId,
    required this.registrationVersion,
    required this.bindingId,
  });

  CallInvitationPushSchemaVersionEnum schemaVersion;

  CallInvitationPushTypeEnum type;

  String callId;

  String eventId;

  String callVersion;

  DateTime expiresAt;

  String registrationId;

  String registrationVersion;

  String bindingId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CallInvitationPush &&
    other.schemaVersion == schemaVersion &&
    other.type == type &&
    other.callId == callId &&
    other.eventId == eventId &&
    other.callVersion == callVersion &&
    other.expiresAt == expiresAt &&
    other.registrationId == registrationId &&
    other.registrationVersion == registrationVersion &&
    other.bindingId == bindingId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (schemaVersion.hashCode) +
    (type.hashCode) +
    (callId.hashCode) +
    (eventId.hashCode) +
    (callVersion.hashCode) +
    (expiresAt.hashCode) +
    (registrationId.hashCode) +
    (registrationVersion.hashCode) +
    (bindingId.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'CallInvitationPush[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'schemaVersion'] = this.schemaVersion;
      json[r'type'] = this.type;
      json[r'callId'] = this.callId;
      json[r'eventId'] = this.eventId;
      json[r'callVersion'] = this.callVersion;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'registrationId'] = this.registrationId;
      json[r'registrationVersion'] = this.registrationVersion;
      json[r'bindingId'] = this.bindingId;
    return json;
  }

  /// Returns a new [CallInvitationPush] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CallInvitationPush? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid CallInvitationPush object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'schemaVersion')) {
        throw const FormatException('Missing CallInvitationPush.schemaVersion');
      }
      if (json[r'schemaVersion'] == null) {
        throw const FormatException('Null CallInvitationPush.schemaVersion');
      }
      if (!json.containsKey(r'type')) {
        throw const FormatException('Missing CallInvitationPush.type');
      }
      if (json[r'type'] == null) {
        throw const FormatException('Null CallInvitationPush.type');
      }
      if (!json.containsKey(r'callId')) {
        throw const FormatException('Missing CallInvitationPush.callId');
      }
      if (json[r'callId'] == null) {
        throw const FormatException('Null CallInvitationPush.callId');
      }
      if (!json.containsKey(r'eventId')) {
        throw const FormatException('Missing CallInvitationPush.eventId');
      }
      if (json[r'eventId'] == null) {
        throw const FormatException('Null CallInvitationPush.eventId');
      }
      if (!json.containsKey(r'callVersion')) {
        throw const FormatException('Missing CallInvitationPush.callVersion');
      }
      if (json[r'callVersion'] == null) {
        throw const FormatException('Null CallInvitationPush.callVersion');
      }
      if (!json.containsKey(r'expiresAt')) {
        throw const FormatException('Missing CallInvitationPush.expiresAt');
      }
      if (json[r'expiresAt'] == null) {
        throw const FormatException('Null CallInvitationPush.expiresAt');
      }
      if (json[r'expiresAt'] != null && (json[r'expiresAt'] is! String || DateTime.tryParse(json[r'expiresAt'] as String) == null)) {
        throw const FormatException('Invalid CallInvitationPush.expiresAt');
      }
      if (!json.containsKey(r'registrationId')) {
        throw const FormatException('Missing CallInvitationPush.registrationId');
      }
      if (json[r'registrationId'] == null) {
        throw const FormatException('Null CallInvitationPush.registrationId');
      }
      if (!json.containsKey(r'registrationVersion')) {
        throw const FormatException('Missing CallInvitationPush.registrationVersion');
      }
      if (json[r'registrationVersion'] == null) {
        throw const FormatException('Null CallInvitationPush.registrationVersion');
      }
      if (!json.containsKey(r'bindingId')) {
        throw const FormatException('Missing CallInvitationPush.bindingId');
      }
      if (json[r'bindingId'] == null) {
        throw const FormatException('Null CallInvitationPush.bindingId');
      }

      return CallInvitationPush(
        schemaVersion: CallInvitationPushSchemaVersionEnum.fromJson(json[r'schemaVersion'])!,
        type: CallInvitationPushTypeEnum.fromJson(json[r'type'])!,
        callId: mapValueOfType<String>(json, r'callId')!,
        eventId: mapValueOfType<String>(json, r'eventId')!,
        callVersion: mapValueOfType<String>(json, r'callVersion')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        registrationId: mapValueOfType<String>(json, r'registrationId')!,
        registrationVersion: mapValueOfType<String>(json, r'registrationVersion')!,
        bindingId: mapValueOfType<String>(json, r'bindingId')!,
      );
    }
    return null;
  }

  static List<CallInvitationPush> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CallInvitationPush>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CallInvitationPush.fromJson(row);
        if (value == null) throw const FormatException('Invalid CallInvitationPush list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CallInvitationPush> mapFromJson(dynamic json) {
    final map = <String, CallInvitationPush>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CallInvitationPush.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CallInvitationPush-objects as value to a dart map
  static Map<String, List<CallInvitationPush>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CallInvitationPush>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CallInvitationPush.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'schemaVersion',
    'type',
    'callId',
    'eventId',
    'callVersion',
    'expiresAt',
    'registrationId',
    'registrationVersion',
    'bindingId',
  };
}


enum CallInvitationPushSchemaVersionEnum {
  n1._(r'1'),
  ;

  /// Instantiate a new enum with the provided value.
  const CallInvitationPushSchemaVersionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CallInvitationPushSchemaVersionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CallInvitationPushSchemaVersionEnum? fromJson(dynamic value) => CallInvitationPushSchemaVersionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CallInvitationPushSchemaVersionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CallInvitationPushSchemaVersionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CallInvitationPushSchemaVersionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CallInvitationPushSchemaVersionEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CallInvitationPushSchemaVersionEnum] to String,
/// and [decode] dynamic data back to [CallInvitationPushSchemaVersionEnum].
class CallInvitationPushSchemaVersionEnumTypeTransformer {
  factory CallInvitationPushSchemaVersionEnumTypeTransformer() => _instance ??= const CallInvitationPushSchemaVersionEnumTypeTransformer._();

  const CallInvitationPushSchemaVersionEnumTypeTransformer._();

  String encode(CallInvitationPushSchemaVersionEnum data) => data._value;

  /// Returns the instance of [CallInvitationPushSchemaVersionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CallInvitationPushSchemaVersionEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CallInvitationPushSchemaVersionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'1': return CallInvitationPushSchemaVersionEnum.n1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CallInvitationPushSchemaVersionEnumTypeTransformer? _instance;
}



enum CallInvitationPushTypeEnum {
  callPeriodInvitation._(r'call.invitation'),
  callPeriodTerminal._(r'call.terminal'),
  ;

  /// Instantiate a new enum with the provided value.
  const CallInvitationPushTypeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CallInvitationPushTypeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CallInvitationPushTypeEnum? fromJson(dynamic value) => CallInvitationPushTypeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CallInvitationPushTypeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CallInvitationPushTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CallInvitationPushTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CallInvitationPushTypeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CallInvitationPushTypeEnum] to String,
/// and [decode] dynamic data back to [CallInvitationPushTypeEnum].
class CallInvitationPushTypeEnumTypeTransformer {
  factory CallInvitationPushTypeEnumTypeTransformer() => _instance ??= const CallInvitationPushTypeEnumTypeTransformer._();

  const CallInvitationPushTypeEnumTypeTransformer._();

  String encode(CallInvitationPushTypeEnum data) => data._value;

  /// Returns the instance of [CallInvitationPushTypeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CallInvitationPushTypeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CallInvitationPushTypeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'call.invitation': return CallInvitationPushTypeEnum.callPeriodInvitation;
        case r'call.terminal': return CallInvitationPushTypeEnum.callPeriodTerminal;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CallInvitationPushTypeEnumTypeTransformer? _instance;
}


