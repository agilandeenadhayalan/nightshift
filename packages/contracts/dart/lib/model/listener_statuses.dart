//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ListenerStatuses {
  /// Returns a new [ListenerStatuses] instance.
  ListenerStatuses({
    this.items = const [],
    this.removedIds = const [],
    required this.serverTime,
  });

  List<Listener> items;

  List<String> removedIds;

  DateTime serverTime;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListenerStatuses &&
    _deepEquality.equals(other.items, items) &&
    _deepEquality.equals(other.removedIds, removedIds) &&
    other.serverTime == serverTime;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (items.hashCode) +
    (removedIds.hashCode) +
    (serverTime.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ListenerStatuses[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'items'] = this.items;
      json[r'removedIds'] = this.removedIds;
      json[r'serverTime'] = this.serverTime.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [ListenerStatuses] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListenerStatuses? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ListenerStatuses object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'items')) {
        throw const FormatException('Missing ListenerStatuses.items');
      }
      if (json[r'items'] == null) {
        throw const FormatException('Null ListenerStatuses.items');
      }
      if (json[r'items'] != null && json[r'items'] is! List) {
        throw const FormatException('Invalid ListenerStatuses.items');
      }
      if (!json.containsKey(r'removedIds')) {
        throw const FormatException('Missing ListenerStatuses.removedIds');
      }
      if (json[r'removedIds'] == null) {
        throw const FormatException('Null ListenerStatuses.removedIds');
      }
      if (json[r'removedIds'] != null && json[r'removedIds'] is! List) {
        throw const FormatException('Invalid ListenerStatuses.removedIds');
      }
      if (!json.containsKey(r'serverTime')) {
        throw const FormatException('Missing ListenerStatuses.serverTime');
      }
      if (json[r'serverTime'] == null) {
        throw const FormatException('Null ListenerStatuses.serverTime');
      }
      if (json[r'serverTime'] != null && (json[r'serverTime'] is! String || DateTime.tryParse(json[r'serverTime'] as String) == null)) {
        throw const FormatException('Invalid ListenerStatuses.serverTime');
      }

      return ListenerStatuses(
        items: Listener.listFromJson(json[r'items']),
        removedIds: json[r'removedIds'] is Iterable
            ? (json[r'removedIds'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        serverTime: mapDateTime(json, r'serverTime', r'')!,
      );
    }
    return null;
  }

  static List<ListenerStatuses> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerStatuses>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerStatuses.fromJson(row);
        if (value == null) throw const FormatException('Invalid ListenerStatuses list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListenerStatuses> mapFromJson(dynamic json) {
    final map = <String, ListenerStatuses>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListenerStatuses.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListenerStatuses-objects as value to a dart map
  static Map<String, List<ListenerStatuses>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListenerStatuses>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListenerStatuses.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
    'removedIds',
    'serverTime',
  };
}

