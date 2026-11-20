//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class DevelopmentSignInRequest {
  /// Returns a new [DevelopmentSignInRequest] instance.
  DevelopmentSignInRequest({
    required this.handle,
    required this.accessKey,
    required this.deviceId,
  });

  DevelopmentSignInRequestHandleEnum handle;

  String accessKey;

  String deviceId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DevelopmentSignInRequest &&
    other.handle == handle &&
    other.accessKey == accessKey &&
    other.deviceId == deviceId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (handle.hashCode) +
    (accessKey.hashCode) +
    (deviceId.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'DevelopmentSignInRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'handle'] = this.handle;
      json[r'accessKey'] = this.accessKey;
      json[r'deviceId'] = this.deviceId;
    return json;
  }

  /// Returns a new [DevelopmentSignInRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DevelopmentSignInRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid DevelopmentSignInRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'handle')) {
        throw const FormatException('Missing DevelopmentSignInRequest.handle');
      }
      if (json[r'handle'] == null) {
        throw const FormatException('Null DevelopmentSignInRequest.handle');
      }
      if (!json.containsKey(r'accessKey')) {
        throw const FormatException('Missing DevelopmentSignInRequest.accessKey');
      }
      if (json[r'accessKey'] == null) {
        throw const FormatException('Null DevelopmentSignInRequest.accessKey');
      }
      if (!json.containsKey(r'deviceId')) {
        throw const FormatException('Missing DevelopmentSignInRequest.deviceId');
      }
      if (json[r'deviceId'] == null) {
        throw const FormatException('Null DevelopmentSignInRequest.deviceId');
      }

      return DevelopmentSignInRequest(
        handle: DevelopmentSignInRequestHandleEnum.fromJson(json[r'handle'])!,
        accessKey: mapValueOfType<String>(json, r'accessKey')!,
        deviceId: mapValueOfType<String>(json, r'deviceId')!,
      );
    }
    return null;
  }

  static List<DevelopmentSignInRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DevelopmentSignInRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DevelopmentSignInRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid DevelopmentSignInRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DevelopmentSignInRequest> mapFromJson(dynamic json) {
    final map = <String, DevelopmentSignInRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DevelopmentSignInRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DevelopmentSignInRequest-objects as value to a dart map
  static Map<String, List<DevelopmentSignInRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DevelopmentSignInRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DevelopmentSignInRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'handle',
    'accessKey',
    'deviceId',
  };
}


enum DevelopmentSignInRequestHandleEnum {
  customer._(r'customer'),
  customer2._(r'customer2'),
  listener._(r'listener'),
  ;

  /// Instantiate a new enum with the provided value.
  const DevelopmentSignInRequestHandleEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [DevelopmentSignInRequestHandleEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DevelopmentSignInRequestHandleEnum? fromJson(dynamic value) => DevelopmentSignInRequestHandleEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DevelopmentSignInRequestHandleEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DevelopmentSignInRequestHandleEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DevelopmentSignInRequestHandleEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DevelopmentSignInRequestHandleEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DevelopmentSignInRequestHandleEnum] to String,
/// and [decode] dynamic data back to [DevelopmentSignInRequestHandleEnum].
class DevelopmentSignInRequestHandleEnumTypeTransformer {
  factory DevelopmentSignInRequestHandleEnumTypeTransformer() => _instance ??= const DevelopmentSignInRequestHandleEnumTypeTransformer._();

  const DevelopmentSignInRequestHandleEnumTypeTransformer._();

  String encode(DevelopmentSignInRequestHandleEnum data) => data._value;

  /// Returns the instance of [DevelopmentSignInRequestHandleEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DevelopmentSignInRequestHandleEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is DevelopmentSignInRequestHandleEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'customer': return DevelopmentSignInRequestHandleEnum.customer;
        case r'customer2': return DevelopmentSignInRequestHandleEnum.customer2;
        case r'listener': return DevelopmentSignInRequestHandleEnum.listener;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DevelopmentSignInRequestHandleEnumTypeTransformer? _instance;
}


