//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;

class DeletionReceiptRequest {
  /// Returns a new [DeletionReceiptRequest] instance.
  DeletionReceiptRequest({
    required this.receiptToken,
  });

  String receiptToken;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DeletionReceiptRequest &&
    other.receiptToken == receiptToken;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (receiptToken.hashCode);

  @override
  // Never include tokens, access keys or private fields in diagnostics.
  String toString() => 'DeletionReceiptRequest[redacted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'receiptToken'] = this.receiptToken;
    return json;
  }

  /// Returns a new [DeletionReceiptRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DeletionReceiptRequest? fromJson(dynamic value) {
    if (value != null && value is! Map) {
      throw const FormatException('Invalid DeletionReceiptRequest object');
    }
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Keep contract checks enabled in release builds; never echo payload values.
      if (!json.containsKey(r'receiptToken')) {
        throw const FormatException('Missing DeletionReceiptRequest.receiptToken');
      }
      if (json[r'receiptToken'] == null) {
        throw const FormatException('Null DeletionReceiptRequest.receiptToken');
      }

      return DeletionReceiptRequest(
        receiptToken: mapValueOfType<String>(json, r'receiptToken')!,
      );
    }
    return null;
  }

  static List<DeletionReceiptRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeletionReceiptRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeletionReceiptRequest.fromJson(row);
        if (value == null) throw const FormatException('Invalid DeletionReceiptRequest list item');
        result.add(value);
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DeletionReceiptRequest> mapFromJson(dynamic json) {
    final map = <String, DeletionReceiptRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DeletionReceiptRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DeletionReceiptRequest-objects as value to a dart map
  static Map<String, List<DeletionReceiptRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DeletionReceiptRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DeletionReceiptRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'receiptToken',
  };
}

