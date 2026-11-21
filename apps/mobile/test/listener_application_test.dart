import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/listener_application.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/core/review_sample_picker.dart';
import 'package:nightshift_api/api.dart' as sdk;
import 'fakes.dart';

Json applicationJson(
        {String state = 'draft', String? uploadId, bool consent = true}) =>
    {
      'id': 'application-id',
      'state': state,
      'bio': 'I enjoy everyday conversation.',
      'topics': ['everyday'],
      'languages': ['ta'],
      'voiceSampleConsent': consent,
      'consentVersion': consent ? 'listener-review-v1' : null,
      'voiceSampleUploadId': uploadId,
      'submittedAt': null,
      'decidedAt': null,
      'updatedAt': '2026-11-20T00:00:00Z'
    };
Uint8List validWav({int seconds = 2}) {
  final bytes = Uint8List(44 + 16000 * seconds), data = ByteData(44);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(4, bytes.length - 8, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  data.setUint32(40, bytes.length - 44, Endian.little);
  for (final range in [(4, 8), (16, 36), (40, 44)]) {
    bytes.setRange(range.$1, range.$2,
        data.buffer.asUint8List().sublist(range.$1, range.$2));
  }
  return bytes;
}

class FakePicker extends ReviewSamplePicker {
  Uint8List? bytes;
  Completer<Uint8List?>? pending;
  @override
  Future<Uint8List?> pick() async => pending == null ? bytes : pending!.future;
}

void main() {
  test(
      'lost submit followed by staff information request starts a new key cycle',
      () async {
    final api = FakeApi()..token = 'token';
    var persisted = applicationJson(uploadId: 'upload-id');
    final cached = <String, Json>{};
    api.interceptor = (m, p, b) async {
      if (m == 'GET') return {'application': persisted};
      final key = api.requests.last['key'] as String;
      if (cached.containsKey(key)) return cached[key];
      persisted = {
        ...persisted,
        'state': 'submitted',
        'submittedAt': '2026-11-20T00:00:01Z',
        'updatedAt': '2026-11-20T00:00:01Z'
      };
      cached[key] = {...persisted};
      if (cached.length == 1) throw const ApiFailure('OFFLINE', 'lost');
      return persisted;
    };
    final flow = ListenerApplication(api: api, currentUserId: () => 'a');
    addTearDown(flow.dispose);
    await flow.load();
    await flow.submit();
    expect(flow.uncertain, true);
    persisted = {
      ...persisted,
      'state': 'needs_information',
      'updatedAt': '2026-11-20T00:00:02Z'
    };
    await flow.load();
    await flow.submit();
    final submits = api.requests.where((r) => r['method'] == 'POST').toList();
    expect(submits[0]['key'], isNot(submits[1]['key']));
    expect(persisted['state'], 'submitted');
    expect(cached.length, 2);
  });
  test(
      'unchanged information request after uncertain submit preserves retry key',
      () async {
    final api = FakeApi()..token = 'token';
    var persisted =
        applicationJson(state: 'needs_information', uploadId: 'upload-id');
    var attempts = 0;
    api.interceptor = (m, p, b) async {
      if (m == 'GET') return {'application': persisted};
      if (++attempts == 1) throw const ApiFailure('OFFLINE', 'not delivered');
      return persisted = {...persisted, 'state': 'submitted'};
    };
    final flow = ListenerApplication(api: api, currentUserId: () => 'a');
    addTearDown(flow.dispose);
    await flow.load();
    await flow.submit();
    await flow.load();
    await flow.submit();
    final submits = api.requests.where((r) => r['method'] == 'POST').toList();
    expect(submits[0]['key'], submits[1]['key']);
    expect(persisted['state'], 'submitted');
  });
  test('authoritative consent withdrawal clears a locally selected sample',
      () async {
    final api = FakeApi()..token = 'token';
    var consent = true;
    api.interceptor =
        (m, p, b) async => {'application': applicationJson(consent: consent)};
    final flow = ListenerApplication(
        api: api,
        currentUserId: () => 'a',
        picker: FakePicker()..bytes = validWav());
    addTearDown(flow.dispose);
    await flow.load();
    await flow.chooseSample();
    expect(flow.sample, isNotNull);
    consent = false;
    await flow.load();
    await flow.upload();
    expect(flow.sample, isNull);
    expect(flow.consent, false);
    expect(flow.canSubmit, false);
    expect(api.requests.where((r) => r['method'] != 'GET'), isEmpty);
  });
  test('resubmission after more information uses a new idempotency cycle',
      () async {
    final api = FakeApi()..token = 'token';
    var persisted = applicationJson(uploadId: 'upload-id');
    final cached = <String, Json>{};
    api.interceptor = (m, p, b) async {
      if (m == 'GET') return {'application': persisted};
      if (m == 'PUT') return persisted = {...persisted, ...b!};
      final key = api.requests.last['key'] as String;
      if (cached.containsKey(key)) return cached[key];
      persisted = {...persisted, 'state': 'submitted'};
      return cached[key] = {...persisted};
    };
    final flow = ListenerApplication(api: api, currentUserId: () => 'a');
    addTearDown(flow.dispose);
    await flow.load();
    await flow.submit();
    persisted = {...persisted, 'state': 'needs_information'};
    await flow.load();
    flow.edit(newBio: 'Updated review information');
    await flow.save();
    await flow.submit();
    final submits = api.requests
        .where((r) => r['path'].toString().endsWith('/submit'))
        .toList();
    expect(submits.length, 2);
    expect(submits[0]['key'], isNot(submits[1]['key']));
    expect(persisted['state'], 'submitted');
    expect(persisted['bio'], 'Updated review information');
  });
  test('lost expired upload grant rotates key only after definitive expiry',
      () async {
    final api = FakeApi()..token = 'token';
    var leases = 0;
    api.interceptor = (m, p, b) async {
      if (m == 'GET') return {'application': applicationJson()};
      if (m == 'PUT') return applicationJson(uploadId: 'renewed-upload');
      leases++;
      if (leases == 1) throw const ApiFailure('OFFLINE', 'lost');
      if (leases == 2) {
        throw const ApiFailure('UPLOAD_EXPIRED', 'expired', status: 410);
      }
      return {
        'uploadId': 'renewed-upload',
        'uploadToken': 'private-capability',
        'expiresAt':
            DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
        'maxBytes': 2097152,
        'contentType': 'audio/wav'
      };
    };
    final flow = ListenerApplication(
        api: api,
        currentUserId: () => 'a',
        picker: FakePicker()..bytes = validWav());
    addTearDown(flow.dispose);
    await flow.load();
    await flow.chooseSample();
    await flow.upload();
    await flow.load();
    await flow.upload();
    expect(flow.errorCode, 'UPLOAD_EXPIRED');
    expect(flow.sample, isNotNull);
    await flow.upload();
    final requests = api.requests.where((r) => r['method'] == 'POST').toList();
    expect(requests[0]['key'], requests[1]['key']);
    expect(requests[1]['key'], isNot(requests[2]['key']));
    expect(flow.application!['voiceSampleUploadId'], 'renewed-upload');
  });
  test(
      'late grant response after logout cannot send bytes or restore private state',
      () async {
    final grant = Completer<Json>();
    var puts = 0;
    final api = FakeApi()..token = 'token';
    api.interceptor = (m, p, b) async {
      if (m == 'GET') return {'application': applicationJson()};
      if (m == 'POST') return grant.future;
      puts++;
      return applicationJson(uploadId: 'upload');
    };
    var owner = 'a';
    final flow = ListenerApplication(
        api: api,
        currentUserId: () => owner,
        picker: FakePicker()..bytes = validWav());
    addTearDown(flow.dispose);
    await flow.load();
    await flow.chooseSample();
    final uploading = flow.upload();
    await Future<void>.delayed(Duration.zero);
    owner = 'b';
    flow.clearPrivateView();
    api.token = 'token-b';
    grant.complete({
      'uploadId': 'upload',
      'uploadToken': 'private',
      'expiresAt':
          DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      'maxBytes': 2097152,
      'contentType': 'audio/wav'
    });
    await uploading;
    expect(puts, 0);
    expect(flow.sample, isNull);
    expect(flow.application, isNull);
    expect(flow.bio, isEmpty);
  });
  test('private samples never dispatch over LAN HTTP or a changed origin',
      () async {
    var sends = 0;
    final api = NightShiftApi(client: MockClient((r) async {
      sends++;
      return http.Response('{}', 200);
    }))
      ..baseUrl = 'http://192.168.1.20:3000'
      ..token = 'private';
    addTearDown(api.close);
    await expectLater(
        api.privateRequest('GET', '/me/listener-application',
            origin: api.baseUrl, isCurrent: () => true),
        throwsA(isA<ApiFailure>()));
    api.baseUrl = 'https://changed.example';
    await expectLater(
        api.privateRequest('GET', '/me/listener-application',
            origin: 'https://original.example', isCurrent: () => true),
        throwsA(isA<ApiFailure>()));
    expect(sends, 0);
  });
  test('WAV validation enforces duration, metadata-free PCM and bounded size',
      () {
    expect(ReviewSample.validate(validWav()).seconds, 2);
    expect(ReviewSample.validate(validWav(seconds: 60)).seconds, 60);
    for (final bytes in [
      validWav(seconds: 1),
      validWav(seconds: 61),
      Uint8List(2097153),
      Uint8List(20),
      validWav()..[20] = 3,
      validWav()..[36] = 0
    ]) {
      expect(() => ReviewSample.validate(bytes), throwsA(isA<ApiFailure>()));
    }
  });
  test('cancel selection keeps prior sample; permission errors stay private',
      () async {
    final api = FakeApi()..token = 'token';
    final picker = FakePicker()..bytes = validWav();
    api.interceptor = (m, p, b) async => {'application': applicationJson()};
    final flow = ListenerApplication(
        api: api, currentUserId: () => 'owner', picker: picker);
    addTearDown(flow.dispose);
    await flow.load();
    await flow.chooseSample();
    final prior = flow.sample;
    picker.bytes = null;
    await flow.chooseSample();
    expect(flow.sample, same(prior));
    picker.pending = Completer();
    final choosing = flow.chooseSample();
    picker.pending!.completeError(StateError('private/file/path'));
    await choosing;
    expect(flow.errorCode, 'SAMPLE_SELECTION_FAILED');
    expect(flow.sample.toString(), 'ReviewSample[private]');
  });
  test(
      'account change during picker discards sample and all private draft fields',
      () async {
    final api = FakeApi()..token = 'token';
    final picker = FakePicker()..pending = Completer();
    var owner = 'a';
    api.interceptor = (m, p, b) async => {'application': applicationJson()};
    final flow = ListenerApplication(
        api: api, currentUserId: () => owner, picker: picker);
    addTearDown(flow.dispose);
    await flow.load();
    final choosing = flow.chooseSample();
    owner = 'b';
    flow.clearPrivateView();
    picker.pending!.complete(validWav());
    await choosing;
    expect(flow.sample, isNull);
    expect(flow.bio, isEmpty);
    expect(flow.application, isNull);
  });
  test('lost creation response recovers existing draft without another create',
      () async {
    final api = FakeApi()..token = 'token';
    Json? persisted;
    api.interceptor = (m, p, b) async {
      if (p == '/me/listener-application') return {'application': persisted};
      persisted = applicationJson();
      throw const ApiFailure('OFFLINE', 'lost');
    };
    final flow = ListenerApplication(api: api, currentUserId: () => 'a');
    addTearDown(flow.dispose);
    await flow.load();
    flow.edit(newBio: 'Private bio', newConsent: true, newTopics: {'everyday'});
    await flow.save();
    expect(flow.uncertain, true);
    expect(flow.canEdit, false);
    await flow.save();
    expect(api.requests.where((r) => r['method'] == 'POST').length, 1);
    await flow.load();
    expect(flow.application!['id'], 'application-id');
    expect(flow.uncertain, false);
    expect(flow.canEdit, true);
  });
  test(
      'uncertain create not yet visible retains original body and key for explicit retry',
      () async {
    final api = FakeApi()..token = 'token';
    var creates = 0;
    api.interceptor = (m, p, b) async {
      if (m == 'GET') return {'application': null};
      if (++creates == 1) throw const ApiFailure('OFFLINE', 'lost');
      return applicationJson();
    };
    final flow = ListenerApplication(api: api, currentUserId: () => 'a');
    addTearDown(flow.dispose);
    await flow.load();
    flow.edit(newBio: 'First private bio', newConsent: true);
    await flow.save();
    await flow.load();
    flow.edit(newBio: 'Changed');
    expect(flow.bio, 'First private bio');
    await flow.save();
    final requests = api.requests.where((r) => r['method'] == 'POST').toList();
    expect(requests[0]['key'], requests[1]['key']);
    expect(requests[0]['body'], requests[1]['body']);
  });
  test(
      'lost raw upload response recovers accepted sample and does not replay upload',
      () async {
    final api = FakeApi()..token = 'token';
    final picker = FakePicker()..bytes = validWav();
    var persisted = applicationJson();
    api.interceptor = (m, p, b) async {
      if (m == 'GET') return {'application': persisted};
      if (m == 'POST') {
        expect(b!['sha256'], matches(r'^[a-f0-9]{64}$'));
        expect(
            b.keys, unorderedEquals(['contentType', 'byteLength', 'sha256']));
        return {
          'uploadId': 'upload-id',
          'uploadToken': 'private-capability',
          'expiresAt':
              DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
          'maxBytes': 2097152,
          'contentType': 'audio/wav'
        };
      }
      persisted = applicationJson(uploadId: 'upload-id');
      throw const ApiFailure('OFFLINE', 'lost');
    };
    final flow =
        ListenerApplication(api: api, currentUserId: () => 'a', picker: picker);
    addTearDown(flow.dispose);
    await flow.load();
    await flow.chooseSample();
    await flow.upload();
    expect(flow.uncertain, true);
    await flow.upload();
    expect(api.requests.where((r) => r['method'] == 'PUT').length, 1);
    await flow.load();
    expect(flow.sample, isNull);
    expect(flow.canSubmit, true);
  });
  test('consent withdrawal blocks selected sample and submit before saving',
      () async {
    final api = FakeApi()..token = 'token';
    api.interceptor = (m, p, b) async =>
        {'application': applicationJson(uploadId: 'upload-id')};
    final flow = ListenerApplication(
        api: api,
        currentUserId: () => 'a',
        picker: FakePicker()..bytes = validWav());
    addTearDown(flow.dispose);
    await flow.load();
    expect(flow.canSubmit, true);
    await flow.chooseSample();
    expect(flow.canSubmit, false);
    flow.edit(newConsent: false);
    await flow.submit();
    await flow.upload();
    expect(flow.sample, isNull);
    expect(flow.canSubmit, false);
    expect(api.requests.length, 1);
  });
  test(
      'lost submission response reloads submitted state without duplicate mutation',
      () async {
    final api = FakeApi()..token = 'token';
    var persisted = applicationJson(uploadId: 'upload-id');
    api.interceptor = (m, p, b) async {
      if (m == 'GET') return {'application': persisted};
      persisted = applicationJson(state: 'submitted', uploadId: 'upload-id');
      throw const ApiFailure('OFFLINE', 'lost');
    };
    final flow = ListenerApplication(api: api, currentUserId: () => 'a');
    addTearDown(flow.dispose);
    await flow.load();
    await flow.submit();
    await flow.submit();
    await flow.load();
    expect(flow.application!['state'], 'submitted');
    expect(flow.canSubmit, false);
    expect(api.requests.where((r) => r['method'] == 'POST').length, 1);
  });
  test(
      'terminal decision permits explicit removal of sample without changing approval',
      () async {
    final api = FakeApi()..token = 'token';
    api.interceptor = (m, p, b) async => m == 'GET'
        ? {
            'application':
                applicationJson(state: 'approved', uploadId: 'upload-id')
          }
        : applicationJson(state: 'approved', consent: false);
    final flow = ListenerApplication(api: api, currentUserId: () => 'a');
    addTearDown(flow.dispose);
    await flow.load();
    expect(flow.canWithdraw, true);
    final loadedRequests = api.requests.length;
    await flow.withdraw(confirmed: false);
    expect(api.requests.length, loadedRequests);
    await flow.withdraw(confirmed: true);
    expect(flow.application!['state'], 'approved');
    expect(flow.consent, false);
    expect(flow.canWithdraw, false);
  });
  test(
      'private HTTP dispatch fences logout/new account while refresh is pending',
      () async {
    var sends = 0, owner = 'a';
    final gate = Completer<void>();
    final api = NightShiftApi(client: MockClient((r) async {
      sends++;
      return http.Response('{}', 200);
    }))
      ..baseUrl = 'https://api.example'
      ..token = 'token-a'
      ..prepareSession = () => gate.future;
    addTearDown(api.close);
    final request = api.privateRequest(
        'PUT', '/listener-applications/app/uploads/upload',
        origin: api.baseUrl,
        isCurrent: () => owner == 'a',
        sample: validWav(),
        uploadToken: 'secret');
    owner = 'b';
    api.token = 'token-b';
    gate.complete();
    await expectLater(request, throwsA(isA<ApiFailure>()));
    expect(sends, 0);
  });
  test(
      'raw generated upload sends exact bytes and capability only in header with redirects off',
      () async {
    final bytes = validWav();
    final api = NightShiftApi(client: MockClient((r) async {
      expect(r.url.toString(),
          'https://api.example/v1/listener-applications/app/uploads/upload');
      expect(r.headers['X-Upload-Token'], 'secret-capability');
      expect(r.headers['Content-Type'], 'audio/wav');
      expect(r.headers['Authorization'], 'Bearer renewed');
      expect(r.followRedirects, false);
      expect(r.bodyBytes, bytes);
      expect(r.url.toString(), isNot(contains('secret')));
      return http.Response(
          jsonEncode(applicationJson(uploadId: 'upload')), 200);
    }))
      ..baseUrl = 'https://api.example'
      ..token = 'old';
    api.prepareSession = () async {
      api.token = 'renewed';
    };
    addTearDown(api.close);
    await api.privateRequest('PUT', '/listener-applications/app/uploads/upload',
        origin: api.baseUrl,
        isCurrent: () => true,
        sample: bytes,
        uploadToken: 'secret-capability');
  });
  test(
      'application contract rejects missing/null fields and uncontrolled values',
      () {
    final valid = applicationJson();
    for (final key in valid.keys) {
      expect(() => sdk.ListenerApplication.fromJson({...valid}..remove(key)),
          throwsA(anything));
      if (!['consentVersion', 'voiceSampleUploadId', 'submittedAt', 'decidedAt']
          .contains(key)) {
        expect(() => sdk.ListenerApplication.fromJson({...valid, key: null}),
            throwsA(anything));
      }
    }
    for (final change in [
      {'state': 'mystery'},
      {
        'topics': ['private-topic']
      },
      {
        'languages': ['xx']
      }
    ]) {
      expect(() => sdk.ListenerApplication.fromJson({...valid, ...change}),
          throwsA(anything));
    }
  });
}
