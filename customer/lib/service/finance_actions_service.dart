import 'dart:async';

import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_insurance_service.dart';
import 'package:customer/service/finance_lending_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/service/finance_transfer_service.dart';
import 'package:customer/utils/finance_actions.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_lending_rules.dart';
import 'package:customer/utils/shared_latest.dart';

/// The live "Needs your action" list of the Finance dashboard
/// ([FinanceActions.collect]) from the records the app already reads:
/// invitations, group loans (and the user's own vote on each one in
/// voting), the user's loans, insurance quotes and claims, transfers and
/// bill payments. One subscription per source, shared by every reader; a
/// source the user cannot read (not enabled, refused) counts as nothing to
/// do, never as an error of the list. Re-checked every minute so expiring
/// confirmations and quotes leave on time.
abstract final class FinanceActionsService {
  static final Map<String, SharedLatest<List<FinanceAction>>> _byUser = {};

  static Stream<List<FinanceAction>> stream() => _byUser.putIfAbsent(FinanceService.uid, () => SharedLatest<List<FinanceAction>>(_open)).stream;

  static Stream<List<FinanceAction>> _open() {
    final String uid = FinanceService.uid;
    final List<StreamSubscription<dynamic>> subs = [];
    final Map<String, StreamSubscription<dynamic>> voteSubs = {};
    final Set<String> voted = {};
    final Set<String> answered = {};
    const int sources = 8;
    Timer? tick;
    Timer? fallback;
    List<Map<String, dynamic>> invitations = const [], quotes = const [], claims = const [], transfers = const [], bills = const [];
    List<SavingsGoal> goals = const [];
    List<Loan> group = const [], mine = const [];
    late final StreamController<List<FinanceAction>> out;

    void emit({bool force = false}) {
      // The first list once every source has answered (or after a few
      // seconds), so it does not grow item by item while loading.
      if (out.isClosed || (!force && answered.length < sources)) return;
      out.add(FinanceActions.collect(
        uid: uid,
        now: DateTime.now(),
        tontineInvitations: invitations,
        goalInvitations: goals,
        groupLoans: group,
        votedLoanIds: voted,
        borrowed: mine,
        quotes: quotes,
        claims: claims,
        transfers: transfers,
        bills: bills,
        toDate: FinanceGroupService.toDate,
      ));
    }

    // Whether the user already voted on each loan in voting.
    void watchVotes() {
      final Set<String> voting = {for (final l in group) if (l.status == 'voting' && l.id.isNotEmpty) l.id};
      for (final id in voteSubs.keys.where((id) => !voting.contains(id)).toList()) {
        voteSubs.remove(id)?.cancel();
        voted.remove(id);
      }
      for (final id in voting.where((id) => !voteSubs.containsKey(id))) {
        voteSubs[id] = FinanceLendingService.myVote(id).listen((v) {
          v == null ? voted.remove(id) : voted.add(id);
          emit();
        }, onError: (_) {});
      }
    }

    void listen<T>(String name, Stream<T> source, void Function(T value) set) {
      subs.add(source.listen((value) {
        set(value);
        answered.add(name);
        emit();
      }, onError: (_) {
        answered.add(name);
        emit();
      }));
    }

    out = StreamController<List<FinanceAction>>(
      onListen: () {
        listen<List<Map<String, dynamic>>>('tontines', FinanceGroupService.tontineInvitations(), (v) => invitations = v);
        listen<List<SavingsGoal>>('goals', FinanceGroupService.goalInvitations(), (v) => goals = v);
        listen<List<Loan>>('group', FinanceLendingService.groupRequests(), (v) {
          group = v;
          watchVotes();
        });
        listen<List<Loan>>('mine', FinanceLendingService.borrowed(), (v) => mine = v);
        listen<List<Map<String, dynamic>>>('quotes', FinanceInsuranceService.quotes(), (v) => quotes = v);
        listen<List<Map<String, dynamic>>>('claims', FinanceInsuranceService.claims(), (v) => claims = v);
        listen<List<Map<String, dynamic>>>('transfers', FinanceTransferService.transfers(), (v) => transfers = v);
        listen<List<Map<String, dynamic>>>('bills', FinanceTransferService.billPayments(), (v) => bills = v);
        fallback = Timer(const Duration(seconds: 4), () => emit(force: true));
        tick = Timer.periodic(const Duration(minutes: 1), (_) => emit(force: true));
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
        for (final s in voteSubs.values) {
          s.cancel();
        }
        fallback?.cancel();
        tick?.cancel();
      },
    );
    return out.stream;
  }
}
