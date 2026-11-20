//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class SetModeRequest {
  /// Returns a new [SetModeRequest] instance.
  SetModeRequest({
    required this.mode,
  });

  SetModeRequestModeEnum mode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SetModeRequest &&
    other.mode == mode;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (mode.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'SetModeRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'mode'] = this.mode;
    return json;
  }

  /// Returns a new [SetModeRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SetModeRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid SetModeRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'mode')) {
        throw const FormatException('Missing SetModeRequest.mode');
      }
      if (json[r'mode'] == null) {
        throw const FormatException('Null SetModeRequest.mode');
      }

      return SetModeRequest(
        mode: SetModeRequestModeEnum.fromJson(json[r'mode'])!,
      );
    }
    return null;
  }

  static List<SetModeRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SetModeRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SetModeRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid SetModeRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SetModeRequest> mapFromJson(dynamic json) {
    final map = <String, SetModeRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SetModeRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SetModeRequest-objects as value to a dart map
  static Map<String, List<SetModeRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SetModeRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SetModeRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'mode',
  };
}


enum SetModeRequestModeEnum {
  customer._(r'customer'),
  listener._(r'listener'),
  ;

  /// Instantiate a new enum with the provided value.
  const SetModeRequestModeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [SetModeRequestModeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static SetModeRequestModeEnum? fromJson(dynamic value) => SetModeRequestModeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [SetModeRequestModeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<SetModeRequestModeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SetModeRequestModeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SetModeRequestModeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SetModeRequestModeEnum] to String,
/// and [decode] dynamic data back to [SetModeRequestModeEnum].
class SetModeRequestModeEnumTypeTransformer {
  factory SetModeRequestModeEnumTypeTransformer() => _instance ??= const SetModeRequestModeEnumTypeTransformer._();

  const SetModeRequestModeEnumTypeTransformer._();

  String encode(SetModeRequestModeEnum data) => data._value;

  /// Returns the instance of [SetModeRequestModeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SetModeRequestModeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is SetModeRequestModeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'customer': return SetModeRequestModeEnum.customer;
        case r'listener': return SetModeRequestModeEnum.listener;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static SetModeRequestModeEnumTypeTransformer? _instance;
}


