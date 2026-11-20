//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

library nightshift.api;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

part 'api_client.dart';
part 'api_helper.dart';
part 'api_exception.dart';
part 'auth/authentication.dart';
part 'auth/api_key_auth.dart';
part 'auth/oauth.dart';
part 'auth/http_basic_auth.dart';
part 'auth/http_bearer_auth.dart';

part 'api/default_api.dart';

part 'model/accept_call_request.dart';
part 'model/block_user200_response.dart';
part 'model/call.dart';
part 'model/call_page.dart';
part 'model/cancel_call_request.dart';
part 'model/complete_onboarding_request.dart';
part 'model/consent_event.dart';
part 'model/consent_history.dart';
part 'model/create_call_request.dart';
part 'model/create_report201_response.dart';
part 'model/create_report_request.dart';
part 'model/decline_call_request.dart';
part 'model/deletion_notice.dart';
part 'model/deletion_receipt.dart';
part 'model/deletion_receipt_request.dart';
part 'model/deletion_request.dart';
part 'model/development_sign_in_request.dart';
part 'model/error.dart';
part 'model/error_error.dart';
part 'model/event.dart';
part 'model/favorite_listener200_response.dart';
part 'model/firebase_verify_request.dart';
part 'model/get_events200_response.dart';
part 'model/get_rates200_response.dart';
part 'model/get_test_earnings200_response.dart';
part 'model/health200_response.dart';
part 'model/heartbeat201_response.dart';
part 'model/listener.dart';
part 'model/listener_application.dart';
part 'model/listener_application_input.dart';
part 'model/listener_application_state.dart';
part 'model/listener_page.dart';
part 'model/login.dart';
part 'model/onboarding_profile.dart';
part 'model/onboarding_state.dart';
part 'model/otp_challenge.dart';
part 'model/otp_proof.dart';
part 'model/otp_request.dart';
part 'model/otp_verify_request.dart';
part 'model/phone_identity.dart';
part 'model/phone_session.dart';
part 'model/phone_session_request.dart';
part 'model/rate.dart';
part 'model/report_media_ready_request.dart';
part 'model/review_upload.dart';
part 'model/review_upload_request.dart';
part 'model/rtc_config.dart';
part 'model/rtc_token.dart';
part 'model/set_availability_request.dart';
part 'model/set_languages_request.dart';
part 'model/set_mode_request.dart';
part 'model/sign_out201_response.dart';
part 'model/snapshot.dart';
part 'model/user.dart';
part 'model/wallet.dart';


/// An [ApiClient] instance that uses the default values obtained from
/// the OpenAPI specification file.
var defaultApiClient = ApiClient();

const _delimiters = {'csv': ',', 'ssv': ' ', 'tsv': '\t', 'pipes': '|'};
const _dateEpochMarker = 'epoch';
const _deepEquality = DeepCollectionEquality();
final _dateFormatter = DateFormat('yyyy-MM-dd');
final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

bool _isEpochMarker(String? pattern) => pattern == _dateEpochMarker || pattern == '/$_dateEpochMarker/';
