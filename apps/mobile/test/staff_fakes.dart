import 'dart:async';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/core/staff_session.dart';
import 'package:nightshift/core/staff_transport.dart';

const staffOwner = 'c874c564-4701-445c-a090-cceab31ba9c9';
const otherStaffOwner = 'f12aaf33-9b9a-45da-b799-a34486bf2202';
const requestId = 'aeed85cf-83ed-45f4-a945-06a7854d5267';
final staffNow = DateTime.utc(2026, 11, 21, 12);
String opaque(String char) => List.filled(64, char).join();
String cookie(String name, String token, int age) =>
    '$name=$token; Secure; HttpOnly; SameSite=Strict; Path=/; Max-Age=$age';
Json receipt({String owner = staffOwner}) => {
      'requestId': requestId,
      'accountReference': owner,
      'status': 'pending',
      'expiresAt': staffNow.add(const Duration(days: 7)).toIso8601String(),
    };

class FakeStaffCookies implements StaffCookies {
  int installs = 0, clears = 0, generation = 0;
  Future<void>? configureGate, installGate, clearGate;
  String? installed;
  @override
  Future<StaffConfiguration> configuration() async {
    await configureGate;
    return StaffConfiguration(Uri.parse('https://staff.example'), generation);
  }

  @override
  Future<int> install(String token, DateTime expiresAt,
      {required bool Function() isCurrent}) async {
    installs++;
    await installGate;
    if (!isCurrent()) throw staffChanged;
    installed = token;
    return ++generation;
  }

  @override
  Future<void> harden(int id, int generation) async {}
  @override
  Future<void> clear() async {
    clears++;
    await clearGate;
    installed = null;
  }
}

class FakeStaffTransport implements StaffTransport {
  final calls = <StaffOperation>[];
  final proofs = <String>[];
  DateTime currentTime = staffNow;
  Future<StaffResponse> Function(StaffOperation)? handler;
  bool approved = true;
  Json? savedReceipt;
  int cancellations = 0;
  @override
  Future<StaffResponse> request(StaffOperation operation,
      {required String proof,
      required bool Function() isCurrent,
      String? challenge,
      String? csrf}) async {
    if (!isCurrent()) throw staffChanged;
    calls.add(operation);
    proofs.add(proof);
    if (handler != null) return handler!(operation);
    return response(operation);
  }

  StaffResponse response(StaffOperation operation) {
    switch (operation) {
      case StaffOperation.currentRequest:
        if (savedReceipt == null) {
          throw const ApiFailure('STAFF_ACCESS_REQUEST_NOT_FOUND', '',
              status: 404);
        }
        return StaffResponse(savedReceipt!);
      case StaffOperation.accessRequest:
        return StaffResponse(savedReceipt = receipt());
      case StaffOperation.challenge:
        return StaffResponse({
          'csrfToken': opaque('c'),
          'expiresAt':
              currentTime.add(const Duration(seconds: 120)).toIso8601String()
        }, [
          cookie('__Host-nightshift_staff_challenge', opaque('b'), 120)
        ]);
      case StaffOperation.exchange:
        if (!approved) {
          throw const ApiFailure('STAFF_ACCESS_NOT_APPROVED', '', status: 403);
        }
        return StaffResponse({
          'staff': {'id': requestId},
          'permissions': ['listener.review.read', 'staff.access.manage'],
          'csrfToken': opaque('d'),
          'expiresAt':
              currentTime.add(const Duration(minutes: 30)).toIso8601String()
        }, [
          cookie('__Host-nightshift_staff', opaque('a'), 1800),
          cookie('__Host-nightshift_staff_challenge', '', 0)
        ]);
    }
  }

  @override
  void cancel() {
    cancellations++;
  }
}
