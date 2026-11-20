//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class Wallet {
  /// Returns a new [Wallet] instance.
  Wallet({
    required this.balanceMicrocredits,
    required this.heldMicrocredits,
    required this.availableMicrocredits,
    required this.testOnly,
  });

  int balanceMicrocredits;

  int heldMicrocredits;

  int availableMicrocredits;

  WalletTestOnlyEnum testOnly;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Wallet &&
    other.balanceMicrocredits == balanceMicrocredits &&
    other.heldMicrocredits == heldMicrocredits &&
    other.availableMicrocredits == availableMicrocredits &&
    other.testOnly == testOnly;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (balanceMicrocredits.hashCode) +
    (heldMicrocredits.hashCode) +
    (availableMicrocredits.hashCode) +
    (testOnly.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'Wallet[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'balanceMicrocredits'] = this.balanceMicrocredits;
      json[r'heldMicrocredits'] = this.heldMicrocredits;
      json[r'availableMicrocredits'] = this.availableMicrocredits;
      json[r'testOnly'] = this.testOnly;
    return json;
  }

  /// Returns a new [Wallet] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Wallet? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid Wallet object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'balanceMicrocredits')) {
        throw const FormatException('Missing Wallet.balanceMicrocredits');
      }
      if (json[r'balanceMicrocredits'] == null) {
        throw const FormatException('Null Wallet.balanceMicrocredits');
      }
      if (json[r'balanceMicrocredits'] != null && json[r'balanceMicrocredits'] is! int) {
        throw const FormatException('Invalid Wallet.balanceMicrocredits integer');
      }
      if (!json.containsKey(r'heldMicrocredits')) {
        throw const FormatException('Missing Wallet.heldMicrocredits');
      }
      if (json[r'heldMicrocredits'] == null) {
        throw const FormatException('Null Wallet.heldMicrocredits');
      }
      if (json[r'heldMicrocredits'] != null && json[r'heldMicrocredits'] is! int) {
        throw const FormatException('Invalid Wallet.heldMicrocredits integer');
      }
      if (!json.containsKey(r'availableMicrocredits')) {
        throw const FormatException('Missing Wallet.availableMicrocredits');
      }
      if (json[r'availableMicrocredits'] == null) {
        throw const FormatException('Null Wallet.availableMicrocredits');
      }
      if (json[r'availableMicrocredits'] != null && json[r'availableMicrocredits'] is! int) {
        throw const FormatException('Invalid Wallet.availableMicrocredits integer');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing Wallet.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null Wallet.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid Wallet.testOnly boolean');
      }

      return Wallet(
        balanceMicrocredits: mapValueOfType<int>(json, r'balanceMicrocredits')!,
        heldMicrocredits: mapValueOfType<int>(json, r'heldMicrocredits')!,
        availableMicrocredits: mapValueOfType<int>(json, r'availableMicrocredits')!,
        testOnly: WalletTestOnlyEnum.fromJson(json[r'testOnly'])!,
      );
    }
    return null;
  }

  static List<Wallet> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Wallet>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Wallet.fromJson(row);
        if (value == null) throw const FormatException('Invalid Wallet list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Wallet> mapFromJson(dynamic json) {
    final map = <String, Wallet>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Wallet.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Wallet-objects as value to a dart map
  static Map<String, List<Wallet>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Wallet>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Wallet.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'balanceMicrocredits',
    'heldMicrocredits',
    'availableMicrocredits',
    'testOnly',
  };
}


enum WalletTestOnlyEnum {
  true_._('true' == 'true'),
  ;

  /// Instantiate a new enum with the provided value.
  const WalletTestOnlyEnum._(this._value);

  /// The underlying value of this enum member.
  final bool _value;

  @override
  String toString() => _value.toString();

  /// Encodes this enum as a value suitable for JSON.
  bool toJson() => _value;

  /// Returns the instance of [WalletTestOnlyEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static WalletTestOnlyEnum? fromJson(dynamic value) => WalletTestOnlyEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [WalletTestOnlyEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<WalletTestOnlyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <WalletTestOnlyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = WalletTestOnlyEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [WalletTestOnlyEnum] to bool,
/// and [decode] dynamic data back to [WalletTestOnlyEnum].
class WalletTestOnlyEnumTypeTransformer {
  factory WalletTestOnlyEnumTypeTransformer() => _instance ??= const WalletTestOnlyEnumTypeTransformer._();

  const WalletTestOnlyEnumTypeTransformer._();

  bool encode(WalletTestOnlyEnum data) => data._value;

  /// Returns the instance of [WalletTestOnlyEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  WalletTestOnlyEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is WalletTestOnlyEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case 'true' == 'true': return WalletTestOnlyEnum.true_;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static WalletTestOnlyEnumTypeTransformer? _instance;
}


