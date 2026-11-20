//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class FavoriteListener200Response {
  /// Returns a new [FavoriteListener200Response] instance.
  FavoriteListener200Response({
    required this.favorite,
  });

  bool favorite;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FavoriteListener200Response &&
    other.favorite == favorite;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (favorite.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'FavoriteListener200Response[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'favorite'] = this.favorite;
    return json;
  }

  /// Returns a new [FavoriteListener200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FavoriteListener200Response? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid FavoriteListener200Response object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'favorite')) {
        throw const FormatException('Missing FavoriteListener200Response.favorite');
      }
      if (json[r'favorite'] == null) {
        throw const FormatException('Null FavoriteListener200Response.favorite');
      }
      if (json[r'favorite'] != null && json[r'favorite'] is! bool) {
        throw const FormatException('Invalid FavoriteListener200Response.favorite boolean');
      }

      return FavoriteListener200Response(
        favorite: mapValueOfType<bool>(json, r'favorite')!,
      );
    }
    return null;
  }

  static List<FavoriteListener200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FavoriteListener200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FavoriteListener200Response.fromJson(row);
        if (value == null) throw const FormatException('Invalid FavoriteListener200Response list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FavoriteListener200Response> mapFromJson(dynamic json) {
    final map = <String, FavoriteListener200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FavoriteListener200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FavoriteListener200Response-objects as value to a dart map
  static Map<String, List<FavoriteListener200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<FavoriteListener200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FavoriteListener200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'favorite',
  };
}

