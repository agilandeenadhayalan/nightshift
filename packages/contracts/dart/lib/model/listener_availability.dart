//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ListenerAvailability {
  /// Returns a new [ListenerAvailability] instance.
  ListenerAvailability({
    required this.online,
    required this.audioEnabled,
    required this.videoEnabled,
  });

  /// Saved master availability intent; not a presence or provider capability proof.
  bool online;

  bool audioEnabled;

  bool videoEnabled;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListenerAvailability &&
    other.online == online &&
    other.audioEnabled == audioEnabled &&
    other.videoEnabled == videoEnabled;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (online.hashCode) +
    (audioEnabled.hashCode) +
    (videoEnabled.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ListenerAvailability[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'online'] = this.online;
      json[r'audioEnabled'] = this.audioEnabled;
      json[r'videoEnabled'] = this.videoEnabled;
    return json;
  }

  /// Returns a new [ListenerAvailability] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListenerAvailability? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ListenerAvailability object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'online')) {
        throw const FormatException('Missing ListenerAvailability.online');
      }
      if (json[r'online'] == null) {
        throw const FormatException('Null ListenerAvailability.online');
      }
      if (json[r'online'] != null && json[r'online'] is! bool) {
        throw const FormatException('Invalid ListenerAvailability.online boolean');
      }
      if (!json.containsKey(r'audioEnabled')) {
        throw const FormatException('Missing ListenerAvailability.audioEnabled');
      }
      if (json[r'audioEnabled'] == null) {
        throw const FormatException('Null ListenerAvailability.audioEnabled');
      }
      if (json[r'audioEnabled'] != null && json[r'audioEnabled'] is! bool) {
        throw const FormatException('Invalid ListenerAvailability.audioEnabled boolean');
      }
      if (!json.containsKey(r'videoEnabled')) {
        throw const FormatException('Missing ListenerAvailability.videoEnabled');
      }
      if (json[r'videoEnabled'] == null) {
        throw const FormatException('Null ListenerAvailability.videoEnabled');
      }
      if (json[r'videoEnabled'] != null && json[r'videoEnabled'] is! bool) {
        throw const FormatException('Invalid ListenerAvailability.videoEnabled boolean');
      }

      return ListenerAvailability(
        online: mapValueOfType<bool>(json, r'online')!,
        audioEnabled: mapValueOfType<bool>(json, r'audioEnabled')!,
        videoEnabled: mapValueOfType<bool>(json, r'videoEnabled')!,
      );
    }
    return null;
  }

  static List<ListenerAvailability> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerAvailability>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerAvailability.fromJson(row);
        if (value == null) throw const FormatException('Invalid ListenerAvailability list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListenerAvailability> mapFromJson(dynamic json) {
    final map = <String, ListenerAvailability>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListenerAvailability.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListenerAvailability-objects as value to a dart map
  static Map<String, List<ListenerAvailability>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListenerAvailability>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListenerAvailability.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'online',
    'audioEnabled',
    'videoEnabled',
  };
}

