import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test(
    'sends structured report DTO fields through the live report service',
    () async {
      final reportApi = _RecordingReportApi();
      final container = ProviderContainer(
        overrides: [
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'reporter',
              refreshToken: null,
              cameras: [],
            ),
          ),
          reportApiProvider.overrideWithValue(reportApi),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(authServiceProvider.notifier)
          .reportDto(
            ReportDto(
              userId: 'reporter',
              report: 'legacy context',
              message: 'Details',
              targetId: 'target-user',
              targetKind: 'user',
            ),
          );

      expect(result, isNull);
      expect(reportApi.request?.targetId, 'target-user');
      expect(reportApi.request?.targetKind, 'user');
      expect(reportApi.request?.report, 'legacy context');
    },
  );
}

final class _RecordingReportApi extends ReportApi {
  ReportDto? request;

  @override
  Future<void> createReport(
    ReportDto reportDto, {
    String? idempotencyKey,
  }) async {
    request = reportDto;
  }
}
