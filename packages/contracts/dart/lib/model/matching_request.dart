//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class MatchingRequest {
  /// Returns a new [MatchingRequest] instance.
  MatchingRequest({
    required this.id,
    required this.version,
    required this.state,
    required this.language,
    required this.mediaType,
    required this.quoteId,
    required this.attemptCount,
    required this.maxAttempts,
    required this.waitBudgetSeconds,
    required this.invitationSeconds,
    required this.createdAt,
    required this.deadlineAt,
    required this.endedAt,
    required this.currentCallId,
    required this.terminalReason,
    this.selectionReasons = const {},
    required this.serverTime,
    required this.testOnly,
  });

  String id;

  /// Minimum value: 1
  int version;

  MatchingRequestStateEnum state;

  MatchingRequestLanguageEnum language;

  MatchingRequestMediaTypeEnum mediaType;

  String quoteId;

  /// Minimum value: 0
  /// Maximum value: 3
  int attemptCount;

  MatchingRequestMaxAttemptsEnum maxAttempts;

  MatchingRequestWaitBudgetSecondsEnum waitBudgetSeconds;

  MatchingRequestInvitationSecondsEnum invitationSeconds;

  DateTime createdAt;

  DateTime deadlineAt;

  DateTime? endedAt;

  String? currentCallId;

  MatchingRequestTerminalReasonEnum? terminalReason;

  Set<MatchingRequestSelectionReasonsEnum> selectionReasons;

  DateTime serverTime;

  MatchingRequestTestOnlyEnum testOnly;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MatchingRequest &&
    other.id == id &&
    other.version == version &&
    other.state == state &&
    other.language == language &&
    other.mediaType == mediaType &&
    other.quoteId == quoteId &&
    other.attemptCount == attemptCount &&
    other.maxAttempts == maxAttempts &&
    other.waitBudgetSeconds == waitBudgetSeconds &&
    other.invitationSeconds == invitationSeconds &&
    other.createdAt == createdAt &&
    other.deadlineAt == deadlineAt &&
    other.endedAt == endedAt &&
    other.currentCallId == currentCallId &&
    other.terminalReason == terminalReason &&
    _deepEquality.equals(other.selectionReasons, selectionReasons) &&
    other.serverTime == serverTime &&
    other.testOnly == testOnly;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (version.hashCode) +
    (state.hashCode) +
    (language.hashCode) +
    (mediaType.hashCode) +
    (quoteId.hashCode) +
    (attemptCount.hashCode) +
    (maxAttempts.hashCode) +
    (waitBudgetSeconds.hashCode) +
    (invitationSeconds.hashCode) +
    (createdAt.hashCode) +
    (deadlineAt.hashCode) +
    (endedAt == null ? 0 : endedAt!.hashCode) +
    (currentCallId == null ? 0 : currentCallId!.hashCode) +
    (terminalReason == null ? 0 : terminalReason!.hashCode) +
    (selectionReasons.hashCode) +
    (serverTime.hashCode) +
    (testOnly.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'MatchingRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'version'] = this.version;
      json[r'state'] = this.state;
      json[r'language'] = this.language;
      json[r'mediaType'] = this.mediaType;
      json[r'quoteId'] = this.quoteId;
      json[r'attemptCount'] = this.attemptCount;
      json[r'maxAttempts'] = this.maxAttempts;
      json[r'waitBudgetSeconds'] = this.waitBudgetSeconds;
      json[r'invitationSeconds'] = this.invitationSeconds;
      json[r'createdAt'] = this.createdAt.toUtc().toIso8601String();
      json[r'deadlineAt'] = this.deadlineAt.toUtc().toIso8601String();
    if (this.endedAt != null) {
      json[r'endedAt'] = this.endedAt!.toUtc().toIso8601String();
    } else {
      json[r'endedAt'] = null;
    }
    if (this.currentCallId != null) {
      json[r'currentCallId'] = this.currentCallId;
    } else {
      json[r'currentCallId'] = null;
    }
    if (this.terminalReason != null) {
      json[r'terminalReason'] = this.terminalReason;
    } else {
      json[r'terminalReason'] = null;
    }
      json[r'selectionReasons'] = this.selectionReasons.toList(growable: false);
      json[r'serverTime'] = this.serverTime.toUtc().toIso8601String();
      json[r'testOnly'] = this.testOnly;
    return json;
  }

  /// Returns a new [MatchingRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MatchingRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid MatchingRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing MatchingRequest.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null MatchingRequest.id');
      }
      if (!json.containsKey(r'version')) {
        throw const FormatException('Missing MatchingRequest.version');
      }
      if (json[r'version'] == null) {
        throw const FormatException('Null MatchingRequest.version');
      }
      if (json[r'version'] != null && json[r'version'] is! int) {
        throw const FormatException('Invalid MatchingRequest.version integer');
      }
      if (!json.containsKey(r'state')) {
        throw const FormatException('Missing MatchingRequest.state');
      }
      if (json[r'state'] == null) {
        throw const FormatException('Null MatchingRequest.state');
      }
      if (!json.containsKey(r'language')) {
        throw const FormatException('Missing MatchingRequest.language');
      }
      if (json[r'language'] == null) {
        throw const FormatException('Null MatchingRequest.language');
      }
      if (!json.containsKey(r'mediaType')) {
        throw const FormatException('Missing MatchingRequest.mediaType');
      }
      if (json[r'mediaType'] == null) {
        throw const FormatException('Null MatchingRequest.mediaType');
      }
      if (!json.containsKey(r'quoteId')) {
        throw const FormatException('Missing MatchingRequest.quoteId');
      }
      if (json[r'quoteId'] == null) {
        throw const FormatException('Null MatchingRequest.quoteId');
      }
      if (!json.containsKey(r'attemptCount')) {
        throw const FormatException('Missing MatchingRequest.attemptCount');
      }
      if (json[r'attemptCount'] == null) {
        throw const FormatException('Null MatchingRequest.attemptCount');
      }
      if (json[r'attemptCount'] != null && json[r'attemptCount'] is! int) {
        throw const FormatException('Invalid MatchingRequest.attemptCount integer');
      }
      if (!json.containsKey(r'maxAttempts')) {
        throw const FormatException('Missing MatchingRequest.maxAttempts');
      }
      if (json[r'maxAttempts'] == null) {
        throw const FormatException('Null MatchingRequest.maxAttempts');
      }
      if (json[r'maxAttempts'] != null && json[r'maxAttempts'] is! int) {
        throw const FormatException('Invalid MatchingRequest.maxAttempts integer');
      }
      if (!json.containsKey(r'waitBudgetSeconds')) {
        throw const FormatException('Missing MatchingRequest.waitBudgetSeconds');
      }
      if (json[r'waitBudgetSeconds'] == null) {
        throw const FormatException('Null MatchingRequest.waitBudgetSeconds');
      }
      if (json[r'waitBudgetSeconds'] != null && json[r'waitBudgetSeconds'] is! int) {
        throw const FormatException('Invalid MatchingRequest.waitBudgetSeconds integer');
      }
      if (!json.containsKey(r'invitationSeconds')) {
        throw const FormatException('Missing MatchingRequest.invitationSeconds');
      }
      if (json[r'invitationSeconds'] == null) {
        throw const FormatException('Null MatchingRequest.invitationSeconds');
      }
      if (json[r'invitationSeconds'] != null && json[r'invitationSeconds'] is! int) {
        throw const FormatException('Invalid MatchingRequest.invitationSeconds integer');
      }
      if (!json.containsKey(r'createdAt')) {
        throw const FormatException('Missing MatchingRequest.createdAt');
      }
      if (json[r'createdAt'] == null) {
        throw const FormatException('Null MatchingRequest.createdAt');
      }
      if (json[r'createdAt'] != null && (json[r'createdAt'] is! String || DateTime.tryParse(json[r'createdAt'] as String) == null)) {
        throw const FormatException('Invalid MatchingRequest.createdAt');
      }
      if (!json.containsKey(r'deadlineAt')) {
        throw const FormatException('Missing MatchingRequest.deadlineAt');
      }
      if (json[r'deadlineAt'] == null) {
        throw const FormatException('Null MatchingRequest.deadlineAt');
      }
      if (json[r'deadlineAt'] != null && (json[r'deadlineAt'] is! String || DateTime.tryParse(json[r'deadlineAt'] as String) == null)) {
        throw const FormatException('Invalid MatchingRequest.deadlineAt');
      }
      if (!json.containsKey(r'endedAt')) {
        throw const FormatException('Missing MatchingRequest.endedAt');
      }
      if (json[r'endedAt'] != null && (json[r'endedAt'] is! String || DateTime.tryParse(json[r'endedAt'] as String) == null)) {
        throw const FormatException('Invalid MatchingRequest.endedAt');
      }
      if (!json.containsKey(r'currentCallId')) {
        throw const FormatException('Missing MatchingRequest.currentCallId');
      }
      if (!json.containsKey(r'terminalReason')) {
        throw const FormatException('Missing MatchingRequest.terminalReason');
      }
      if (!json.containsKey(r'selectionReasons')) {
        throw const FormatException('Missing MatchingRequest.selectionReasons');
      }
      if (json[r'selectionReasons'] == null) {
        throw const FormatException('Null MatchingRequest.selectionReasons');
      }
      if (json[r'selectionReasons'] != null && json[r'selectionReasons'] is! List) {
        throw const FormatException('Invalid MatchingRequest.selectionReasons');
      }
      if (!json.containsKey(r'serverTime')) {
        throw const FormatException('Missing MatchingRequest.serverTime');
      }
      if (json[r'serverTime'] == null) {
        throw const FormatException('Null MatchingRequest.serverTime');
      }
      if (json[r'serverTime'] != null && (json[r'serverTime'] is! String || DateTime.tryParse(json[r'serverTime'] as String) == null)) {
        throw const FormatException('Invalid MatchingRequest.serverTime');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing MatchingRequest.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null MatchingRequest.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid MatchingRequest.testOnly boolean');
      }

      return MatchingRequest(
        id: mapValueOfType<String>(json, r'id')!,
        version: mapValueOfType<int>(json, r'version')!,
        state: MatchingRequestStateEnum.fromJson(json[r'state'])!,
        language: MatchingRequestLanguageEnum.fromJson(json[r'language'])!,
        mediaType: MatchingRequestMediaTypeEnum.fromJson(json[r'mediaType'])!,
        quoteId: mapValueOfType<String>(json, r'quoteId')!,
        attemptCount: mapValueOfType<int>(json, r'attemptCount')!,
        maxAttempts: MatchingRequestMaxAttemptsEnum.fromJson(json[r'maxAttempts'])!,
        waitBudgetSeconds: MatchingRequestWaitBudgetSecondsEnum.fromJson(json[r'waitBudgetSeconds'])!,
        invitationSeconds: MatchingRequestInvitationSecondsEnum.fromJson(json[r'invitationSeconds'])!,
        createdAt: mapDateTime(json, r'createdAt', r'')!,
        deadlineAt: mapDateTime(json, r'deadlineAt', r'')!,
        endedAt: mapDateTime(json, r'endedAt', r''),
        currentCallId: mapValueOfType<String>(json, r'currentCallId'),
        terminalReason: MatchingRequestTerminalReasonEnum.fromJson(json[r'terminalReason']),
        selectionReasons: MatchingRequestSelectionReasonsEnum.listFromJson(json[r'selectionReasons']).toSet(),
        serverTime: mapDateTime(json, r'serverTime', r'')!,
        testOnly: MatchingRequestTestOnlyEnum.fromJson(json[r'testOnly'])!,
      );
    }
    return null;
  }

  static List<MatchingRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MatchingRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MatchingRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid MatchingRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MatchingRequest> mapFromJson(dynamic json) {
    final map = <String, MatchingRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MatchingRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MatchingRequest-objects as value to a dart map
  static Map<String, List<MatchingRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<MatchingRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MatchingRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'version',
    'state',
    'language',
    'mediaType',
    'quoteId',
    'attemptCount',
    'maxAttempts',
    'waitBudgetSeconds',
    'invitationSeconds',
    'createdAt',
    'deadlineAt',
    'endedAt',
    'currentCallId',
    'terminalReason',
    'selectionReasons',
    'serverTime',
    'testOnly',
  };
}


enum MatchingRequestStateEnum {
  searching._(r'searching'),
  ringing._(r'ringing'),
  matched._(r'matched'),
  cancelled._(r'cancelled'),
  exhausted._(r'exhausted'),
  expired._(r'expired'),
  failed._(r'failed'),
  ;

  /// Instantiate a new enum with the provided value.
  const MatchingRequestStateEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [MatchingRequestStateEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static MatchingRequestStateEnum? fromJson(dynamic value) => MatchingRequestStateEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [MatchingRequestStateEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<MatchingRequestStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MatchingRequestStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MatchingRequestStateEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [MatchingRequestStateEnum] to String,
/// and [decode] dynamic data back to [MatchingRequestStateEnum].
class MatchingRequestStateEnumTypeTransformer {
  factory MatchingRequestStateEnumTypeTransformer() => _instance ??= const MatchingRequestStateEnumTypeTransformer._();

  const MatchingRequestStateEnumTypeTransformer._();

  String encode(MatchingRequestStateEnum data) => data._value;

  /// Returns the instance of [MatchingRequestStateEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  MatchingRequestStateEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is MatchingRequestStateEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'searching': return MatchingRequestStateEnum.searching;
        case r'ringing': return MatchingRequestStateEnum.ringing;
        case r'matched': return MatchingRequestStateEnum.matched;
        case r'cancelled': return MatchingRequestStateEnum.cancelled;
        case r'exhausted': return MatchingRequestStateEnum.exhausted;
        case r'expired': return MatchingRequestStateEnum.expired;
        case r'failed': return MatchingRequestStateEnum.failed;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static MatchingRequestStateEnumTypeTransformer? _instance;
}



enum MatchingRequestLanguageEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const MatchingRequestLanguageEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [MatchingRequestLanguageEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static MatchingRequestLanguageEnum? fromJson(dynamic value) => MatchingRequestLanguageEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [MatchingRequestLanguageEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<MatchingRequestLanguageEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MatchingRequestLanguageEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MatchingRequestLanguageEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [MatchingRequestLanguageEnum] to String,
/// and [decode] dynamic data back to [MatchingRequestLanguageEnum].
class MatchingRequestLanguageEnumTypeTransformer {
  factory MatchingRequestLanguageEnumTypeTransformer() => _instance ??= const MatchingRequestLanguageEnumTypeTransformer._();

  const MatchingRequestLanguageEnumTypeTransformer._();

  String encode(MatchingRequestLanguageEnum data) => data._value;

  /// Returns the instance of [MatchingRequestLanguageEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  MatchingRequestLanguageEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is MatchingRequestLanguageEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return MatchingRequestLanguageEnum.ta;
        case r'en': return MatchingRequestLanguageEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static MatchingRequestLanguageEnumTypeTransformer? _instance;
}



enum MatchingRequestMediaTypeEnum {
  audio._(r'audio'),
  ;

  /// Instantiate a new enum with the provided value.
  const MatchingRequestMediaTypeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [MatchingRequestMediaTypeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static MatchingRequestMediaTypeEnum? fromJson(dynamic value) => MatchingRequestMediaTypeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [MatchingRequestMediaTypeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<MatchingRequestMediaTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MatchingRequestMediaTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MatchingRequestMediaTypeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [MatchingRequestMediaTypeEnum] to String,
/// and [decode] dynamic data back to [MatchingRequestMediaTypeEnum].
class MatchingRequestMediaTypeEnumTypeTransformer {
  factory MatchingRequestMediaTypeEnumTypeTransformer() => _instance ??= const MatchingRequestMediaTypeEnumTypeTransformer._();

  const MatchingRequestMediaTypeEnumTypeTransformer._();

  String encode(MatchingRequestMediaTypeEnum data) => data._value;

  /// Returns the instance of [MatchingRequestMediaTypeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  MatchingRequestMediaTypeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is MatchingRequestMediaTypeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'audio': return MatchingRequestMediaTypeEnum.audio;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static MatchingRequestMediaTypeEnumTypeTransformer? _instance;
}



enum MatchingRequestMaxAttemptsEnum {
  number3._(3),
  ;

  /// Instantiate a new enum with the provided value.
  const MatchingRequestMaxAttemptsEnum._(this._value);

  /// The underlying value of this enum member.
  final int _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  int toJson() => _value;

  /// Returns the instance of [MatchingRequestMaxAttemptsEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static MatchingRequestMaxAttemptsEnum? fromJson(dynamic value) => MatchingRequestMaxAttemptsEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [MatchingRequestMaxAttemptsEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<MatchingRequestMaxAttemptsEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MatchingRequestMaxAttemptsEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MatchingRequestMaxAttemptsEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [MatchingRequestMaxAttemptsEnum] to int,
/// and [decode] dynamic data back to [MatchingRequestMaxAttemptsEnum].
class MatchingRequestMaxAttemptsEnumTypeTransformer {
  factory MatchingRequestMaxAttemptsEnumTypeTransformer() => _instance ??= const MatchingRequestMaxAttemptsEnumTypeTransformer._();

  const MatchingRequestMaxAttemptsEnumTypeTransformer._();

  int encode(MatchingRequestMaxAttemptsEnum data) => data._value;

  /// Returns the instance of [MatchingRequestMaxAttemptsEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  MatchingRequestMaxAttemptsEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is MatchingRequestMaxAttemptsEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 3: return MatchingRequestMaxAttemptsEnum.number3;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static MatchingRequestMaxAttemptsEnumTypeTransformer? _instance;
}



enum MatchingRequestWaitBudgetSecondsEnum {
  number90._(90),
  ;

  /// Instantiate a new enum with the provided value.
  const MatchingRequestWaitBudgetSecondsEnum._(this._value);

  /// The underlying value of this enum member.
  final int _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  int toJson() => _value;

  /// Returns the instance of [MatchingRequestWaitBudgetSecondsEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static MatchingRequestWaitBudgetSecondsEnum? fromJson(dynamic value) => MatchingRequestWaitBudgetSecondsEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [MatchingRequestWaitBudgetSecondsEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<MatchingRequestWaitBudgetSecondsEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MatchingRequestWaitBudgetSecondsEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MatchingRequestWaitBudgetSecondsEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [MatchingRequestWaitBudgetSecondsEnum] to int,
/// and [decode] dynamic data back to [MatchingRequestWaitBudgetSecondsEnum].
class MatchingRequestWaitBudgetSecondsEnumTypeTransformer {
  factory MatchingRequestWaitBudgetSecondsEnumTypeTransformer() => _instance ??= const MatchingRequestWaitBudgetSecondsEnumTypeTransformer._();

  const MatchingRequestWaitBudgetSecondsEnumTypeTransformer._();

  int encode(MatchingRequestWaitBudgetSecondsEnum data) => data._value;

  /// Returns the instance of [MatchingRequestWaitBudgetSecondsEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  MatchingRequestWaitBudgetSecondsEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is MatchingRequestWaitBudgetSecondsEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 90: return MatchingRequestWaitBudgetSecondsEnum.number90;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static MatchingRequestWaitBudgetSecondsEnumTypeTransformer? _instance;
}



enum MatchingRequestInvitationSecondsEnum {
  number30._(30),
  ;

  /// Instantiate a new enum with the provided value.
  const MatchingRequestInvitationSecondsEnum._(this._value);

  /// The underlying value of this enum member.
  final int _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  int toJson() => _value;

  /// Returns the instance of [MatchingRequestInvitationSecondsEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static MatchingRequestInvitationSecondsEnum? fromJson(dynamic value) => MatchingRequestInvitationSecondsEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [MatchingRequestInvitationSecondsEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<MatchingRequestInvitationSecondsEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MatchingRequestInvitationSecondsEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MatchingRequestInvitationSecondsEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [MatchingRequestInvitationSecondsEnum] to int,
/// and [decode] dynamic data back to [MatchingRequestInvitationSecondsEnum].
class MatchingRequestInvitationSecondsEnumTypeTransformer {
  factory MatchingRequestInvitationSecondsEnumTypeTransformer() => _instance ??= const MatchingRequestInvitationSecondsEnumTypeTransformer._();

  const MatchingRequestInvitationSecondsEnumTypeTransformer._();

  int encode(MatchingRequestInvitationSecondsEnum data) => data._value;

  /// Returns the instance of [MatchingRequestInvitationSecondsEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  MatchingRequestInvitationSecondsEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is MatchingRequestInvitationSecondsEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 30: return MatchingRequestInvitationSecondsEnum.number30;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static MatchingRequestInvitationSecondsEnumTypeTransformer? _instance;
}



enum MatchingRequestTerminalReasonEnum {
  noSupply._(r'no_supply'),
  allDeclined._(r'all_declined'),
  attemptsExhausted._(r'attempts_exhausted'),
  waitBudgetElapsed._(r'wait_budget_elapsed'),
  customerCancelled._(r'customer_cancelled'),
  sourceSessionEnded._(r'source_session_ended'),
  accountRestricted._(r'account_restricted'),
  safetyBlocked._(r'safety_blocked'),
  insufficientBalance._(r'insufficient_balance'),
  quoteUnavailable._(r'quote_unavailable'),
  ;

  /// Instantiate a new enum with the provided value.
  const MatchingRequestTerminalReasonEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [MatchingRequestTerminalReasonEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static MatchingRequestTerminalReasonEnum? fromJson(dynamic value) => MatchingRequestTerminalReasonEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [MatchingRequestTerminalReasonEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<MatchingRequestTerminalReasonEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MatchingRequestTerminalReasonEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MatchingRequestTerminalReasonEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [MatchingRequestTerminalReasonEnum] to String,
/// and [decode] dynamic data back to [MatchingRequestTerminalReasonEnum].
class MatchingRequestTerminalReasonEnumTypeTransformer {
  factory MatchingRequestTerminalReasonEnumTypeTransformer() => _instance ??= const MatchingRequestTerminalReasonEnumTypeTransformer._();

  const MatchingRequestTerminalReasonEnumTypeTransformer._();

  String encode(MatchingRequestTerminalReasonEnum data) => data._value;

  /// Returns the instance of [MatchingRequestTerminalReasonEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  MatchingRequestTerminalReasonEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is MatchingRequestTerminalReasonEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'no_supply': return MatchingRequestTerminalReasonEnum.noSupply;
        case r'all_declined': return MatchingRequestTerminalReasonEnum.allDeclined;
        case r'attempts_exhausted': return MatchingRequestTerminalReasonEnum.attemptsExhausted;
        case r'wait_budget_elapsed': return MatchingRequestTerminalReasonEnum.waitBudgetElapsed;
        case r'customer_cancelled': return MatchingRequestTerminalReasonEnum.customerCancelled;
        case r'source_session_ended': return MatchingRequestTerminalReasonEnum.sourceSessionEnded;
        case r'account_restricted': return MatchingRequestTerminalReasonEnum.accountRestricted;
        case r'safety_blocked': return MatchingRequestTerminalReasonEnum.safetyBlocked;
        case r'insufficient_balance': return MatchingRequestTerminalReasonEnum.insufficientBalance;
        case r'quote_unavailable': return MatchingRequestTerminalReasonEnum.quoteUnavailable;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static MatchingRequestTerminalReasonEnumTypeTransformer? _instance;
}



enum MatchingRequestSelectionReasonsEnum {
  languageMatch._(r'language_match'),
  currentlyAvailable._(r'currently_available'),
  fairRotation._(r'fair_rotation'),
  ;

  /// Instantiate a new enum with the provided value.
  const MatchingRequestSelectionReasonsEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [MatchingRequestSelectionReasonsEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static MatchingRequestSelectionReasonsEnum? fromJson(dynamic value) => MatchingRequestSelectionReasonsEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [MatchingRequestSelectionReasonsEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<MatchingRequestSelectionReasonsEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MatchingRequestSelectionReasonsEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MatchingRequestSelectionReasonsEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [MatchingRequestSelectionReasonsEnum] to String,
/// and [decode] dynamic data back to [MatchingRequestSelectionReasonsEnum].
class MatchingRequestSelectionReasonsEnumTypeTransformer {
  factory MatchingRequestSelectionReasonsEnumTypeTransformer() => _instance ??= const MatchingRequestSelectionReasonsEnumTypeTransformer._();

  const MatchingRequestSelectionReasonsEnumTypeTransformer._();

  String encode(MatchingRequestSelectionReasonsEnum data) => data._value;

  /// Returns the instance of [MatchingRequestSelectionReasonsEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  MatchingRequestSelectionReasonsEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is MatchingRequestSelectionReasonsEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'language_match': return MatchingRequestSelectionReasonsEnum.languageMatch;
        case r'currently_available': return MatchingRequestSelectionReasonsEnum.currentlyAvailable;
        case r'fair_rotation': return MatchingRequestSelectionReasonsEnum.fairRotation;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static MatchingRequestSelectionReasonsEnumTypeTransformer? _instance;
}



enum MatchingRequestTestOnlyEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const MatchingRequestTestOnlyEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [MatchingRequestTestOnlyEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static MatchingRequestTestOnlyEnum? fromJson(dynamic value) => MatchingRequestTestOnlyEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [MatchingRequestTestOnlyEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<MatchingRequestTestOnlyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MatchingRequestTestOnlyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MatchingRequestTestOnlyEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [MatchingRequestTestOnlyEnum] to bool,
/// and [decode] dynamic data back to [MatchingRequestTestOnlyEnum].
class MatchingRequestTestOnlyEnumTypeTransformer {
  factory MatchingRequestTestOnlyEnumTypeTransformer() => _instance ??= const MatchingRequestTestOnlyEnumTypeTransformer._();

  const MatchingRequestTestOnlyEnumTypeTransformer._();

  bool encode(MatchingRequestTestOnlyEnum data) => data._value;

  /// Returns the instance of [MatchingRequestTestOnlyEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  MatchingRequestTestOnlyEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is MatchingRequestTestOnlyEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return MatchingRequestTestOnlyEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static MatchingRequestTestOnlyEnumTypeTransformer? _instance;
}


