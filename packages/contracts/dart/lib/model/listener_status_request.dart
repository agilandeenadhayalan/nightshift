//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ListenerStatusRequest {
  /// Returns a new [ListenerStatusRequest] instance.
  ListenerStatusRequest({
    required this.language,
    this.listenerIds = const {},
  });

  ListenerStatusRequestLanguageEnum language;

  Set<String> listenerIds;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListenerStatusRequest &&
    other.language == language &&
    _deepEquality.equals(other.listenerIds, listenerIds);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (language.hashCode) +
    (listenerIds.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ListenerStatusRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'language'] = this.language;
      json[r'listenerIds'] = this.listenerIds.toList(growable: false);
    return json;
  }

  /// Returns a new [ListenerStatusRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListenerStatusRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ListenerStatusRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'language')) {
        throw const FormatException('Missing ListenerStatusRequest.language');
      }
      if (json[r'language'] == null) {
        throw const FormatException('Null ListenerStatusRequest.language');
      }
      if (!json.containsKey(r'listenerIds')) {
        throw const FormatException('Missing ListenerStatusRequest.listenerIds');
      }
      if (json[r'listenerIds'] == null) {
        throw const FormatException('Null ListenerStatusRequest.listenerIds');
      }
      if (json[r'listenerIds'] != null && json[r'listenerIds'] is! List) {
        throw const FormatException('Invalid ListenerStatusRequest.listenerIds');
      }

      return ListenerStatusRequest(
        language: ListenerStatusRequestLanguageEnum.fromJson(json[r'language'])!,
        listenerIds: json[r'listenerIds'] is Iterable
            ? (json[r'listenerIds'] as Iterable).cast<String>().toSet()
            : const {},
      );
    }
    return null;
  }

  static List<ListenerStatusRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerStatusRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerStatusRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid ListenerStatusRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListenerStatusRequest> mapFromJson(dynamic json) {
    final map = <String, ListenerStatusRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListenerStatusRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListenerStatusRequest-objects as value to a dart map
  static Map<String, List<ListenerStatusRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListenerStatusRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListenerStatusRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'language',
    'listenerIds',
  };
}


enum ListenerStatusRequestLanguageEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerStatusRequestLanguageEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerStatusRequestLanguageEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerStatusRequestLanguageEnum? fromJson(dynamic value) => ListenerStatusRequestLanguageEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerStatusRequestLanguageEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerStatusRequestLanguageEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerStatusRequestLanguageEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerStatusRequestLanguageEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerStatusRequestLanguageEnum] to String,
/// and [decode] dynamic data back to [ListenerStatusRequestLanguageEnum].
class ListenerStatusRequestLanguageEnumTypeTransformer {
  factory ListenerStatusRequestLanguageEnumTypeTransformer() => _instance ??= const ListenerStatusRequestLanguageEnumTypeTransformer._();

  const ListenerStatusRequestLanguageEnumTypeTransformer._();

  String encode(ListenerStatusRequestLanguageEnum data) => data._value;

  /// Returns the instance of [ListenerStatusRequestLanguageEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerStatusRequestLanguageEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerStatusRequestLanguageEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return ListenerStatusRequestLanguageEnum.ta;
        case r'en': return ListenerStatusRequestLanguageEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerStatusRequestLanguageEnumTypeTransformer? _instance;
}


