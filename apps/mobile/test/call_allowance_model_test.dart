import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

void main() {
  for (final (connected, charge, remaining) in [
    (0, 0, 60000),
    (40000, 0, 20000),
    (40001, 3600000, 19999),
    (59999, 3600000, 1),
    (60000, 3600000, 0),
    (60001, 3600000, 0),
  ]) {
    test('confirmed $connected ms leaves $remaining ms regardless of charge',
        () {
      final call = CallSession.fromJson({
        ...callJson(state: 'connected'),
        'maxDurationSeconds': 60,
        'connectedMs': connected,
        'chargeMicrocredits': charge,
        'durationLimitReason': 'test_credit_balance'
      });
      expect(call.remainingConnectedMs, remaining);
      expect(call.chargeMicrocredits, charge);
      expect(
          call.durationLimitReason, CallDurationLimitReason.testCreditBalance);
    });
  }

  for (final field in ['maxDurationSeconds', 'connectedMs']) {
    for (final invalid in <Object?>[null, -1, 60.5, '60', 'bad']) {
      test('$field=$invalid is unavailable rather than a coerced allowance',
          () {
        final call = CallSession.fromJson({...callJson(), field: invalid});
        expect(call.remainingConnectedMs, isNull);
      });
    }
    test('missing $field is unavailable', () {
      expect(
          CallSession.fromJson(callJson()..remove(field)).remainingConnectedMs,
          isNull);
    });
  }

  test('zero or overflow-sized cap cannot produce a false zero warning', () {
    for (final cap in [0, 9007199254741]) {
      expect(
          CallSession.fromJson({...callJson(), 'maxDurationSeconds': cap})
              .remainingConnectedMs,
          isNull);
    }
  });

  test('missing legacy reason stays neutral at the development cap', () {
    final call = CallSession.fromJson(callJson());
    expect(call.remainingConnectedMs, 559000);
    expect(call.durationLimitReason, isNull);
  });

  test('explicit unsupported or null reason is not accepted as legacy', () {
    for (final reason in <Object?>['unlimited', 1, null]) {
      expect(
          () => CallSession.fromJson(
              {...callJson(), 'durationLimitReason': reason}),
          throwsFormatException);
    }
  });

  test('valid direct constructors retain their allowance', () {
    final call = CallSession(
        id: 'id',
        customerId: 'customer',
        listenerId: 'listener',
        customerName: 'Customer',
        listenerName: 'Listener',
        state: 'connected',
        version: 1,
        connectedMs: 1234,
        chargeMicrocredits: 0,
        earningPaise: 0,
        createdAt: DateTime.utc(2026),
        maxDurationSeconds: 600);
    expect(call.remainingConnectedMs, 598766);
  });

  test('video remaining uses its allocation, not the free threshold or price',
      () {
    final call = CallSession.fromJson({
      ...callJson(video: true),
      'connectedMs': 40001,
      'maxDurationSeconds': 90,
      'chargeMicrocredits': 7200000,
      'durationLimitReason': 'test_credit_balance'
    });
    expect(call.remainingConnectedMs, 49999);
    expect(call.rate.coinsPerMinute, 120);
    expect(call.chargeMicrocredits, 7200000);
  });
}
