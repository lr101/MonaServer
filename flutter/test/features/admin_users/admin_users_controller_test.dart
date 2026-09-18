import 'dart:async';

import 'package:buff_lisa/features/admin_users/domain/admin_user_models.dart';
import 'package:buff_lisa/features/admin_users/domain/admin_user_ports.dart';
import 'package:buff_lisa/features/admin_users/presentation/admin_users_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps selected IDs when another page is loaded', () async {
    final repository = _FakeAdminUsersRepository([
      AdminUserPage(items: [_user('one')], nextCursor: 'next'),
      AdminUserPage(items: [_user('two')]),
    ]);
    final controller = AdminUsersController(repository);

    await controller.searchUsers('');
    controller.toggleSelection('one');
    await controller.loadNextPage();
    controller.toggleSelection('two');

    expect(controller.state.users.map((user) => user.id), ['one', 'two']);
    expect(controller.state.selectedIds, {'one', 'two'});
  });

  test('ignores a stale search result after a newer query completes', () async {
    final first = Completer<AdminUserPage>();
    final repository = _SequencedAdminUsersRepository({
      'old': first.future,
      'new': Future.value(AdminUserPage(items: [_user('new')])),
    });
    final controller = AdminUsersController(repository);

    final oldSearch = controller.searchUsers('old');
    await controller.searchUsers('new');
    first.complete(AdminUserPage(items: [_user('old')]));
    await oldSearch;

    expect(controller.state.query, 'new');
    expect(controller.state.users.single.id, 'new');
  });

  test('changing search clears selection from the old result set', () async {
    final repository = _FakeAdminUsersRepository([
      AdminUserPage(items: [_user('one')]),
      AdminUserPage(items: [_user('two')]),
    ]);
    final controller = AdminUsersController(repository);

    await controller.searchUsers('one');
    controller.toggleSelection('one');
    await controller.searchUsers('two');

    expect(controller.state.selectedIds, isEmpty);
    expect(controller.state.users.single.id, 'two');
  });

  test(
    'overlapping pagination and detail requests both settle loading state',
    () async {
      final nextPage = Completer<AdminUserPage>();
      final details = Completer<AdminUserDetails?>();
      final repository = _OverlappingAdminUsersRepository(nextPage, details);
      final controller = AdminUsersController(repository);

      await controller.searchUsers('');
      final pageLoad = controller.loadNextPage();
      final detailLoad = controller.loadDetails('one');

      nextPage.complete(AdminUserPage(items: [_user('two')]));
      await pageLoad;
      expect(controller.state.loading, isFalse);
      expect(controller.state.loadingDetail, isTrue);

      details.complete(_details('one'));
      await detailLoad;
      expect(controller.state.loading, isFalse);
      expect(controller.state.loadingDetail, isFalse);
      expect(controller.state.selectedDetail?.id, 'one');
    },
  );
}

AdminUserRecord _user(String id) => AdminUserRecord(
  id: id,
  username: id,
  email: '$id@example.com',
  emailVerified: true,
  securityStatus: AdminSecurityStatus.normal,
  createdAt: DateTime.utc(2026, 1, 1),
  isAdmin: false,
  passwordDisabled: false,
  passwordResetRequired: false,
  authGeneration: 0,
  eligibilityReasons: const [],
);

final class _FakeAdminUsersRepository implements AdminUsersRepository {
  _FakeAdminUsersRepository(this.pages);

  final List<AdminUserPage> pages;
  var calls = 0;

  @override
  Future<AdminUserDetails?> getUser(String userId) async => null;

  @override
  Future<AdminUserPage> listUsers(AdminUserQuery query) async {
    return pages[calls++];
  }
}

final class _SequencedAdminUsersRepository implements AdminUsersRepository {
  _SequencedAdminUsersRepository(this.results);

  final Map<String, Future<AdminUserPage>> results;

  @override
  Future<AdminUserDetails?> getUser(String userId) async => null;

  @override
  Future<AdminUserPage> listUsers(AdminUserQuery query) =>
      results[query.search]!;
}

final class _OverlappingAdminUsersRepository implements AdminUsersRepository {
  _OverlappingAdminUsersRepository(this.nextPage, this.details);

  final Completer<AdminUserPage> nextPage;
  final Completer<AdminUserDetails?> details;
  var firstCall = true;

  @override
  Future<AdminUserDetails?> getUser(String userId) => details.future;

  @override
  Future<AdminUserPage> listUsers(AdminUserQuery query) {
    if (firstCall) {
      firstCall = false;
      return Future.value(
        AdminUserPage(items: [_user('one')], nextCursor: 'next'),
      );
    }
    return nextPage.future;
  }
}

AdminUserDetails _details(String id) => AdminUserDetails(
  id: id,
  username: id,
  email: '$id@example.com',
  emailVerified: true,
  securityStatus: AdminSecurityStatus.normal,
  createdAt: DateTime.utc(2026, 1, 1),
  isAdmin: false,
  passwordDisabled: false,
  passwordResetRequired: false,
  authGeneration: 0,
  eligibilityReasons: const [],
  communicationOptOut: false,
  registeredDeviceCount: 1,
);
