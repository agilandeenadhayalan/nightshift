// Presentation copy is selected by stable codes, never by provider/server prose.
// Unknown codes deliberately use a safe fallback in the selected app language.
String errorMessage(String? code, String locale) {
  final copy = switch (code) {
    'PRIVATE_ORIGIN_REQUIRED' => (
        'Private applications need a configured secure server. Reconnect using phone sign-in.',
        'தனிப்பட்ட விண்ணப்பத்திற்கு பாதுகாப்பான சேவையகம் தேவை. தொலைபேசி உள்நுழைவு மூலம் மீண்டும் இணைக்கவும்.'
      ),
    'APPLICATION_OUTCOME_UNKNOWN' => (
        'The last action may have completed. Check saved application status before retrying. Nothing is retried automatically.',
        'கடைசி செயல் முடிந்திருக்கலாம். மீண்டும் முயற்சிக்கும் முன் சேமித்த விண்ணப்ப நிலையை சரிபார்க்கவும். தானாக மீண்டும் அனுப்பப்படாது.'
      ),
    'APPLICATION_EXISTS' => (
        'An application already exists. Check its saved status.',
        'விண்ணப்பம் ஏற்கனவே உள்ளது. சேமித்த நிலையை சரிபார்க்கவும்.'
      ),
    'APPLICATION_NOT_EDITABLE' => (
        'This application cannot be edited in its current state. Refresh its status.',
        'தற்போதைய நிலையில் விண்ணப்பத்தை மாற்ற முடியாது. நிலையை புதுப்பிக்கவும்.'
      ),
    'APPLICATION_INCOMPLETE' => (
        'Save a bio, a topic, speaking languages and an accepted voice sample before submitting.',
        'சமர்ப்பிக்கும் முன் சுயவிவரம், தலைப்பு, பேசும் மொழிகள் மற்றும் ஏற்கப்பட்ட குரல் மாதிரியை சேமிக்கவும்.'
      ),
    'REVIEW_CONSENT_REQUIRED' => (
        'Save your voice review consent before uploading or submitting.',
        'பதிவேற்றம் அல்லது சமர்ப்பிப்பிற்கு முன் குரல் ஆய்வு ஒப்புதலை சேமிக்கவும்.'
      ),
    'UPLOAD_LIMIT' => (
        'Choose a WAV file no larger than 2 MiB.',
        '2 MiB அளவுக்கு மிகாத WAV கோப்பை தேர்ந்தெடுக்கவும்.'
      ),
    'INVALID_WAV' ||
    'INVALID_UPLOAD' ||
    'UPLOAD_LENGTH_MISMATCH' ||
    'UPLOAD_DIGEST_MISMATCH' =>
      (
        'Choose a 2–60 second PCM 16-bit WAV sample, mono or stereo, 8–48 kHz, without metadata.',
        '2–60 விநாடி PCM 16-bit WAV மாதிரியை தேர்ந்தெடுக்கவும்; மோனோ அல்லது ஸ்டீரியோ, 8–48 kHz, மெட்டாடேட்டா இல்லாமல்.'
      ),
    'UPLOAD_EXPIRED' || 'UPLOAD_CAPABILITY_INVALID' => (
        'This upload permission expired. Check status, then choose the sample again.',
        'பதிவேற்ற அனுமதி காலாவதியானது. நிலையை சரிபார்த்து மாதிரியை மீண்டும் தேர்ந்தெடுக்கவும்.'
      ),
    'REVIEW_UPLOAD_UNAVAILABLE' => (
        'Private sample storage is unavailable. Try again later.',
        'தனிப்பட்ட மாதிரி சேமிப்பகம் கிடைக்கவில்லை. பின்னர் முயற்சிக்கவும்.'
      ),
    'SAMPLE_SELECTION_FAILED' => (
        'The file could not be opened. Choose an accessible WAV file.',
        'கோப்பை திறக்க முடியவில்லை. அணுகக்கூடிய WAV கோப்பை தேர்ந்தெடுக்கவும்.'
      ),
    'PRIVATE_SESSION_CHANGED' => (
        'Your sign-in changed. Reopen this page before continuing.',
        'உங்கள் உள்நுழைவு மாறிவிட்டது. தொடரும் முன் இந்தப் பக்கத்தை மீண்டும் திறக்கவும்.'
      ),
    'NOTICE_OUTDATED' => (
        'Refresh the deletion notice and read it before submitting.',
        'நீக்க அறிவிப்பை புதுப்பித்து, சமர்ப்பிக்கும் முன் படிக்கவும்.'
      ),
    'DELETION_CONFIRMATION_REQUIRED' => (
        'Confirm that you understand the deletion request before submitting.',
        'சமர்ப்பிக்கும் முன் நீக்கக் கோரிக்கையை புரிந்துகொண்டதை உறுதிசெய்யவும்.'
      ),
    'DELETION_STATUS_UNKNOWN' => (
        'The request outcome is uncertain. Use your saved receipt to check status; no deletion request has been retried.',
        'கோரிக்கையின் முடிவு உறுதியில்லை. சேமிக்கப்பட்ட ரசீது மூலம் நிலையை சரிபார்க்கவும்; நீக்கக் கோரிக்கை மீண்டும் அனுப்பப்படவில்லை.'
      ),
    'DELETION_RECEIPT_NOT_FOUND' => (
        'No request was found for this receipt yet. Check again later. A deletion request has not been sent again.',
        'இந்த ரசீதிற்கான கோரிக்கை இன்னும் கிடைக்கவில்லை. பின்னர் சரிபார்க்கவும். நீக்கக் கோரிக்கை மீண்டும் அனுப்பப்படவில்லை.'
      ),
    'DELETION_RECEIPT_EXISTS_LOCAL' || 'DELETION_REQUEST_EXISTS' => (
        'A deletion receipt is already saved. Check that receipt before creating another request.',
        'நீக்க ரசீது ஏற்கனவே சேமிக்கப்பட்டுள்ளது. மற்றொரு கோரிக்கைக்கு முன் அந்த ரசீதை சரிபார்க்கவும்.'
      ),
    'DELETION_RECEIPT_UNREADABLE' => (
        'The saved receipt cannot be read. Do not clear app data while you need recovery.',
        'சேமிக்கப்பட்ட ரசீதை படிக்க முடியவில்லை. மீட்பு தேவைப்படும்போது செயலித் தரவை அழிக்க வேண்டாம்.'
      ),
    'DELETION_ORIGIN_CHANGED' => (
        'This receipt belongs to a different service address. It will not be sent to another server.',
        'இந்த ரசீது வேறு சேவையக முகவரிக்குரியது. இது மற்றொரு சேவையகத்திற்கு அனுப்பப்படாது.'
      ),
    'FRESH_SIGN_IN_REQUIRED' => (
        'Sign out and verify a new SMS code, then try again. Refreshing your existing sign-in is not enough.',
        'வெளியேறி புதிய SMS குறியீட்டை சரிபார்த்து மீண்டும் முயற்சிக்கவும். தற்போதைய உள்நுழைவை புதுப்பிப்பது மட்டும் போதாது.'
      ),
    'ADULT_REQUIRED' || 'ADULT_ONLY' || 'UNDERAGE' => (
        'NightShift is only available to adults aged 18 and over.',
        'NightShift 18 வயது மற்றும் அதற்கு மேற்பட்ட பெரியவர்களுக்கு மட்டுமே கிடைக்கும்.'
      ),
    'INVALID_DATE_OF_BIRTH' || 'INVALID_BIRTH_DATE' || 'DOB_INVALID' => (
        'Enter a valid date of birth as YYYY-MM-DD.',
        'சரியான பிறந்த தேதியை YYYY-MM-DD வடிவில் உள்ளிடவும்.'
      ),
    'DOB_IMMUTABLE' => (
        'Your saved date of birth cannot be changed here.',
        'சேமிக்கப்பட்ட பிறந்த தேதியை இங்கு மாற்ற முடியாது.'
      ),
    'INVALID_PROFILE' ||
    'INVALID_DISPLAY_NAME' ||
    'INVALID_NICKNAME' ||
    'INVALID_AVATAR' =>
      (
        'Check your nickname and choose one of the available avatars.',
        'உங்கள் பெயரை சரிபார்த்து, கிடைக்கும் அவதாரங்களில் ஒன்றைத் தேர்வுசெய்யவும்.'
      ),
    'ONBOARDING_REQUIRED' => (
        'Complete your adult profile before continuing.',
        'தொடர்வதற்கு முன் பெரியவர்களுக்கான சுயவிவரத்தை முடிக்கவும்.'
      ),
    'ONBOARDING_CONSENT_REQUIRED' => (
        'Read and accept the adult profile notice before continuing.',
        'தொடர்வதற்கு முன் பெரியவர்களுக்கான சுயவிவர அறிவிப்பைப் படித்து ஏற்கவும்.'
      ),
    'SESSION_REVOKED' || 'SESSION_SUPERSEDED' || 'TOKEN_DEVICE_MISMATCH' => (
        'This sign-in is no longer available on this device. Sign in again.',
        'இந்தச் சாதனத்தில் இந்த உள்நுழைவு இனி கிடைக்காது. மீண்டும் உள்நுழையவும்.'
      ),
    'OFFLINE' => (
        'Cannot reach the server. Check your connection and backend address.',
        'சேவையகத்தை அணுக முடியவில்லை. இணைப்பையும் சேவையக முகவரியையும் சரிபார்க்கவும்.'
      ),
    'INVALID_URL' => (
        'Enter a valid backend HTTP or HTTPS address.',
        'சரியான HTTP அல்லது HTTPS சேவையக முகவரியை உள்ளிடவும்.'
      ),
    'INVALID_CREDENTIALS' => (
        'Check your test account and development access key.',
        'சோதனை கணக்கையும் மேம்பாட்டு அணுகல் சாவியையும் சரிபார்க்கவும்.'
      ),
    'UNAUTHENTICATED' => (
        'Your session has expired. Sign in again.',
        'உங்கள் அமர்வு காலாவதியானது. மீண்டும் உள்நுழையவும்.'
      ),
    'RATE_LIMITED' => (
        'Too many attempts. Wait a moment before trying again.',
        'அதிக முயற்சிகள். சிறிது நேரம் கழித்து மீண்டும் முயற்சிக்கவும்.'
      ),
    'OTP_INVALID_PHONE' => (
        'Enter a valid Indian mobile number.',
        'சரியான இந்திய மொபைல் எண்ணை உள்ளிடவும்.'
      ),
    'OTP_INVALID_INPUT' => (
        'Check your phone number and verification code.',
        'உங்கள் மொபைல் எண்ணையும் சரிபார்ப்புக் குறியீட்டையும் சரிபார்க்கவும்.'
      ),
    'OTP_INVALID_CONSENT' => (
        'Review and accept the current phone sign-in consent.',
        'தொலைபேசி உள்நுழைவிற்கான தற்போதைய ஒப்புதலைப் படித்து ஏற்கவும்.'
      ),
    'OTP_INVALID_CODE' => (
        'The code is incorrect. Check the six-digit code and try again.',
        'குறியீடு தவறாக உள்ளது. ஆறு இலக்கக் குறியீட்டை சரிபார்த்து மீண்டும் முயற்சிக்கவும்.'
      ),
    'OTP_EXPIRED' => (
        'The code has expired. Request a new code.',
        'குறியீடு காலாவதியானது. புதிய குறியீட்டைக் கோரவும்.'
      ),
    'OTP_CONSUMED' => (
        'This code request can no longer be used. Request a new code when allowed.',
        'இந்தக் குறியீட்டுக் கோரிக்கையை இனி பயன்படுத்த முடியாது. அனுமதிக்கப்படும் போது புதிய குறியீட்டைக் கோரவும்.'
      ),
    'OTP_NOT_FOUND' => (
        'This sign-in request is unavailable. Request a new code.',
        'இந்த உள்நுழைவுக் கோரிக்கை கிடைக்கவில்லை. புதிய குறியீட்டைக் கோரவும்.'
      ),
    'OTP_COOLDOWN' || 'OTP_RATE_LIMITED' => (
        'Wait before requesting another code. Please respect the retry time.',
        'மற்றொரு குறியீட்டைக் கோர காத்திருக்கவும். மீண்டும் முயற்சிக்கும் நேரம் வரை காத்திருக்கவும்.'
      ),
    'OTP_LOCKED' => (
        'Too many incorrect codes. Wait before requesting a new code.',
        'அதிக தவறான குறியீடுகள் உள்ளிடப்பட்டன. புதிய குறியீட்டைக் கோர காத்திருக்கவும்.'
      ),
    'OTP_IN_PROGRESS' => (
        'Your previous sign-in request is still pending. Wait before trying again.',
        'உங்கள் முந்தைய உள்நுழைவுக் கோரிக்கை இன்னும் நிலுவையில் உள்ளது. மீண்டும் முயற்சிக்கும் முன் காத்திருக்கவும்.'
      ),
    'OTP_UNKNOWN_OUTCOME' => (
        'We could not confirm the previous request. Wait before requesting a new code.',
        'முந்தைய கோரிக்கையின் முடிவை உறுதிப்படுத்த முடியவில்லை. புதிய குறியீட்டைக் கோர காத்திருக்கவும்.'
      ),
    'OTP_UNAVAILABLE' || 'OTP_PROVIDER_UNAVAILABLE' => (
        'Phone sign-in could not be completed. Wait before requesting a new code.',
        'தொலைபேசி உள்நுழைவை முடிக்க முடியவில்லை. புதிய குறியீட்டைக் கோர காத்திருக்கவும்.'
      ),
    'PHONE_AUTH_UNAVAILABLE' ||
    'IDENTITY_CONFIGURATION' ||
    'IDENTITY_UNAVAILABLE' =>
      (
        'Phone sign-in is unavailable right now. Try again later.',
        'தொலைபேசி உள்நுழைவு தற்போது கிடைக்கவில்லை. பின்னர் மீண்டும் முயற்சிக்கவும்.'
      ),
    'INVALID_ID_TOKEN' || 'ID_TOKEN_EXPIRED' || 'ID_TOKEN_REVOKED' => (
        'Your identity session is no longer valid. Sign in again.',
        'உங்கள் அடையாள அமர்வு இனி செல்லுபடியாகாது. மீண்டும் உள்நுழையவும்.'
      ),
    'IDENTITY_DISABLED' || 'ACCOUNT_RESTRICTED' => (
        'This account is unavailable.',
        'இந்தக் கணக்கு கிடைக்கவில்லை.'
      ),
    'MICROPHONE_DENIED' => (
        'Allow microphone access in Android settings to make a call.',
        'அழைக்க Android அமைப்புகளில் மைக்ரோஃபோன் அனுமதியை வழங்கவும்.'
      ),
    'CAMERA_DENIED' => (
        'Allow camera access in Android settings, then preview your camera again. You can still choose an audio call.',
        'Android அமைப்புகளில் கேமரா அனுமதியை வழங்கி மீண்டும் முன்னோட்டத்தை பார்க்கவும். ஆடியோ அழைப்பையும் தேர்வு செய்யலாம்.'
      ),
    'VIDEO_UNAVAILABLE' || 'VIDEO_DISABLED' => (
        'Video calling is unavailable on this test server. You can choose an audio call.',
        'இந்த சோதனை சேவையகத்தில் வீடியோ அழைப்பு கிடைக்கவில்லை. ஆடியோ அழைப்பை தேர்வு செய்யலாம்.'
      ),
    'VIDEO_CONSENT_REQUIRED' || 'VIDEO_PREVIEW_REQUIRED' => (
        'Preview your camera and give consent before joining video.',
        'வீடியோவில் சேருவதற்கு முன் கேமரா முன்னோட்டத்தை பார்த்து ஒப்புதல் அளிக்கவும்.'
      ),
    'CAMERA_FAILED' || 'RTC_CAMERA_FAILED' || 'VIDEO_FAILED' => (
        'The camera could not continue. End the call or try camera preview again.',
        'கேமராவை தொடர முடியவில்லை. அழைப்பை முடிக்கவும் அல்லது கேமரா முன்னோட்டத்தை மீண்டும் முயற்சிக்கவும்.'
      ),
    'VIDEO_NOT_READY' || 'VIDEO_READINESS_REQUIRED' => (
        'Waiting for both cameras. Missing video time is not charged.',
        'இரு கேமராக்களுக்காக காத்திருக்கிறது. வீடியோ இல்லாத நேரத்திற்கு கட்டணம் இல்லை.'
      ),
    'RTC_VIDEO_QUALITY_FAILED' => (
        'Video could not adapt to this connection. End the video call and choose a new audio call if needed.',
        'இந்த இணைப்பிற்கு வீடியோ தரத்தை மாற்ற முடியவில்லை. வீடியோ அழைப்பை முடித்து தேவைப்பட்டால் புதிய ஆடியோ அழைப்பை தேர்வு செய்யவும்.'
      ),
    'RTC_UNAVAILABLE' => (
        'Audio calling is not configured on this test server yet.',
        'இந்த சோதனை சேவையகத்தில் ஆடியோ அழைப்பு இன்னும் அமைக்கப்படவில்லை.'
      ),
    'AUDIO_FAILED' ||
    'RTC_CONNECTION_FAILED' ||
    'RTC_MICROPHONE_FAILED' ||
    'RTC_RENEWAL_FAILED' ||
    'RTC_TOKEN_EXPIRED' =>
      (
        'The audio connection failed. Try another call.',
        'ஆடியோ இணைப்பு தோல்வியடைந்தது. மீண்டும் அழைக்கவும்.'
      ),
    'END_PENDING' => (
        'Audio has stopped. Waiting for the server to confirm the call ended.',
        'ஆடியோ நிறுத்தப்பட்டது. அழைப்பு முடிவை சேவையகம் உறுதிப்படுத்த காத்திருக்கிறது.'
      ),
    'LISTENER_BUSY' || 'CALL_ACTIVE' => (
        'A participant is already in a call. Try again when available.',
        'ஒருவர் ஏற்கனவே அழைப்பில் உள்ளார். கிடைக்கும்போது மீண்டும் முயற்சிக்கவும்.'
      ),
    'LISTENER_OFFLINE' => (
        'This listener is no longer available. Refresh to find another listener.',
        'இந்த கேட்பவர் தற்போது கிடைக்கவில்லை. வேறொருவரை காண புதுப்பிக்கவும்.'
      ),
    'LISTENER_NOT_APPROVED' => (
        'Listener approval is required before going online.',
        'ஆன்லைன் செல்ல கேட்பவர் அங்கீகாரம் தேவை.'
      ),
    'INSUFFICIENT_BALANCE' => (
        'There are not enough test credits for this call.',
        'இந்த அழைப்பிற்கு போதுமான சோதனை நாணயங்கள் இல்லை.'
      ),
    'QUOTE_EXPIRED' => (
        'The call rate has changed. Refresh before starting a call.',
        'அழைப்பு விகிதம் மாறியுள்ளது. அழைப்பிற்கு முன் புதுப்பிக்கவும்.'
      ),
    'PAIR_BLOCKED' || 'CALL_NOT_ELIGIBLE' => (
        'This conversation is unavailable.',
        'இந்த உரையாடல் கிடைக்கவில்லை.'
      ),
    'LANGUAGE_MISMATCH' || 'INVALID_LANGUAGE' => (
        'Choose a supported conversation language.',
        'ஆதரிக்கப்படும் உரையாடல் மொழியைத் தேர்ந்தெடுக்கவும்.'
      ),
    'CALL_ALREADY_ENDED' || 'CALL_NOT_ACTIVE' => (
        'This call has ended. Check your recent conversations.',
        'இந்த அழைப்பு முடிந்துவிட்டது. சமீபத்திய உரையாடல்களை பார்க்கவும்.'
      ),
    'STALE_VERSION' || 'INVALID_TRANSITION' => (
        'The call has changed. Refresh its status before trying again.',
        'அழைப்பின் நிலை மாறியுள்ளது. மீண்டும் முயற்சிக்கும் முன் புதுப்பிக்கவும்.'
      ),
    'IDEMPOTENCY_CONFLICT' => (
        'The request details changed. Start a new attempt.',
        'கோரிக்கையின் விவரங்கள் மாறியுள்ளன. புதிய முயற்சியைத் தொடங்கவும்.'
      ),
    'INVALID_RESPONSE' || 'SERVICE_UNAVAILABLE' => (
        'The server is temporarily unavailable. Try again shortly.',
        'சேவையகம் தற்காலிகமாக கிடைக்கவில்லை. சிறிது நேரத்தில் மீண்டும் முயற்சிக்கவும்.'
      ),
    'TEST_ONLY' => (
        'Development sign-in is available only in the debug test build.',
        'மேம்பாட்டு உள்நுழைவு சோதனை பதிப்பில் மட்டுமே கிடைக்கும்.'
      ),
    _ => (
        'Something went wrong. Try again.',
        'ஏதோ தவறு ஏற்பட்டது. மீண்டும் முயற்சிக்கவும்.'
      ),
  };
  return locale == 'ta' ? copy.$2 : copy.$1;
}

String endReasonLabel(String? reason, String locale) {
  final copy = switch (reason) {
    'timeout' => ('No answer', 'பதில் இல்லை'),
    'declined' => ('Declined', 'நிராகரிக்கப்பட்டது'),
    'cancelled' => ('Cancelled', 'ரத்து செய்யப்பட்டது'),
    'connection_timeout' => ('Connection timed out', 'இணைப்பு நேரம் முடிந்தது'),
    'video_unavailable' => ('Video became unavailable', 'வீடியோ கிடைக்கவில்லை'),
    'test_credit_limit' => (
        'Test credit or call limit reached',
        'சோதனை நாணயம் அல்லது அழைப்பு வரம்பை எட்டியது'
      ),
    'session_limit' => (
        'Call time limit reached',
        'அழைப்பு நேர வரம்பை எட்டியது'
      ),
    'signed_out' => ('Signed out', 'வெளியேறப்பட்டது'),
    'blocked' => ('Blocked', 'தடுக்கப்பட்டது'),
    _ => ('Call ended', 'அழைப்பு முடிந்தது'),
  };
  return locale == 'ta' ? copy.$2 : copy.$1;
}
