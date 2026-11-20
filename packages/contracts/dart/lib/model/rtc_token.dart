//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class RtcToken {
  /// Returns a new [RtcToken] instance.
  RtcToken({
    required this.appId,
    required this.channel,
    required this.uid,
    required this.remoteUid,
    required this.token,
    required this.expiresAt,
    this.mediaType,
  });

  String appId;

  String channel;

  RtcTokenUidEnum uid;

  RtcTokenRemoteUidEnum remoteUid;

  String token;

  DateTime expiresAt;

  RtcTokenMediaTypeEnum? mediaType;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RtcToken &&
    other.appId == appId &&
    other.channel == channel &&
    other.uid == uid &&
    other.remoteUid == remoteUid &&
    other.token == token &&
    other.expiresAt == expiresAt &&
    other.mediaType == mediaType;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (appId.hashCode) +
    (channel.hashCode) +
    (uid.hashCode) +
    (remoteUid.hashCode) +
    (token.hashCode) +
    (expiresAt.hashCode) +
    (mediaType == null ? 0 : mediaType!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'RtcToken[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'appId'] = this.appId;
      json[r'channel'] = this.channel;
      json[r'uid'] = this.uid;
      json[r'remoteUid'] = this.remoteUid;
      json[r'token'] = this.token;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
    if (this.mediaType != null) {
      json[r'mediaType'] = this.mediaType;
    }
    return json;
  }

  /// Returns a new [RtcToken] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RtcToken? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid RtcToken object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'appId')) {
        throw const FormatException('Missing RtcToken.appId');
      }
      if (json[r'appId'] == null) {
        throw const FormatException('Null RtcToken.appId');
      }
      if (!json.containsKey(r'channel')) {
        throw const FormatException('Missing RtcToken.channel');
      }
      if (json[r'channel'] == null) {
        throw const FormatException('Null RtcToken.channel');
      }
      if (!json.containsKey(r'uid')) {
        throw const FormatException('Missing RtcToken.uid');
      }
      if (json[r'uid'] == null) {
        throw const FormatException('Null RtcToken.uid');
      }
      if (json[r'uid'] != null && json[r'uid'] is! int) {
        throw const FormatException('Invalid RtcToken.uid integer');
      }
      if (!json.containsKey(r'remoteUid')) {
        throw const FormatException('Missing RtcToken.remoteUid');
      }
      if (json[r'remoteUid'] == null) {
        throw const FormatException('Null RtcToken.remoteUid');
      }
      if (json[r'remoteUid'] != null && json[r'remoteUid'] is! int) {
        throw const FormatException('Invalid RtcToken.remoteUid integer');
      }
      if (!json.containsKey(r'token')) {
        throw const FormatException('Missing RtcToken.token');
      }
      if (json[r'token'] == null) {
        throw const FormatException('Null RtcToken.token');
      }
      if (!json.containsKey(r'expiresAt')) {
        throw const FormatException('Missing RtcToken.expiresAt');
      }
      if (json[r'expiresAt'] == null) {
        throw const FormatException('Null RtcToken.expiresAt');
      }
      if (json[r'expiresAt'] != null && (json[r'expiresAt'] is! String || DateTime.tryParse(json[r'expiresAt'] as String) == null)) {
        throw const FormatException('Invalid RtcToken.expiresAt');
      }

      return RtcToken(
        appId: mapValueOfType<String>(json, r'appId')!,
        channel: mapValueOfType<String>(json, r'channel')!,
        uid: RtcTokenUidEnum.fromJson(json[r'uid'])!,
        remoteUid: RtcTokenRemoteUidEnum.fromJson(json[r'remoteUid'])!,
        token: mapValueOfType<String>(json, r'token')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        mediaType: RtcTokenMediaTypeEnum.fromJson(json[r'mediaType']),
      );
    }
    return null;
  }

  static List<RtcToken> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RtcToken>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RtcToken.fromJson(row);
        if (value == null) throw const FormatException('Invalid RtcToken list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RtcToken> mapFromJson(dynamic json) {
    final map = <String, RtcToken>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RtcToken.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RtcToken-objects as value to a dart map
  static Map<String, List<RtcToken>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RtcToken>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RtcToken.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'appId',
    'channel',
    'uid',
    'remoteUid',
    'token',
    'expiresAt',
  };
}


enum RtcTokenUidEnum {
  number1._(1),
  number2._(2),
  ;

  /// Instantiate a new enum with the provided value.
  const RtcTokenUidEnum._(this._value);

  /// The underlying value of this enum member.
  final int _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  int toJson() => _value;

  /// Returns the instance of [RtcTokenUidEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static RtcTokenUidEnum? fromJson(dynamic value) => RtcTokenUidEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [RtcTokenUidEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<RtcTokenUidEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RtcTokenUidEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RtcTokenUidEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RtcTokenUidEnum] to int,
/// and [decode] dynamic data back to [RtcTokenUidEnum].
class RtcTokenUidEnumTypeTransformer {
  factory RtcTokenUidEnumTypeTransformer() => _instance ??= const RtcTokenUidEnumTypeTransformer._();

  const RtcTokenUidEnumTypeTransformer._();

  int encode(RtcTokenUidEnum data) => data._value;

  /// Returns the instance of [RtcTokenUidEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RtcTokenUidEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is RtcTokenUidEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 1: return RtcTokenUidEnum.number1;
        case 2: return RtcTokenUidEnum.number2;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static RtcTokenUidEnumTypeTransformer? _instance;
}



enum RtcTokenRemoteUidEnum {
  number1._(1),
  number2._(2),
  ;

  /// Instantiate a new enum with the provided value.
  const RtcTokenRemoteUidEnum._(this._value);

  /// The underlying value of this enum member.
  final int _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  int toJson() => _value;

  /// Returns the instance of [RtcTokenRemoteUidEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static RtcTokenRemoteUidEnum? fromJson(dynamic value) => RtcTokenRemoteUidEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [RtcTokenRemoteUidEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<RtcTokenRemoteUidEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RtcTokenRemoteUidEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RtcTokenRemoteUidEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RtcTokenRemoteUidEnum] to int,
/// and [decode] dynamic data back to [RtcTokenRemoteUidEnum].
class RtcTokenRemoteUidEnumTypeTransformer {
  factory RtcTokenRemoteUidEnumTypeTransformer() => _instance ??= const RtcTokenRemoteUidEnumTypeTransformer._();

  const RtcTokenRemoteUidEnumTypeTransformer._();

  int encode(RtcTokenRemoteUidEnum data) => data._value;

  /// Returns the instance of [RtcTokenRemoteUidEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RtcTokenRemoteUidEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is RtcTokenRemoteUidEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 1: return RtcTokenRemoteUidEnum.number1;
        case 2: return RtcTokenRemoteUidEnum.number2;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static RtcTokenRemoteUidEnumTypeTransformer? _instance;
}



enum RtcTokenMediaTypeEnum {
  audio._(r'audio'),
  video._(r'video'),
  ;

  /// Instantiate a new enum with the provided value.
  const RtcTokenMediaTypeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [RtcTokenMediaTypeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static RtcTokenMediaTypeEnum? fromJson(dynamic value) => RtcTokenMediaTypeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [RtcTokenMediaTypeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<RtcTokenMediaTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RtcTokenMediaTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RtcTokenMediaTypeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RtcTokenMediaTypeEnum] to String,
/// and [decode] dynamic data back to [RtcTokenMediaTypeEnum].
class RtcTokenMediaTypeEnumTypeTransformer {
  factory RtcTokenMediaTypeEnumTypeTransformer() => _instance ??= const RtcTokenMediaTypeEnumTypeTransformer._();

  const RtcTokenMediaTypeEnumTypeTransformer._();

  String encode(RtcTokenMediaTypeEnum data) => data._value;

  /// Returns the instance of [RtcTokenMediaTypeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RtcTokenMediaTypeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is RtcTokenMediaTypeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'audio': return RtcTokenMediaTypeEnum.audio;
        case r'video': return RtcTokenMediaTypeEnum.video;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static RtcTokenMediaTypeEnumTypeTransformer? _instance;
}


