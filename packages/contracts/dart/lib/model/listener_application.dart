//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class ListenerApplication {
  /// Returns a new [ListenerApplication] instance.
  ListenerApplication({
    required this.id,
    required this.state,
    required this.bio,
    this.topics = const [],
    this.languages = const [],
    required this.voiceSampleConsent,
    required this.consentVersion,
    required this.voiceSampleUploadId,
    required this.submittedAt,
    required this.decidedAt,
    required this.updatedAt,
  });

  String id;

  ListenerApplicationStateEnum state;

  String bio;

  List<ListenerApplicationTopicsEnum> topics;

  List<ListenerApplicationLanguagesEnum> languages;

  bool voiceSampleConsent;

  String? consentVersion;

  String? voiceSampleUploadId;

  DateTime? submittedAt;

  DateTime? decidedAt;

  DateTime updatedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ListenerApplication &&
    other.id == id &&
    other.state == state &&
    other.bio == bio &&
    _deepEquality.equals(other.topics, topics) &&
    _deepEquality.equals(other.languages, languages) &&
    other.voiceSampleConsent == voiceSampleConsent &&
    other.consentVersion == consentVersion &&
    other.voiceSampleUploadId == voiceSampleUploadId &&
    other.submittedAt == submittedAt &&
    other.decidedAt == decidedAt &&
    other.updatedAt == updatedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (state.hashCode) +
    (bio.hashCode) +
    (topics.hashCode) +
    (languages.hashCode) +
    (voiceSampleConsent.hashCode) +
    (consentVersion == null ? 0 : consentVersion!.hashCode) +
    (voiceSampleUploadId == null ? 0 : voiceSampleUploadId!.hashCode) +
    (submittedAt == null ? 0 : submittedAt!.hashCode) +
    (decidedAt == null ? 0 : decidedAt!.hashCode) +
    (updatedAt.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'ListenerApplication[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'state'] = this.state;
      json[r'bio'] = this.bio;
      json[r'topics'] = this.topics;
      json[r'languages'] = this.languages;
      json[r'voiceSampleConsent'] = this.voiceSampleConsent;
    if (this.consentVersion != null) {
      json[r'consentVersion'] = this.consentVersion;
    } else {
      json[r'consentVersion'] = null;
    }
    if (this.voiceSampleUploadId != null) {
      json[r'voiceSampleUploadId'] = this.voiceSampleUploadId;
    } else {
      json[r'voiceSampleUploadId'] = null;
    }
    if (this.submittedAt != null) {
      json[r'submittedAt'] = this.submittedAt!.toUtc().toIso8601String();
    } else {
      json[r'submittedAt'] = null;
    }
    if (this.decidedAt != null) {
      json[r'decidedAt'] = this.decidedAt!.toUtc().toIso8601String();
    } else {
      json[r'decidedAt'] = null;
    }
      json[r'updatedAt'] = this.updatedAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [ListenerApplication] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ListenerApplication? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid ListenerApplication object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'id')) {
        throw const FormatException('Missing ListenerApplication.id');
      }
      if (json[r'id'] == null) {
        throw const FormatException('Null ListenerApplication.id');
      }
      if (!json.containsKey(r'state')) {
        throw const FormatException('Missing ListenerApplication.state');
      }
      if (json[r'state'] == null) {
        throw const FormatException('Null ListenerApplication.state');
      }
      if (!json.containsKey(r'bio')) {
        throw const FormatException('Missing ListenerApplication.bio');
      }
      if (json[r'bio'] == null) {
        throw const FormatException('Null ListenerApplication.bio');
      }
      if (!json.containsKey(r'topics')) {
        throw const FormatException('Missing ListenerApplication.topics');
      }
      if (json[r'topics'] == null) {
        throw const FormatException('Null ListenerApplication.topics');
      }
      if (json[r'topics'] != null && json[r'topics'] is! List) {
        throw const FormatException('Invalid ListenerApplication.topics');
      }
      if (!json.containsKey(r'languages')) {
        throw const FormatException('Missing ListenerApplication.languages');
      }
      if (json[r'languages'] == null) {
        throw const FormatException('Null ListenerApplication.languages');
      }
      if (json[r'languages'] != null && json[r'languages'] is! List) {
        throw const FormatException('Invalid ListenerApplication.languages');
      }
      if (!json.containsKey(r'voiceSampleConsent')) {
        throw const FormatException('Missing ListenerApplication.voiceSampleConsent');
      }
      if (json[r'voiceSampleConsent'] == null) {
        throw const FormatException('Null ListenerApplication.voiceSampleConsent');
      }
      if (json[r'voiceSampleConsent'] != null && json[r'voiceSampleConsent'] is! bool) {
        throw const FormatException('Invalid ListenerApplication.voiceSampleConsent boolean');
      }
      if (!json.containsKey(r'consentVersion')) {
        throw const FormatException('Missing ListenerApplication.consentVersion');
      }
      if (!json.containsKey(r'voiceSampleUploadId')) {
        throw const FormatException('Missing ListenerApplication.voiceSampleUploadId');
      }
      if (!json.containsKey(r'submittedAt')) {
        throw const FormatException('Missing ListenerApplication.submittedAt');
      }
      if (json[r'submittedAt'] != null && (json[r'submittedAt'] is! String || DateTime.tryParse(json[r'submittedAt'] as String) == null)) {
        throw const FormatException('Invalid ListenerApplication.submittedAt');
      }
      if (!json.containsKey(r'decidedAt')) {
        throw const FormatException('Missing ListenerApplication.decidedAt');
      }
      if (json[r'decidedAt'] != null && (json[r'decidedAt'] is! String || DateTime.tryParse(json[r'decidedAt'] as String) == null)) {
        throw const FormatException('Invalid ListenerApplication.decidedAt');
      }
      if (!json.containsKey(r'updatedAt')) {
        throw const FormatException('Missing ListenerApplication.updatedAt');
      }
      if (json[r'updatedAt'] == null) {
        throw const FormatException('Null ListenerApplication.updatedAt');
      }
      if (json[r'updatedAt'] != null && (json[r'updatedAt'] is! String || DateTime.tryParse(json[r'updatedAt'] as String) == null)) {
        throw const FormatException('Invalid ListenerApplication.updatedAt');
      }

      return ListenerApplication(
        id: mapValueOfType<String>(json, r'id')!,
        state: ListenerApplicationStateEnum.fromJson(json[r'state'])!,
        bio: mapValueOfType<String>(json, r'bio')!,
        topics: ListenerApplicationTopicsEnum.listFromJson(json[r'topics']),
        languages: ListenerApplicationLanguagesEnum.listFromJson(json[r'languages']),
        voiceSampleConsent: mapValueOfType<bool>(json, r'voiceSampleConsent')!,
        consentVersion: mapValueOfType<String>(json, r'consentVersion'),
        voiceSampleUploadId: mapValueOfType<String>(json, r'voiceSampleUploadId'),
        submittedAt: mapDateTime(json, r'submittedAt', r''),
        decidedAt: mapDateTime(json, r'decidedAt', r''),
        updatedAt: mapDateTime(json, r'updatedAt', r'')!,
      );
    }
    return null;
  }

  static List<ListenerApplication> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerApplication>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerApplication.fromJson(row);
        if (value == null) throw const FormatException('Invalid ListenerApplication list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ListenerApplication> mapFromJson(dynamic json) {
    final map = <String, ListenerApplication>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ListenerApplication.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ListenerApplication-objects as value to a dart map
  static Map<String, List<ListenerApplication>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ListenerApplication>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ListenerApplication.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'state',
    'bio',
    'topics',
    'languages',
    'voiceSampleConsent',
    'consentVersion',
    'voiceSampleUploadId',
    'submittedAt',
    'decidedAt',
    'updatedAt',
  };
}


enum ListenerApplicationStateEnum {
  draft._(r'draft'),
  submitted._(r'submitted'),
  needsInformation._(r'needs_information'),
  approved._(r'approved'),
  rejected._(r'rejected'),
  withdrawn._(r'withdrawn'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerApplicationStateEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerApplicationStateEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerApplicationStateEnum? fromJson(dynamic value) => ListenerApplicationStateEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerApplicationStateEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerApplicationStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerApplicationStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerApplicationStateEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerApplicationStateEnum] to String,
/// and [decode] dynamic data back to [ListenerApplicationStateEnum].
class ListenerApplicationStateEnumTypeTransformer {
  factory ListenerApplicationStateEnumTypeTransformer() => _instance ??= const ListenerApplicationStateEnumTypeTransformer._();

  const ListenerApplicationStateEnumTypeTransformer._();

  String encode(ListenerApplicationStateEnum data) => data._value;

  /// Returns the instance of [ListenerApplicationStateEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerApplicationStateEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerApplicationStateEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'draft': return ListenerApplicationStateEnum.draft;
        case r'submitted': return ListenerApplicationStateEnum.submitted;
        case r'needs_information': return ListenerApplicationStateEnum.needsInformation;
        case r'approved': return ListenerApplicationStateEnum.approved;
        case r'rejected': return ListenerApplicationStateEnum.rejected;
        case r'withdrawn': return ListenerApplicationStateEnum.withdrawn;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerApplicationStateEnumTypeTransformer? _instance;
}



enum ListenerApplicationTopicsEnum {
  everyday._(r'everyday'),
  work._(r'work'),
  study._(r'study'),
  hobbies._(r'hobbies'),
  languagePractice._(r'language-practice'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerApplicationTopicsEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerApplicationTopicsEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerApplicationTopicsEnum? fromJson(dynamic value) => ListenerApplicationTopicsEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerApplicationTopicsEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerApplicationTopicsEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerApplicationTopicsEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerApplicationTopicsEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerApplicationTopicsEnum] to String,
/// and [decode] dynamic data back to [ListenerApplicationTopicsEnum].
class ListenerApplicationTopicsEnumTypeTransformer {
  factory ListenerApplicationTopicsEnumTypeTransformer() => _instance ??= const ListenerApplicationTopicsEnumTypeTransformer._();

  const ListenerApplicationTopicsEnumTypeTransformer._();

  String encode(ListenerApplicationTopicsEnum data) => data._value;

  /// Returns the instance of [ListenerApplicationTopicsEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerApplicationTopicsEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerApplicationTopicsEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'everyday': return ListenerApplicationTopicsEnum.everyday;
        case r'work': return ListenerApplicationTopicsEnum.work;
        case r'study': return ListenerApplicationTopicsEnum.study;
        case r'hobbies': return ListenerApplicationTopicsEnum.hobbies;
        case r'language-practice': return ListenerApplicationTopicsEnum.languagePractice;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerApplicationTopicsEnumTypeTransformer? _instance;
}



enum ListenerApplicationLanguagesEnum {
  ta._(r'ta'),
  en._(r'en'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerApplicationLanguagesEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerApplicationLanguagesEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerApplicationLanguagesEnum? fromJson(dynamic value) => ListenerApplicationLanguagesEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerApplicationLanguagesEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerApplicationLanguagesEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerApplicationLanguagesEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerApplicationLanguagesEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerApplicationLanguagesEnum] to String,
/// and [decode] dynamic data back to [ListenerApplicationLanguagesEnum].
class ListenerApplicationLanguagesEnumTypeTransformer {
  factory ListenerApplicationLanguagesEnumTypeTransformer() => _instance ??= const ListenerApplicationLanguagesEnumTypeTransformer._();

  const ListenerApplicationLanguagesEnumTypeTransformer._();

  String encode(ListenerApplicationLanguagesEnum data) => data._value;

  /// Returns the instance of [ListenerApplicationLanguagesEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerApplicationLanguagesEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerApplicationLanguagesEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'ta': return ListenerApplicationLanguagesEnum.ta;
        case r'en': return ListenerApplicationLanguagesEnum.en;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerApplicationLanguagesEnumTypeTransformer? _instance;
}


