//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ReviewUpload {
  /// Returns a new [ReviewUpload] instance.
  ReviewUpload({
    required this.uploadId,
    required this.uploadToken,
    required this.expiresAt,
    required this.maxBytes,
    required this.contentType,
  });

  String uploadId;

  String uploadToken;

  DateTime expiresAt;

  ReviewUploadMaxBytesEnum maxBytes;

  ReviewUploadContentTypeEnum contentType;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReviewUpload &&
    other.uploadId == uploadId &&
    other.uploadToken == uploadToken &&
    other.expiresAt == expiresAt &&
    other.maxBytes == maxBytes &&
    other.contentType == contentType;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (uploadId.hashCode) +
    (uploadToken.hashCode) +
    (expiresAt.hashCode) +
    (maxBytes.hashCode) +
    (contentType.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ReviewUpload[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'uploadId'] = this.uploadId;
      json[r'uploadToken'] = this.uploadToken;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'maxBytes'] = this.maxBytes;
      json[r'contentType'] = this.contentType;
    return json;
  }

  /// Returns a new [ReviewUpload] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReviewUpload? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ReviewUpload object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'uploadId')) {
        throw const FormatException('Missing ReviewUpload.uploadId');
      }
      if (json[r'uploadId'] == null) {
        throw const FormatException('Null ReviewUpload.uploadId');
      }
      if (!json.containsKey(r'uploadToken')) {
        throw const FormatException('Missing ReviewUpload.uploadToken');
      }
      if (json[r'uploadToken'] == null) {
        throw const FormatException('Null ReviewUpload.uploadToken');
      }
      if (!json.containsKey(r'expiresAt')) {
        throw const FormatException('Missing ReviewUpload.expiresAt');
      }
      if (json[r'expiresAt'] == null) {
        throw const FormatException('Null ReviewUpload.expiresAt');
      }
      if (json[r'expiresAt'] != null && (json[r'expiresAt'] is! String || DateTime.tryParse(json[r'expiresAt'] as String) == null)) {
        throw const FormatException('Invalid ReviewUpload.expiresAt');
      }
      if (!json.containsKey(r'maxBytes')) {
        throw const FormatException('Missing ReviewUpload.maxBytes');
      }
      if (json[r'maxBytes'] == null) {
        throw const FormatException('Null ReviewUpload.maxBytes');
      }
      if (json[r'maxBytes'] != null && json[r'maxBytes'] is! int) {
        throw const FormatException('Invalid ReviewUpload.maxBytes integer');
      }
      if (!json.containsKey(r'contentType')) {
        throw const FormatException('Missing ReviewUpload.contentType');
      }
      if (json[r'contentType'] == null) {
        throw const FormatException('Null ReviewUpload.contentType');
      }

      return ReviewUpload(
        uploadId: mapValueOfType<String>(json, r'uploadId')!,
        uploadToken: mapValueOfType<String>(json, r'uploadToken')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        maxBytes: ReviewUploadMaxBytesEnum.fromJson(json[r'maxBytes'])!,
        contentType: ReviewUploadContentTypeEnum.fromJson(json[r'contentType'])!,
      );
    }
    return null;
  }

  static List<ReviewUpload> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReviewUpload>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReviewUpload.fromJson(row);
        if (value == null) throw const FormatException('Invalid ReviewUpload list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReviewUpload> mapFromJson(dynamic json) {
    final map = <String, ReviewUpload>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReviewUpload.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReviewUpload-objects as value to a dart map
  static Map<String, List<ReviewUpload>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReviewUpload>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReviewUpload.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'uploadId',
    'uploadToken',
    'expiresAt',
    'maxBytes',
    'contentType',
  };
}


enum ReviewUploadMaxBytesEnum {
  number2097152._(2097152),
  ;

  /// Instantiate a new enum with the provided value.
  const ReviewUploadMaxBytesEnum._(this._value);

  /// The underlying value of this enum member.
  final int _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  int toJson() => _value;

  /// Returns the instance of [ReviewUploadMaxBytesEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ReviewUploadMaxBytesEnum? fromJson(dynamic value) => ReviewUploadMaxBytesEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ReviewUploadMaxBytesEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ReviewUploadMaxBytesEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReviewUploadMaxBytesEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReviewUploadMaxBytesEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReviewUploadMaxBytesEnum] to int,
/// and [decode] dynamic data back to [ReviewUploadMaxBytesEnum].
class ReviewUploadMaxBytesEnumTypeTransformer {
  factory ReviewUploadMaxBytesEnumTypeTransformer() => _instance ??= const ReviewUploadMaxBytesEnumTypeTransformer._();

  const ReviewUploadMaxBytesEnumTypeTransformer._();

  int encode(ReviewUploadMaxBytesEnum data) => data._value;

  /// Returns the instance of [ReviewUploadMaxBytesEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReviewUploadMaxBytesEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ReviewUploadMaxBytesEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 2097152: return ReviewUploadMaxBytesEnum.number2097152;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ReviewUploadMaxBytesEnumTypeTransformer? _instance;
}



enum ReviewUploadContentTypeEnum {
  audioSlashWav._(r'audio/wav'),
  ;

  /// Instantiate a new enum with the provided value.
  const ReviewUploadContentTypeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ReviewUploadContentTypeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ReviewUploadContentTypeEnum? fromJson(dynamic value) => ReviewUploadContentTypeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ReviewUploadContentTypeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ReviewUploadContentTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReviewUploadContentTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReviewUploadContentTypeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReviewUploadContentTypeEnum] to String,
/// and [decode] dynamic data back to [ReviewUploadContentTypeEnum].
class ReviewUploadContentTypeEnumTypeTransformer {
  factory ReviewUploadContentTypeEnumTypeTransformer() => _instance ??= const ReviewUploadContentTypeEnumTypeTransformer._();

  const ReviewUploadContentTypeEnumTypeTransformer._();

  String encode(ReviewUploadContentTypeEnum data) => data._value;

  /// Returns the instance of [ReviewUploadContentTypeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReviewUploadContentTypeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ReviewUploadContentTypeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'audio/wav': return ReviewUploadContentTypeEnum.audioSlashWav;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ReviewUploadContentTypeEnumTypeTransformer? _instance;
}


