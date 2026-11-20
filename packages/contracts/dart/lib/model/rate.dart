//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class Rate {
  /// Returns a new [Rate] instance.
  Rate({
    required this.id,
    required this.coinsPerMinute,
    required this.microcreditsPerCoin,
    required this.microcreditsPerSecond,
    required this.freeThroughSeconds,
    required this.minimumChargedSeconds,
    required this.listenerPaisePerHour,
    required this.testOnly,
  });

  RateIdEnum id;

  int coinsPerMinute;

  int microcreditsPerCoin;

  int microcreditsPerSecond;

  int freeThroughSeconds;

  int minimumChargedSeconds;

  int listenerPaisePerHour;

  RateTestOnlyEnum testOnly;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Rate &&
    other.id == id &&
    other.coinsPerMinute == coinsPerMinute &&
    other.microcreditsPerCoin == microcreditsPerCoin &&
    other.microcreditsPerSecond == microcreditsPerSecond &&
    other.freeThroughSeconds == freeThroughSeconds &&
    other.minimumChargedSeconds == minimumChargedSeconds &&
    other.listenerPaisePerHour == listenerPaisePerHour &&
    other.testOnly == testOnly;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (coinsPerMinute.hashCode) +
    (microcreditsPerCoin.hashCode) +
    (microcreditsPerSecond.hashCode) +
    (freeThroughSeconds.hashCode) +
    (minimumChargedSeconds.hashCode) +
    (listenerPaisePerHour.hashCode) +
    (testOnly.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'Rate[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'coinsPerMinute'] = this.coinsPerMinute;
      json[r'microcreditsPerCoin'] = this.microcreditsPerCoin;
      json[r'microcreditsPerSecond'] = this.microcreditsPerSecond;
      json[r'freeThroughSeconds'] = this.freeThroughSeconds;
      json[r'minimumChargedSeconds'] = this.minimumChargedSeconds;
      json[r'listenerPaisePerHour'] = this.listenerPaisePerHour;
      json[r'testOnly'] = this.testOnly;
    return json;
  }

  /// Returns a new [Rate] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Rate? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid Rate object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing Rate.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null Rate.id');
      }
      if (!json.containsKey(r'coinsPerMinute')) {
        throw const FormatException('Missing Rate.coinsPerMinute');
      }
      if (json[r'coinsPerMinute'] == null) {
        throw const FormatException('Null Rate.coinsPerMinute');
      }
      if (json[r'coinsPerMinute'] != null && json[r'coinsPerMinute'] is! int) {
        throw const FormatException('Invalid Rate.coinsPerMinute integer');
      }
      if (!json.containsKey(r'microcreditsPerCoin')) {
        throw const FormatException('Missing Rate.microcreditsPerCoin');
      }
      if (json[r'microcreditsPerCoin'] == null) {
        throw const FormatException('Null Rate.microcreditsPerCoin');
      }
      if (json[r'microcreditsPerCoin'] != null && json[r'microcreditsPerCoin'] is! int) {
        throw const FormatException('Invalid Rate.microcreditsPerCoin integer');
      }
      if (!json.containsKey(r'microcreditsPerSecond')) {
        throw const FormatException('Missing Rate.microcreditsPerSecond');
      }
      if (json[r'microcreditsPerSecond'] == null) {
        throw const FormatException('Null Rate.microcreditsPerSecond');
      }
      if (json[r'microcreditsPerSecond'] != null && json[r'microcreditsPerSecond'] is! int) {
        throw const FormatException('Invalid Rate.microcreditsPerSecond integer');
      }
      if (!json.containsKey(r'freeThroughSeconds')) {
        throw const FormatException('Missing Rate.freeThroughSeconds');
      }
      if (json[r'freeThroughSeconds'] == null) {
        throw const FormatException('Null Rate.freeThroughSeconds');
      }
      if (json[r'freeThroughSeconds'] != null && json[r'freeThroughSeconds'] is! int) {
        throw const FormatException('Invalid Rate.freeThroughSeconds integer');
      }
      if (!json.containsKey(r'minimumChargedSeconds')) {
        throw const FormatException('Missing Rate.minimumChargedSeconds');
      }
      if (json[r'minimumChargedSeconds'] == null) {
        throw const FormatException('Null Rate.minimumChargedSeconds');
      }
      if (json[r'minimumChargedSeconds'] != null && json[r'minimumChargedSeconds'] is! int) {
        throw const FormatException('Invalid Rate.minimumChargedSeconds integer');
      }
      if (!json.containsKey(r'listenerPaisePerHour')) {
        throw const FormatException('Missing Rate.listenerPaisePerHour');
      }
      if (json[r'listenerPaisePerHour'] == null) {
        throw const FormatException('Null Rate.listenerPaisePerHour');
      }
      if (json[r'listenerPaisePerHour'] != null && json[r'listenerPaisePerHour'] is! int) {
        throw const FormatException('Invalid Rate.listenerPaisePerHour integer');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing Rate.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null Rate.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid Rate.testOnly boolean');
      }

      return Rate(
        id: RateIdEnum.fromJson(json[r'id'])!,
        coinsPerMinute: mapValueOfType<int>(json, r'coinsPerMinute')!,
        microcreditsPerCoin: mapValueOfType<int>(json, r'microcreditsPerCoin')!,
        microcreditsPerSecond: mapValueOfType<int>(json, r'microcreditsPerSecond')!,
        freeThroughSeconds: mapValueOfType<int>(json, r'freeThroughSeconds')!,
        minimumChargedSeconds: mapValueOfType<int>(json, r'minimumChargedSeconds')!,
        listenerPaisePerHour: mapValueOfType<int>(json, r'listenerPaisePerHour')!,
        testOnly: RateTestOnlyEnum.fromJson(json[r'testOnly'])!,
      );
    }
    return null;
  }

  static List<Rate> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Rate>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Rate.fromJson(row);
        if (value == null) throw const FormatException('Invalid Rate list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Rate> mapFromJson(dynamic json) {
    final map = <String, Rate>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Rate.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Rate-objects as value to a dart map
  static Map<String, List<Rate>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Rate>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Rate.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'coinsPerMinute',
    'microcreditsPerCoin',
    'microcreditsPerSecond',
    'freeThroughSeconds',
    'minimumChargedSeconds',
    'listenerPaisePerHour',
    'testOnly',
  };
}


enum RateIdEnum {
  testAudioV1._(r'test-audio-v1'),
  testVideoV1._(r'test-video-v1'),
  ;

  /// Instantiate a new enum with the provided value.
  const RateIdEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [RateIdEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static RateIdEnum? fromJson(dynamic value) => RateIdEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [RateIdEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<RateIdEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RateIdEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RateIdEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RateIdEnum] to String,
/// and [decode] dynamic data back to [RateIdEnum].
class RateIdEnumTypeTransformer {
  factory RateIdEnumTypeTransformer() => _instance ??= const RateIdEnumTypeTransformer._();

  const RateIdEnumTypeTransformer._();

  String encode(RateIdEnum data) => data._value;

  /// Returns the instance of [RateIdEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RateIdEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is RateIdEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'test-audio-v1': return RateIdEnum.testAudioV1;
        case r'test-video-v1': return RateIdEnum.testVideoV1;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static RateIdEnumTypeTransformer? _instance;
}



enum RateTestOnlyEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const RateTestOnlyEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [RateTestOnlyEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static RateTestOnlyEnum? fromJson(dynamic value) => RateTestOnlyEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [RateTestOnlyEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<RateTestOnlyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RateTestOnlyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RateTestOnlyEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RateTestOnlyEnum] to bool,
/// and [decode] dynamic data back to [RateTestOnlyEnum].
class RateTestOnlyEnumTypeTransformer {
  factory RateTestOnlyEnumTypeTransformer() => _instance ??= const RateTestOnlyEnumTypeTransformer._();

  const RateTestOnlyEnumTypeTransformer._();

  bool encode(RateTestOnlyEnum data) => data._value;

  /// Returns the instance of [RateTestOnlyEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RateTestOnlyEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is RateTestOnlyEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return RateTestOnlyEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static RateTestOnlyEnumTypeTransformer? _instance;
}


