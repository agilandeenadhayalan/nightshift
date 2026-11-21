//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class Call {
  /// Returns a new [Call] instance.
  Call({
    required this.id,
    required this.customerId,
    required this.listenerId,
    required this.customerName,
    required this.listenerName,
    required this.state,
    required this.version,
    required this.createdAt,
    required this.expiresAt,
    required this.acceptedAt,
    required this.endedAt,
    required this.reason,
    required this.connectedMs,
    required this.chargeMicrocredits,
    required this.earningPaise,
    required this.rate,
    required this.maxDurationSeconds,
    required this.testOnly,
    this.mediaType,
    this.durationLimitReason,
  });

  String id;

  String customerId;

  String listenerId;

  String customerName;

  String listenerName;

  CallStateEnum state;

  int version;

  DateTime createdAt;

  DateTime expiresAt;

  DateTime? acceptedAt;

  DateTime? endedAt;

  String? reason;

  int connectedMs;

  int chargeMicrocredits;

  int earningPaise;

  Rate rate;

  int maxDurationSeconds;

  CallTestOnlyEnum testOnly;

  CallMediaTypeEnum? mediaType;

  /// Reason for the frozen connected-time allowance at reservation. May be absent on legacy events and idempotent responses.
  CallDurationLimitReasonEnum? durationLimitReason;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Call &&
    other.id == id &&
    other.customerId == customerId &&
    other.listenerId == listenerId &&
    other.customerName == customerName &&
    other.listenerName == listenerName &&
    other.state == state &&
    other.version == version &&
    other.createdAt == createdAt &&
    other.expiresAt == expiresAt &&
    other.acceptedAt == acceptedAt &&
    other.endedAt == endedAt &&
    other.reason == reason &&
    other.connectedMs == connectedMs &&
    other.chargeMicrocredits == chargeMicrocredits &&
    other.earningPaise == earningPaise &&
    other.rate == rate &&
    other.maxDurationSeconds == maxDurationSeconds &&
    other.testOnly == testOnly &&
    other.mediaType == mediaType &&
    other.durationLimitReason == durationLimitReason;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (customerId.hashCode) +
    (listenerId.hashCode) +
    (customerName.hashCode) +
    (listenerName.hashCode) +
    (state.hashCode) +
    (version.hashCode) +
    (createdAt.hashCode) +
    (expiresAt.hashCode) +
    (acceptedAt == null ? 0 : acceptedAt!.hashCode) +
    (endedAt == null ? 0 : endedAt!.hashCode) +
    (reason == null ? 0 : reason!.hashCode) +
    (connectedMs.hashCode) +
    (chargeMicrocredits.hashCode) +
    (earningPaise.hashCode) +
    (rate.hashCode) +
    (maxDurationSeconds.hashCode) +
    (testOnly.hashCode) +
    (mediaType == null ? 0 : mediaType!.hashCode) +
    (durationLimitReason == null ? 0 : durationLimitReason!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'Call[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'customerId'] = this.customerId;
      json[r'listenerId'] = this.listenerId;
      json[r'customerName'] = this.customerName;
      json[r'listenerName'] = this.listenerName;
      json[r'state'] = this.state;
      json[r'version'] = this.version;
      json[r'createdAt'] = this.createdAt.toUtc().toIso8601String();
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
    if (this.acceptedAt != null) {
      json[r'acceptedAt'] = this.acceptedAt!.toUtc().toIso8601String();
    } else {
      json[r'acceptedAt'] = null;
    }
    if (this.endedAt != null) {
      json[r'endedAt'] = this.endedAt!.toUtc().toIso8601String();
    } else {
      json[r'endedAt'] = null;
    }
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    } else {
      json[r'reason'] = null;
    }
      json[r'connectedMs'] = this.connectedMs;
      json[r'chargeMicrocredits'] = this.chargeMicrocredits;
      json[r'earningPaise'] = this.earningPaise;
      json[r'rate'] = this.rate;
      json[r'maxDurationSeconds'] = this.maxDurationSeconds;
      json[r'testOnly'] = this.testOnly;
    if (this.mediaType != null) {
      json[r'mediaType'] = this.mediaType;
    }
    if (this.durationLimitReason != null) {
      json[r'durationLimitReason'] = this.durationLimitReason;
    }
    return json;
  }

  /// Returns a new [Call] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Call? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid Call object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing Call.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null Call.id');
      }
      if (!json.containsKey(r'customerId')) {
        throw const FormatException('Missing Call.customerId');
      }
      if (json[r'customerId'] == null) {
        throw const FormatException('Null Call.customerId');
      }
      if (!json.containsKey(r'listenerId')) {
        throw const FormatException('Missing Call.listenerId');
      }
      if (json[r'listenerId'] == null) {
        throw const FormatException('Null Call.listenerId');
      }
      if (!json.containsKey(r'customerName')) {
        throw const FormatException('Missing Call.customerName');
      }
      if (json[r'customerName'] == null) {
        throw const FormatException('Null Call.customerName');
      }
      if (!json.containsKey(r'listenerName')) {
        throw const FormatException('Missing Call.listenerName');
      }
      if (json[r'listenerName'] == null) {
        throw const FormatException('Null Call.listenerName');
      }
      if (!json.containsKey(r'state')) {
        throw const FormatException('Missing Call.state');
      }
      if (json[r'state'] == null) {
        throw const FormatException('Null Call.state');
      }
      if (!json.containsKey(r'version')) {
        throw const FormatException('Missing Call.version');
      }
      if (json[r'version'] == null) {
        throw const FormatException('Null Call.version');
      }
      if (json[r'version'] != null && json[r'version'] is! int) {
        throw const FormatException('Invalid Call.version integer');
      }
      if (!json.containsKey(r'createdAt')) {
        throw const FormatException('Missing Call.createdAt');
      }
      if (json[r'createdAt'] == null) {
        throw const FormatException('Null Call.createdAt');
      }
      if (json[r'createdAt'] != null && (json[r'createdAt'] is! String || DateTime.tryParse(json[r'createdAt'] as String) == null)) {
        throw const FormatException('Invalid Call.createdAt');
      }
      if (!json.containsKey(r'expiresAt')) {
        throw const FormatException('Missing Call.expiresAt');
      }
      if (json[r'expiresAt'] == null) {
        throw const FormatException('Null Call.expiresAt');
      }
      if (json[r'expiresAt'] != null && (json[r'expiresAt'] is! String || DateTime.tryParse(json[r'expiresAt'] as String) == null)) {
        throw const FormatException('Invalid Call.expiresAt');
      }
      if (!json.containsKey(r'acceptedAt')) {
        throw const FormatException('Missing Call.acceptedAt');
      }
      if (json[r'acceptedAt'] != null && (json[r'acceptedAt'] is! String || DateTime.tryParse(json[r'acceptedAt'] as String) == null)) {
        throw const FormatException('Invalid Call.acceptedAt');
      }
      if (!json.containsKey(r'endedAt')) {
        throw const FormatException('Missing Call.endedAt');
      }
      if (json[r'endedAt'] != null && (json[r'endedAt'] is! String || DateTime.tryParse(json[r'endedAt'] as String) == null)) {
        throw const FormatException('Invalid Call.endedAt');
      }
      if (!json.containsKey(r'reason')) {
        throw const FormatException('Missing Call.reason');
      }
      if (!json.containsKey(r'connectedMs')) {
        throw const FormatException('Missing Call.connectedMs');
      }
      if (json[r'connectedMs'] == null) {
        throw const FormatException('Null Call.connectedMs');
      }
      if (json[r'connectedMs'] != null && json[r'connectedMs'] is! int) {
        throw const FormatException('Invalid Call.connectedMs integer');
      }
      if (!json.containsKey(r'chargeMicrocredits')) {
        throw const FormatException('Missing Call.chargeMicrocredits');
      }
      if (json[r'chargeMicrocredits'] == null) {
        throw const FormatException('Null Call.chargeMicrocredits');
      }
      if (json[r'chargeMicrocredits'] != null && json[r'chargeMicrocredits'] is! int) {
        throw const FormatException('Invalid Call.chargeMicrocredits integer');
      }
      if (!json.containsKey(r'earningPaise')) {
        throw const FormatException('Missing Call.earningPaise');
      }
      if (json[r'earningPaise'] == null) {
        throw const FormatException('Null Call.earningPaise');
      }
      if (json[r'earningPaise'] != null && json[r'earningPaise'] is! int) {
        throw const FormatException('Invalid Call.earningPaise integer');
      }
      if (!json.containsKey(r'rate')) {
        throw const FormatException('Missing Call.rate');
      }
      if (json[r'rate'] == null) {
        throw const FormatException('Null Call.rate');
      }
      if (!json.containsKey(r'maxDurationSeconds')) {
        throw const FormatException('Missing Call.maxDurationSeconds');
      }
      if (json[r'maxDurationSeconds'] == null) {
        throw const FormatException('Null Call.maxDurationSeconds');
      }
      if (json[r'maxDurationSeconds'] != null && json[r'maxDurationSeconds'] is! int) {
        throw const FormatException('Invalid Call.maxDurationSeconds integer');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing Call.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null Call.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid Call.testOnly boolean');
      }

      return Call(
        id: mapValueOfType<String>(json, r'id')!,
        customerId: mapValueOfType<String>(json, r'customerId')!,
        listenerId: mapValueOfType<String>(json, r'listenerId')!,
        customerName: mapValueOfType<String>(json, r'customerName')!,
        listenerName: mapValueOfType<String>(json, r'listenerName')!,
        state: CallStateEnum.fromJson(json[r'state'])!,
        version: mapValueOfType<int>(json, r'version')!,
        createdAt: mapDateTime(json, r'createdAt', r'')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        acceptedAt: mapDateTime(json, r'acceptedAt', r''),
        endedAt: mapDateTime(json, r'endedAt', r''),
        reason: mapValueOfType<String>(json, r'reason'),
        connectedMs: mapValueOfType<int>(json, r'connectedMs')!,
        chargeMicrocredits: mapValueOfType<int>(json, r'chargeMicrocredits')!,
        earningPaise: mapValueOfType<int>(json, r'earningPaise')!,
        rate: Rate.fromJson(json[r'rate'])!,
        maxDurationSeconds: mapValueOfType<int>(json, r'maxDurationSeconds')!,
        testOnly: CallTestOnlyEnum.fromJson(json[r'testOnly'])!,
        mediaType: CallMediaTypeEnum.fromJson(json[r'mediaType']),
        durationLimitReason: CallDurationLimitReasonEnum.fromJson(json[r'durationLimitReason']),
      );
    }
    return null;
  }

  static List<Call> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Call>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Call.fromJson(row);
        if (value == null) throw const FormatException('Invalid Call list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Call> mapFromJson(dynamic json) {
    final map = <String, Call>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Call.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Call-objects as value to a dart map
  static Map<String, List<Call>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Call>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Call.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'customerId',
    'listenerId',
    'customerName',
    'listenerName',
    'state',
    'version',
    'createdAt',
    'expiresAt',
    'acceptedAt',
    'endedAt',
    'reason',
    'connectedMs',
    'chargeMicrocredits',
    'earningPaise',
    'rate',
    'maxDurationSeconds',
    'testOnly',
  };
}


enum CallStateEnum {
  ringing._(r'ringing'),
  connecting._(r'connecting'),
  connected._(r'connected'),
  reconnecting._(r'reconnecting'),
  ended._(r'ended'),
  ;

  /// Instantiate a new enum with the provided value.
  const CallStateEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CallStateEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CallStateEnum? fromJson(dynamic value) => CallStateEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CallStateEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CallStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CallStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CallStateEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CallStateEnum] to String,
/// and [decode] dynamic data back to [CallStateEnum].
class CallStateEnumTypeTransformer {
  factory CallStateEnumTypeTransformer() => _instance ??= const CallStateEnumTypeTransformer._();

  const CallStateEnumTypeTransformer._();

  String encode(CallStateEnum data) => data._value;

  /// Returns the instance of [CallStateEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CallStateEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CallStateEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ringing': return CallStateEnum.ringing;
        case r'connecting': return CallStateEnum.connecting;
        case r'connected': return CallStateEnum.connected;
        case r'reconnecting': return CallStateEnum.reconnecting;
        case r'ended': return CallStateEnum.ended;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CallStateEnumTypeTransformer? _instance;
}



enum CallTestOnlyEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const CallTestOnlyEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [CallTestOnlyEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CallTestOnlyEnum? fromJson(dynamic value) => CallTestOnlyEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CallTestOnlyEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CallTestOnlyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CallTestOnlyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CallTestOnlyEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CallTestOnlyEnum] to bool,
/// and [decode] dynamic data back to [CallTestOnlyEnum].
class CallTestOnlyEnumTypeTransformer {
  factory CallTestOnlyEnumTypeTransformer() => _instance ??= const CallTestOnlyEnumTypeTransformer._();

  const CallTestOnlyEnumTypeTransformer._();

  bool encode(CallTestOnlyEnum data) => data._value;

  /// Returns the instance of [CallTestOnlyEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CallTestOnlyEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CallTestOnlyEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return CallTestOnlyEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CallTestOnlyEnumTypeTransformer? _instance;
}



enum CallMediaTypeEnum {
  audio._(r'audio'),
  video._(r'video'),
  ;

  /// Instantiate a new enum with the provided value.
  const CallMediaTypeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CallMediaTypeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CallMediaTypeEnum? fromJson(dynamic value) => CallMediaTypeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CallMediaTypeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CallMediaTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CallMediaTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CallMediaTypeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CallMediaTypeEnum] to String,
/// and [decode] dynamic data back to [CallMediaTypeEnum].
class CallMediaTypeEnumTypeTransformer {
  factory CallMediaTypeEnumTypeTransformer() => _instance ??= const CallMediaTypeEnumTypeTransformer._();

  const CallMediaTypeEnumTypeTransformer._();

  String encode(CallMediaTypeEnum data) => data._value;

  /// Returns the instance of [CallMediaTypeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CallMediaTypeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CallMediaTypeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'audio': return CallMediaTypeEnum.audio;
        case r'video': return CallMediaTypeEnum.video;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CallMediaTypeEnumTypeTransformer? _instance;
}


/// Reason for the frozen connected-time allowance at reservation. May be absent on legacy events and idempotent responses.
enum CallDurationLimitReasonEnum {
  testCreditBalance._(r'test_credit_balance'),
  testDurationCap._(r'test_duration_cap'),
  ;

  /// Instantiate a new enum with the provided value.
  const CallDurationLimitReasonEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CallDurationLimitReasonEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CallDurationLimitReasonEnum? fromJson(dynamic value) => CallDurationLimitReasonEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CallDurationLimitReasonEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CallDurationLimitReasonEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CallDurationLimitReasonEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CallDurationLimitReasonEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CallDurationLimitReasonEnum] to String,
/// and [decode] dynamic data back to [CallDurationLimitReasonEnum].
class CallDurationLimitReasonEnumTypeTransformer {
  factory CallDurationLimitReasonEnumTypeTransformer() => _instance ??= const CallDurationLimitReasonEnumTypeTransformer._();

  const CallDurationLimitReasonEnumTypeTransformer._();

  String encode(CallDurationLimitReasonEnum data) => data._value;

  /// Returns the instance of [CallDurationLimitReasonEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CallDurationLimitReasonEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CallDurationLimitReasonEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'test_credit_balance': return CallDurationLimitReasonEnum.testCreditBalance;
        case r'test_duration_cap': return CallDurationLimitReasonEnum.testDurationCap;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CallDurationLimitReasonEnumTypeTransformer? _instance;
}


