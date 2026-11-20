//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class DeletionReceipt {
  /// Returns a new [DeletionReceipt] instance.
  DeletionReceipt({
    required this.requestId,
    required this.status,
    required this.requestedAt,
    required this.personalDataDeletedAt,
    this.holds = const [],
    required this.noticeVersion,
    required this.testOnly,
    required this.retentionReviewRequired,
  });

  String requestId;

  DeletionReceiptStatusEnum status;

  DateTime requestedAt;

  DateTime? personalDataDeletedAt;

  List<String> holds;

  DeletionReceiptNoticeVersionEnum noticeVersion;

  DeletionReceiptTestOnlyEnum testOnly;

  DeletionReceiptRetentionReviewRequiredEnum retentionReviewRequired;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DeletionReceipt &&
    other.requestId == requestId &&
    other.status == status &&
    other.requestedAt == requestedAt &&
    other.personalDataDeletedAt == personalDataDeletedAt &&
    _deepEquality.equals(other.holds, holds) &&
    other.noticeVersion == noticeVersion &&
    other.testOnly == testOnly &&
    other.retentionReviewRequired == retentionReviewRequired;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (requestId.hashCode) +
    (status.hashCode) +
    (requestedAt.hashCode) +
    (personalDataDeletedAt == null ? 0 : personalDataDeletedAt!.hashCode) +
    (holds.hashCode) +
    (noticeVersion.hashCode) +
    (testOnly.hashCode) +
    (retentionReviewRequired.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'DeletionReceipt[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'requestId'] = this.requestId;
      json[r'status'] = this.status;
      json[r'requestedAt'] = this.requestedAt.toUtc().toIso8601String();
    if (this.personalDataDeletedAt != null) {
      json[r'personalDataDeletedAt'] = this.personalDataDeletedAt!.toUtc().toIso8601String();
    } else {
      json[r'personalDataDeletedAt'] = null;
    }
      json[r'holds'] = this.holds;
      json[r'noticeVersion'] = this.noticeVersion;
      json[r'testOnly'] = this.testOnly;
      json[r'retentionReviewRequired'] = this.retentionReviewRequired;
    return json;
  }

  /// Returns a new [DeletionReceipt] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DeletionReceipt? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid DeletionReceipt object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'requestId')) {
        throw const FormatException('Missing DeletionReceipt.requestId');
      }
      if (json[r'requestId'] == null) {
        throw const FormatException('Null DeletionReceipt.requestId');
      }
      if (!json.containsKey(r'status')) {
        throw const FormatException('Missing DeletionReceipt.status');
      }
      if (json[r'status'] == null) {
        throw const FormatException('Null DeletionReceipt.status');
      }
      if (!json.containsKey(r'requestedAt')) {
        throw const FormatException('Missing DeletionReceipt.requestedAt');
      }
      if (json[r'requestedAt'] == null) {
        throw const FormatException('Null DeletionReceipt.requestedAt');
      }
      if (json[r'requestedAt'] != null && (json[r'requestedAt'] is! String || DateTime.tryParse(json[r'requestedAt'] as String) == null)) {
        throw const FormatException('Invalid DeletionReceipt.requestedAt');
      }
      if (!json.containsKey(r'personalDataDeletedAt')) {
        throw const FormatException('Missing DeletionReceipt.personalDataDeletedAt');
      }
      if (json[r'personalDataDeletedAt'] != null && (json[r'personalDataDeletedAt'] is! String || DateTime.tryParse(json[r'personalDataDeletedAt'] as String) == null)) {
        throw const FormatException('Invalid DeletionReceipt.personalDataDeletedAt');
      }
      if (!json.containsKey(r'holds')) {
        throw const FormatException('Missing DeletionReceipt.holds');
      }
      if (json[r'holds'] == null) {
        throw const FormatException('Null DeletionReceipt.holds');
      }
      if (json[r'holds'] != null && json[r'holds'] is! List) {
        throw const FormatException('Invalid DeletionReceipt.holds');
      }
      if (!json.containsKey(r'noticeVersion')) {
        throw const FormatException('Missing DeletionReceipt.noticeVersion');
      }
      if (json[r'noticeVersion'] == null) {
        throw const FormatException('Null DeletionReceipt.noticeVersion');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing DeletionReceipt.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null DeletionReceipt.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid DeletionReceipt.testOnly boolean');
      }
      if (!json.containsKey(r'retentionReviewRequired')) {
        throw const FormatException('Missing DeletionReceipt.retentionReviewRequired');
      }
      if (json[r'retentionReviewRequired'] == null) {
        throw const FormatException('Null DeletionReceipt.retentionReviewRequired');
      }
      if (json[r'retentionReviewRequired'] != null && json[r'retentionReviewRequired'] is! bool) {
        throw const FormatException('Invalid DeletionReceipt.retentionReviewRequired boolean');
      }

      return DeletionReceipt(
        requestId: mapValueOfType<String>(json, r'requestId')!,
        status: DeletionReceiptStatusEnum.fromJson(json[r'status'])!,
        requestedAt: mapDateTime(json, r'requestedAt', r'')!,
        personalDataDeletedAt: mapDateTime(json, r'personalDataDeletedAt', r''),
        holds: json[r'holds'] is Iterable
            ? (json[r'holds'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        noticeVersion: DeletionReceiptNoticeVersionEnum.fromJson(json[r'noticeVersion'])!,
        testOnly: DeletionReceiptTestOnlyEnum.fromJson(json[r'testOnly'])!,
        retentionReviewRequired: DeletionReceiptRetentionReviewRequiredEnum.fromJson(json[r'retentionReviewRequired'])!,
      );
    }
    return null;
  }

  static List<DeletionReceipt> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionReceipt>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionReceipt.fromJson(row);
        if (value == null) throw const FormatException('Invalid DeletionReceipt list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DeletionReceipt> mapFromJson(dynamic json) {
    final map = <String, DeletionReceipt>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DeletionReceipt.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DeletionReceipt-objects as value to a dart map
  static Map<String, List<DeletionReceipt>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DeletionReceipt>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DeletionReceipt.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'requestId',
    'status',
    'requestedAt',
    'personalDataDeletedAt',
    'holds',
    'noticeVersion',
    'testOnly',
    'retentionReviewRequired',
  };
}


enum DeletionReceiptStatusEnum {
  pendingHold._(r'pending_hold'),
  reviewRequired._(r'review_required'),
  ;

  /// Instantiate a new enum with the provided value.
  const DeletionReceiptStatusEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [DeletionReceiptStatusEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DeletionReceiptStatusEnum? fromJson(dynamic value) => DeletionReceiptStatusEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DeletionReceiptStatusEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DeletionReceiptStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionReceiptStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionReceiptStatusEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DeletionReceiptStatusEnum] to String,
/// and [decode] dynamic data back to [DeletionReceiptStatusEnum].
class DeletionReceiptStatusEnumTypeTransformer {
  factory DeletionReceiptStatusEnumTypeTransformer() => _instance ??= const DeletionReceiptStatusEnumTypeTransformer._();

  const DeletionReceiptStatusEnumTypeTransformer._();

  String encode(DeletionReceiptStatusEnum data) => data._value;

  /// Returns the instance of [DeletionReceiptStatusEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DeletionReceiptStatusEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DeletionReceiptStatusEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'pending_hold': return DeletionReceiptStatusEnum.pendingHold;
        case r'review_required': return DeletionReceiptStatusEnum.reviewRequired;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DeletionReceiptStatusEnumTypeTransformer? _instance;
}



enum DeletionReceiptNoticeVersionEnum {
  accountDeletionTestV1._(r'account-deletion-test-v1'),
  ;

  /// Instantiate a new enum with the provided value.
  const DeletionReceiptNoticeVersionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [DeletionReceiptNoticeVersionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DeletionReceiptNoticeVersionEnum? fromJson(dynamic value) => DeletionReceiptNoticeVersionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DeletionReceiptNoticeVersionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DeletionReceiptNoticeVersionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionReceiptNoticeVersionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionReceiptNoticeVersionEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DeletionReceiptNoticeVersionEnum] to String,
/// and [decode] dynamic data back to [DeletionReceiptNoticeVersionEnum].
class DeletionReceiptNoticeVersionEnumTypeTransformer {
  factory DeletionReceiptNoticeVersionEnumTypeTransformer() => _instance ??= const DeletionReceiptNoticeVersionEnumTypeTransformer._();

  const DeletionReceiptNoticeVersionEnumTypeTransformer._();

  String encode(DeletionReceiptNoticeVersionEnum data) => data._value;

  /// Returns the instance of [DeletionReceiptNoticeVersionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DeletionReceiptNoticeVersionEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DeletionReceiptNoticeVersionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'account-deletion-test-v1': return DeletionReceiptNoticeVersionEnum.accountDeletionTestV1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DeletionReceiptNoticeVersionEnumTypeTransformer? _instance;
}



enum DeletionReceiptTestOnlyEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const DeletionReceiptTestOnlyEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [DeletionReceiptTestOnlyEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DeletionReceiptTestOnlyEnum? fromJson(dynamic value) => DeletionReceiptTestOnlyEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DeletionReceiptTestOnlyEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DeletionReceiptTestOnlyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionReceiptTestOnlyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionReceiptTestOnlyEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DeletionReceiptTestOnlyEnum] to bool,
/// and [decode] dynamic data back to [DeletionReceiptTestOnlyEnum].
class DeletionReceiptTestOnlyEnumTypeTransformer {
  factory DeletionReceiptTestOnlyEnumTypeTransformer() => _instance ??= const DeletionReceiptTestOnlyEnumTypeTransformer._();

  const DeletionReceiptTestOnlyEnumTypeTransformer._();

  bool encode(DeletionReceiptTestOnlyEnum data) => data._value;

  /// Returns the instance of [DeletionReceiptTestOnlyEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DeletionReceiptTestOnlyEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DeletionReceiptTestOnlyEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return DeletionReceiptTestOnlyEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DeletionReceiptTestOnlyEnumTypeTransformer? _instance;
}



enum DeletionReceiptRetentionReviewRequiredEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const DeletionReceiptRetentionReviewRequiredEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [DeletionReceiptRetentionReviewRequiredEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DeletionReceiptRetentionReviewRequiredEnum? fromJson(dynamic value) => DeletionReceiptRetentionReviewRequiredEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DeletionReceiptRetentionReviewRequiredEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DeletionReceiptRetentionReviewRequiredEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionReceiptRetentionReviewRequiredEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionReceiptRetentionReviewRequiredEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DeletionReceiptRetentionReviewRequiredEnum] to bool,
/// and [decode] dynamic data back to [DeletionReceiptRetentionReviewRequiredEnum].
class DeletionReceiptRetentionReviewRequiredEnumTypeTransformer {
  factory DeletionReceiptRetentionReviewRequiredEnumTypeTransformer() => _instance ??= const DeletionReceiptRetentionReviewRequiredEnumTypeTransformer._();

  const DeletionReceiptRetentionReviewRequiredEnumTypeTransformer._();

  bool encode(DeletionReceiptRetentionReviewRequiredEnum data) => data._value;

  /// Returns the instance of [DeletionReceiptRetentionReviewRequiredEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DeletionReceiptRetentionReviewRequiredEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DeletionReceiptRetentionReviewRequiredEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return DeletionReceiptRetentionReviewRequiredEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DeletionReceiptRetentionReviewRequiredEnumTypeTransformer? _instance;
}


