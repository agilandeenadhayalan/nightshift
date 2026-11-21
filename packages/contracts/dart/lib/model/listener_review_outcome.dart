//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ListenerReviewOutcome {
  /// Returns a new [ListenerReviewOutcome] instance.
  ListenerReviewOutcome({
    required this.applicationId,
    required this.decisionId,
    required this.outcome,
    required this.reasonCode,
    required this.message,
    this.missingChecks = const [],
    required this.recordedAt,
    required this.entitlement,
    required this.notification,
  });

  String applicationId;

  String decisionId;

  ListenerReviewOutcomeOutcomeEnum outcome;

  String reasonCode;

  ReviewLocalizedText message;

  List<ReviewMissingCheck> missingChecks;

  DateTime recordedAt;

  ListenerReviewOutcomeEntitlementEnum entitlement;

  ListenerReviewNotice? notification;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListenerReviewOutcome &&
    other.applicationId == applicationId &&
    other.decisionId == decisionId &&
    other.outcome == outcome &&
    other.reasonCode == reasonCode &&
    other.message == message &&
    _deepEquality.equals(other.missingChecks, missingChecks) &&
    other.recordedAt == recordedAt &&
    other.entitlement == entitlement &&
    other.notification == notification;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (applicationId.hashCode) +
    (decisionId.hashCode) +
    (outcome.hashCode) +
    (reasonCode.hashCode) +
    (message.hashCode) +
    (missingChecks.hashCode) +
    (recordedAt.hashCode) +
    (entitlement.hashCode) +
    (notification == null ? 0 : notification!.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ListenerReviewOutcome[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'applicationId'] = this.applicationId;
      json[r'decisionId'] = this.decisionId;
      json[r'outcome'] = this.outcome;
      json[r'reasonCode'] = this.reasonCode;
      json[r'message'] = this.message;
      json[r'missingChecks'] = this.missingChecks;
      json[r'recordedAt'] = this.recordedAt.toUtc().toIso8601String();
      json[r'entitlement'] = this.entitlement;
    if (this.notification != null) {
      json[r'notification'] = this.notification;
    } else {
      json[r'notification'] = null;
    }
    return json;
  }

  /// Returns a new [ListenerReviewOutcome] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListenerReviewOutcome? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ListenerReviewOutcome object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'applicationId')) {
        throw const FormatException('Missing ListenerReviewOutcome.applicationId');
      }
      if (json[r'applicationId'] == null) {
        throw const FormatException('Null ListenerReviewOutcome.applicationId');
      }
      if (!json.containsKey(r'decisionId')) {
        throw const FormatException('Missing ListenerReviewOutcome.decisionId');
      }
      if (json[r'decisionId'] == null) {
        throw const FormatException('Null ListenerReviewOutcome.decisionId');
      }
      if (!json.containsKey(r'outcome')) {
        throw const FormatException('Missing ListenerReviewOutcome.outcome');
      }
      if (json[r'outcome'] == null) {
        throw const FormatException('Null ListenerReviewOutcome.outcome');
      }
      if (!json.containsKey(r'reasonCode')) {
        throw const FormatException('Missing ListenerReviewOutcome.reasonCode');
      }
      if (json[r'reasonCode'] == null) {
        throw const FormatException('Null ListenerReviewOutcome.reasonCode');
      }
      if (!json.containsKey(r'message')) {
        throw const FormatException('Missing ListenerReviewOutcome.message');
      }
      if (json[r'message'] == null) {
        throw const FormatException('Null ListenerReviewOutcome.message');
      }
      if (!json.containsKey(r'missingChecks')) {
        throw const FormatException('Missing ListenerReviewOutcome.missingChecks');
      }
      if (json[r'missingChecks'] == null) {
        throw const FormatException('Null ListenerReviewOutcome.missingChecks');
      }
      if (json[r'missingChecks'] != null && json[r'missingChecks'] is! List) {
        throw const FormatException('Invalid ListenerReviewOutcome.missingChecks');
      }
      if (!json.containsKey(r'recordedAt')) {
        throw const FormatException('Missing ListenerReviewOutcome.recordedAt');
      }
      if (json[r'recordedAt'] == null) {
        throw const FormatException('Null ListenerReviewOutcome.recordedAt');
      }
      if (json[r'recordedAt'] != null && (json[r'recordedAt'] is! String || DateTime.tryParse(json[r'recordedAt'] as String) == null)) {
        throw const FormatException('Invalid ListenerReviewOutcome.recordedAt');
      }
      if (!json.containsKey(r'entitlement')) {
        throw const FormatException('Missing ListenerReviewOutcome.entitlement');
      }
      if (json[r'entitlement'] == null) {
        throw const FormatException('Null ListenerReviewOutcome.entitlement');
      }
      if (!json.containsKey(r'notification')) {
        throw const FormatException('Missing ListenerReviewOutcome.notification');
      }

      return ListenerReviewOutcome(
        applicationId: mapValueOfType<String>(json, r'applicationId')!,
        decisionId: mapValueOfType<String>(json, r'decisionId')!,
        outcome: ListenerReviewOutcomeOutcomeEnum.fromJson(json[r'outcome'])!,
        reasonCode: mapValueOfType<String>(json, r'reasonCode')!,
        message: ReviewLocalizedText.fromJson(json[r'message'])!,
        missingChecks: ReviewMissingCheck.listFromJson(json[r'missingChecks']),
        recordedAt: mapDateTime(json, r'recordedAt', r'')!,
        entitlement: ListenerReviewOutcomeEntitlementEnum.fromJson(json[r'entitlement'])!,
        notification: ListenerReviewNotice.fromJson(json[r'notification']),
      );
    }
    return null;
  }

  static List<ListenerReviewOutcome> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerReviewOutcome>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerReviewOutcome.fromJson(row);
        if (value == null) throw const FormatException('Invalid ListenerReviewOutcome list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListenerReviewOutcome> mapFromJson(dynamic json) {
    final map = <String, ListenerReviewOutcome>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListenerReviewOutcome.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListenerReviewOutcome-objects as value to a dart map
  static Map<String, List<ListenerReviewOutcome>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListenerReviewOutcome>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListenerReviewOutcome.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'applicationId',
    'decisionId',
    'outcome',
    'reasonCode',
    'message',
    'missingChecks',
    'recordedAt',
    'entitlement',
    'notification',
  };
}


enum ListenerReviewOutcomeOutcomeEnum {
  approved._(r'approved'),
  rejected._(r'rejected'),
  needsInformation._(r'needs_information'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerReviewOutcomeOutcomeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerReviewOutcomeOutcomeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerReviewOutcomeOutcomeEnum? fromJson(dynamic value) => ListenerReviewOutcomeOutcomeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerReviewOutcomeOutcomeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerReviewOutcomeOutcomeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerReviewOutcomeOutcomeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerReviewOutcomeOutcomeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerReviewOutcomeOutcomeEnum] to String,
/// and [decode] dynamic data back to [ListenerReviewOutcomeOutcomeEnum].
class ListenerReviewOutcomeOutcomeEnumTypeTransformer {
  factory ListenerReviewOutcomeOutcomeEnumTypeTransformer() => _instance ??= const ListenerReviewOutcomeOutcomeEnumTypeTransformer._();

  const ListenerReviewOutcomeOutcomeEnumTypeTransformer._();

  String encode(ListenerReviewOutcomeOutcomeEnum data) => data._value;

  /// Returns the instance of [ListenerReviewOutcomeOutcomeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerReviewOutcomeOutcomeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerReviewOutcomeOutcomeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'approved': return ListenerReviewOutcomeOutcomeEnum.approved;
        case r'rejected': return ListenerReviewOutcomeOutcomeEnum.rejected;
        case r'needs_information': return ListenerReviewOutcomeOutcomeEnum.needsInformation;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerReviewOutcomeOutcomeEnumTypeTransformer? _instance;
}



enum ListenerReviewOutcomeEntitlementEnum {
  notApplicable._(r'not_applicable'),
  pending._(r'pending'),
  active._(r'active'),
  withheld._(r'withheld'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerReviewOutcomeEntitlementEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerReviewOutcomeEntitlementEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerReviewOutcomeEntitlementEnum? fromJson(dynamic value) => ListenerReviewOutcomeEntitlementEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerReviewOutcomeEntitlementEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerReviewOutcomeEntitlementEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerReviewOutcomeEntitlementEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerReviewOutcomeEntitlementEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerReviewOutcomeEntitlementEnum] to String,
/// and [decode] dynamic data back to [ListenerReviewOutcomeEntitlementEnum].
class ListenerReviewOutcomeEntitlementEnumTypeTransformer {
  factory ListenerReviewOutcomeEntitlementEnumTypeTransformer() => _instance ??= const ListenerReviewOutcomeEntitlementEnumTypeTransformer._();

  const ListenerReviewOutcomeEntitlementEnumTypeTransformer._();

  String encode(ListenerReviewOutcomeEntitlementEnum data) => data._value;

  /// Returns the instance of [ListenerReviewOutcomeEntitlementEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerReviewOutcomeEntitlementEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerReviewOutcomeEntitlementEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'not_applicable': return ListenerReviewOutcomeEntitlementEnum.notApplicable;
        case r'pending': return ListenerReviewOutcomeEntitlementEnum.pending;
        case r'active': return ListenerReviewOutcomeEntitlementEnum.active;
        case r'withheld': return ListenerReviewOutcomeEntitlementEnum.withheld;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerReviewOutcomeEntitlementEnumTypeTransformer? _instance;
}


