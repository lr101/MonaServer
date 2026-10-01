import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

/// The privacy-safe level and fractional progress shown on public profiles.
final publicUserProgressionProvider =
    FutureProvider.family<ProfileProgressionDto?, String>((ref, userId) async {
      if (!ref.watch(accountSessionProvider).isActive) return null;
      try {
        final result = await ref
            .watch(batchReadCoalescerProvider)
            .readKey(BatchReadKey(BatchReadKind.userProgression, userId));
        return result.progression;
      } catch (_) {
        return null;
      }
    });
