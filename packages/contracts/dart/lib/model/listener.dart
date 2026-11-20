//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class Listener {
  /// Returns a new [Listener] instance.
  Listener({
    required this.id,
    required this.displayName,
    this.languages = const [],
    required this.online,
    required this.available,
    required this.busy,
    required this.favorite,
    required this.testOnly,
    required this.rate,
    this.videoRate,
  });

  String id;

  String displayName;

  List<ListenerLanguagesEnum> languages;

  bool online;

  bool available;

  bool busy;

  bool favorite;

  bool testOnly;

  Rate rate;

  Rate? videoRate;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Listener &&
    other.id == id &&
    other.displayName == displayName &&
    _deepEquality.equals(other.languages, languages) &&
    other.online == online &&
    other.available == available &&
    other.busy == busy &&
    other.favorite == favorite &&
    other.testOnly == testOnly &&
    other.rate == rate &&
    other.videoRate == videoRate;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (displayName.hashCode) +
    (languages.hashCode) +
    (online.hashCode) +
    (available.hashCode) +
    (busy.hashCode) +
    (favorite.hashCode) +
    (testOnly.hashCode) +
    (rate.hashCode) +
    (videoRate == null ? 0 : videoRate!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'Listener[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'displayName'] = this.displayName;
      json[r'languages'] = this.languages;
      json[r'online'] = this.online;
      json[r'available'] = this.available;
      json[r'busy'] = this.busy;
      json[r'favorite'] = this.favorite;
      json[r'testOnly'] = this.testOnly;
      json[r'rate'] = this.rate;
    if (this.videoRate != null) {
      json[r'videoRate'] = this.videoRate;
    } else {
      json[r'videoRate'] = null;
    }
    return json;
  }

  /// Returns a new [Listener] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Listener? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid Listener object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing Listener.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null Listener.id');
      }
      if (!json.containsKey(r'displayName')) {
        throw const FormatException('Missing Listener.displayName');
      }
      if (json[r'displayName'] == null) {
        throw const FormatException('Null Listener.displayName');
      }
      if (!json.containsKey(r'languages')) {
        throw const FormatException('Missing Listener.languages');
      }
      if (json[r'languages'] == null) {
        throw const FormatException('Null Listener.languages');
      }
      if (json[r'languages'] != null && json[r'languages'] is! List) {
        throw const FormatException('Invalid Listener.languages');
      }
      if (!json.containsKey(r'online')) {
        throw const FormatException('Missing Listener.online');
      }
      if (json[r'online'] == null) {
        throw const FormatException('Null Listener.online');
      }
      if (json[r'online'] != null && json[r'online'] is! bool) {
        throw const FormatException('Invalid Listener.online boolean');
      }
      if (!json.containsKey(r'available')) {
        throw const FormatException('Missing Listener.available');
      }
      if (json[r'available'] == null) {
        throw const FormatException('Null Listener.available');
      }
      if (json[r'available'] != null && json[r'available'] is! bool) {
        throw const FormatException('Invalid Listener.available boolean');
      }
      if (!json.containsKey(r'busy')) {
        throw const FormatException('Missing Listener.busy');
      }
      if (json[r'busy'] == null) {
        throw const FormatException('Null Listener.busy');
      }
      if (json[r'busy'] != null && json[r'busy'] is! bool) {
        throw const FormatException('Invalid Listener.busy boolean');
      }
      if (!json.containsKey(r'favorite')) {
        throw const FormatException('Missing Listener.favorite');
      }
      if (json[r'favorite'] == null) {
        throw const FormatException('Null Listener.favorite');
      }
      if (json[r'favorite'] != null && json[r'favorite'] is! bool) {
        throw const FormatException('Invalid Listener.favorite boolean');
      }
      if (!json.containsKey(r'testOnly')) {
        throw const FormatException('Missing Listener.testOnly');
      }
      if (json[r'testOnly'] == null) {
        throw const FormatException('Null Listener.testOnly');
      }
      if (json[r'testOnly'] != null && json[r'testOnly'] is! bool) {
        throw const FormatException('Invalid Listener.testOnly boolean');
      }
      if (!json.containsKey(r'rate')) {
        throw const FormatException('Missing Listener.rate');
      }
      if (json[r'rate'] == null) {
        throw const FormatException('Null Listener.rate');
      }

      return Listener(
        id: mapValueOfType<String>(json, r'id')!,
        displayName: mapValueOfType<String>(json, r'displayName')!,
        languages: ListenerLanguagesEnum.listFromJson(json[r'languages']),
        online: mapValueOfType<bool>(json, r'online')!,
        available: mapValueOfType<bool>(json, r'available')!,
        busy: mapValueOfType<bool>(json, r'busy')!,
        favorite: mapValueOfType<bool>(json, r'favorite')!,
        testOnly: mapValueOfType<bool>(json, r'testOnly')!,
        rate: Rate.fromJson(json[r'rate'])!,
        videoRate: Rate.fromJson(json[r'videoRate']),
      );
    }
    return null;
  }

  static List<Listener> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Listener>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Listener.fromJson(row);
        if (value == null) throw const FormatException('Invalid Listener list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Listener> mapFromJson(dynamic json) {
    final map = <String, Listener>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Listener.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Listener-objects as value to a dart map
  static Map<String, List<Listener>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Listener>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Listener.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'displayName',
    'languages',
    'online',
    'available',
    'busy',
    'favorite',
    'testOnly',
    'rate',
  };
}


enum ListenerLanguagesEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerLanguagesEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerLanguagesEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerLanguagesEnum? fromJson(dynamic value) => ListenerLanguagesEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerLanguagesEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerLanguagesEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerLanguagesEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerLanguagesEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerLanguagesEnum] to String,
/// and [decode] dynamic data back to [ListenerLanguagesEnum].
class ListenerLanguagesEnumTypeTransformer {
  factory ListenerLanguagesEnumTypeTransformer() => _instance ??= const ListenerLanguagesEnumTypeTransformer._();

  const ListenerLanguagesEnumTypeTransformer._();

  String encode(ListenerLanguagesEnum data) => data._value;

  /// Returns the instance of [ListenerLanguagesEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerLanguagesEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerLanguagesEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return ListenerLanguagesEnum.ta;
        case r'en': return ListenerLanguagesEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerLanguagesEnumTypeTransformer? _instance;
}


