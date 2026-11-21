//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of nightshift.api;


class DefaultApi {
  DefaultApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Performs an HTTP 'POST /v1/calls/{id}/accept' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [AcceptCallRequest] acceptCallRequest (required):
  Future<Response> acceptCallWithHttpInfo(String id, String idempotencyKey, AcceptCallRequest acceptCallRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/calls/{id}/accept'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody = acceptCallRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [AcceptCallRequest] acceptCallRequest (required):
  Future<Call?> acceptCall(String id, String idempotencyKey, AcceptCallRequest acceptCallRequest, { Future<void>? abortTrigger, }) async {
    final response = await acceptCallWithHttpInfo(id, idempotencyKey, acceptCallRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Call',) as Call;
    
    }
    return null;
  }

  /// Explicit bounded audio-invitation opt-in after native binding installation. Does not enable ongoing background audio or prove notification delivery. Same-key replay never renews a lease.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [ActivatePushRegistration] activatePushRegistration (required):
  Future<Response> activatePushRegistrationWithHttpInfo(String idempotencyKey, ActivatePushRegistration activatePushRegistration, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/push/registration/activate';

    // ignore: prefer_final_locals
    Object? postBody = activatePushRegistration;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Explicit bounded audio-invitation opt-in after native binding installation. Does not enable ongoing background audio or prove notification delivery. Same-key replay never renews a lease.
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [ActivatePushRegistration] activatePushRegistration (required):
  Future<PushRegistration?> activatePushRegistration(String idempotencyKey, ActivatePushRegistration activatePushRegistration, { Future<void>? abortTrigger, }) async {
    final response = await activatePushRegistrationWithHttpInfo(idempotencyKey, activatePushRegistration, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PushRegistration',) as PushRegistration;
    
    }
    return null;
  }

  /// Performs an HTTP 'PUT /v1/blocks/{id}' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  Future<Response> blockUserWithHttpInfo(String id, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/blocks/{id}'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  Future<BlockUser200Response?> blockUser(String id, { Future<void>? abortTrigger, }) async {
    final response = await blockUserWithHttpInfo(id, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'BlockUser200Response',) as BlockUser200Response;
    
    }
    return null;
  }

  /// Performs an HTTP 'POST /v1/calls/{id}/cancel' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CancelCallRequest] cancelCallRequest (required):
  Future<Response> cancelCallWithHttpInfo(String id, String idempotencyKey, CancelCallRequest cancelCallRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/calls/{id}/cancel'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody = cancelCallRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CancelCallRequest] cancelCallRequest (required):
  Future<Call?> cancelCall(String id, String idempotencyKey, CancelCallRequest cancelCallRequest, { Future<void>? abortTrigger, }) async {
    final response = await cancelCallWithHttpInfo(id, idempotencyKey, cancelCallRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Call',) as Call;
    
    }
    return null;
  }

  /// Cancel only this search. An acceptance winning the race returns matched and must not be translated into ending the accepted call.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CancelMatchingRequest] cancelMatchingRequest (required):
  Future<Response> cancelMatchingRequestWithHttpInfo(String id, String idempotencyKey, CancelMatchingRequest cancelMatchingRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/matches/{id}/cancel'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody = cancelMatchingRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Cancel only this search. An acceptance winning the race returns matched and must not be translated into ending the accepted call.
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CancelMatchingRequest] cancelMatchingRequest (required):
  Future<MatchingRequest?> cancelMatchingRequest(String id, String idempotencyKey, CancelMatchingRequest cancelMatchingRequest, { Future<void>? abortTrigger, }) async {
    final response = await cancelMatchingRequestWithHttpInfo(id, idempotencyKey, cancelMatchingRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'MatchingRequest',) as MatchingRequest;
    
    }
    return null;
  }

  /// Atomically record an immutable adult date of birth, private proposed nickname, built-in avatar, separate UI/speaking languages, and versioned development consent. Pending nicknames are not published.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CompleteOnboardingRequest] completeOnboardingRequest (required):
  Future<Response> completeOnboardingWithHttpInfo(CompleteOnboardingRequest completeOnboardingRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/onboarding';

    // ignore: prefer_final_locals
    Object? postBody = completeOnboardingRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Atomically record an immutable adult date of birth, private proposed nickname, built-in avatar, separate UI/speaking languages, and versioned development consent. Pending nicknames are not published.
  ///
  /// Parameters:
  ///
  /// * [CompleteOnboardingRequest] completeOnboardingRequest (required):
  Future<OnboardingState?> completeOnboarding(CompleteOnboardingRequest completeOnboardingRequest, { Future<void>? abortTrigger, }) async {
    final response = await completeOnboardingWithHttpInfo(completeOnboardingRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'OnboardingState',) as OnboardingState;
    
    }
    return null;
  }

  /// Performs an HTTP 'POST /v1/calls' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CreateCallRequest] createCallRequest (required):
  Future<Response> createCallWithHttpInfo(String idempotencyKey, CreateCallRequest createCallRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/calls';

    // ignore: prefer_final_locals
    Object? postBody = createCallRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CreateCallRequest] createCallRequest (required):
  Future<Call?> createCall(String idempotencyKey, CreateCallRequest createCallRequest, { Future<void>? abortTrigger, }) async {
    final response = await createCallWithHttpInfo(idempotencyKey, createCallRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Call',) as Call;
    
    }
    return null;
  }

  /// Owner-only draft with explicit review-sample consent. A voice sample never proves age or gender.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [ListenerApplicationInput] listenerApplicationInput (required):
  Future<Response> createListenerApplicationWithHttpInfo(String idempotencyKey, ListenerApplicationInput listenerApplicationInput, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/listener-applications';

    // ignore: prefer_final_locals
    Object? postBody = listenerApplicationInput;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Owner-only draft with explicit review-sample consent. A voice sample never proves age or gender.
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [ListenerApplicationInput] listenerApplicationInput (required):
  Future<ListenerApplication?> createListenerApplication(String idempotencyKey, ListenerApplicationInput listenerApplicationInput, { Future<void>? abortTrigger, }) async {
    final response = await createListenerApplicationWithHttpInfo(idempotencyKey, listenerApplicationInput, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListenerApplication',) as ListenerApplication;
    
    }
    return null;
  }

  /// Explicit audio-only opt-in: at most three sequential invitations within a single 90-second deadline. Search and ringing are uncharged; existing test-credit call tariff applies after connection. Preserve this key and body on uncertain delivery; recover own current request before an explicit retry.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CreateMatchingRequest] createMatchingRequest (required):
  Future<Response> createMatchingRequestWithHttpInfo(String idempotencyKey, CreateMatchingRequest createMatchingRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/matches';

    // ignore: prefer_final_locals
    Object? postBody = createMatchingRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Explicit audio-only opt-in: at most three sequential invitations within a single 90-second deadline. Search and ringing are uncharged; existing test-credit call tariff applies after connection. Preserve this key and body on uncertain delivery; recover own current request before an explicit retry.
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CreateMatchingRequest] createMatchingRequest (required):
  Future<MatchingRequest?> createMatchingRequest(String idempotencyKey, CreateMatchingRequest createMatchingRequest, { Future<void>? abortTrigger, }) async {
    final response = await createMatchingRequestWithHttpInfo(idempotencyKey, createMatchingRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'MatchingRequest',) as MatchingRequest;
    
    }
    return null;
  }

  /// Performs an HTTP 'POST /v1/reports' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CreateReportRequest] createReportRequest (required):
  Future<Response> createReportWithHttpInfo(String idempotencyKey, CreateReportRequest createReportRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/reports';

    // ignore: prefer_final_locals
    Object? postBody = createReportRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CreateReportRequest] createReportRequest (required):
  Future<CreateReport201Response?> createReport(String idempotencyKey, CreateReportRequest createReportRequest, { Future<void>? abortTrigger, }) async {
    final response = await createReportWithHttpInfo(idempotencyKey, createReportRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'CreateReport201Response',) as CreateReport201Response;
    
    }
    return null;
  }

  /// Five-minute owner-bound upload lease. Private PCM WAV, 2–60 seconds, at most 2 MiB. No public URL.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [ReviewUploadRequest] reviewUploadRequest (required):
  Future<Response> createReviewUploadWithHttpInfo(String id, String idempotencyKey, ReviewUploadRequest reviewUploadRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/listener-applications/{id}/uploads'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody = reviewUploadRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Five-minute owner-bound upload lease. Private PCM WAV, 2–60 seconds, at most 2 MiB. No public URL.
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [ReviewUploadRequest] reviewUploadRequest (required):
  Future<ReviewUpload?> createReviewUpload(String id, String idempotencyKey, ReviewUploadRequest reviewUploadRequest, { Future<void>? abortTrigger, }) async {
    final response = await createReviewUploadWithHttpInfo(id, idempotencyKey, reviewUploadRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ReviewUpload',) as ReviewUpload;
    
    }
    return null;
  }

  /// Performs an HTTP 'POST /v1/calls/{id}/decline' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [DeclineCallRequest] declineCallRequest (required):
  Future<Response> declineCallWithHttpInfo(String id, String idempotencyKey, DeclineCallRequest declineCallRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/calls/{id}/decline'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody = declineCallRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [DeclineCallRequest] declineCallRequest (required):
  Future<Call?> declineCall(String id, String idempotencyKey, DeclineCallRequest declineCallRequest, { Future<void>? abortTrigger, }) async {
    final response = await declineCallWithHttpInfo(id, idempotencyKey, declineCallRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Call',) as Call;
    
    }
    return null;
  }

  /// Development/test only. Server refuses production boot.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DevelopmentSignInRequest] developmentSignInRequest (required):
  Future<Response> developmentSignInWithHttpInfo(DevelopmentSignInRequest developmentSignInRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/auth/dev';

    // ignore: prefer_final_locals
    Object? postBody = developmentSignInRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Development/test only. Server refuses production boot.
  ///
  /// Parameters:
  ///
  /// * [DevelopmentSignInRequest] developmentSignInRequest (required):
  Future<Login?> developmentSignIn(DevelopmentSignInRequest developmentSignInRequest, { Future<void>? abortTrigger, }) async {
    final response = await developmentSignInWithHttpInfo(developmentSignInRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Login',) as Login;
    
    }
    return null;
  }

  /// Performs an HTTP 'POST /v1/calls/{id}/end' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CancelCallRequest] cancelCallRequest (required):
  Future<Response> endCallWithHttpInfo(String id, String idempotencyKey, CancelCallRequest cancelCallRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/calls/{id}/end'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody = cancelCallRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [CancelCallRequest] cancelCallRequest (required):
  Future<Call?> endCall(String id, String idempotencyKey, CancelCallRequest cancelCallRequest, { Future<void>? abortTrigger, }) async {
    final response = await endCallWithHttpInfo(id, idempotencyKey, cancelCallRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Call',) as Call;
    
    }
    return null;
  }

  /// Registers a provider-verified ID token and device. Returns restricted access until adult onboarding completes. Every phone-session request checks Firebase revocation and local authorization. No credits or Listener approval are granted.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PhoneSessionRequest] phoneSessionRequest (required):
  Future<Response> exchangePhoneSessionWithHttpInfo(PhoneSessionRequest phoneSessionRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/auth/exchange';

    // ignore: prefer_final_locals
    Object? postBody = phoneSessionRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Registers a provider-verified ID token and device. Returns restricted access until adult onboarding completes. Every phone-session request checks Firebase revocation and local authorization. No credits or Listener approval are granted.
  ///
  /// Parameters:
  ///
  /// * [PhoneSessionRequest] phoneSessionRequest (required):
  Future<PhoneSession?> exchangePhoneSession(PhoneSessionRequest phoneSessionRequest, { Future<void>? abortTrigger, }) async {
    final response = await exchangePhoneSessionWithHttpInfo(phoneSessionRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PhoneSession',) as PhoneSession;
    
    }
    return null;
  }

  /// Performs an HTTP 'PUT /v1/favorites/{id}' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  Future<Response> favoriteListenerWithHttpInfo(String id, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/favorites/{id}'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  Future<FavoriteListener200Response?> favoriteListener(String id, { Future<void>? abortTrigger, }) async {
    final response = await favoriteListenerWithHttpInfo(id, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'FavoriteListener200Response',) as FavoriteListener200Response;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/calls/{id}' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  Future<Response> getCallWithHttpInfo(String id, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/calls/{id}'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  Future<Call?> getCall(String id, { Future<void>? abortTrigger, }) async {
    final response = await getCallWithHttpInfo(id, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Call',) as Call;
    
    }
    return null;
  }

  /// Owner-only recorded consent purposes and notice versions, including restricted onboarding accounts.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getConsentHistoryWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/consents';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Owner-only recorded consent purposes and notice versions, including restricted onboarding accounts.
  Future<ConsentHistory?> getConsentHistory({ Future<void>? abortTrigger, }) async {
    final response = await getConsentHistoryWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ConsentHistory',) as ConsentHistory;
    
    }
    return null;
  }

  /// Authoritative owner-only current/latest matching request. Reading never creates a new search or invitation. Poll at most once per second while active; recover after resume.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getCurrentMatchingRequestWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/match';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Authoritative owner-only current/latest matching request. Reading never creates a new search or invitation. Poll at most once per second while active; recover after resume.
  Future<CurrentMatchingRequest?> getCurrentMatchingRequest({ Future<void>? abortTrigger, }) async {
    final response = await getCurrentMatchingRequestWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'CurrentMatchingRequest',) as CurrentMatchingRequest;
    
    }
    return null;
  }

  /// Development-only deletion effects and explicit retention limits before confirmation.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getDeletionNoticeWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/deletion-notice';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Development-only deletion effects and explicit retention limits before confirmation.
  Future<DeletionNotice?> getDeletionNotice({ Future<void>? abortTrigger, }) async {
    final response = await getDeletionNoticeWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'DeletionNotice',) as DeletionNotice;
    
    }
    return null;
  }

  /// A private receipt capability reveals only deletion status after account sessions have been revoked. Never include it in URLs or diagnostics.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DeletionReceiptRequest] deletionReceiptRequest (required):
  Future<Response> getDeletionReceiptWithHttpInfo(DeletionReceiptRequest deletionReceiptRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/account-deletion/status';

    // ignore: prefer_final_locals
    Object? postBody = deletionReceiptRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// A private receipt capability reveals only deletion status after account sessions have been revoked. Never include it in URLs or diagnostics.
  ///
  /// Parameters:
  ///
  /// * [DeletionReceiptRequest] deletionReceiptRequest (required):
  Future<DeletionReceipt?> getDeletionReceipt(DeletionReceiptRequest deletionReceiptRequest, { Future<void>? abortTrigger, }) async {
    final response = await getDeletionReceiptWithHttpInfo(deletionReceiptRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'DeletionReceipt',) as DeletionReceipt;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/events' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] cursor:
  Future<Response> getEventsWithHttpInfo({ String? cursor, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/events';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (cursor != null) {
      queryParams.addAll(_queryParams('', 'cursor', cursor));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] cursor:
  Future<GetEvents200Response?> getEvents({ String? cursor, Future<void>? abortTrigger, }) async {
    final response = await getEventsWithHttpInfo(cursor: cursor, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GetEvents200Response',) as GetEvents200Response;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/me/listener-application' operation and returns the [Response].
  Future<Response> getListenerApplicationWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/listener-application';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  Future<ListenerApplicationState?> getListenerApplication({ Future<void>? abortTrigger, }) async {
    final response = await getListenerApplicationWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListenerApplicationState',) as ListenerApplicationState;
    
    }
    return null;
  }

  /// Owner-only safe decision result and durable in-app notice. Approval is distinct from active Listener entitlement; no staff notes or evidence are returned.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getListenerApplicationReviewWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/listener-application/review';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Owner-only safe decision result and durable in-app notice. Approval is distinct from active Listener entitlement; no staff notes or evidence are returned.
  Future<ListenerReviewState?> getListenerApplicationReview({ Future<void>? abortTrigger, }) async {
    final response = await getListenerApplicationReviewWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListenerReviewState',) as ListenerReviewState;
    
    }
    return null;
  }

  /// Current status for at most 40 own favorites, served view members or historical Listener counterparts. Unknown/ineligible IDs are removed without revealing account details. Historical call outcomes are separate.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [ListenerStatusRequest] listenerStatusRequest (required):
  Future<Response> getListenerStatusesWithHttpInfo(ListenerStatusRequest listenerStatusRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/listeners/status';

    // ignore: prefer_final_locals
    Object? postBody = listenerStatusRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Current status for at most 40 own favorites, served view members or historical Listener counterparts. Unknown/ineligible IDs are removed without revealing account details. Historical call outcomes are separate.
  ///
  /// Parameters:
  ///
  /// * [ListenerStatusRequest] listenerStatusRequest (required):
  Future<ListenerStatuses?> getListenerStatuses(ListenerStatusRequest listenerStatusRequest, { Future<void>? abortTrigger, }) async {
    final response = await getListenerStatusesWithHttpInfo(listenerStatusRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListenerStatuses',) as ListenerStatuses;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/matches/{id}' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  Future<Response> getMatchingRequestWithHttpInfo(String id, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/matches/{id}'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  Future<MatchingRequest?> getMatchingRequest(String id, { Future<void>? abortTrigger, }) async {
    final response = await getMatchingRequestWithHttpInfo(id, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'MatchingRequest',) as MatchingRequest;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/me' operation and returns the [Response].
  Future<Response> getMeWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  Future<User?> getMe({ Future<void>? abortTrigger, }) async {
    final response = await getMeWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'User',) as User;
    
    }
    return null;
  }

  /// Owner-only profile and onboarding state. Available to restricted onboarding sessions; date of birth is never public.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getOnboardingWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/onboarding';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Owner-only profile and onboarding state. Available to restricted onboarding sessions; date of birth is never public.
  Future<OnboardingState?> getOnboarding({ Future<void>? abortTrigger, }) async {
    final response = await getOnboardingWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'OnboardingState',) as OnboardingState;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/me/push/registration' operation and returns the [Response].
  Future<Response> getPushRegistrationWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/push/registration';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  Future<CurrentPushRegistration?> getPushRegistration({ Future<void>? abortTrigger, }) async {
    final response = await getPushRegistrationWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'CurrentPushRegistration',) as CurrentPushRegistration;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/rates' operation and returns the [Response].
  Future<Response> getRatesWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/rates';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  Future<GetRates200Response?> getRates({ Future<void>? abortTrigger, }) async {
    final response = await getRatesWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GetRates200Response',) as GetRates200Response;
    
    }
    return null;
  }

  /// Authenticated private-video preview configuration. Contains a public app ID only when video is enabled; never a certificate or channel token.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getRtcConfigWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/rtc/config';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Authenticated private-video preview configuration. Contains a public app ID only when video is enabled; never a certificate or channel token.
  Future<RtcConfig?> getRtcConfig({ Future<void>? abortTrigger, }) async {
    final response = await getRtcConfigWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'RtcConfig',) as RtcConfig;
    
    }
    return null;
  }

  /// Performs an HTTP 'POST /v1/calls/{id}/rtc-token' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  Future<Response> getRtcTokenWithHttpInfo(String id, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/calls/{id}/rtc-token'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  Future<RtcToken?> getRtcToken(String id, { Future<void>? abortTrigger, }) async {
    final response = await getRtcTokenWithHttpInfo(id, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'RtcToken',) as RtcToken;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/snapshot' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] language:
  Future<Response> getSnapshotWithHttpInfo({ String? language, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/snapshot';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (language != null) {
      queryParams.addAll(_queryParams('', 'language', language));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] language:
  Future<Snapshot?> getSnapshot({ String? language, Future<void>? abortTrigger, }) async {
    final response = await getSnapshotWithHttpInfo(language: language, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Snapshot',) as Snapshot;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/me/earnings' operation and returns the [Response].
  Future<Response> getTestEarningsWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/earnings';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  Future<GetTestEarnings200Response?> getTestEarnings({ Future<void>? abortTrigger, }) async {
    final response = await getTestEarningsWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GetTestEarnings200Response',) as GetTestEarnings200Response;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/wallet' operation and returns the [Response].
  Future<Response> getWalletWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/wallet';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  Future<Wallet?> getWallet({ Future<void>? abortTrigger, }) async {
    final response = await getWalletWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Wallet',) as Wallet;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/health' operation and returns the [Response].
  Future<Response> healthWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/health';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  Future<Health200Response?> health({ Future<void>? abortTrigger, }) async {
    final response = await healthWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Health200Response',) as Health200Response;
    
    }
    return null;
  }

  /// Performs an HTTP 'POST /v1/presence/heartbeat' operation and returns the [Response].
  Future<Response> heartbeatWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/presence/heartbeat';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  Future<Heartbeat201Response?> heartbeat({ Future<void>? abortTrigger, }) async {
    final response = await heartbeatWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Heartbeat201Response',) as Heartbeat201Response;
    
    }
    return null;
  }

  /// Performs an HTTP 'GET /v1/calls' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] cursor:
  Future<Response> listCallsWithHttpInfo({ String? cursor, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/calls';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (cursor != null) {
      queryParams.addAll(_queryParams('', 'cursor', cursor));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] cursor:
  Future<CallPage?> listCalls({ String? cursor, Future<void>? abortTrigger, }) async {
    final response = await listCallsWithHttpInfo(cursor: cursor, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'CallPage',) as CallPage;
    
    }
    return null;
  }

  /// Private favorite listeners with current eligibility and presence, using the same frozen-view pagination as Discover.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] language:
  ///
  /// * [bool] availableOnly:
  ///
  /// * [String] cursor:
  Future<Response> listFavoritesWithHttpInfo({ String? language, bool? availableOnly, String? cursor, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/favorites';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (language != null) {
      queryParams.addAll(_queryParams('', 'language', language));
    }
    if (availableOnly != null) {
      queryParams.addAll(_queryParams('', 'availableOnly', availableOnly));
    }
    if (cursor != null) {
      queryParams.addAll(_queryParams('', 'cursor', cursor));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Private favorite listeners with current eligibility and presence, using the same frozen-view pagination as Discover.
  ///
  /// Parameters:
  ///
  /// * [String] language:
  ///
  /// * [bool] availableOnly:
  ///
  /// * [String] cursor:
  Future<ListenerPage?> listFavorites({ String? language, bool? availableOnly, String? cursor, Future<void>? abortTrigger, }) async {
    final response = await listFavoritesWithHttpInfo(language: language, availableOnly: availableOnly, cursor: cursor, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListenerPage',) as ListenerPage;
    
    }
    return null;
  }

  /// Twenty-card pages from a five-minute owner/filter-bound frozen view. Live eligibility is rechecked without reranking; refresh creates a new view. At most four active views per owner and 2000 IDs per view. A truncated view must not be presented as complete or as proof of no language supply.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] language:
  ///
  /// * [bool] availableOnly:
  ///
  /// * [String] cursor:
  Future<Response> listListenersWithHttpInfo({ String? language, bool? availableOnly, String? cursor, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/listeners';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (language != null) {
      queryParams.addAll(_queryParams('', 'language', language));
    }
    if (availableOnly != null) {
      queryParams.addAll(_queryParams('', 'availableOnly', availableOnly));
    }
    if (cursor != null) {
      queryParams.addAll(_queryParams('', 'cursor', cursor));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Twenty-card pages from a five-minute owner/filter-bound frozen view. Live eligibility is rechecked without reranking; refresh creates a new view. At most four active views per owner and 2000 IDs per view. A truncated view must not be presented as complete or as proof of no language supply.
  ///
  /// Parameters:
  ///
  /// * [String] language:
  ///
  /// * [bool] availableOnly:
  ///
  /// * [String] cursor:
  Future<ListenerPage?> listListeners({ String? language, bool? availableOnly, String? cursor, Future<void>? abortTrigger, }) async {
    final response = await listListenersWithHttpInfo(language: language, availableOnly: availableOnly, cursor: cursor, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListenerPage',) as ListenerPage;
    
    }
    return null;
  }

  /// Prepare a current verified-device registration. Token is write-only; install the native binding durably before explicit activation. Unknown outcomes require a read before explicit retry.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [PreparePushRegistration] preparePushRegistration (required):
  Future<Response> preparePushRegistrationWithHttpInfo(String idempotencyKey, PreparePushRegistration preparePushRegistration, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/push/registration';

    // ignore: prefer_final_locals
    Object? postBody = preparePushRegistration;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Prepare a current verified-device registration. Token is write-only; install the native binding durably before explicit activation. Unknown outcomes require a read before explicit retry.
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [PreparePushRegistration] preparePushRegistration (required):
  Future<PushRegistration?> preparePushRegistration(String idempotencyKey, PreparePushRegistration preparePushRegistration, { Future<void>? abortTrigger, }) async {
    final response = await preparePushRegistrationWithHttpInfo(idempotencyKey, preparePushRegistration, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PushRegistration',) as PushRegistration;
    
    }
    return null;
  }

  /// Authenticated applicant-only private sample; never a public capability URL.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] uploadId (required):
  Future<Response> readListenerSampleWithHttpInfo(String id, String uploadId, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/listener-applications/{id}/uploads/{uploadId}'
      .replaceAll('{id}', id)
      .replaceAll('{uploadId}', uploadId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Authenticated applicant-only private sample; never a public capability URL.
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] uploadId (required):
  Future<MultipartFile?> readListenerSample(String id, String uploadId, { Future<void>? abortTrigger, }) async {
    final response = await readListenerSampleWithHttpInfo(id, uploadId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'MultipartFile',) as MultipartFile;
    
    }
    return null;
  }

  /// Report only local/remote RTC readiness. Video calls require videoReady and both audio and video readiness. No client duration or price. Heartbeat every two seconds; not provider proof.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [ReportMediaReadyRequest] reportMediaReadyRequest (required):
  Future<Response> reportMediaReadyWithHttpInfo(String id, ReportMediaReadyRequest reportMediaReadyRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/calls/{id}/media'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody = reportMediaReadyRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Report only local/remote RTC readiness. Video calls require videoReady and both audio and video readiness. No client duration or price. Heartbeat every two seconds; not provider proof.
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [ReportMediaReadyRequest] reportMediaReadyRequest (required):
  Future<Call?> reportMediaReady(String id, ReportMediaReadyRequest reportMediaReadyRequest, { Future<void>? abortTrigger, }) async {
    final response = await reportMediaReadyWithHttpInfo(id, reportMediaReadyRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Call',) as Call;
    
    }
    return null;
  }

  /// Requires provider authentication within five minutes. Withdraws account access and records deletion, retaining financial/dispute evidence for review. Client generates and securely persists a random 32-byte hex receipt capability before submitting.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DeletionRequest] deletionRequest (required):
  Future<Response> requestAccountDeletionWithHttpInfo(DeletionRequest deletionRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/deletion-requests';

    // ignore: prefer_final_locals
    Object? postBody = deletionRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Requires provider authentication within five minutes. Withdraws account access and records deletion, retaining financial/dispute evidence for review. Client generates and securely persists a random 32-byte hex receipt capability before submitting.
  ///
  /// Parameters:
  ///
  /// * [DeletionRequest] deletionRequest (required):
  Future<DeletionReceipt?> requestAccountDeletion(DeletionRequest deletionRequest, { Future<void>? abortTrigger, }) async {
    final response = await requestAccountDeletionWithHttpInfo(deletionRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'DeletionReceipt',) as DeletionReceipt;
    
    }
    return null;
  }

  /// Versioned consent and bounded app-level admission before native Firebase Phone Authentication. Does not send an SMS and cannot hard-limit direct Firebase SDK SMS requests. Enrollment requires matching fresh phone-provider proof within five minutes.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [OtpRequest] otpRequest (required):
  Future<Response> requestFirebasePhoneAdmissionWithHttpInfo(String idempotencyKey, OtpRequest otpRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/auth/firebase/admissions';

    // ignore: prefer_final_locals
    Object? postBody = otpRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Versioned consent and bounded app-level admission before native Firebase Phone Authentication. Does not send an SMS and cannot hard-limit direct Firebase SDK SMS requests. Enrollment requires matching fresh phone-provider proof within five minutes.
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [OtpRequest] otpRequest (required):
  Future<FirebasePhoneAdmission?> requestFirebasePhoneAdmission(String idempotencyKey, OtpRequest otpRequest, { Future<void>? abortTrigger, }) async {
    final response = await requestFirebasePhoneAdmissionWithHttpInfo(idempotencyKey, otpRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'FirebasePhoneAdmission',) as FirebasePhoneAdmission;
    
    }
    return null;
  }

  /// Disabled by default. Requires server-configured provider validation. Explicit versioned consent; never an app session.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [OtpRequest] otpRequest (required):
  Future<Response> requestOtpChallengeWithHttpInfo(String idempotencyKey, OtpRequest otpRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/auth/otp/request';

    // ignore: prefer_final_locals
    Object? postBody = otpRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Disabled by default. Requires server-configured provider validation. Explicit versioned consent; never an app session.
  ///
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [OtpRequest] otpRequest (required):
  Future<OtpChallenge?> requestOtpChallenge(String idempotencyKey, OtpRequest otpRequest, { Future<void>? abortTrigger, }) async {
    final response = await requestOtpChallengeWithHttpInfo(idempotencyKey, otpRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'OtpChallenge',) as OtpChallenge;
    
    }
    return null;
  }

  /// Performs an HTTP 'DELETE /v1/me/push/registration' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [RevokePushRegistration] revokePushRegistration (required):
  Future<Response> revokePushRegistrationWithHttpInfo(String idempotencyKey, RevokePushRegistration revokePushRegistration, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/push/registration';

    // ignore: prefer_final_locals
    Object? postBody = revokePushRegistration;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] idempotencyKey (required):
  ///
  /// * [RevokePushRegistration] revokePushRegistration (required):
  Future<PushRegistration?> revokePushRegistration(String idempotencyKey, RevokePushRegistration revokePushRegistration, { Future<void>? abortTrigger, }) async {
    final response = await revokePushRegistrationWithHttpInfo(idempotencyKey, revokePushRegistration, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PushRegistration',) as PushRegistration;
    
    }
    return null;
  }

  /// Performs an HTTP 'PUT /v1/me/availability' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [SetAvailabilityRequest] setAvailabilityRequest (required):
  Future<Response> setAvailabilityWithHttpInfo(SetAvailabilityRequest setAvailabilityRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/availability';

    // ignore: prefer_final_locals
    Object? postBody = setAvailabilityRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [SetAvailabilityRequest] setAvailabilityRequest (required):
  Future<User?> setAvailability(SetAvailabilityRequest setAvailabilityRequest, { Future<void>? abortTrigger, }) async {
    final response = await setAvailabilityWithHttpInfo(setAvailabilityRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'User',) as User;
    
    }
    return null;
  }

  /// Performs an HTTP 'PUT /v1/me/languages' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [SetLanguagesRequest] setLanguagesRequest (required):
  Future<Response> setLanguagesWithHttpInfo(SetLanguagesRequest setLanguagesRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/languages';

    // ignore: prefer_final_locals
    Object? postBody = setLanguagesRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [SetLanguagesRequest] setLanguagesRequest (required):
  Future<User?> setLanguages(SetLanguagesRequest setLanguagesRequest, { Future<void>? abortTrigger, }) async {
    final response = await setLanguagesWithHttpInfo(setLanguagesRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'User',) as User;
    
    }
    return null;
  }

  /// Performs an HTTP 'PUT /v1/me/mode' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [SetModeRequest] setModeRequest (required):
  Future<Response> setModeWithHttpInfo(SetModeRequest setModeRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/me/mode';

    // ignore: prefer_final_locals
    Object? postBody = setModeRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [SetModeRequest] setModeRequest (required):
  Future<User?> setMode(SetModeRequest setModeRequest, { Future<void>? abortTrigger, }) async {
    final response = await setModeWithHttpInfo(setModeRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'User',) as User;
    
    }
    return null;
  }

  /// Performs an HTTP 'POST /v1/auth/logout' operation and returns the [Response].
  Future<Response> signOutWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/auth/logout';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  Future<SignOut201Response?> signOut({ Future<void>? abortTrigger, }) async {
    final response = await signOutWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SignOut201Response',) as SignOut201Response;
    
    }
    return null;
  }

  /// Performs an HTTP 'POST /v1/listener-applications/{id}/submit' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  Future<Response> submitListenerApplicationWithHttpInfo(String id, String idempotencyKey, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/listener-applications/{id}/submit'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  Future<ListenerApplication?> submitListenerApplication(String id, String idempotencyKey, { Future<void>? abortTrigger, }) async {
    final response = await submitListenerApplicationWithHttpInfo(id, idempotencyKey, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListenerApplication',) as ListenerApplication;
    
    }
    return null;
  }

  /// Performs an HTTP 'DELETE /v1/favorites/{id}' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  Future<Response> unfavoriteListenerWithHttpInfo(String id, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/favorites/{id}'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  Future<FavoriteListener200Response?> unfavoriteListener(String id, { Future<void>? abortTrigger, }) async {
    final response = await unfavoriteListenerWithHttpInfo(id, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'FavoriteListener200Response',) as FavoriteListener200Response;
    
    }
    return null;
  }

  /// Performs an HTTP 'PUT /v1/listener-applications/{id}' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [ListenerApplicationInput] listenerApplicationInput (required):
  Future<Response> updateListenerApplicationWithHttpInfo(String id, ListenerApplicationInput listenerApplicationInput, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/listener-applications/{id}'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody = listenerApplicationInput;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [ListenerApplicationInput] listenerApplicationInput (required):
  Future<ListenerApplication?> updateListenerApplication(String id, ListenerApplicationInput listenerApplicationInput, { Future<void>? abortTrigger, }) async {
    final response = await updateListenerApplicationWithHttpInfo(id, listenerApplicationInput, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListenerApplication',) as ListenerApplication;
    
    }
    return null;
  }

  /// Performs an HTTP 'PUT /v1/listener-applications/{id}/uploads/{uploadId}' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] uploadId (required):
  ///
  /// * [String] xUploadToken (required):
  ///
  /// * [MultipartFile] body (required):
  Future<Response> uploadListenerSampleWithHttpInfo(String id, String uploadId, String xUploadToken, MultipartFile body, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/listener-applications/{id}/uploads/{uploadId}'
      .replaceAll('{id}', id)
      .replaceAll('{uploadId}', uploadId);

    // ignore: prefer_final_locals
    Object? postBody = body;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-Upload-Token'] = parameterToString(xUploadToken);

    const contentTypes = <String>['audio/wav'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] uploadId (required):
  ///
  /// * [String] xUploadToken (required):
  ///
  /// * [MultipartFile] body (required):
  Future<ListenerApplication?> uploadListenerSample(String id, String uploadId, String xUploadToken, MultipartFile body, { Future<void>? abortTrigger, }) async {
    final response = await uploadListenerSampleWithHttpInfo(id, uploadId, xUploadToken, body, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListenerApplication',) as ListenerApplication;
    
    }
    return null;
  }

  /// Consumes one challenge and returns a Firebase custom token, which must be exchanged for an ID token in the Firebase client. No app permissions or adult approval are granted.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [OtpVerifyRequest] otpVerifyRequest (required):
  Future<Response> verifyOtpChallengeWithHttpInfo(OtpVerifyRequest otpVerifyRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/auth/otp/verify';

    // ignore: prefer_final_locals
    Object? postBody = otpVerifyRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Consumes one challenge and returns a Firebase custom token, which must be exchanged for an ID token in the Firebase client. No app permissions or adult approval are granted.
  ///
  /// Parameters:
  ///
  /// * [OtpVerifyRequest] otpVerifyRequest (required):
  Future<OtpProof?> verifyOtpChallenge(OtpVerifyRequest otpVerifyRequest, { Future<void>? abortTrigger, }) async {
    final response = await verifyOtpChallengeWithHttpInfo(otpVerifyRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'OtpProof',) as OtpProof;
    
    }
    return null;
  }

  /// Verifies a Firebase ID token including revocation and its existing MSG91 identity binding. Returns an identity receipt, not an app session; onboarding and session integration remain separate.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [FirebaseVerifyRequest] firebaseVerifyRequest (required):
  Future<Response> verifyPhoneIdentityWithHttpInfo(FirebaseVerifyRequest firebaseVerifyRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/auth/firebase/verify';

    // ignore: prefer_final_locals
    Object? postBody = firebaseVerifyRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Verifies a Firebase ID token including revocation and its existing MSG91 identity binding. Returns an identity receipt, not an app session; onboarding and session integration remain separate.
  ///
  /// Parameters:
  ///
  /// * [FirebaseVerifyRequest] firebaseVerifyRequest (required):
  Future<PhoneIdentity?> verifyPhoneIdentity(FirebaseVerifyRequest firebaseVerifyRequest, { Future<void>? abortTrigger, }) async {
    final response = await verifyPhoneIdentityWithHttpInfo(firebaseVerifyRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PhoneIdentity',) as PhoneIdentity;
    
    }
    return null;
  }

  /// Performs an HTTP 'POST /v1/listener-applications/{id}/withdraw' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  Future<Response> withdrawListenerApplicationWithHttpInfo(String id, String idempotencyKey, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/v1/listener-applications/{id}/withdraw'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Parameters:
  ///
  /// * [String] id (required):
  ///
  /// * [String] idempotencyKey (required):
  Future<ListenerApplication?> withdrawListenerApplication(String id, String idempotencyKey, { Future<void>? abortTrigger, }) async {
    final response = await withdrawListenerApplicationWithHttpInfo(id, idempotencyKey, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ListenerApplication',) as ListenerApplication;
    
    }
    return null;
  }
}
