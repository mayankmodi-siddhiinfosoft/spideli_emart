import 'package:customer/utils/finance_group_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime? _d(dynamic v) => v is DateTime ? v : null;

void main() {
  group('configuration (fails closed)', () {
    test('savings', () {
      expect(SavingsConfig.parse(null), isNull);
      expect(SavingsConfig.parse({'purposes': ['travel'], 'currencies': ['XAF'], 'paymentMethods': []}), isNull);
      final c = SavingsConfig.parse({
        'purposes': ['travel', 'education'],
        'currencies': ['XAF', 'bad'],
        'frequencies': ['monthly', 'yearly'],
        'groupGoals': true,
        'maxMembers': 5,
        'earlyWithdrawal': {'allowed': true},
        'paymentMethods': ['wallet', 'mobile_money'],
      })!;
      expect(c.currencies, ['XAF']);
      expect(c.frequencies, ['monthly']);
      expect(c.earlyWithdrawal, isTrue);
      expect(c.maxMembers, 5);
    });
    test('tontines', () {
      expect(TontineConfig.parse({'currencies': ['XAF'], 'frequencies': ['monthly'], 'paymentMethods': ['wallet'], 'minMembers': 1, 'maxMembers': 10}), isNull);
      final c = TontineConfig.parse({
        'currencies': ['XAF'],
        'frequencies': ['weekly', 'monthly'],
        'paymentMethods': ['wallet'],
        'minMembers': 3,
        'maxMembers': 20,
        'minContribution': {'XAF': 1000},
      })!;
      expect(c.minFor('XAF'), 1000);
      expect(c.minFor('XOF'), 1);
      expect(c.payoutOrderMethods, ['fixed']);
    });
  });

  group('savings projections use deposited funds, never the target', () {
    SavingsGoal goal({int saved = 30000, int target = 120000, String? freq, int sched = 0, DateTime? deadline}) => SavingsGoal.fromMap({
          'id': 'g',
          'name': 'Trip',
          'currency': 'XAF',
          'targetAmount': target,
          'savedAmount': saved,
          'deadline': deadline,
          'schedule': {'frequency': freq, 'amount': sched},
          'memberIds': ['u'],
        }, _d);
    final now = DateTime(2026, 10, 13);

    test('progress and remaining', () {
      expect(goal().progress, 0.25);
      expect(goal().remaining, 90000);
      expect(goal(saved: 200000).remaining, 0);
      expect(goal(saved: 200000).progress, 1.0);
    });
    test('the schedule sets the rate; otherwise the average of received contributions', () {
      expect(SavingsProjection.monthlyRate(goal(freq: 'monthly', sched: 10000), const [], now), 10000);
      expect(SavingsProjection.monthlyRate(goal(freq: 'weekly', sched: 1200), const [], now), closeTo(5200, 0.01));
      final contribs = [DatedAmount(DateTime(2026, 8, 13), 10000), DatedAmount(DateTime(2026, 9, 13), 10000), DatedAmount(DateTime(2026, 10, 1), 10000)];
      expect(SavingsProjection.monthlyRate(goal(), contribs, now), closeTo(30000 / (61 / 30.44), 1));
      // One deposit today is not a monthly rate of its own size per day.
      expect(SavingsProjection.monthlyRate(goal(), [DatedAmount(now, 5000)], now), 5000);
      expect(SavingsProjection.monthlyRate(goal(), const [], now), 0);
    });
    test('completion date, needed monthly amount and on-track', () {
      final g = goal(freq: 'monthly', sched: 10000, deadline: DateTime(2027, 4, 13));
      final p = SavingsProjection.projectedCompletion(g, 10000, now)!;
      expect(p.difference(now).inDays, (9 * 30.44).ceil());
      expect(SavingsProjection.neededMonthly(g, now), 15000);
      expect(SavingsProjection.onTrack(g, p), isFalse);
      expect(SavingsProjection.projectedCompletion(goal(), 0, now), isNull);
      expect(SavingsProjection.projectedCompletion(goal(saved: 120000), 0, now), now);
      expect(SavingsProjection.neededMonthly(goal(deadline: DateTime(2026, 10, 30)), now), 90000);
      expect(SavingsProjection.neededMonthly(goal(), now), isNull);
    });
  });

  group('tontines', () {
    Tontine t({String status = 'forming', List<String> members = const ['a', 'b', 'c'], String freq = 'monthly', DateTime? start, String order = 'fixed'}) => Tontine.fromMap({
          'id': 't',
          'name': 'Family',
          'currency': 'XAF',
          'contributionAmount': 5000,
          'frequency': freq,
          'membersLimit': 4,
          'payoutOrderMethod': order,
          'status': status,
          'adminIds': ['a'],
          'memberIds': members,
          'startDate': start,
        }, _d);
    final cfg = TontineConfig.parse({'currencies': ['XAF'], 'frequencies': ['monthly'], 'paymentMethods': ['wallet'], 'minMembers': 3, 'maxMembers': 20})!;

    test('pot and schedule (one cycle per member; month ends clamp)', () {
      expect(t().potPerCycle, 15000);
      expect(t(start: DateTime(2026, 1, 31)).schedule(), [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 28)]);
      expect(t(freq: 'biweekly', start: DateTime(2026, 10, 1)).schedule().last, DateTime(2026, 10, 29));
      expect(t().schedule(), isEmpty);
    });
    test('admin actions mirror the server', () {
      expect(TontineActions.canInvite(t(), 'a', 3), isTrue);
      expect(TontineActions.canInvite(t(), 'a', 4), isFalse);
      expect(TontineActions.canInvite(t(), 'b', 3), isFalse);
      expect(TontineActions.startBlocker(t(), 'a', cfg, const ['c', 'a', 'b']), isNull);
      expect(TontineActions.startBlocker(t(), 'a', cfg, const ['a', 'b']), 'Set the payout order for every member first.');
      expect(TontineActions.startBlocker(t(order: 'random'), 'a', cfg, const []), isNull);
      expect(TontineActions.startBlocker(t(members: const ['a', 'b']), 'a', cfg, const ['a', 'b']), 'More members are needed to start.');
      expect(TontineActions.startBlocker(t(), 'b', cfg, const ['a', 'b', 'c']), 'Only an administrator of the tontine can start it.');
      expect(TontineActions.startBlocker(t(status: 'active'), 'a', cfg, const ['a', 'b', 'c']), 'This tontine has already started.');
    });
    test('cycle transparency: paid wins; missing becomes overdue after the due date', () {
      final contributions = [
        {'userId': 'a', 'status': 'failed', 'amount': 5000},
        {'userId': 'a', 'status': 'paid', 'amount': 5000},
        {'userId': 'b', 'status': 'pending', 'amount': 5000},
        {'userId': 'zz', 'status': 'paid', 'amount': 5000},
      ];
      final before = CycleSummary.of(contributions, const ['a', 'b', 'c'], 5000, DateTime(2026, 10, 20), DateTime(2026, 10, 13));
      expect([before.paid, before.pending, before.overdue], [1, 2, 0]);
      expect(before.collected, 5000);
      expect(before.expected, 15000);
      final after = CycleSummary.of(contributions, const ['a', 'b', 'c'], 5000, DateTime(2026, 10, 1), DateTime(2026, 10, 13));
      expect(after.statusByMember, {'a': 'paid', 'b': 'overdue', 'c': 'overdue'});
    });
  });

  test('labels', () {
    expect(GroupLabels.purpose('real_estate'), 'Real estate');
    expect(GroupLabels.purpose('boat'), 'Boat');
    expect(Frequency.label('biweekly'), 'Every two weeks');
    expect(GroupLabels.method('mobile_money'), 'Mobile Money');
  });
}
