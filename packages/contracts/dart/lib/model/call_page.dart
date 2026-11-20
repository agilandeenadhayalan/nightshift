//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class CallPage {
  /// Returns a new [CallPage] instance.
  CallPage({
    this.items = const [],
    required this.nextCursor,
  });

  List<Call> items;

  String? nextCursor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CallPage &&
    _deepEquality.equals(other.items, items) &&
    other.nextCursor == nextCursor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (items.hashCode) +
    (nextCursor == null ? 0 : nextCursor!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'CallPage[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'items'] = this.items;
    if (this.nextCursor != null) {
      json[r'nextCursor'] = this.nextCursor;
    } else {
      json[r'nextCursor'] = null;
    }
    return json;
  }

  /// Returns a new [CallPage] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CallPage? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid CallPage object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'items')) {
        throw const FormatException('Missing CallPage.items');
      }
      if (json[r'items'] == null) {
        throw const FormatException('Null CallPage.items');
      }
      if (json[r'items'] != null && json[r'items'] is! List) {
        throw const FormatException('Invalid CallPage.items');
      }
      if (!json.containsKey(r'nextCursor')) {
        throw const FormatException('Missing CallPage.nextCursor');
      }

      return CallPage(
        items: Call.listFromJson(json[r'items']),
        nextCursor: mapValueOfType<String>(json, r'nextCursor'),
      );
    }
    return null;
  }

  static List<CallPage> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CallPage>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CallPage.fromJson(row);
        if (value == null) throw const FormatException('Invalid CallPage list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CallPage> mapFromJson(dynamic json) {
    final map = <String, CallPage>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CallPage.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CallPage-objects as value to a dart map
  static Map<String, List<CallPage>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CallPage>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CallPage.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
    'nextCursor',
  };
}

