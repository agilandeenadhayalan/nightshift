import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/audio.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/media_diagnostics.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/media_diagnostics.dart';
import 'discovery_state_test.dart' show FakeEvents;
import 'fakes.dart';

const diagnosticCallId = '00000000-0000-4000-8000-000000000032';

class DiagnosticUiAudio extends FakeAudio implements CallAudioDiagnostics {
  MediaDiagnosticSink? sink;
  @override
  Future<void> joinWithDiagnostics(
      RtcCredentials credentials, Future<RtcCredentials> Function() renew,
      {required bool video, required MediaDiagnosticSink sink}) async {
    this.sink = sink;
    joinCount++;
    sink.milestone(DiagnosticMilestone.joinRequested);
  }
}

class DiagnosticUiFixture {
  DiagnosticUiFixture(this.state, this.api, this.audio, this.store);
  final AppController state;
  final FakeApi api;
  final DiagnosticUiAudio audio;
  final MemoryStore store;
}

class DiagnosticStateOwner extends StatefulWidget {
  const DiagnosticStateOwner(
      {super.key, required this.state, required this.child});
  final AppController state;
  final Widget child;
  @override
  State<DiagnosticStateOwner> createState() => _DiagnosticStateOwnerState();
}

class _DiagnosticStateOwnerState extends State<DiagnosticStateOwner> {
  @override
  Widget build(BuildContext context) => widget.child;
  @override
  void dispose() {
    widget.state.dispose();
    super.dispose();
  }
}

Future<DiagnosticUiFixture> mountDiagnostics(WidgetTester tester,
    {String locale = 'en',
    double scale = 1,
    bool realApp = false,
    Duration Function()? now,
    Future<void> Function(String)? copy}) async {
  final api = FakeApi()
    ..call = {...callJson(state: 'connecting'), 'id': diagnosticCallId};
  api.interceptor = (method, path, body) async {
    if (path.endsWith('/end')) {
      final ended = {...api.call!, 'state': 'ended', 'reason': 'ended'};
      api.historyItems = [ended];
      api.call = null;
      return ended;
    }
    return null;
  };
  final audio = DiagnosticUiAudio();
  final store = MemoryStore()
    ..values.addAll({'token': 'saved', 'locale': locale});
  final state = AppController(
      api: api,
      store: store,
      audio: audio,
      directoryEvents: FakeEvents(),
      diagnosticsNow: now,
      startTimers: false);
  await state.initialize();
  if (realApp) {
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => state)],
        child: const NightShiftApp()));
  } else {
    await tester.pumpWidget(DiagnosticStateOwner(
        state: state,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(body: Builder(builder: (context) {
              return TextButton(
                  onPressed: () => showMediaDiagnostics(
                      context, state, diagnosticCallId,
                      copy: copy),
                  child: const Text('Open details'));
            })))));
  }
  await tester.pumpAndSettle();
  expect(state.mediaDiagnosticsFor(diagnosticCallId), isNotNull);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
  return DiagnosticUiFixture(state, api, audio, store);
}

Future<void> openDetails(WidgetTester tester) async {
  await tester.tap(find.text('Open details'));
  await tester.pumpAndSettle();
}

Future<void> revealDetail(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'actual call and history screens open only the retained call receipt',
      (tester) async {
    final fixture = await mountDiagnostics(tester, realApp: true);
    final details =
        find.byKey(const ValueKey('connection-details-$diagnosticCallId'));
    await tester.scrollUntilVisible(details, 200,
        scrollable: find.byType(Scrollable).first, maxScrolls: 30);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(details), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(details.hitTestable(), findsOneWidget);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.byType(MediaDiagnosticsDialog), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    final end = find.text('End call');
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    expect(
        fixture.api.requests
            .where((r) => r['path'] == '/calls/$diagnosticCallId/end'),
        hasLength(1));
    expect(fixture.state.activeCall, isNull);
    fixture.api.historyItems.add({
      ...callJson(state: 'ended'),
      'id': '00000000-0000-4000-8000-000000000034'
    });
    await tester.tap(find.text('Recents'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(details, 160,
        scrollable: find.byType(Scrollable).first, maxScrolls: 30);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(details), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(details.hitTestable(), findsOneWidget);
    expect(find.byType(MediaDiagnosticsButton), findsWidgets);
    expect(
        find.byKey(const ValueKey(
            'connection-details-00000000-0000-4000-8000-000000000034')),
        findsNothing);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.byType(MediaDiagnosticsDialog), findsOneWidget);
    expect(find.textContaining('Server call end observed:'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Report or block'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'viewing distinguishes accepted from SDK joined and has no sharing effects',
      (tester) async {
    final fixture = await mountDiagnostics(tester);
    final requests = fixture.api.requests.length;
    final stored = Map<String, String>.from(fixture.store.values);
    var clipboardCalls = 0;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardCalls++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await openDetails(tester);
    expect(find.textContaining('Server acceptance observed:'), findsOneWidget);
    expect(find.textContaining('SDK channel joined:'), findsNothing);
    expect(find.text('Incoming audio frame loss (%): Unavailable'),
        findsOneWidget);
    expect(find.textContaining('do not determine charges'), findsOneWidget);
    expect(clipboardCalls, 0);
    expect(fixture.api.requests.length, requests);
    expect(fixture.store.values, stored);
  });

  testWidgets(
      'copy includes only an explicit user symptom separately from numeric observations',
      (tester) async {
    String? copied;
    final fixture =
        await mountDiagnostics(tester, copy: (value) async => copied = value);
    fixture.audio.sink!.metric(DiagnosticMetric.remoteFrameLossPercent, 0);
    fixture.audio.sink!.metric(DiagnosticMetric.jitterBufferDelayMs, 48);
    await openDetails(tester);
    expect(find.textContaining('Incoming audio frame loss (%): latest 0'),
        findsOneWidget);
    final selected = find.text('I could not hear the other person');
    await revealDetail(tester, selected);
    await tester.tap(selected);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('copy-connection-details')));
    await tester.pumpAndSettle();
    final data = jsonDecode(copied!) as Map<String, dynamic>;
    expect(data['userReportedSymptom'], 'couldNotHearOther');
    expect(copied, contains(diagnosticCallId));
    for (final forbidden in [
      'rtc-test-token',
      'customer-id',
      'listener-id',
      'Test Customer',
      'Test Listener',
      'localhost',
      'channel'
    ]) {
      expect(copied, isNot(contains(forbidden)));
    }
    expect(fixture.api.requests.any((request) => request['path'] == '/reports'),
        isFalse);
    expect(find.textContaining('Nothing was sent to support'), findsOneWidget);
  });

  testWidgets('copy defaults to no symptom and does not infer one from loss',
      (tester) async {
    String? copied;
    final fixture =
        await mountDiagnostics(tester, copy: (value) async => copied = value);
    fixture.audio.sink!.metric(DiagnosticMetric.remoteFrameLossPercent, 100);
    await openDetails(tester);
    await tester.tap(find.byKey(const ValueKey('copy-connection-details')));
    await tester.pumpAndSettle();
    expect(
        (jsonDecode(copied!) as Map<String, dynamic>)
            .containsKey('userReportedSymptom'),
        isFalse);
  });

  for (final locale in ['en', 'ta']) {
    testWidgets(
        '$locale connection details remain readable with Copy and Close at 2x text',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var copies = 0;
      await mountDiagnostics(tester,
          locale: locale, scale: 2, copy: (_) async => copies++);
      await openDetails(tester);
      expect(tester.takeException(), isNull);
      final copy = find.byKey(const ValueKey('copy-connection-details'));
      expect(tester.widget<TextButton>(copy).onPressed, isNotNull);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copies, 1);
      final close = find.text(locale == 'en' ? 'Close' : 'மூடு');
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final fail in [false, true]) {
    testWidgets(
        'logout hides a mounted receipt and fences ${fail ? 'failed' : 'successful'} copy completion',
        (tester) async {
      final gate = Completer<void>();
      String? dispatched;
      final fixture = await mountDiagnostics(tester, copy: (value) {
        dispatched = value;
        return gate.future;
      });
      final reference = fixture.state.mediaDiagnostics!.receiptId;
      await openDetails(tester);
      await tester.tap(find.byKey(const ValueKey('copy-connection-details')));
      await tester.pump();
      expect(dispatched, contains(reference));
      await fixture.state.logout();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining(reference), findsNothing);
      expect(find.textContaining(diagnosticCallId), findsNothing);
      expect(
          find.byKey(const ValueKey('copy-connection-details')), findsNothing);
      expect(find.text('These local details are no longer available.'),
          findsOneWidget);
      if (fail) {
        gate.completeError(StateError('PRIVATE_ERROR_SENTINEL'));
      } else {
        gate.complete();
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('copied'), findsNothing);
      expect(find.textContaining('Could not copy'), findsNothing);
      expect(find.textContaining('PRIVATE_ERROR_SENTINEL'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'expiry removes an open receipt and repeated snapshots do not revive it',
      (tester) async {
    var elapsed = Duration.zero;
    final fixture = await mountDiagnostics(tester, now: () => elapsed);
    await openDetails(tester);
    elapsed = const Duration(minutes: 15);
    await tester.pump(const Duration(minutes: 15));
    await tester.pumpAndSettle();
    expect(find.text('These local details are no longer available.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('copy-connection-details')), findsNothing);
    await fixture.state.refresh();
    await tester.pumpAndSettle();
    expect(fixture.state.mediaDiagnostics, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'origin changes hide the old receipt even while the dialog remains mounted',
      (tester) async {
    final fixture = await mountDiagnostics(tester);
    final reference = fixture.state.mediaDiagnostics!.receiptId;
    await openDetails(tester);
    fixture.api.baseUrl = 'https://different.invalid';
    fixture.state.clearError();
    await tester.pumpAndSettle();
    expect(find.textContaining(reference), findsNothing);
    expect(find.text('These local details are no longer available.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a new call replaces the receipt without changing an open view to another call',
      (tester) async {
    final fixture = await mountDiagnostics(tester);
    await openDetails(tester);
    fixture.api.call = {
      ...callJson(state: 'connecting'),
      'id': '00000000-0000-4000-8000-000000000033'
    };
    await fixture.state.refresh();
    await tester.pumpAndSettle();
    expect(fixture.state.mediaDiagnostics!.callId, endsWith('0033'));
    expect(find.textContaining('00000000-0000-4000-8000-000000000033'),
        findsNothing);
    expect(find.text('These local details are no longer available.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'copy failure reveals no raw platform error and remains retryable',
      (tester) async {
    await mountDiagnostics(tester,
        copy: (_) async => throw StateError('PRIVATE_PLATFORM_SENTINEL'));
    await openDetails(tester);
    await tester.tap(find.byKey(const ValueKey('copy-connection-details')));
    await tester.pumpAndSettle();
    expect(find.text('Could not copy the details. Try again.'), findsOneWidget);
    expect(find.textContaining('PRIVATE_PLATFORM_SENTINEL'), findsNothing);
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('copy-connection-details')))
            .onPressed,
        isNotNull);
  });
}
