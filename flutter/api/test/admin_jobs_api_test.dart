//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

import 'package:openapi/api.dart';
import 'package:test/test.dart';


/// tests for AdminJobsApi
void main() {
  // final instance = AdminJobsApi();

  group('tests for AdminJobsApi', () {
    // Cancel pending job work
    //
    //Future<AdminJobAcceptedDto> cancelAdminJob(String jobId, String xCSRFToken, String idempotencyKey, AdminJobCommandRequestDto adminJobCommandRequestDto) async
    test('test cancelAdminJob', () async {
      // TODO
    });

    // Commit an administrative action job
    //
    // Commit exactly one unexpired preview snapshot and action. The Idempotency-Key header is required.
    //
    //Future<AdminJobAcceptedDto> createAdminJob(String xCSRFToken, String idempotencyKey, AdminJobCreateRequestDto adminJobCreateRequestDto) async
    test('test createAdminJob', () async {
      // TODO
    });

    // Read an administrative job
    //
    //Future<AdminJobDto> getAdminJob(String jobId) async
    test('test getAdminJob', () async {
      // TODO
    });

    // List job recipient outcomes
    //
    //Future<AdminJobRecipientPageDto> listAdminJobRecipients(String jobId, { String cursor, int limit }) async
    test('test listAdminJobRecipients', () async {
      // TODO
    });

    // List administrative action jobs
    //
    //Future<AdminJobPageDto> listAdminJobs({ String cursor, int limit, AdminJobStatus status, AdminActionKind action }) async
    test('test listAdminJobs', () async {
      // TODO
    });

    // Retry eligible failed job work
    //
    //Future<AdminJobAcceptedDto> retryAdminJob(String jobId, String xCSRFToken, String idempotencyKey, AdminJobCommandRequestDto adminJobCommandRequestDto) async
    test('test retryAdminJob', () async {
      // TODO
    });

  });
}
