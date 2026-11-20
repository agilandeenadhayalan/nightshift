//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class OtpChallenge {
  /// Returns a new [OtpChallenge] instance.
  OtpChallenge({
    required this.challengeId,
    required this.state,
    required this.expiresAt,
    required this.retryAt,
  });

  String challengeId;

  OtpChallengeStateEnum state;

  DateTime expiresAt;

  DateTime retryAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is OtpChallenge &&
    other.challengeId == challengeId &&
    other.state == state &&
    other.expiresAt == expiresAt &&
    other.retryAt == retryAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (challengeId.hashCode) +
    (state.hashCode) +
    (expiresAt.hashCode) +
    (retryAt.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'OtpChallenge[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'challengeId'] = this.challengeId;
      json[r'state'] = this.state;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'retryAt'] = this.retryAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [OtpChallenge] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static OtpChallenge? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid OtpChallenge object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'challengeId')) {
        throw const FormatException('Missing OtpChallenge.challengeId');
      }
      if (json[r'challengeId'] == null) {
        throw const FormatException('Null OtpChallenge.challengeId');
      }
      if (!json.containsKey(r'state')) {
        throw const FormatException('Missing OtpChallenge.state');
      }
      if (json[r'state'] == null) {
        throw const FormatException('Null OtpChallenge.state');
      }
      if (!json.containsKey(r'expiresAt')) {
        throw const FormatException('Missing OtpChallenge.expiresAt');
      }
      if (json[r'expiresAt'] == null) {
        throw const FormatException('Null OtpChallenge.expiresAt');
      }
      if (json[r'expiresAt'] != null && (json[r'expiresAt'] is! String || DateTime.tryParse(json[r'expiresAt'] as String) == null)) {
        throw const FormatException('Invalid OtpChallenge.expiresAt');
      }
      if (!json.containsKey(r'retryAt')) {
        throw const FormatException('Missing OtpChallenge.retryAt');
      }
      if (json[r'retryAt'] == null) {
        throw const FormatException('Null OtpChallenge.retryAt');
      }
      if (json[r'retryAt'] != null && (json[r'retryAt'] is! String || DateTime.tryParse(json[r'retryAt'] as String) == null)) {
        throw const FormatException('Invalid OtpChallenge.retryAt');
      }

      return OtpChallenge(
        challengeId: mapValueOfType<String>(json, r'challengeId')!,
        state: OtpChallengeStateEnum.fromJson(json[r'state'])!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        retryAt: mapDateTime(json, r'retryAt', r'')!,
      );
    }
    return null;
  }

  static List<OtpChallenge> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OtpChallenge>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OtpChallenge.fromJson(row);
        if (value == null) throw const FormatException('Invalid OtpChallenge list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, OtpChallenge> mapFromJson(dynamic json) {
    final map = <String, OtpChallenge>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = OtpChallenge.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of OtpChallenge-objects as value to a dart map
  static Map<String, List<OtpChallenge>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<OtpChallenge>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = OtpChallenge.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'challengeId',
    'state',
    'expiresAt',
    'retryAt',
  };
}


enum OtpChallengeStateEnum {
  sending._(r'sending'),
  sent._(r'sent'),
  verifying._(r'verifying'),
  consumed._(r'consumed'),
  expired._(r'expired'),
  locked._(r'locked'),
  sendUnknown._(r'send_unknown'),
  verifyUnknown._(r'verify_unknown'),
  superseded._(r'superseded'),
  ;

  /// Instantiate a new enum with the provided value.
  const OtpChallengeStateEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [OtpChallengeStateEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static OtpChallengeStateEnum? fromJson(dynamic value) => OtpChallengeStateEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [OtpChallengeStateEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<OtpChallengeStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <OtpChallengeStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = OtpChallengeStateEnum.fromJson(row);
        if (value == null) throw const FormatException('Invalid enum list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [OtpChallengeStateEnum] to String,
/// and [decode] dynamic data back to [OtpChallengeStateEnum].
class OtpChallengeStateEnumTypeTransformer {
  factory OtpChallengeStateEnumTypeTransformer() => _instance ??= const OtpChallengeStateEnumTypeTransformer._();

  const OtpChallengeStateEnumTypeTransformer._();

  String encode(OtpChallengeStateEnum data) => data._value;

  /// Returns the instance of [OtpChallengeStateEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  OtpChallengeStateEnum? decode(dynamic data, {bool allowNull = false}) {
    if (data is OtpChallengeStateEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'sending': return OtpChallengeStateEnum.sending;
        case r'sent': return OtpChallengeStateEnum.sent;
        case r'verifying': return OtpChallengeStateEnum.verifying;
        case r'consumed': return OtpChallengeStateEnum.consumed;
        case r'expired': return OtpChallengeStateEnum.expired;
        case r'locked': return OtpChallengeStateEnum.locked;
        case r'send_unknown': return OtpChallengeStateEnum.sendUnknown;
        case r'verify_unknown': return OtpChallengeStateEnum.verifyUnknown;
        case r'superseded': return OtpChallengeStateEnum.superseded;
        default:
          if (!allowNull) {
            throw const FormatException('Unknown enum value');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static OtpChallengeStateEnumTypeTransformer? _instance;
}


