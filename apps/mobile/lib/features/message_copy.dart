// Presentation copy is selected by stable codes, never by provider/server prose.
// Unknown codes deliberately use a safe fallback in the selected app language.
String errorMessage(String? code, String locale) {
  final copy = switch (code) {
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
    'MICROPHONE_DENIED' => (
        'Allow microphone access in Android settings to make a call.',
        'அழைக்க Android அமைப்புகளில் மைக்ரோஃபோன் அனுமதியை வழங்கவும்.'
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
    'STALE_VERSION' || 'INVALID_TRANSITION' || 'IDEMPOTENCY_CONFLICT' => (
        'The call has changed. Refresh its status before trying again.',
        'அழைப்பின் நிலை மாறியுள்ளது. மீண்டும் முயற்சிக்கும் முன் புதுப்பிக்கவும்.'
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
