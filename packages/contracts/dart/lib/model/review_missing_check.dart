//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ReviewMissingCheck {
  /// Returns a new [ReviewMissingCheck] instance.
  ReviewMissingCheck({
    required this.id,
    required this.label,
  });

  String id;

  ReviewMissingCheckLabel label;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReviewMissingCheck &&
    other.id == id &&
    other.label == label;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (label.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ReviewMissingCheck[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'label'] = this.label;
    return json;
  }

  /// Returns a new [ReviewMissingCheck] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReviewMissingCheck? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ReviewMissingCheck object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing ReviewMissingCheck.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null ReviewMissingCheck.id');
      }
      if (!json.containsKey(r'label')) {
        throw const FormatException('Missing ReviewMissingCheck.label');
      }
      if (json[r'label'] == null) {
        throw const FormatException('Null ReviewMissingCheck.label');
      }

      return ReviewMissingCheck(
        id: mapValueOfType<String>(json, r'id')!,
        label: ReviewMissingCheckLabel.fromJson(json[r'label'])!,
      );
    }
    return null;
  }

  static List<ReviewMissingCheck> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReviewMissingCheck>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReviewMissingCheck.fromJson(row);
        if (value == null) throw const FormatException('Invalid ReviewMissingCheck list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReviewMissingCheck> mapFromJson(dynamic json) {
    final map = <String, ReviewMissingCheck>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReviewMissingCheck.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReviewMissingCheck-objects as value to a dart map
  static Map<String, List<ReviewMissingCheck>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReviewMissingCheck>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReviewMissingCheck.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'label',
  };
}

