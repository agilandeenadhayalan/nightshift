//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ListenerPage {
  /// Returns a new [ListenerPage] instance.
  ListenerPage({
    this.items = const [],
    required this.nextCursor,
    required this.viewEpoch,
    required this.expiresAt,
    required this.serverTime,
    required this.truncated,
  });

  List<Listener> items;

  String? nextCursor;

  String viewEpoch;

  DateTime expiresAt;

  DateTime serverTime;

  bool truncated;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListenerPage &&
    _deepEquality.equals(other.items, items) &&
    other.nextCursor == nextCursor &&
    other.viewEpoch == viewEpoch &&
    other.expiresAt == expiresAt &&
    other.serverTime == serverTime &&
    other.truncated == truncated;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (items.hashCode) +
    (nextCursor == null ? 0 : nextCursor!.hashCode) +
    (viewEpoch.hashCode) +
    (expiresAt.hashCode) +
    (serverTime.hashCode) +
    (truncated.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ListenerPage[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'items'] = this.items;
    if (this.nextCursor != null) {
      json[r'nextCursor'] = this.nextCursor;
    } else {
      json[r'nextCursor'] = null;
    }
      json[r'viewEpoch'] = this.viewEpoch;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'serverTime'] = this.serverTime.toUtc().toIso8601String();
      json[r'truncated'] = this.truncated;
    return json;
  }

  /// Returns a new [ListenerPage] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListenerPage? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ListenerPage object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'items')) {
        throw const FormatException('Missing ListenerPage.items');
      }
      if (json[r'items'] == null) {
        throw const FormatException('Null ListenerPage.items');
      }
      if (json[r'items'] != null && json[r'items'] is! List) {
        throw const FormatException('Invalid ListenerPage.items');
      }
      if (!json.containsKey(r'nextCursor')) {
        throw const FormatException('Missing ListenerPage.nextCursor');
      }
      if (!json.containsKey(r'viewEpoch')) {
        throw const FormatException('Missing ListenerPage.viewEpoch');
      }
      if (json[r'viewEpoch'] == null) {
        throw const FormatException('Null ListenerPage.viewEpoch');
      }
      if (!json.containsKey(r'expiresAt')) {
        throw const FormatException('Missing ListenerPage.expiresAt');
      }
      if (json[r'expiresAt'] == null) {
        throw const FormatException('Null ListenerPage.expiresAt');
      }
      if (json[r'expiresAt'] != null && (json[r'expiresAt'] is! String || DateTime.tryParse(json[r'expiresAt'] as String) == null)) {
        throw const FormatException('Invalid ListenerPage.expiresAt');
      }
      if (!json.containsKey(r'serverTime')) {
        throw const FormatException('Missing ListenerPage.serverTime');
      }
      if (json[r'serverTime'] == null) {
        throw const FormatException('Null ListenerPage.serverTime');
      }
      if (json[r'serverTime'] != null && (json[r'serverTime'] is! String || DateTime.tryParse(json[r'serverTime'] as String) == null)) {
        throw const FormatException('Invalid ListenerPage.serverTime');
      }
      if (!json.containsKey(r'truncated')) {
        throw const FormatException('Missing ListenerPage.truncated');
      }
      if (json[r'truncated'] == null) {
        throw const FormatException('Null ListenerPage.truncated');
      }
      if (json[r'truncated'] != null && json[r'truncated'] is! bool) {
        throw const FormatException('Invalid ListenerPage.truncated boolean');
      }

      return ListenerPage(
        items: Listener.listFromJson(json[r'items']),
        nextCursor: mapValueOfType<String>(json, r'nextCursor'),
        viewEpoch: mapValueOfType<String>(json, r'viewEpoch')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        serverTime: mapDateTime(json, r'serverTime', r'')!,
        truncated: mapValueOfType<bool>(json, r'truncated')!,
      );
    }
    return null;
  }

  static List<ListenerPage> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerPage>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerPage.fromJson(row);
        if (value == null) throw const FormatException('Invalid ListenerPage list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListenerPage> mapFromJson(dynamic json) {
    final map = <String, ListenerPage>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListenerPage.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListenerPage-objects as value to a dart map
  static Map<String, List<ListenerPage>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListenerPage>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListenerPage.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
    'nextCursor',
    'viewEpoch',
    'expiresAt',
    'serverTime',
    'truncated',
  };
}

