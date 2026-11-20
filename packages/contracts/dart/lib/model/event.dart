//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class Event {
  /// Returns a new [Event] instance.
  Event({
    required this.id,
    required this.type,
    required this.entityId,
    required this.version,
    required this.timestamp,
    required this.data,
  });

  String id;

  EventTypeEnum type;

  String entityId;

  int version;

  DateTime timestamp;

  Call data;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Event &&
    other.id == id &&
    other.type == type &&
    other.entityId == entityId &&
    other.version == version &&
    other.timestamp == timestamp &&
    other.data == data;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (type.hashCode) +
    (entityId.hashCode) +
    (version.hashCode) +
    (timestamp.hashCode) +
    (data.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'Event[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'type'] = this.type;
      json[r'entityId'] = this.entityId;
      json[r'version'] = this.version;
      json[r'timestamp'] = this.timestamp.toUtc().toIso8601String();
      json[r'data'] = this.data;
    return json;
  }

  /// Returns a new [Event] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Event? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid Event object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing Event.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null Event.id');
      }
      if (!json.containsKey(r'type')) {
        throw const FormatException('Missing Event.type');
      }
      if (json[r'type'] == null) {
        throw const FormatException('Null Event.type');
      }
      if (!json.containsKey(r'entityId')) {
        throw const FormatException('Missing Event.entityId');
      }
      if (json[r'entityId'] == null) {
        throw const FormatException('Null Event.entityId');
      }
      if (!json.containsKey(r'version')) {
        throw const FormatException('Missing Event.version');
      }
      if (json[r'version'] == null) {
        throw const FormatException('Null Event.version');
      }
      if (json[r'version'] != null && json[r'version'] is! int) {
        throw const FormatException('Invalid Event.version integer');
      }
      if (!json.containsKey(r'timestamp')) {
        throw const FormatException('Missing Event.timestamp');
      }
      if (json[r'timestamp'] == null) {
        throw const FormatException('Null Event.timestamp');
      }
      if (json[r'timestamp'] != null && (json[r'timestamp'] is! String || DateTime.tryParse(json[r'timestamp'] as String) == null)) {
        throw const FormatException('Invalid Event.timestamp');
      }
      if (!json.containsKey(r'data')) {
        throw const FormatException('Missing Event.data');
      }
      if (json[r'data'] == null) {
        throw const FormatException('Null Event.data');
      }

      return Event(
        id: mapValueOfType<String>(json, r'id')!,
        type: EventTypeEnum.fromJson(json[r'type'])!,
        entityId: mapValueOfType<String>(json, r'entityId')!,
        version: mapValueOfType<int>(json, r'version')!,
        timestamp: mapDateTime(json, r'timestamp', r'')!,
        data: Call.fromJson(json[r'data'])!,
      );
    }
    return null;
  }

  static List<Event> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Event>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Event.fromJson(row);
        if (value == null) throw const FormatException('Invalid Event list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Event> mapFromJson(dynamic json) {
    final map = <String, Event>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Event.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Event-objects as value to a dart map
  static Map<String, List<Event>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Event>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Event.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'type',
    'entityId',
    'version',
    'timestamp',
    'data',
  };
}


enum EventTypeEnum {
  callPeriodInvited._(r'call.invited'),
  callPeriodStateChanged._(r'call.state_changed'),
  ;

  /// Instantiate a new enum with the provided value.
  const EventTypeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [EventTypeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static EventTypeEnum? fromJson(dynamic value) => EventTypeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [EventTypeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<EventTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <EventTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = EventTypeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [EventTypeEnum] to String,
/// and [decode] dynamic data back to [EventTypeEnum].
class EventTypeEnumTypeTransformer {
  factory EventTypeEnumTypeTransformer() => _instance ??= const EventTypeEnumTypeTransformer._();

  const EventTypeEnumTypeTransformer._();

  String encode(EventTypeEnum data) => data._value;

  /// Returns the instance of [EventTypeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  EventTypeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is EventTypeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'call.invited': return EventTypeEnum.callPeriodInvited;
        case r'call.state_changed': return EventTypeEnum.callPeriodStateChanged;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static EventTypeEnumTypeTransformer? _instance;
}


