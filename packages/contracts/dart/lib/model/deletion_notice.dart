//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class DeletionNotice {
  /// Returns a new [DeletionNotice] instance.
  DeletionNotice({
    required this.noticeVersion,
    required this.text,
    required this.testOnly,
    required this.retentionReviewRequired,
  });

  DeletionNoticeNoticeVersionEnum noticeVersion;

  String text;

  DeletionNoticeTestOnlyEnum testOnly;

  DeletionNoticeRetentionReviewRequiredEnum retentionReviewRequired;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DeletionNotice &&
    other.noticeVersion == noticeVersion &&
    other.text == text &&
    other.testOnly == testOnly &&
    other.retentionReviewRequired == retentionReviewRequired;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (noticeVersion.hashCode) +
    (text.hashCode) +
    (testOnly.hashCode) +
    (retentionReviewRequired.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'DeletionNotice[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'noticeVersion'] = this.noticeVersion;
      json[r'text'] = this.text;
      json[r'testOnly'] = this.testOnly;
      json[r'retentionReviewRequired'] = this.retentionReviewRequired;
    return json;
  }

  /// Returns a new [DeletionNotice] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DeletionNotice? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid DeletionNotice object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'noticeVersion')) {
        throw const FormatException('Missing DeletionNotice.noticeVersion');
      }
      if (json[r'noticeVersion'] == null) {
        throw const FormatException('Null DeletionNotice.noticeVersion');
      }
      if (!json.containsKey(r'text')) {
        throw const FormatException('Missing DeletionNotice.text');
      }
      if (json[r'text'] == null) {
        throw const FormatException('Null DeletionNotice.text');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing DeletionNotice.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null DeletionNotice.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid DeletionNotice.testOnly boolean');
      }
      if (!json.containsKey(r'retentionReviewRequired')) {
        throw const FormatException('Missing DeletionNotice.retentionReviewRequired');
      }
      if (json[r'retentionReviewRequired'] == null) {
        throw const FormatException('Null DeletionNotice.retentionReviewRequired');
      }
      if (json[r'retentionReviewRequired'] != null && json[r'retentionReviewRequired'] is! bool) {
        throw const FormatException('Invalid DeletionNotice.retentionReviewRequired boolean');
      }

      return DeletionNotice(
        noticeVersion: DeletionNoticeNoticeVersionEnum.fromJson(json[r'noticeVersion'])!,
        text: mapValueOfType<String>(json, r'text')!,
        testOnly: DeletionNoticeTestOnlyEnum.fromJson(json[r'testOnly'])!,
        retentionReviewRequired: DeletionNoticeRetentionReviewRequiredEnum.fromJson(json[r'retentionReviewRequired'])!,
      );
    }
    return null;
  }

  static List<DeletionNotice> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionNotice>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionNotice.fromJson(row);
        if (value == null) throw const FormatException('Invalid DeletionNotice list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DeletionNotice> mapFromJson(dynamic json) {
    final map = <String, DeletionNotice>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DeletionNotice.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DeletionNotice-objects as value to a dart map
  static Map<String, List<DeletionNotice>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DeletionNotice>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DeletionNotice.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'noticeVersion',
    'text',
    'testOnly',
    'retentionReviewRequired',
  };
}


enum DeletionNoticeNoticeVersionEnum {
  accountDeletionTestV1._(r'account-deletion-test-v1'),
  ;

  /// Instantiate a new enum with the provided value.
  const DeletionNoticeNoticeVersionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [DeletionNoticeNoticeVersionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DeletionNoticeNoticeVersionEnum? fromJson(dynamic value) => DeletionNoticeNoticeVersionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DeletionNoticeNoticeVersionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DeletionNoticeNoticeVersionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionNoticeNoticeVersionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionNoticeNoticeVersionEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DeletionNoticeNoticeVersionEnum] to String,
/// and [decode] dynamic data back to [DeletionNoticeNoticeVersionEnum].
class DeletionNoticeNoticeVersionEnumTypeTransformer {
  factory DeletionNoticeNoticeVersionEnumTypeTransformer() => _instance ??= const DeletionNoticeNoticeVersionEnumTypeTransformer._();

  const DeletionNoticeNoticeVersionEnumTypeTransformer._();

  String encode(DeletionNoticeNoticeVersionEnum data) => data._value;

  /// Returns the instance of [DeletionNoticeNoticeVersionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DeletionNoticeNoticeVersionEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DeletionNoticeNoticeVersionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'account-deletion-test-v1': return DeletionNoticeNoticeVersionEnum.accountDeletionTestV1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DeletionNoticeNoticeVersionEnumTypeTransformer? _instance;
}



enum DeletionNoticeTestOnlyEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const DeletionNoticeTestOnlyEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [DeletionNoticeTestOnlyEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DeletionNoticeTestOnlyEnum? fromJson(dynamic value) => DeletionNoticeTestOnlyEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DeletionNoticeTestOnlyEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DeletionNoticeTestOnlyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionNoticeTestOnlyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionNoticeTestOnlyEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DeletionNoticeTestOnlyEnum] to bool,
/// and [decode] dynamic data back to [DeletionNoticeTestOnlyEnum].
class DeletionNoticeTestOnlyEnumTypeTransformer {
  factory DeletionNoticeTestOnlyEnumTypeTransformer() => _instance ??= const DeletionNoticeTestOnlyEnumTypeTransformer._();

  const DeletionNoticeTestOnlyEnumTypeTransformer._();

  bool encode(DeletionNoticeTestOnlyEnum data) => data._value;

  /// Returns the instance of [DeletionNoticeTestOnlyEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DeletionNoticeTestOnlyEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DeletionNoticeTestOnlyEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return DeletionNoticeTestOnlyEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DeletionNoticeTestOnlyEnumTypeTransformer? _instance;
}



enum DeletionNoticeRetentionReviewRequiredEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const DeletionNoticeRetentionReviewRequiredEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [DeletionNoticeRetentionReviewRequiredEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DeletionNoticeRetentionReviewRequiredEnum? fromJson(dynamic value) => DeletionNoticeRetentionReviewRequiredEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DeletionNoticeRetentionReviewRequiredEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DeletionNoticeRetentionReviewRequiredEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionNoticeRetentionReviewRequiredEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionNoticeRetentionReviewRequiredEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DeletionNoticeRetentionReviewRequiredEnum] to bool,
/// and [decode] dynamic data back to [DeletionNoticeRetentionReviewRequiredEnum].
class DeletionNoticeRetentionReviewRequiredEnumTypeTransformer {
  factory DeletionNoticeRetentionReviewRequiredEnumTypeTransformer() => _instance ??= const DeletionNoticeRetentionReviewRequiredEnumTypeTransformer._();

  const DeletionNoticeRetentionReviewRequiredEnumTypeTransformer._();

  bool encode(DeletionNoticeRetentionReviewRequiredEnum data) => data._value;

  /// Returns the instance of [DeletionNoticeRetentionReviewRequiredEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DeletionNoticeRetentionReviewRequiredEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DeletionNoticeRetentionReviewRequiredEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return DeletionNoticeRetentionReviewRequiredEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DeletionNoticeRetentionReviewRequiredEnumTypeTransformer? _instance;
}


