//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ReviewLocalizedText {
  /// Returns a new [ReviewLocalizedText] instance.
  ReviewLocalizedText({
    required this.en,
    required this.ta,
  });

  String en;

  String ta;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReviewLocalizedText &&
    other.en == en &&
    other.ta == ta;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (en.hashCode) +
    (ta.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ReviewLocalizedText[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'en'] = this.en;
      json[r'ta'] = this.ta;
    return json;
  }

  /// Returns a new [ReviewLocalizedText] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReviewLocalizedText? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ReviewLocalizedText object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'en')) {
        throw const FormatException('Missing ReviewLocalizedText.en');
      }
      if (json[r'en'] == null) {
        throw const FormatException('Null ReviewLocalizedText.en');
      }
      if (!json.containsKey(r'ta')) {
        throw const FormatException('Missing ReviewLocalizedText.ta');
      }
      if (json[r'ta'] == null) {
        throw const FormatException('Null ReviewLocalizedText.ta');
      }

      return ReviewLocalizedText(
        en: mapValueOfType<String>(json, r'en')!,
        ta: mapValueOfType<String>(json, r'ta')!,
      );
    }
    return null;
  }

  static List<ReviewLocalizedText> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReviewLocalizedText>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReviewLocalizedText.fromJson(row);
        if (value == null) throw const FormatException('Invalid ReviewLocalizedText list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReviewLocalizedText> mapFromJson(dynamic json) {
    final map = <String, ReviewLocalizedText>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReviewLocalizedText.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReviewLocalizedText-objects as value to a dart map
  static Map<String, List<ReviewLocalizedText>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReviewLocalizedText>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReviewLocalizedText.listFromJson(entry.value, growable: growable,);
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

