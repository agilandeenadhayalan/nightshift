//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ListenerReviewState {
  /// Returns a new [ListenerReviewState] instance.
  ListenerReviewState({
    required this.applicationId,
    required this.state,
    required this.review,
  });

  String? applicationId;

  ListenerReviewStateStateEnum? state;

  ListenerReviewOutcome? review;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListenerReviewState &&
    other.applicationId == applicationId &&
    other.state == state &&
    other.review == review;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (applicationId == null ? 0 : applicationId!.hashCode) +
    (state == null ? 0 : state!.hashCode) +
    (review == null ? 0 : review!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ListenerReviewState[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.applicationId != null) {
      json[r'applicationId'] = this.applicationId;
    } else {
      json[r'applicationId'] = null;
    }
    if (this.state != null) {
      json[r'state'] = this.state;
    } else {
      json[r'state'] = null;
    }
    if (this.review != null) {
      json[r'review'] = this.review;
    } else {
      json[r'review'] = null;
    }
    return json;
  }

  /// Returns a new [ListenerReviewState] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListenerReviewState? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ListenerReviewState object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'applicationId')) {
        throw const FormatException('Missing ListenerReviewState.applicationId');
      }
      if (!json.containsKey(r'state')) {
        throw const FormatException('Missing ListenerReviewState.state');
      }
      if (!json.containsKey(r'review')) {
        throw const FormatException('Missing ListenerReviewState.review');
      }

      return ListenerReviewState(
        applicationId: mapValueOfType<String>(json, r'applicationId'),
        state: ListenerReviewStateStateEnum.fromJson(json[r'state']),
        review: ListenerReviewOutcome.fromJson(json[r'review']),
      );
    }
    return null;
  }

  static List<ListenerReviewState> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerReviewState>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerReviewState.fromJson(row);
        if (value == null) throw const FormatException('Invalid ListenerReviewState list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListenerReviewState> mapFromJson(dynamic json) {
    final map = <String, ListenerReviewState>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListenerReviewState.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListenerReviewState-objects as value to a dart map
  static Map<String, List<ListenerReviewState>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListenerReviewState>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListenerReviewState.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'applicationId',
    'state',
    'review',
  };
}


enum ListenerReviewStateStateEnum {
  draft._(r'draft'),
  submitted._(r'submitted'),
  needsInformation._(r'needs_information'),
  approved._(r'approved'),
  rejected._(r'rejected'),
  withdrawn._(r'withdrawn'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerReviewStateStateEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerReviewStateStateEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerReviewStateStateEnum? fromJson(dynamic value) => ListenerReviewStateStateEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerReviewStateStateEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerReviewStateStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerReviewStateStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerReviewStateStateEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerReviewStateStateEnum] to String,
/// and [decode] dynamic data back to [ListenerReviewStateStateEnum].
class ListenerReviewStateStateEnumTypeTransformer {
  factory ListenerReviewStateStateEnumTypeTransformer() => _instance ??= const ListenerReviewStateStateEnumTypeTransformer._();

  const ListenerReviewStateStateEnumTypeTransformer._();

  String encode(ListenerReviewStateStateEnum data) => data._value;

  /// Returns the instance of [ListenerReviewStateStateEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerReviewStateStateEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerReviewStateStateEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'draft': return ListenerReviewStateStateEnum.draft;
        case r'submitted': return ListenerReviewStateStateEnum.submitted;
        case r'needs_information': return ListenerReviewStateStateEnum.needsInformation;
        case r'approved': return ListenerReviewStateStateEnum.approved;
        case r'rejected': return ListenerReviewStateStateEnum.rejected;
        case r'withdrawn': return ListenerReviewStateStateEnum.withdrawn;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerReviewStateStateEnumTypeTransformer? _instance;
}


