import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_campaigns/domain/admin_campaign_models.dart';

/// App wiring adapts this pure port to the generated admin APIs.
abstract interface class AdminCampaignRepository
    implements AdminAudiencePreviewPort {
  Future<AdminCampaignCommitResult> commit(AdminCampaignCommitCommand command);

  /// This endpoint only accepts an explicit account ID; it is never a broadcast.
  Future<AdminCampaignTestResult> sendTest({
    required String recipientUserId,
    required AdminAudienceAction action,
  });
}
