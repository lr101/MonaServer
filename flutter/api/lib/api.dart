//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

library openapi.api;

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

part 'api/admin_api.dart';
part 'api/admin_audiences_api.dart';
part 'api/admin_audit_api.dart';
part 'api/admin_campaigns_api.dart';
part 'api/admin_jobs_api.dart';
part 'api/admin_messages_api.dart';
part 'api/admin_reports_api.dart';
part 'api/admin_session_api.dart';
part 'api/admin_users_api.dart';
part 'api/auth_api.dart';
part 'api/batch_api.dart';
part 'api/groups_api.dart';
part 'api/likes_api.dart';
part 'api/members_api.dart';
part 'api/pins_api.dart';
part 'api/public_api.dart';
part 'api/public_auth_api.dart';
part 'api/ranking_api.dart';
part 'api/report_api.dart';
part 'api/session_auth_api.dart';
part 'api/users_api.dart';

part 'model/admin_action.dart';
part 'model/admin_action_kind.dart';
part 'model/admin_audience.dart';
part 'model/admin_audience_counts_dto.dart';
part 'model/admin_audience_exclusion_dto.dart';
part 'model/admin_audience_filter.dart';
part 'model/admin_audience_member_dto.dart';
part 'model/admin_audience_page_dto.dart';
part 'model/admin_audience_preview_accepted_dto.dart';
part 'model/admin_audience_preview_dto.dart';
part 'model/admin_audience_preview_request_dto.dart';
part 'model/admin_audience_preview_response_dto.dart';
part 'model/admin_audit_event_dto.dart';
part 'model/admin_audit_page_dto.dart';
part 'model/admin_campaign_channel.dart';
part 'model/admin_campaign_content_dto.dart';
part 'model/admin_campaign_create_request_dto.dart';
part 'model/admin_campaign_dto.dart';
part 'model/admin_campaign_page_dto.dart';
part 'model/admin_campaign_revision_request_dto.dart';
part 'model/admin_campaign_status.dart';
part 'model/admin_campaign_update_request_dto.dart';
part 'model/admin_job_accepted_dto.dart';
part 'model/admin_job_command_request_dto.dart';
part 'model/admin_job_create_request_dto.dart';
part 'model/admin_job_dto.dart';
part 'model/admin_job_page_dto.dart';
part 'model/admin_job_recipient_dto.dart';
part 'model/admin_job_recipient_page_dto.dart';
part 'model/admin_job_status.dart';
part 'model/admin_mail_dto.dart';
part 'model/admin_mfa_request_dto.dart';
part 'model/admin_reauthenticate_request_dto.dart';
part 'model/admin_report_dto.dart';
part 'model/admin_report_filter_dto.dart';
part 'model/admin_report_note_dto.dart';
part 'model/admin_report_note_page_dto.dart';
part 'model/admin_report_note_request_dto.dart';
part 'model/admin_report_page_dto.dart';
part 'model/admin_report_status.dart';
part 'model/admin_report_target_dto.dart';
part 'model/admin_report_update_request_dto.dart';
part 'model/admin_security_state.dart';
part 'model/admin_session_bootstrap_dto.dart';
part 'model/admin_session_dto.dart';
part 'model/admin_session_login_request_dto.dart';
part 'model/admin_session_login_response_dto.dart';
part 'model/admin_session_state.dart';
part 'model/admin_test_message_accepted_dto.dart';
part 'model/admin_test_message_request_dto.dart';
part 'model/admin_user_details_dto.dart';
part 'model/admin_user_dto.dart';
part 'model/admin_user_filter_dto.dart';
part 'model/admin_user_page_dto.dart';
part 'model/all_audience.dart';
part 'model/api_error_dto.dart';
part 'model/audience_kind.dart';
part 'model/audience_resource_kind.dart';
part 'model/batch_read_item.dart';
part 'model/batch_read_request.dart';
part 'model/batch_read_response.dart';
part 'model/batch_read_result.dart';
part 'model/create_group_dto.dart';
part 'model/create_like_dto.dart';
part 'model/email_action_dto.dart';
part 'model/email_link_exchange_request_dto.dart';
part 'model/email_link_exchange_response_dto.dart';
part 'model/email_link_request_accepted_dto.dart';
part 'model/email_link_request_dto.dart';
part 'model/filter_audience.dart';
part 'model/group_dto.dart';
part 'model/group_ranking_dto_inner.dart';
part 'model/groups_sync_dto.dart';
part 'model/info_dto.dart';
part 'model/login_link_action_dto.dart';
part 'model/map_info_dto.dart';
part 'model/mark_compromised_action_dto.dart';
part 'model/member_response_dto.dart';
part 'model/notification_dto.dart';
part 'model/pin_like_dto.dart';
part 'model/pin_request_dto.dart';
part 'model/pin_with_optional_image_dto.dart';
part 'model/pins_sync_dto.dart';
part 'model/push_action_dto.dart';
part 'model/ranking_search_dto_inner.dart';
part 'model/recovery_complete_request_dto.dart';
part 'model/recovery_resend_action_dto.dart';
part 'model/refresh_token_request_dto.dart';
part 'model/report_dismiss_action_dto.dart';
part 'model/report_dto.dart';
part 'model/report_resolve_action_dto.dart';
part 'model/revoke_sessions_action_dto.dart';
part 'model/season_dto.dart';
part 'model/season_item_dto.dart';
part 'model/selected_audience.dart';
part 'model/session_revoke_request_dto.dart';
part 'model/status.dart';
part 'model/sync_dto.dart';
part 'model/sync_dto_group_updates_inner.dart';
part 'model/token_response_dto.dart';
part 'model/update_group_dto.dart';
part 'model/user_achievements_dto_inner.dart';
part 'model/user_info_dto.dart';
part 'model/user_likes_dto.dart';
part 'model/user_login_request.dart';
part 'model/user_ranking_dto_inner.dart';
part 'model/user_request_dto.dart';
part 'model/user_update_dto.dart';
part 'model/user_update_response_dto.dart';
part 'model/user_xp_dto.dart';


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
