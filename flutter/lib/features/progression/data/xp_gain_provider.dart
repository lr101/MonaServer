import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/features/progression/domain/xp_gain_ledger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final xpGainsProvider = NotifierProvider<XpGains, List<XpGain>>(XpGains.new);

class XpGains extends Notifier<List<XpGain>> {
  var _ledger = XpGainLedger();

  @override
  List<XpGain> build() {
    ref.watch(accountSessionProvider);
    _ledger = XpGainLedger();
    return const [];
  }

  void observe(String owner, int totalXp, int level) {
    if (!ref.read(accountSessionProvider).isActive) return;
    final amount = _ledger.observe(owner, totalXp);
    if (amount == 0) return;
    final existing = state.where((gain) => gain.owner == owner).firstOrNull;
    state = [
      ...state.where((gain) => gain.owner != owner),
      XpGain(
        owner: owner,
        amount: amount + (existing?.amount ?? 0),
        level: level,
      ),
    ];
  }

  bool hasBaseline(String owner) => _ledger.hasBaseline(owner);

  void dismiss() => state = const [];
}
