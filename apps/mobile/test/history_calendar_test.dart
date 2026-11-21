import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/models.dart';

typedef CalendarCase = ({
  String name,
  String timestamp,
  String now,
  String expected,
});

const calendarCases = <String, List<CalendarCase>>{
  'UTC': [
    (
      name: 'year midnight today',
      timestamp: '2027-01-01T00:00:00Z',
      now: '2027-01-01T00:01:00Z',
      expected: 'today'
    ),
    (
      name: 'previous year yesterday',
      timestamp: '2026-12-31T23:59:00Z',
      now: '2027-01-01T00:01:00Z',
      expected: 'yesterday'
    ),
    (
      name: 'previous year older',
      timestamp: '2026-12-30T23:59:00Z',
      now: '2027-01-01T00:01:00Z',
      expected: 'older'
    ),
    (
      name: 'leap day yesterday',
      timestamp: '2028-02-29T23:59:00Z',
      now: '2028-03-01T00:01:00Z',
      expected: 'yesterday'
    ),
    (
      name: 'before leap day older',
      timestamp: '2028-02-28T23:59:00Z',
      now: '2028-03-01T00:01:00Z',
      expected: 'older'
    ),
  ],
  'Asia/Kolkata': [
    (
      name: 'year midnight today',
      timestamp: '2026-12-31T18:30:00Z',
      now: '2026-12-31T18:31:00Z',
      expected: 'today'
    ),
    (
      name: 'previous year yesterday',
      timestamp: '2026-12-31T18:29:00Z',
      now: '2026-12-31T18:31:00Z',
      expected: 'yesterday'
    ),
    (
      name: 'previous year older',
      timestamp: '2026-12-30T18:29:00Z',
      now: '2026-12-31T18:31:00Z',
      expected: 'older'
    ),
    (
      name: 'leap day yesterday',
      timestamp: '2028-02-29T18:29:00Z',
      now: '2028-02-29T18:31:00Z',
      expected: 'yesterday'
    ),
    (
      name: 'before leap day older',
      timestamp: '2028-02-28T18:29:00Z',
      now: '2028-02-29T18:31:00Z',
      expected: 'older'
    ),
  ],
  'America/New_York': [
    (
      name: 'year midnight today',
      timestamp: '2027-01-01T05:00:00Z',
      now: '2027-01-01T05:01:00Z',
      expected: 'today'
    ),
    (
      name: 'previous year yesterday',
      timestamp: '2027-01-01T04:59:00Z',
      now: '2027-01-01T05:01:00Z',
      expected: 'yesterday'
    ),
    (
      name: 'previous year older',
      timestamp: '2026-12-31T04:59:00Z',
      now: '2027-01-01T05:01:00Z',
      expected: 'older'
    ),
    (
      name: 'leap day yesterday',
      timestamp: '2028-03-01T04:59:00Z',
      now: '2028-03-01T05:01:00Z',
      expected: 'yesterday'
    ),
    (
      name: 'before leap day older',
      timestamp: '2028-02-29T04:59:00Z',
      now: '2028-03-01T05:01:00Z',
      expected: 'older'
    ),
  ],
  'Pacific/Kiritimati': [
    (
      name: 'year midnight today',
      timestamp: '2026-12-31T10:00:00Z',
      now: '2026-12-31T10:01:00Z',
      expected: 'today'
    ),
    (
      name: 'previous year yesterday',
      timestamp: '2026-12-31T09:59:00Z',
      now: '2026-12-31T10:01:00Z',
      expected: 'yesterday'
    ),
    (
      name: 'previous year older',
      timestamp: '2026-12-30T09:59:00Z',
      now: '2026-12-31T10:01:00Z',
      expected: 'older'
    ),
    (
      name: 'leap day yesterday',
      timestamp: '2028-02-29T09:59:00Z',
      now: '2028-02-29T10:01:00Z',
      expected: 'yesterday'
    ),
    (
      name: 'before leap day older',
      timestamp: '2028-02-28T09:59:00Z',
      now: '2028-02-29T10:01:00Z',
      expected: 'older'
    ),
  ],
};

void main() {
  final configuredZone = Platform.environment['NIGHTSHIFT_HISTORY_TEST_TZ'];
  final Object probeSkip = configuredZone == null
      ? 'No NIGHTSHIFT_HISTORY_TEST_TZ configured; Linux zone probes run in CI.'
      : !Platform.isLinux
          ? 'Linux process-scoped TZ probe only; host timezone is unchanged.'
          : false;
  Object skipZone(String zone) => probeSkip != false
      ? probeSkip
      : configuredZone != zone
          ? 'This invocation probes $configuredZone.'
          : false;

  test(
      'local calendar grouping crosses the year without elapsed-day arithmetic',
      () {
    final now = DateTime(2027, 1, 1, 0, 1);
    expect(historyDay(DateTime(2027, 1, 1, 0, 0), now), 'today');
    expect(historyDay(DateTime(2026, 12, 31, 23, 59), now), 'yesterday');
    expect(historyDay(DateTime(2026, 12, 30, 23, 59), now), 'older');
  });

  test('local calendar grouping handles leap and non-leap February', () {
    final leap = DateTime(2028, 3, 1, 0, 1);
    expect(historyDay(DateTime(2028, 3, 1), leap), 'today');
    expect(historyDay(DateTime(2028, 2, 29, 23, 59), leap), 'yesterday');
    expect(historyDay(DateTime(2028, 2, 28, 23, 59), leap), 'older');
    expect(historyDay(DateTime(2027, 2, 28, 23, 59), DateTime(2027, 3, 1)),
        'yesterday');
  });

  test('configured Linux zone is actually active in the Dart process', () {
    expect(calendarCases.keys, contains(configuredZone));
    expect(Platform.environment['TZ'], configuredZone);
    final local = DateTime.parse('2027-01-01T00:00:00Z').toLocal();
    final (offsetMinutes, components) = switch (configuredZone) {
      'UTC' => (0, (2027, 1, 1, 0, 0)),
      'Asia/Kolkata' => (330, (2027, 1, 1, 5, 30)),
      'America/New_York' => (-300, (2026, 12, 31, 19, 0)),
      'Pacific/Kiritimati' => (840, (2027, 1, 1, 14, 0)),
      _ => throw StateError('Unsupported calendar probe zone'),
    };
    expect(local.timeZoneOffset.inMinutes, offsetMinutes);
    expect((local.year, local.month, local.day, local.hour, local.minute),
        components);
  }, skip: probeSkip);

  for (final entry in calendarCases.entries) {
    for (final fixture in entry.value) {
      test('${entry.key}: ${fixture.name}', () {
        expect(
            historyDay(
                DateTime.parse(fixture.timestamp), DateTime.parse(fixture.now)),
            fixture.expected);
      }, skip: skipZone(entry.key));
    }
  }

  test('America/New_York: spring calendar day is 23 elapsed hours', () {
    final yesterday = DateTime.parse('2026-03-08T05:00:00Z');
    final today = DateTime.parse('2026-03-09T04:00:00Z');
    expect(yesterday.toLocal().timeZoneOffset, const Duration(hours: -5));
    expect(today.toLocal().timeZoneOffset, const Duration(hours: -4));
    expect(today.difference(yesterday), const Duration(hours: 23));
    expect(historyDay(yesterday, today), 'yesterday');
  }, skip: skipZone('America/New_York'));

  test('America/New_York: fall calendar day is 25 elapsed hours', () {
    final yesterday = DateTime.parse('2026-11-01T04:00:00Z');
    final today = DateTime.parse('2026-11-02T05:00:00Z');
    expect(yesterday.toLocal().timeZoneOffset, const Duration(hours: -4));
    expect(today.toLocal().timeZoneOffset, const Duration(hours: -5));
    expect(today.difference(yesterday), const Duration(hours: 25));
    expect(historyDay(yesterday, today), 'yesterday');
  }, skip: skipZone('America/New_York'));

  test('America/New_York: both repeated 01:30 instants share a calendar group',
      () {
    final first = DateTime.parse('2026-11-01T05:30:00Z');
    final second = DateTime.parse('2026-11-01T06:30:00Z');
    final sameDay = DateTime.parse('2026-11-01T07:30:00Z');
    final nextDay = DateTime.parse('2026-11-02T05:00:00Z');
    expect((first.toLocal().hour, first.toLocal().minute), (1, 30));
    expect((second.toLocal().hour, second.toLocal().minute), (1, 30));
    expect(first.toLocal().timeZoneOffset, const Duration(hours: -4));
    expect(second.toLocal().timeZoneOffset, const Duration(hours: -5));
    expect(second.difference(first), const Duration(hours: 1));
    expect(historyDay(first, sameDay), 'today');
    expect(historyDay(second, sameDay), 'today');
    expect(historyDay(first, nextDay), 'yesterday');
    expect(historyDay(second, nextDay), 'yesterday');
  }, skip: skipZone('America/New_York'));
}
