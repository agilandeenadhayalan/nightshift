//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ListenerReviewNotice {
  /// Returns a new [ListenerReviewNotice] instance.
  ListenerReviewNotice({
    required this.id,
    required this.createdAt,
  });

  String id;

  DateTime createdAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListenerReviewNotice &&
    other.id == id &&
    other.createdAt == createdAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (createdAt.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ListenerReviewNotice[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'createdAt'] = this.createdAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [ListenerReviewNotice] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListenerReviewNotice? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ListenerReviewNotice object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing ListenerReviewNotice.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null ListenerReviewNotice.id');
      }
      if (!json.containsKey(r'createdAt')) {
        throw const FormatException('Missing ListenerReviewNotice.createdAt');
      }
      if (json[r'createdAt'] == null) {
        throw const FormatException('Null ListenerReviewNotice.createdAt');
      }
      if (json[r'createdAt'] != null && (json[r'createdAt'] is! String || DateTime.tryParse(json[r'createdAt'] as String) == null)) {
        throw const FormatException('Invalid ListenerReviewNotice.createdAt');
      }

      return ListenerReviewNotice(
        id: mapValueOfType<String>(json, r'id')!,
        createdAt: mapDateTime(json, r'createdAt', r'')!,
      );
    }
    return null;
  }

  static List<ListenerReviewNotice> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerReviewNotice>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerReviewNotice.fromJson(row);
        if (value == null) throw const FormatException('Invalid ListenerReviewNotice list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListenerReviewNotice> mapFromJson(dynamic json) {
    final map = <String, ListenerReviewNotice>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListenerReviewNotice.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListenerReviewNotice-objects as value to a dart map
  static Map<String, List<ListenerReviewNotice>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListenerReviewNotice>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListenerReviewNotice.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'createdAt',
  };
}

