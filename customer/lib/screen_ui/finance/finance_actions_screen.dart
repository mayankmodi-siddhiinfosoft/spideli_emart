import 'package:customer/screen_ui/finance/bill_screens.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/insurance_screens.dart';
import 'package:customer/screen_ui/finance/lending_screens.dart';
import 'package:customer/screen_ui/finance/savings_screens.dart';
import 'package:customer/screen_ui/finance/tontine_screens.dart';
import 'package:customer/screen_ui/finance/transfer_screens.dart';
import 'package:customer/service/finance_actions_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_actions.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Home > "Needs your action": what the user has to answer (invitations,
/// votes, agreements, confirmations, quotes, claims), urgent first. Hidden
/// while it loads and when nothing waits, so the dashboard does not jump or
/// show an empty block.
class FinanceActionsSection extends StatelessWidget {
  const FinanceActionsSection({super.key});

  /// How many the dashboard shows; the rest are one tap away.
  static const int shown = 3;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FinanceAction>>(
      stream: FinanceActionsService.stream(),
      builder: (context, snap) {
        final all = snap.data ?? const <FinanceAction>[];
        if (all.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: '${"Needs your action".tr} (${all.length})',
          actionLabel: all.length > shown ? "See all".tr : null,
          onAction: () => Get.to(() => const FinanceActionsScreen()),
          divided: true,
          children: [for (final a in all.take(shown)) FinanceActionTile(action: a)],
        );
      },
    );
  }
}

/// Every action waiting for the user.
class FinanceActionsScreen extends StatelessWidget {
  const FinanceActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Needs your action".tr,
      body: StreamBuilder<List<FinanceAction>>(
        stream: FinanceActionsService.stream(),
        builder: (context, snap) {
          if (!snap.hasData) return FinBody(children: [FinState.loading(rows: 4)]);
          final all = snap.data!;
          if (all.isEmpty) {
            return FinBody(children: [FinState.empty(Icons.task_alt_rounded, "You are all set.".tr, message: "Nothing needs your action right now.".tr)]);
          }
          return FinBody(children: [
            FinSection(
              divided: true,
              footnote: "Invitations, votes, agreements and confirmations waiting for you, the most pressing first.".tr,
              children: [for (final a in all) FinanceActionTile(action: a)],
            ),
          ]);
        },
      ),
    );
  }
}

class FinanceActionTile extends StatelessWidget {
  final FinanceAction action;

  const FinanceActionTile({super.key, required this.action});

  static IconData _icon(FinanceActionKind k) => switch (k) {
        FinanceActionKind.tontineInvitation => Icons.groups_2_outlined,
        FinanceActionKind.goalInvitation => Icons.savings_outlined,
        FinanceActionKind.loanVote => Icons.how_to_vote_outlined,
        FinanceActionKind.loanFunding => Icons.volunteer_activism_outlined,
        FinanceActionKind.loanAgreement => Icons.description_outlined,
        FinanceActionKind.loanOverdue => Icons.warning_amber_rounded,
        FinanceActionKind.insuranceQuote => Icons.request_quote_outlined,
        FinanceActionKind.claimInformation => Icons.assignment_late_outlined,
        FinanceActionKind.transferConfirmation => Icons.north_east_rounded,
        FinanceActionKind.billConfirmation => Icons.receipt_outlined,
      };

  /// The status chip (text and icon, never colour alone).
  static (String, String)? _status(FinanceActionKind k) => switch (k) {
        FinanceActionKind.loanOverdue => ('overdue', "Overdue"),
        FinanceActionKind.transferConfirmation || FinanceActionKind.billConfirmation => ('awaiting_confirmation', "To confirm"),
        FinanceActionKind.loanAgreement => ('agreement_pending', "To accept"),
        FinanceActionKind.claimInformation => ('info_requested', "Information needed"),
        FinanceActionKind.tontineInvitation || FinanceActionKind.goalInvitation => ('invited', "Invited"),
        FinanceActionKind.loanVote => ('voting', "Vote open"),
        _ => null,
      };

  /// When it has to be done by, in words.
  static String? _due(FinanceAction a, DateTime now) {
    final d = a.dueAt;
    if (d == null) return null;
    final bool today = d.year == now.year && d.month == now.month && d.day == now.day;
    final String at = ltr(today ? DateFormat('HH:mm').format(d) : DateFormat('dd MMM, HH:mm').format(d));
    return switch (a.kind) {
      FinanceActionKind.loanVote => '${"Voting ends".tr} $at',
      FinanceActionKind.insuranceQuote => '${"Valid until".tr} $at',
      _ => '${"Expires".tr} $at',
    };
  }

  /// Opens the screen where it is done.
  static void open(FinanceAction a) {
    switch (a.kind) {
      case FinanceActionKind.tontineInvitation:
        Get.to(() => const TontineListScreen());
      case FinanceActionKind.goalInvitation:
        Get.to(() => const SavingsListScreen());
      case FinanceActionKind.loanVote || FinanceActionKind.loanFunding || FinanceActionKind.loanAgreement:
        Get.to(() => LoanScreen(loanId: a.id));
      case FinanceActionKind.loanOverdue:
        a.id.isEmpty ? Get.to(() => const LoansScreen()) : Get.to(() => LoanScreen(loanId: a.id));
      case FinanceActionKind.insuranceQuote:
        Get.to(() => const InsuranceScreen(initialTab: 1));
      case FinanceActionKind.claimInformation:
        Get.to(() => const InsuranceScreen(initialTab: 2));
      case FinanceActionKind.transferConfirmation:
        Get.to(() => const TransfersScreen());
      case FinanceActionKind.billConfirmation:
        Get.to(() => const BillsScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = action;
    final status = _status(a.kind);
    final String sub = [if (a.detail.isNotEmpty) a.detail, ?_due(a, DateTime.now())].join(' · ');
    return FinListTile(
      icon: _icon(a.kind),
      iconTone: a.kind == FinanceActionKind.loanOverdue ? DsTone.danger : (a.urgent ? DsTone.warning : DsTone.brand),
      title: a.title.tr,
      subtitle: sub,
      status: status?.$1,
      statusLabel: status?.$2.tr,
      chevron: true,
      onTap: () => open(a),
    );
  }
}
