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
    required this.reachability,
    required this.available,
    required this.busy,
    required this.favorite,
    required this.testOnly,
    required this.rate,
    this.avatarCode,
    this.audioAvailable,
    this.videoAvailable,
    this.videoRate,
  });

  String id;

  String displayName;

  List<ListenerLanguagesEnum> languages;

  bool online;

  ListenerReachabilityEnum reachability;

  bool available;

  bool busy;

  bool favorite;

  bool testOnly;

  Rate rate;

  ListenerAvatarCodeEnum? avatarCode;

  /// Effective audio invitation eligibility, including saved preference, reachability and busy state.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? audioAvailable;

  /// Effective video invitation eligibility, including saved preference, foreground reachability, server capability and busy state.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? videoAvailable;

  Rate? videoRate;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Listener &&
    other.id == id &&
    other.displayName == displayName &&
    _deepEquality.equals(other.languages, languages) &&
    other.online == online &&
    other.reachability == reachability &&
    other.available == available &&
    other.busy == busy &&
    other.favorite == favorite &&
    other.testOnly == testOnly &&
    other.rate == rate &&
    other.avatarCode == avatarCode &&
    other.audioAvailable == audioAvailable &&
    other.videoAvailable == videoAvailable &&
    other.videoRate == videoRate;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (displayName.hashCode) +
    (languages.hashCode) +
    (online.hashCode) +
    (reachability.hashCode) +
    (available.hashCode) +
    (busy.hashCode) +
    (favorite.hashCode) +
    (testOnly.hashCode) +
    (rate.hashCode) +
    (avatarCode == null ? 0 : avatarCode!.hashCode) +
    (audioAvailable == null ? 0 : audioAvailable!.hashCode) +
    (videoAvailable == null ? 0 : videoAvailable!.hashCode) +
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
      json[r'reachability'] = this.reachability;
      json[r'available'] = this.available;
      json[r'busy'] = this.busy;
      json[r'favorite'] = this.favorite;
      json[r'testOnly'] = this.testOnly;
      json[r'rate'] = this.rate;
    if (this.avatarCode != null) {
      json[r'avatarCode'] = this.avatarCode;
    }
    if (this.audioAvailable != null) {
      json[r'audioAvailable'] = this.audioAvailable;
    }
    if (this.videoAvailable != null) {
      json[r'videoAvailable'] = this.videoAvailable;
    }
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
      if (!json.containsKey(r'reachability')) {
        throw const FormatException('Missing Listener.reachability');
      }
      if (json[r'reachability'] == null) {
        throw const FormatException('Null Listener.reachability');
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
      if (json[r'audioAvailable'] != null && json[r'audioAvailable'] is! bool) {
        throw const FormatException('Invalid Listener.audioAvailable boolean');
      }
      if (json[r'videoAvailable'] != null && json[r'videoAvailable'] is! bool) {
        throw const FormatException('Invalid Listener.videoAvailable boolean');
      }

      return Listener(
        id: mapValueOfType<String>(json, r'id')!,
        displayName: mapValueOfType<String>(json, r'displayName')!,
        languages: ListenerLanguagesEnum.listFromJson(json[r'languages']),
        online: mapValueOfType<bool>(json, r'online')!,
        reachability: ListenerReachabilityEnum.fromJson(json[r'reachability'])!,
        available: mapValueOfType<bool>(json, r'available')!,
        busy: mapValueOfType<bool>(json, r'busy')!,
        favorite: mapValueOfType<bool>(json, r'favorite')!,
        testOnly: mapValueOfType<bool>(json, r'testOnly')!,
        rate: Rate.fromJson(json[r'rate'])!,
        avatarCode: ListenerAvatarCodeEnum.fromJson(json[r'avatarCode']),
        audioAvailable: mapValueOfType<bool>(json, r'audioAvailable'),
        videoAvailable: mapValueOfType<bool>(json, r'videoAvailable'),
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
    'reachability',
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



enum ListenerReachabilityEnum {
  foreground._(r'foreground'),
  backgroundEligible._(r'background_eligible'),
  offline._(r'offline'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerReachabilityEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerReachabilityEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerReachabilityEnum? fromJson(dynamic value) => ListenerReachabilityEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerReachabilityEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerReachabilityEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerReachabilityEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerReachabilityEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerReachabilityEnum] to String,
/// and [decode] dynamic data back to [ListenerReachabilityEnum].
class ListenerReachabilityEnumTypeTransformer {
  factory ListenerReachabilityEnumTypeTransformer() => _instance ??= const ListenerReachabilityEnumTypeTransformer._();

  const ListenerReachabilityEnumTypeTransformer._();

  String encode(ListenerReachabilityEnum data) => data._value;

  /// Returns the instance of [ListenerReachabilityEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerReachabilityEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerReachabilityEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'foreground': return ListenerReachabilityEnum.foreground;
        case r'background_eligible': return ListenerReachabilityEnum.backgroundEligible;
        case r'offline': return ListenerReachabilityEnum.offline;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerReachabilityEnumTypeTransformer? _instance;
}



enum ListenerAvatarCodeEnum {
  moon._(r'moon'),
  star._(r'star'),
  leaf._(r'leaf'),
  wave._(r'wave'),
  male01._(r'male_01'),
  male02._(r'male_02'),
  male03._(r'male_03'),
  male04._(r'male_04'),
  male05._(r'male_05'),
  male06._(r'male_06'),
  male07._(r'male_07'),
  male08._(r'male_08'),
  male09._(r'male_09'),
  male10._(r'male_10'),
  male11._(r'male_11'),
  male12._(r'male_12'),
  male13._(r'male_13'),
  male14._(r'male_14'),
  male15._(r'male_15'),
  male16._(r'male_16'),
  male17._(r'male_17'),
  male18._(r'male_18'),
  male19._(r'male_19'),
  male20._(r'male_20'),
  male21._(r'male_21'),
  male22._(r'male_22'),
  male23._(r'male_23'),
  male24._(r'male_24'),
  male25._(r'male_25'),
  male26._(r'male_26'),
  male27._(r'male_27'),
  male28._(r'male_28'),
  male29._(r'male_29'),
  male30._(r'male_30'),
  female01._(r'female_01'),
  female02._(r'female_02'),
  female03._(r'female_03'),
  female04._(r'female_04'),
  female05._(r'female_05'),
  female06._(r'female_06'),
  female07._(r'female_07'),
  female08._(r'female_08'),
  female09._(r'female_09'),
  female10._(r'female_10'),
  female11._(r'female_11'),
  female12._(r'female_12'),
  female13._(r'female_13'),
  female14._(r'female_14'),
  female15._(r'female_15'),
  female16._(r'female_16'),
  female17._(r'female_17'),
  female18._(r'female_18'),
  female19._(r'female_19'),
  female20._(r'female_20'),
  female21._(r'female_21'),
  female22._(r'female_22'),
  female23._(r'female_23'),
  female24._(r'female_24'),
  female25._(r'female_25'),
  female26._(r'female_26'),
  female27._(r'female_27'),
  female28._(r'female_28'),
  female29._(r'female_29'),
  female30._(r'female_30'),
  ;

  /// Instantiate a new enum with the provided value.
  const ListenerAvatarCodeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ListenerAvatarCodeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ListenerAvatarCodeEnum? fromJson(dynamic value) => ListenerAvatarCodeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ListenerAvatarCodeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ListenerAvatarCodeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ListenerAvatarCodeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ListenerAvatarCodeEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ListenerAvatarCodeEnum] to String,
/// and [decode] dynamic data back to [ListenerAvatarCodeEnum].
class ListenerAvatarCodeEnumTypeTransformer {
  factory ListenerAvatarCodeEnumTypeTransformer() => _instance ??= const ListenerAvatarCodeEnumTypeTransformer._();

  const ListenerAvatarCodeEnumTypeTransformer._();

  String encode(ListenerAvatarCodeEnum data) => data._value;

  /// Returns the instance of [ListenerAvatarCodeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ListenerAvatarCodeEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is ListenerAvatarCodeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'moon': return ListenerAvatarCodeEnum.moon;
        case r'star': return ListenerAvatarCodeEnum.star;
        case r'leaf': return ListenerAvatarCodeEnum.leaf;
        case r'wave': return ListenerAvatarCodeEnum.wave;
        case r'male_01': return ListenerAvatarCodeEnum.male01;
        case r'male_02': return ListenerAvatarCodeEnum.male02;
        case r'male_03': return ListenerAvatarCodeEnum.male03;
        case r'male_04': return ListenerAvatarCodeEnum.male04;
        case r'male_05': return ListenerAvatarCodeEnum.male05;
        case r'male_06': return ListenerAvatarCodeEnum.male06;
        case r'male_07': return ListenerAvatarCodeEnum.male07;
        case r'male_08': return ListenerAvatarCodeEnum.male08;
        case r'male_09': return ListenerAvatarCodeEnum.male09;
        case r'male_10': return ListenerAvatarCodeEnum.male10;
        case r'male_11': return ListenerAvatarCodeEnum.male11;
        case r'male_12': return ListenerAvatarCodeEnum.male12;
        case r'male_13': return ListenerAvatarCodeEnum.male13;
        case r'male_14': return ListenerAvatarCodeEnum.male14;
        case r'male_15': return ListenerAvatarCodeEnum.male15;
        case r'male_16': return ListenerAvatarCodeEnum.male16;
        case r'male_17': return ListenerAvatarCodeEnum.male17;
        case r'male_18': return ListenerAvatarCodeEnum.male18;
        case r'male_19': return ListenerAvatarCodeEnum.male19;
        case r'male_20': return ListenerAvatarCodeEnum.male20;
        case r'male_21': return ListenerAvatarCodeEnum.male21;
        case r'male_22': return ListenerAvatarCodeEnum.male22;
        case r'male_23': return ListenerAvatarCodeEnum.male23;
        case r'male_24': return ListenerAvatarCodeEnum.male24;
        case r'male_25': return ListenerAvatarCodeEnum.male25;
        case r'male_26': return ListenerAvatarCodeEnum.male26;
        case r'male_27': return ListenerAvatarCodeEnum.male27;
        case r'male_28': return ListenerAvatarCodeEnum.male28;
        case r'male_29': return ListenerAvatarCodeEnum.male29;
        case r'male_30': return ListenerAvatarCodeEnum.male30;
        case r'female_01': return ListenerAvatarCodeEnum.female01;
        case r'female_02': return ListenerAvatarCodeEnum.female02;
        case r'female_03': return ListenerAvatarCodeEnum.female03;
        case r'female_04': return ListenerAvatarCodeEnum.female04;
        case r'female_05': return ListenerAvatarCodeEnum.female05;
        case r'female_06': return ListenerAvatarCodeEnum.female06;
        case r'female_07': return ListenerAvatarCodeEnum.female07;
        case r'female_08': return ListenerAvatarCodeEnum.female08;
        case r'female_09': return ListenerAvatarCodeEnum.female09;
        case r'female_10': return ListenerAvatarCodeEnum.female10;
        case r'female_11': return ListenerAvatarCodeEnum.female11;
        case r'female_12': return ListenerAvatarCodeEnum.female12;
        case r'female_13': return ListenerAvatarCodeEnum.female13;
        case r'female_14': return ListenerAvatarCodeEnum.female14;
        case r'female_15': return ListenerAvatarCodeEnum.female15;
        case r'female_16': return ListenerAvatarCodeEnum.female16;
        case r'female_17': return ListenerAvatarCodeEnum.female17;
        case r'female_18': return ListenerAvatarCodeEnum.female18;
        case r'female_19': return ListenerAvatarCodeEnum.female19;
        case r'female_20': return ListenerAvatarCodeEnum.female20;
        case r'female_21': return ListenerAvatarCodeEnum.female21;
        case r'female_22': return ListenerAvatarCodeEnum.female22;
        case r'female_23': return ListenerAvatarCodeEnum.female23;
        case r'female_24': return ListenerAvatarCodeEnum.female24;
        case r'female_25': return ListenerAvatarCodeEnum.female25;
        case r'female_26': return ListenerAvatarCodeEnum.female26;
        case r'female_27': return ListenerAvatarCodeEnum.female27;
        case r'female_28': return ListenerAvatarCodeEnum.female28;
        case r'female_29': return ListenerAvatarCodeEnum.female29;
        case r'female_30': return ListenerAvatarCodeEnum.female30;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ListenerAvatarCodeEnumTypeTransformer? _instance;
}


