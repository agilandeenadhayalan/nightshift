//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class CreateMatchingRequest {
  /// Returns a new [CreateMatchingRequest] instance.
  CreateMatchingRequest({
    required this.language,
    required this.mediaType,
    required this.quoteId,
    required this.consent,
    required this.consentVersion,
  });

  CreateMatchingRequestLanguageEnum language;

  CreateMatchingRequestMediaTypeEnum mediaType;

  String quoteId;

  CreateMatchingRequestConsentEnum consent;

  CreateMatchingRequestConsentVersionEnum consentVersion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateMatchingRequest &&
    other.language == language &&
    other.mediaType == mediaType &&
    other.quoteId == quoteId &&
    other.consent == consent &&
    other.consentVersion == consentVersion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (language.hashCode) +
    (mediaType.hashCode) +
    (quoteId.hashCode) +
    (consent.hashCode) +
    (consentVersion.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'CreateMatchingRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'language'] = this.language;
      json[r'mediaType'] = this.mediaType;
      json[r'quoteId'] = this.quoteId;
      json[r'consent'] = this.consent;
      json[r'consentVersion'] = this.consentVersion;
    return json;
  }

  /// Returns a new [CreateMatchingRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateMatchingRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid CreateMatchingRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'language')) {
        throw const FormatException('Missing CreateMatchingRequest.language');
      }
      if (json[r'language'] == null) {
        throw const FormatException('Null CreateMatchingRequest.language');
      }
      if (!json.containsKey(r'mediaType')) {
        throw const FormatException('Missing CreateMatchingRequest.mediaType');
      }
      if (json[r'mediaType'] == null) {
        throw const FormatException('Null CreateMatchingRequest.mediaType');
      }
      if (!json.containsKey(r'quoteId')) {
        throw const FormatException('Missing CreateMatchingRequest.quoteId');
      }
      if (json[r'quoteId'] == null) {
        throw const FormatException('Null CreateMatchingRequest.quoteId');
      }
      if (!json.containsKey(r'consent')) {
        throw const FormatException('Missing CreateMatchingRequest.consent');
      }
      if (json[r'consent'] == null) {
        throw const FormatException('Null CreateMatchingRequest.consent');
      }
      if (json[r'consent'] != null && json[r'consent'] is! bool) {
        throw const FormatException('Invalid CreateMatchingRequest.consent boolean');
      }
      if (!json.containsKey(r'consentVersion')) {
        throw const FormatException('Missing CreateMatchingRequest.consentVersion');
      }
      if (json[r'consentVersion'] == null) {
        throw const FormatException('Null CreateMatchingRequest.consentVersion');
      }

      return CreateMatchingRequest(
        language: CreateMatchingRequestLanguageEnum.fromJson(json[r'language'])!,
        mediaType: CreateMatchingRequestMediaTypeEnum.fromJson(json[r'mediaType'])!,
        quoteId: mapValueOfType<String>(json, r'quoteId')!,
        consent: CreateMatchingRequestConsentEnum.fromJson(json[r'consent'])!,
        consentVersion: CreateMatchingRequestConsentVersionEnum.fromJson(json[r'consentVersion'])!,
      );
    }
    return null;
  }

  static List<CreateMatchingRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateMatchingRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateMatchingRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid CreateMatchingRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateMatchingRequest> mapFromJson(dynamic json) {
    final map = <String, CreateMatchingRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateMatchingRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateMatchingRequest-objects as value to a dart map
  static Map<String, List<CreateMatchingRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateMatchingRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateMatchingRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'language',
    'mediaType',
    'quoteId',
    'consent',
    'consentVersion',
  };
}


enum CreateMatchingRequestLanguageEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const CreateMatchingRequestLanguageEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CreateMatchingRequestLanguageEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CreateMatchingRequestLanguageEnum? fromJson(dynamic value) => CreateMatchingRequestLanguageEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CreateMatchingRequestLanguageEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CreateMatchingRequestLanguageEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateMatchingRequestLanguageEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateMatchingRequestLanguageEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CreateMatchingRequestLanguageEnum] to String,
/// and [decode] dynamic data back to [CreateMatchingRequestLanguageEnum].
class CreateMatchingRequestLanguageEnumTypeTransformer {
  factory CreateMatchingRequestLanguageEnumTypeTransformer() => _instance ??= const CreateMatchingRequestLanguageEnumTypeTransformer._();

  const CreateMatchingRequestLanguageEnumTypeTransformer._();

  String encode(CreateMatchingRequestLanguageEnum data) => data._value;

  /// Returns the instance of [CreateMatchingRequestLanguageEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CreateMatchingRequestLanguageEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CreateMatchingRequestLanguageEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return CreateMatchingRequestLanguageEnum.ta;
        case r'en': return CreateMatchingRequestLanguageEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CreateMatchingRequestLanguageEnumTypeTransformer? _instance;
}



enum CreateMatchingRequestMediaTypeEnum {
  audio._(r'audio'),
  ;

  /// Instantiate a new enum with the provided value.
  const CreateMatchingRequestMediaTypeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CreateMatchingRequestMediaTypeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CreateMatchingRequestMediaTypeEnum? fromJson(dynamic value) => CreateMatchingRequestMediaTypeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CreateMatchingRequestMediaTypeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CreateMatchingRequestMediaTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateMatchingRequestMediaTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateMatchingRequestMediaTypeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CreateMatchingRequestMediaTypeEnum] to String,
/// and [decode] dynamic data back to [CreateMatchingRequestMediaTypeEnum].
class CreateMatchingRequestMediaTypeEnumTypeTransformer {
  factory CreateMatchingRequestMediaTypeEnumTypeTransformer() => _instance ??= const CreateMatchingRequestMediaTypeEnumTypeTransformer._();

  const CreateMatchingRequestMediaTypeEnumTypeTransformer._();

  String encode(CreateMatchingRequestMediaTypeEnum data) => data._value;

  /// Returns the instance of [CreateMatchingRequestMediaTypeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CreateMatchingRequestMediaTypeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CreateMatchingRequestMediaTypeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'audio': return CreateMatchingRequestMediaTypeEnum.audio;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CreateMatchingRequestMediaTypeEnumTypeTransformer? _instance;
}



enum CreateMatchingRequestConsentEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const CreateMatchingRequestConsentEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [CreateMatchingRequestConsentEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CreateMatchingRequestConsentEnum? fromJson(dynamic value) => CreateMatchingRequestConsentEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CreateMatchingRequestConsentEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CreateMatchingRequestConsentEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateMatchingRequestConsentEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateMatchingRequestConsentEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CreateMatchingRequestConsentEnum] to bool,
/// and [decode] dynamic data back to [CreateMatchingRequestConsentEnum].
class CreateMatchingRequestConsentEnumTypeTransformer {
  factory CreateMatchingRequestConsentEnumTypeTransformer() => _instance ??= const CreateMatchingRequestConsentEnumTypeTransformer._();

  const CreateMatchingRequestConsentEnumTypeTransformer._();

  bool encode(CreateMatchingRequestConsentEnum data) => data._value;

  /// Returns the instance of [CreateMatchingRequestConsentEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CreateMatchingRequestConsentEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CreateMatchingRequestConsentEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return CreateMatchingRequestConsentEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CreateMatchingRequestConsentEnumTypeTransformer? _instance;
}



enum CreateMatchingRequestConsentVersionEnum {
  matchingSearchV1._(r'matching-search-v1'),
  ;

  /// Instantiate a new enum with the provided value.
  const CreateMatchingRequestConsentVersionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CreateMatchingRequestConsentVersionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CreateMatchingRequestConsentVersionEnum? fromJson(dynamic value) => CreateMatchingRequestConsentVersionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CreateMatchingRequestConsentVersionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CreateMatchingRequestConsentVersionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateMatchingRequestConsentVersionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateMatchingRequestConsentVersionEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CreateMatchingRequestConsentVersionEnum] to String,
/// and [decode] dynamic data back to [CreateMatchingRequestConsentVersionEnum].
class CreateMatchingRequestConsentVersionEnumTypeTransformer {
  factory CreateMatchingRequestConsentVersionEnumTypeTransformer() => _instance ??= const CreateMatchingRequestConsentVersionEnumTypeTransformer._();

  const CreateMatchingRequestConsentVersionEnumTypeTransformer._();

  String encode(CreateMatchingRequestConsentVersionEnum data) => data._value;

  /// Returns the instance of [CreateMatchingRequestConsentVersionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CreateMatchingRequestConsentVersionEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is CreateMatchingRequestConsentVersionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'matching-search-v1': return CreateMatchingRequestConsentVersionEnum.matchingSearchV1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CreateMatchingRequestConsentVersionEnumTypeTransformer? _instance;
}


