import 'package:buff_lisa/features/progression/domain/xp_gain_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'only celebrates new XP, never initial load, retries or stale totals',
    () {
      final ledger = XpGainLedger();
      expect(ledger.observe('user:a', 90), 0);
      expect(ledger.observe('group:b', 400), 0);
      expect(ledger.observe('user:a', 110), 20);
      expect(ledger.observe('group:b', 410), 10);
      expect(ledger.observe('user:a', 110), 0);
      expect(ledger.observe('user:a', 90), 0);
      expect(ledger.observe('user:a', 110), 0);
      expect(ledger.observe('user:a', 115), 5);
    },
  );

  test('a new session starts without celebrating historical XP', () {
    final first = XpGainLedger();
    first.observe('user:a', 90);
    expect(first.observe('user:a', 100), 10);
    expect(XpGainLedger().observe('user:a', 100), 0);
  });
}
