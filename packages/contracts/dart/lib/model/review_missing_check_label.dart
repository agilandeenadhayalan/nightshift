//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ReviewMissingCheckLabel {
  /// Returns a new [ReviewMissingCheckLabel] instance.
  ReviewMissingCheckLabel({
    required this.en,
    required this.ta,
  });

  String en;

  String ta;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReviewMissingCheckLabel &&
    other.en == en &&
    other.ta == ta;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (en.hashCode) +
    (ta.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ReviewMissingCheckLabel[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'en'] = this.en;
      json[r'ta'] = this.ta;
    return json;
  }

  /// Returns a new [ReviewMissingCheckLabel] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReviewMissingCheckLabel? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ReviewMissingCheckLabel object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'en')) {
        throw const FormatException('Missing ReviewMissingCheckLabel.en');
      }
      if (json[r'en'] == null) {
        throw const FormatException('Null ReviewMissingCheckLabel.en');
      }
      if (!json.containsKey(r'ta')) {
        throw const FormatException('Missing ReviewMissingCheckLabel.ta');
      }
      if (json[r'ta'] == null) {
        throw const FormatException('Null ReviewMissingCheckLabel.ta');
      }

      return ReviewMissingCheckLabel(
        en: mapValueOfType<String>(json, r'en')!,
        ta: mapValueOfType<String>(json, r'ta')!,
      );
    }
    return null;
  }

  static List<ReviewMissingCheckLabel> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReviewMissingCheckLabel>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReviewMissingCheckLabel.fromJson(row);
        if (value == null) throw const FormatException('Invalid ReviewMissingCheckLabel list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReviewMissingCheckLabel> mapFromJson(dynamic json) {
    final map = <String, ReviewMissingCheckLabel>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReviewMissingCheckLabel.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReviewMissingCheckLabel-objects as value to a dart map
  static Map<String, List<ReviewMissingCheckLabel>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReviewMissingCheckLabel>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReviewMissingCheckLabel.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'en',
    'ta',
  };
}

