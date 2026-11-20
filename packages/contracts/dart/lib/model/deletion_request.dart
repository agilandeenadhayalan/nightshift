//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class DeletionRequest {
  /// Returns a new [DeletionRequest] instance.
  DeletionRequest({
    required this.noticeVersion,
    required this.confirm,
    required this.receiptToken,
  });

  DeletionRequestNoticeVersionEnum noticeVersion;

  DeletionRequestConfirmEnum confirm;

  String receiptToken;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DeletionRequest &&
    other.noticeVersion == noticeVersion &&
    other.confirm == confirm &&
    other.receiptToken == receiptToken;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (noticeVersion.hashCode) +
    (confirm.hashCode) +
    (receiptToken.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'DeletionRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'noticeVersion'] = this.noticeVersion;
      json[r'confirm'] = this.confirm;
      json[r'receiptToken'] = this.receiptToken;
    return json;
  }

  /// Returns a new [DeletionRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DeletionRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid DeletionRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'noticeVersion')) {
        throw const FormatException('Missing DeletionRequest.noticeVersion');
      }
      if (json[r'noticeVersion'] == null) {
        throw const FormatException('Null DeletionRequest.noticeVersion');
      }
      if (!json.containsKey(r'confirm')) {
        throw const FormatException('Missing DeletionRequest.confirm');
      }
      if (json[r'confirm'] == null) {
        throw const FormatException('Null DeletionRequest.confirm');
      }
      if (json[r'confirm'] != null && json[r'confirm'] is! bool) {
        throw const FormatException('Invalid DeletionRequest.confirm boolean');
      }
      if (!json.containsKey(r'receiptToken')) {
        throw const FormatException('Missing DeletionRequest.receiptToken');
      }
      if (json[r'receiptToken'] == null) {
        throw const FormatException('Null DeletionRequest.receiptToken');
      }

      return DeletionRequest(
        noticeVersion: DeletionRequestNoticeVersionEnum.fromJson(json[r'noticeVersion'])!,
        confirm: DeletionRequestConfirmEnum.fromJson(json[r'confirm'])!,
        receiptToken: mapValueOfType<String>(json, r'receiptToken')!,
      );
    }
    return null;
  }

  static List<DeletionRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid DeletionRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DeletionRequest> mapFromJson(dynamic json) {
    final map = <String, DeletionRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DeletionRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DeletionRequest-objects as value to a dart map
  static Map<String, List<DeletionRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DeletionRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DeletionRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'noticeVersion',
    'confirm',
    'receiptToken',
  };
}


enum DeletionRequestNoticeVersionEnum {
  accountDeletionTestV1._(r'account-deletion-test-v1'),
  ;

  /// Instantiate a new enum with the provided value.
  const DeletionRequestNoticeVersionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [DeletionRequestNoticeVersionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DeletionRequestNoticeVersionEnum? fromJson(dynamic value) => DeletionRequestNoticeVersionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DeletionRequestNoticeVersionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DeletionRequestNoticeVersionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionRequestNoticeVersionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionRequestNoticeVersionEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DeletionRequestNoticeVersionEnum] to String,
/// and [decode] dynamic data back to [DeletionRequestNoticeVersionEnum].
class DeletionRequestNoticeVersionEnumTypeTransformer {
  factory DeletionRequestNoticeVersionEnumTypeTransformer() => _instance ??= const DeletionRequestNoticeVersionEnumTypeTransformer._();

  const DeletionRequestNoticeVersionEnumTypeTransformer._();

  String encode(DeletionRequestNoticeVersionEnum data) => data._value;

  /// Returns the instance of [DeletionRequestNoticeVersionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DeletionRequestNoticeVersionEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DeletionRequestNoticeVersionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'account-deletion-test-v1': return DeletionRequestNoticeVersionEnum.accountDeletionTestV1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DeletionRequestNoticeVersionEnumTypeTransformer? _instance;
}



enum DeletionRequestConfirmEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const DeletionRequestConfirmEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [DeletionRequestConfirmEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DeletionRequestConfirmEnum? fromJson(dynamic value) => DeletionRequestConfirmEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DeletionRequestConfirmEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DeletionRequestConfirmEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionRequestConfirmEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionRequestConfirmEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DeletionRequestConfirmEnum] to bool,
/// and [decode] dynamic data back to [DeletionRequestConfirmEnum].
class DeletionRequestConfirmEnumTypeTransformer {
  factory DeletionRequestConfirmEnumTypeTransformer() => _instance ??= const DeletionRequestConfirmEnumTypeTransformer._();

  const DeletionRequestConfirmEnumTypeTransformer._();

  bool encode(DeletionRequestConfirmEnum data) => data._value;

  /// Returns the instance of [DeletionRequestConfirmEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DeletionRequestConfirmEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DeletionRequestConfirmEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return DeletionRequestConfirmEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DeletionRequestConfirmEnumTypeTransformer? _instance;
}


