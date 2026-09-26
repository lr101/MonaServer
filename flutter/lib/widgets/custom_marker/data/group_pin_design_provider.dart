import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

final groupPinDesignCatalogProvider =
    FutureProvider.family<GroupPinDesignCatalogDto?, String>((ref, groupId) {
      final session = ref.watch(accountSessionProvider);
      if (!session.isActive) return null;
      return ref
          .watch(groupPinDesignsApiProvider)
          .getGroupPinDesignCatalog(groupId);
    });
