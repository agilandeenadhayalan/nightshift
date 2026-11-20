//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class RtcConfig {
  /// Returns a new [RtcConfig] instance.
  RtcConfig({
    required this.appId,
    required this.videoEnabled,
    required this.testOnly,
  });

  String? appId;

  bool videoEnabled;

  RtcConfigTestOnlyEnum testOnly;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RtcConfig &&
    other.appId == appId &&
    other.videoEnabled == videoEnabled &&
    other.testOnly == testOnly;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (appId == null ? 0 : appId!.hashCode) +
    (videoEnabled.hashCode) +
    (testOnly.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'RtcConfig[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.appId != null) {
      json[r'appId'] = this.appId;
    } else {
      json[r'appId'] = null;
    }
      json[r'videoEnabled'] = this.videoEnabled;
      json[r'testOnly'] = this.testOnly;
    return json;
  }

  /// Returns a new [RtcConfig] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RtcConfig? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid RtcConfig object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'appId')) {
        throw const FormatException('Missing RtcConfig.appId');
      }
      if (!json.containsKey(r'videoEnabled')) {
        throw const FormatException('Missing RtcConfig.videoEnabled');
      }
      if (json[r'videoEnabled'] == null) {
        throw const FormatException('Null RtcConfig.videoEnabled');
      }
      if (json[r'videoEnabled'] != null && json[r'videoEnabled'] is! bool) {
        throw const FormatException('Invalid RtcConfig.videoEnabled boolean');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing RtcConfig.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null RtcConfig.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid RtcConfig.testOnly boolean');
      }

      return RtcConfig(
        appId: mapValueOfType<String>(json, r'appId'),
        videoEnabled: mapValueOfType<bool>(json, r'videoEnabled')!,
        testOnly: RtcConfigTestOnlyEnum.fromJson(json[r'testOnly'])!,
      );
    }
    return null;
  }

  static List<RtcConfig> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RtcConfig>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RtcConfig.fromJson(row);
        if (value == null) throw const FormatException('Invalid RtcConfig list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RtcConfig> mapFromJson(dynamic json) {
    final map = <String, RtcConfig>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RtcConfig.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RtcConfig-objects as value to a dart map
  static Map<String, List<RtcConfig>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RtcConfig>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RtcConfig.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'appId',
    'videoEnabled',
    'testOnly',
  };
}


enum RtcConfigTestOnlyEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const RtcConfigTestOnlyEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [RtcConfigTestOnlyEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static RtcConfigTestOnlyEnum? fromJson(dynamic value) => RtcConfigTestOnlyEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [RtcConfigTestOnlyEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<RtcConfigTestOnlyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RtcConfigTestOnlyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RtcConfigTestOnlyEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RtcConfigTestOnlyEnum] to bool,
/// and [decode] dynamic data back to [RtcConfigTestOnlyEnum].
class RtcConfigTestOnlyEnumTypeTransformer {
  factory RtcConfigTestOnlyEnumTypeTransformer() => _instance ??= const RtcConfigTestOnlyEnumTypeTransformer._();

  const RtcConfigTestOnlyEnumTypeTransformer._();

  bool encode(RtcConfigTestOnlyEnum data) => data._value;

  /// Returns the instance of [RtcConfigTestOnlyEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RtcConfigTestOnlyEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is RtcConfigTestOnlyEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return RtcConfigTestOnlyEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static RtcConfigTestOnlyEnumTypeTransformer? _instance;
}


