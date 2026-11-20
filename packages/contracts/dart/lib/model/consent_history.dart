//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ConsentHistory {
  /// Returns a new [ConsentHistory] instance.
  ConsentHistory({
    this.items = const [],
  });

  List<ConsentEvent> items;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ConsentHistory &&
    _deepEquality.equals(other.items, items);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (items.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ConsentHistory[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'items'] = this.items;
    return json;
  }

  /// Returns a new [ConsentHistory] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ConsentHistory? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ConsentHistory object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'items')) {
        throw const FormatException('Missing ConsentHistory.items');
      }
      if (json[r'items'] == null) {
        throw const FormatException('Null ConsentHistory.items');
      }
      if (json[r'items'] != null && json[r'items'] is! List) {
        throw const FormatException('Invalid ConsentHistory.items');
      }

      return ConsentHistory(
        items: ConsentEvent.listFromJson(json[r'items']),
      );
    }
    return null;
  }

  static List<ConsentHistory> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ConsentHistory>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ConsentHistory.fromJson(row);
        if (value == null) throw const FormatException('Invalid ConsentHistory list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ConsentHistory> mapFromJson(dynamic json) {
    final map = <String, ConsentHistory>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ConsentHistory.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ConsentHistory-objects as value to a dart map
  static Map<String, List<ConsentHistory>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ConsentHistory>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ConsentHistory.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
  };
}

