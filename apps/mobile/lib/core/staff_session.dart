import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'api.dart';

const staffOrigin = String.fromEnvironment('STAFF_CONSOLE_ORIGIN');
final staffHex = RegExp(r'^[a-f0-9]{64}$');
final staffUuid =
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
const staffUnavailable =
    ApiFailure('STAFF_UNAVAILABLE', 'Staff access is unavailable.');
const staffChanged = ApiFailure('STAFF_STALE', 'Staff access has closed.');

Uri? fixedStaffOrigin(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          uri.path.isEmpty &&
          !uri.hasQuery &&
          !uri.hasFragment &&
          uri.origin == value
      ? uri
      : null;
}

DateTime staffTime(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$').hasMatch(value)) {
    throw staffUnavailable;
  }
  final date = DateTime.tryParse(value);
  if (date == null || date.toIso8601String() != value) throw staffUnavailable;
  return date;
}

class StaffConfiguration {
  const StaffConfiguration(this.origin, this.generation, [this.debugTrust]);
  final Uri origin;
  final int generation;
  final Uint8List? debugTrust;
}

abstract interface class StaffCookies {
  Future<StaffConfiguration> configuration();
  Future<int> install(String token, DateTime expiresAt,
      {required bool Function() isCurrent});
  Future<void> harden(int webViewId, int generation);
  Future<void> clear();
}

/// Cookie strings/URLs are never accepted by the native bridge. The native
/// coordinator retains serialization even when a caller times out.
class NativeStaffCookies implements StaffCookies {
  NativeStaffCookies({this.origin = staffOrigin, MethodChannel? channel})
      : channel = channel ?? const MethodChannel('nightshift/staff_session');
  final String origin;
  final MethodChannel channel;
  Future<StaffConfiguration>? _configuration;
  int _generation = 0, _revision = 0;

  @override
  Future<StaffConfiguration> configuration() => _configuration ??= _configure();
  Future<StaffConfiguration> _configure() async {
    final expected = fixedStaffOrigin(origin);
    if (expected == null) throw staffUnavailable;
    final result = await channel
        .invokeMapMethod<String, Object?>('configuration')
        .timeout(const Duration(seconds: 8));
    if (result == null ||
        result['origin'] != origin ||
        result['generation'] is! int ||
        (result['generation'] as int) < 0) {
      throw staffUnavailable;
    }
    _generation = result['generation'] as int;
    final trust = result['debugTrustBytes'];
    if (trust != null &&
        (!kDebugMode || trust is! Uint8List || trust.length > 16384)) {
      throw staffUnavailable;
    }
    return StaffConfiguration(expected, _generation, trust as Uint8List?);
  }

  @override
  Future<int> install(String token, DateTime expiresAt,
      {required bool Function() isCurrent}) async {
    final revision = ++_revision;
    await configuration();
    if (revision != _revision || !isCurrent()) throw staffChanged;
    final remaining = expiresAt.difference(DateTime.now());
    if (!staffHex.hasMatch(token) ||
        remaining <= Duration.zero ||
        remaining > const Duration(minutes: 30)) {
      throw staffUnavailable;
    }
    final generation = ++_generation;
    await channel.invokeMethod<void>('install', {
      'token': token,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'generation': generation,
    }).timeout(const Duration(seconds: 10));
    if (revision != _revision || !isCurrent()) throw staffChanged;
    return generation;
  }

  @override
  Future<void> harden(int webViewId, int generation) async {
    if (generation != _generation) throw staffChanged;
    await channel.invokeMethod<void>('harden', {
      'webViewId': webViewId,
      'generation': generation,
    }).timeout(const Duration(seconds: 8));
    if (generation != _generation) throw staffChanged;
  }

  @override
  Future<void> clear() async {
    final revision = ++_revision;
    await configuration();
    if (revision != _revision) return;
    await channel.invokeMethod<void>('clear',
        {'generation': ++_generation}).timeout(const Duration(seconds: 10));
  }
}
