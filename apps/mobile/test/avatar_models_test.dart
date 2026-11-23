import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift_api/api.dart' as sdk;
import 'fakes.dart';

Json user(String? code) => {
      'id': 'owner',
      'displayName': 'A',
      'mode': 'customer',
      'listenerApproved': false,
      'online': false,
      'languages': ['ta'],
      if (code != null) 'avatarCode': code,
    };
Json listener(String? code) => {
      'id': 'listener',
      'displayName': 'B',
      'languages': ['ta'],
      'available': false,
      'online': false,
      if (code != null) 'avatarCode': code,
    };

void main() {
  test('selected avatars survive user, listener favorite and call parsing', () {
    for (final code in [
      'moon',
      'wave',
      'male_01',
      'male_30',
      'female_01',
      'female_30'
    ]) {
      final dynamic owner = UserProfile.fromJson(user(code));
      final dynamic card = ListenerProfile.fromJson(listener(code));
      final dynamic call = CallSession.fromJson({
        ...callJson(),
        'customerAvatarCode': code,
        'listenerAvatarCode': code
      });
      expect(owner.avatarCode, code);
      expect(card.withFavorite(true).avatarCode, code);
      expect(call.customerAvatarCode, code);
      expect(call.listenerAvatarCode, code);
    }
  });
  test('legacy missing avatar fields remain absent without inferred portraits',
      () {
    final dynamic owner = UserProfile.fromJson(user(null));
    final dynamic card = ListenerProfile.fromJson(listener(null));
    final dynamic call = CallSession.fromJson(callJson());
    expect(owner.avatarCode, isNull);
    expect(card.withFavorite(true).avatarCode, isNull);
    expect(call.customerAvatarCode, isNull);
    expect(call.listenerAvatarCode, isNull);
  });
  test(
      'explicit invalid avatar fields fail closed instead of becoming image URLs',
      () {
    for (final code in <Object?>[
      'male_00',
      'female_31',
      'female_1',
      'Male_01',
      '../male_01',
      'https://example.com/a.png',
      ['moon'],
      1,
      null
    ]) {
      expect(() => UserProfile.fromJson({...user(null), 'avatarCode': code}),
          throwsFormatException);
      expect(
          () =>
              ListenerProfile.fromJson({...listener(null), 'avatarCode': code}),
          throwsFormatException);
      expect(
          () =>
              CallSession.fromJson({...callJson(), 'customerAvatarCode': code}),
          throwsFormatException);
      expect(
          () =>
              CallSession.fromJson({...callJson(), 'listenerAvatarCode': code}),
          throwsFormatException);
    }
  });
  test('generated onboarding enums round trip all sixty selected portraits',
      () {
    for (final prefix in ['male', 'female']) {
      for (var i = 1; i <= 30; i++) {
        final code = '${prefix}_${i.toString().padLeft(2, '0')}';
        expect(
            sdk.CompleteOnboardingRequestAvatarCodeEnum.fromJson(code)
                ?.toJson(),
            code);
        expect(
            sdk.OnboardingProfileAvatarCodeEnum.fromJson(code)?.toJson(), code);
      }
    }
    expect(
        () => sdk.CompleteOnboardingRequestAvatarCodeEnum.fromJson('female_31'),
        throwsFormatException);
  });
}
