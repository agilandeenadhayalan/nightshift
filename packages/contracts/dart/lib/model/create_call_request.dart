//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class CreateCallRequest {
  /// Returns a new [CreateCallRequest] instance.
  CreateCallRequest({
    required this.listenerId,
    required this.quoteId,
    this.mediaType,
    this.videoConsent,
  });

  String listenerId;

  CreateCallRequestQuoteIdEnum quoteId;

  CreateCallRequestMediaTypeEnum? mediaType;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? videoConsent;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateCallRequest &&
    other.listenerId == listenerId &&
    other.quoteId == quoteId &&
    other.mediaType == mediaType &&
    other.videoConsent == videoConsent;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (listenerId.hashCode) +
    (quoteId.hashCode) +
    (mediaType == null ? 0 : mediaType!.hashCode) +
    (videoConsent == null ? 0 : videoConsent!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'CreateCallRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'listenerId'] = this.listenerId;
      json[r'quoteId'] = this.quoteId;
    if (this.mediaType != null) {
      json[r'mediaType'] = this.mediaType;
    }
    if (this.videoConsent != null) {
      json[r'videoConsent'] = this.videoConsent;
    }
    return json;
  }

  /// Returns a new [CreateCallRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateCallRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid CreateCallRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'listenerId')) {
        throw const FormatException('Missing CreateCallRequest.listenerId');
      }
      if (json[r'listenerId'] == null) {
        throw const FormatException('Null CreateCallRequest.listenerId');
      }
      if (!json.containsKey(r'quoteId')) {
        throw const FormatException('Missing CreateCallRequest.quoteId');
      }
      if (json[r'quoteId'] == null) {
        throw const FormatException('Null CreateCallRequest.quoteId');
      }
      if (json[r'videoConsent'] != null && json[r'videoConsent'] is! bool) {
        throw const FormatException('Invalid CreateCallRequest.videoConsent boolean');
      }

      return CreateCallRequest(
        listenerId: mapValueOfType<String>(json, r'listenerId')!,
        quoteId: CreateCallRequestQuoteIdEnum.fromJson(json[r'quoteId'])!,
        mediaType: CreateCallRequestMediaTypeEnum.fromJson(json[r'mediaType']),
        videoConsent: mapValueOfType<bool>(json, r'videoConsent'),
      );
    }
    return null;
  }

  static List<CreateCallRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateCallRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateCallRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid CreateCallRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateCallRequest> mapFromJson(dynamic json) {
    final map = <String, CreateCallRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateCallRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateCallRequest-objects as value to a dart map
  static Map<String, List<CreateCallRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateCallRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateCallRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'listenerId',
    'quoteId',
  };
}


enum CreateCallRequestQuoteIdEnum {
  testAudioV1._(r'test-audio-v1'),
  testVideoV1._(r'test-video-v1'),
  ;

  /// Instantiate a new enum with the provided value.
  const CreateCallRequestQuoteIdEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CreateCallRequestQuoteIdEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CreateCallRequestQuoteIdEnum? fromJson(dynamic value) => CreateCallRequestQuoteIdEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CreateCallRequestQuoteIdEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CreateCallRequestQuoteIdEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateCallRequestQuoteIdEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateCallRequestQuoteIdEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CreateCallRequestQuoteIdEnum] to String,
/// and [decode] dynamic data back to [CreateCallRequestQuoteIdEnum].
class CreateCallRequestQuoteIdEnumTypeTransformer {
  factory CreateCallRequestQuoteIdEnumTypeTransformer() => _instance ??= const CreateCallRequestQuoteIdEnumTypeTransformer._();

  const CreateCallRequestQuoteIdEnumTypeTransformer._();

  String encode(CreateCallRequestQuoteIdEnum data) => data._value;

  /// Returns the instance of [CreateCallRequestQuoteIdEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CreateCallRequestQuoteIdEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CreateCallRequestQuoteIdEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'test-audio-v1': return CreateCallRequestQuoteIdEnum.testAudioV1;
        case r'test-video-v1': return CreateCallRequestQuoteIdEnum.testVideoV1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CreateCallRequestQuoteIdEnumTypeTransformer? _instance;
}



enum CreateCallRequestMediaTypeEnum {
  audio._(r'audio'),
  video._(r'video'),
  ;

  /// Instantiate a new enum with the provided value.
  const CreateCallRequestMediaTypeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CreateCallRequestMediaTypeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CreateCallRequestMediaTypeEnum? fromJson(dynamic value) => CreateCallRequestMediaTypeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CreateCallRequestMediaTypeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CreateCallRequestMediaTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateCallRequestMediaTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateCallRequestMediaTypeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CreateCallRequestMediaTypeEnum] to String,
/// and [decode] dynamic data back to [CreateCallRequestMediaTypeEnum].
class CreateCallRequestMediaTypeEnumTypeTransformer {
  factory CreateCallRequestMediaTypeEnumTypeTransformer() => _instance ??= const CreateCallRequestMediaTypeEnumTypeTransformer._();

  const CreateCallRequestMediaTypeEnumTypeTransformer._();

  String encode(CreateCallRequestMediaTypeEnum data) => data._value;

  /// Returns the instance of [CreateCallRequestMediaTypeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CreateCallRequestMediaTypeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CreateCallRequestMediaTypeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'audio': return CreateCallRequestMediaTypeEnum.audio;
        case r'video': return CreateCallRequestMediaTypeEnum.video;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CreateCallRequestMediaTypeEnumTypeTransformer? _instance;
}


