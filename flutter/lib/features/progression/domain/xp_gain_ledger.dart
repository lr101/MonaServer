/// Tracks confirmed XP totals within one account session.
class XpGainLedger {
  final _totals = <String, int>{};

  bool hasBaseline(String owner) => _totals.containsKey(owner);

  int observe(String owner, int totalXp) {
    final previous = _totals[owner];
    if (previous != null && totalXp <= previous) return 0;
    _totals[owner] = totalXp;
    return previous == null ? 0 : totalXp - previous;
  }
}

class XpGain {
  const XpGain({
    required this.owner,
    required this.amount,
    required this.level,
  });

  /// `user:<id>` or `group:<id>`; keeps independently earned XP distinct.
  final String owner;
  final int amount;
  final int level;
  bool get isGroup => owner.startsWith('group:');
  String get id => owner.substring(owner.indexOf(':') + 1);
}
