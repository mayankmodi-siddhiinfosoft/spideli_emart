import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_summary_builder.dart';
import 'package:customer/utils/shared_latest.dart';

/// The dashboard totals, live, worked out on the device from the user's own
/// records ([FinanceSummaryBuilder]). One subscription per source, shared
/// by every screen (Home, Insights, Savings, Tontines, Investments); the
/// first value once every source has answered (or after a few seconds), so
/// the totals do not grow line by line. A source the user cannot read
/// counts as empty.
abstract final class FinanceSummaryService {
  static final Map<String, SharedLatest<FinanceSummary?>> _byUser = {};

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static Stream<FinanceSummary?> stream() => _byUser.putIfAbsent(FinanceService.uid, () => SharedLatest<FinanceSummary?>(_open)).stream;

  /// A Firestore timestamp or a DateTime as a DateTime.
  static DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  static List<Map<String, dynamic>> _docs(QuerySnapshot<Map<String, dynamic>> q) => [for (final d in q.docs) {...d.data(), 'id': d.id}];

  static Stream<FinanceSummary?> _open() {
    final String uid = FinanceService.uid;
    final List<StreamSubscription<dynamic>> subs = [];
    final Map<String, StreamSubscription<dynamic>> scheduleSubs = {};
    final Map<String, StreamSubscription<dynamic>> paidSubs = {};
    final Set<String> answered = {};
    const int sources = 10;
    Timer? fallback;
    var accounts = <Map<String, dynamic>>[], holdings = <Map<String, dynamic>>[], goals = <Map<String, dynamic>>[], tontines = <Map<String, dynamic>>[];
    var borrowed = <Map<String, dynamic>>[], lentLoans = <Map<String, dynamic>>[], fundings = <Map<String, dynamic>>[];
    var policies = <Map<String, dynamic>>[], claims = <Map<String, dynamic>>[], ledger = <Map<String, dynamic>>[];
    final Map<String, List<Map<String, dynamic>>> schedules = {};
    final Map<String, bool> paid = {};
    late final StreamController<FinanceSummary?> out;

    void emit({bool force = false}) {
      if (out.isClosed || (!force && answered.length < sources)) return;
      final raw = FinanceSummaryBuilder.build(
        FinanceSummarySources(
          accounts: accounts,
          holdings: holdings,
          goals: goals,
          tontines: tontines,
          paidCurrentCycle: paid,
          borrowed: borrowed,
          schedules: schedules,
          lentLoans: lentLoans,
          fundings: fundings,
          policies: policies,
          claims: claims,
          ledger: ledger,
        ),
        uid: uid,
        now: DateTime.now(),
        toDate: toDate,
      );
      out.add(FinanceSummary.parse(raw, toDate: toDate));
    }

    void listen(String name, Stream<List<Map<String, dynamic>>> source, void Function(List<Map<String, dynamic>> value) set) {
      subs.add(source.listen((value) {
        set(value);
        answered.add(name);
        emit();
      }, onError: (_) {
        answered.add(name);
        emit();
      }));
    }

    Stream<List<Map<String, dynamic>>> q(Query<Map<String, dynamic>> query) => query.snapshots().map(_docs);

    // The schedule of each loan the user is repaying.
    void watchSchedules() {
      final Set<String> ids = {for (final l in borrowed) if (l['status'] == 'active' || l['status'] == 'overdue') l['id'].toString()};
      for (final id in scheduleSubs.keys.where((id) => !ids.contains(id)).toList()) {
        scheduleSubs.remove(id)?.cancel();
        schedules.remove(id);
      }
      for (final id in ids.where((id) => !scheduleSubs.containsKey(id))) {
        scheduleSubs[id] = _db.doc('loan_schedules/$id').snapshots().listen((d) {
          schedules[id] = ((d.data()?['installments'] as List?) ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
          emit();
        }, onError: (_) {});
      }
    }

    // Whether the user already paid the current cycle of each active
    // tontine (`tontine_contributions/{tontineId}_{cycle}_{uid}`).
    void watchContributions() {
      final Map<String, String> current = {
        for (final t in tontines)
          if (t['status'] == 'active' && t['currentCycle'] != null) t['id'].toString(): '${t['id']}_${t['currentCycle']}_$uid',
      };
      for (final id in paidSubs.keys.where((id) => !current.containsKey(id)).toList()) {
        paidSubs.remove(id)?.cancel();
        paid.remove(id);
      }
      for (final e in current.entries) {
        paidSubs[e.key]?.cancel();
        paidSubs[e.key] = _db.doc('tontine_contributions/${e.value}').snapshots().listen((d) {
          paid[e.key] = d.exists && d.data()?['status'] == 'paid';
          emit();
        }, onError: (_) {});
      }
    }

    out = StreamController<FinanceSummary?>(
      onListen: () {
        final DateTime from = DateTime.now().subtract(const Duration(days: 366));
        listen('accounts', FinanceService.myAccounts().map((l) => [for (final a in l) {...a, 'id': a['id'] ?? ''}]), (v) => accounts = v);
        listen('holdings', q(_db.collection('investment_holdings').where('userId', isEqualTo: uid)), (v) => holdings = v);
        listen('goals', q(_db.collection('savings_goals').where('memberIds', arrayContains: uid)), (v) => goals = v);
        listen('tontines', q(_db.collection('tontines').where('memberIds', arrayContains: uid)), (v) {
          tontines = v;
          watchContributions();
        });
        listen('borrowed', q(_db.collection('loan_applications').where('borrowerId', isEqualTo: uid).limit(50)), (v) {
          borrowed = v;
          watchSchedules();
        });
        listen('lent', q(_db.collection('loan_applications').where('lenderIds', arrayContains: uid).limit(50)), (v) => lentLoans = v);
        listen('fundings', q(_db.collection('loan_fundings').where('lenderId', isEqualTo: uid)), (v) => fundings = v);
        listen('policies', q(_db.collection('insurance_policies').where('userId', isEqualTo: uid).limit(50)), (v) => policies = v);
        listen('claims', q(_db.collection('insurance_claims').where('userId', isEqualTo: uid).limit(50)), (v) => claims = v);
        listen(
          'ledger',
          q(_db
              .collection('ledger_transactions')
              .where('userIds', arrayContains: uid)
              .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
              .orderBy('createdAt', descending: true)
              .limit(500)),
          (v) => ledger = v,
        );
        fallback = Timer(const Duration(seconds: 5), () => emit(force: true));
      },
      onCancel: () {
        for (final s in [...subs, ...scheduleSubs.values, ...paidSubs.values]) {
          s.cancel();
        }
        fallback?.cancel();
      },
    );
    return out.stream;
  }

  /// Opens the totals again after a failure (the dashboard's Retry).
  static void retry() => _byUser[FinanceService.uid]?.retry();
}
