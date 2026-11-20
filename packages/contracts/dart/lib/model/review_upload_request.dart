//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ReviewUploadRequest {
  /// Returns a new [ReviewUploadRequest] instance.
  ReviewUploadRequest({
    required this.contentType,
    required this.byteLength,
    required this.sha256,
  });

  ReviewUploadRequestContentTypeEnum contentType;

  /// Minimum value: 44
  /// Maximum value: 2097152
  int byteLength;

  String sha256;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReviewUploadRequest &&
    other.contentType == contentType &&
    other.byteLength == byteLength &&
    other.sha256 == sha256;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (contentType.hashCode) +
    (byteLength.hashCode) +
    (sha256.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ReviewUploadRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'contentType'] = this.contentType;
      json[r'byteLength'] = this.byteLength;
      json[r'sha256'] = this.sha256;
    return json;
  }

  /// Returns a new [ReviewUploadRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReviewUploadRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ReviewUploadRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'contentType')) {
        throw const FormatException('Missing ReviewUploadRequest.contentType');
      }
      if (json[r'contentType'] == null) {
        throw const FormatException('Null ReviewUploadRequest.contentType');
      }
      if (!json.containsKey(r'byteLength')) {
        throw const FormatException('Missing ReviewUploadRequest.byteLength');
      }
      if (json[r'byteLength'] == null) {
        throw const FormatException('Null ReviewUploadRequest.byteLength');
      }
      if (json[r'byteLength'] != null && json[r'byteLength'] is! int) {
        throw const FormatException('Invalid ReviewUploadRequest.byteLength integer');
      }
      if (!json.containsKey(r'sha256')) {
        throw const FormatException('Missing ReviewUploadRequest.sha256');
      }
      if (json[r'sha256'] == null) {
        throw const FormatException('Null ReviewUploadRequest.sha256');
      }

      return ReviewUploadRequest(
        contentType: ReviewUploadRequestContentTypeEnum.fromJson(json[r'contentType'])!,
        byteLength: mapValueOfType<int>(json, r'byteLength')!,
        sha256: mapValueOfType<String>(json, r'sha256')!,
      );
    }
    return null;
  }

  static List<ReviewUploadRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReviewUploadRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReviewUploadRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid ReviewUploadRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReviewUploadRequest> mapFromJson(dynamic json) {
    final map = <String, ReviewUploadRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReviewUploadRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReviewUploadRequest-objects as value to a dart map
  static Map<String, List<ReviewUploadRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReviewUploadRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReviewUploadRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'contentType',
    'byteLength',
    'sha256',
  };
}


enum ReviewUploadRequestContentTypeEnum {
  audioSlashWav._(r'audio/wav'),
  ;

  /// Instantiate a new enum with the provided value.
  const ReviewUploadRequestContentTypeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ReviewUploadRequestContentTypeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ReviewUploadRequestContentTypeEnum? fromJson(dynamic value) => ReviewUploadRequestContentTypeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ReviewUploadRequestContentTypeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ReviewUploadRequestContentTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReviewUploadRequestContentTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReviewUploadRequestContentTypeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReviewUploadRequestContentTypeEnum] to String,
/// and [decode] dynamic data back to [ReviewUploadRequestContentTypeEnum].
class ReviewUploadRequestContentTypeEnumTypeTransformer {
  factory ReviewUploadRequestContentTypeEnumTypeTransformer() => _instance ??= const ReviewUploadRequestContentTypeEnumTypeTransformer._();

  const ReviewUploadRequestContentTypeEnumTypeTransformer._();

  String encode(ReviewUploadRequestContentTypeEnum data) => data._value;

  /// Returns the instance of [ReviewUploadRequestContentTypeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReviewUploadRequestContentTypeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ReviewUploadRequestContentTypeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'audio/wav': return ReviewUploadRequestContentTypeEnum.audioSlashWav;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ReviewUploadRequestContentTypeEnumTypeTransformer? _instance;
}


