import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:customer/screen_ui/help_support_screen/help_support_screen.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_rules.dart' show ltr;
import 'package:customer/utils/finance_security_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// Other modules check a restriction with FinanceRestriction.blocks(userDoc, scope).
export 'package:customer/utils/finance_security_rules.dart' show FinanceRestriction, FinanceRestrictionInfo;

/// The admin's restriction of the user (blacklist, situation of insolvency:
/// `users/{uid}.financeRestriction`, .claude/FINANCE-DIRECT-FIRESTORE.md
/// section 3.12) told to the user it concerns: what is blocked, why, since
/// when, and how to reach support. Nothing at all when the user is not
/// restricted, while loading, or when the profile cannot be read (the
/// actions themselves are refused by the rules either way).
class FinanceRestrictionNotice extends StatefulWidget {
  /// The data of `users/{uid}` already read by the screen; null when the
  /// notice reads it itself ([FinanceService.myProfile]).
  final Map<String, dynamic>? profile;
  final bool _reads;

  /// Space around the notice when it is shown.
  final EdgeInsetsGeometry padding;

  /// Shown only when the restriction blocks this service (`transfers`,
  /// `payments`…): at the top of that service, before the customer fills a
  /// form that would be refused. Null: any restriction (Finance Home).
  final String? scope;

  /// Reads the user's profile itself (e.g. at the top of Finance Home).
  const FinanceRestrictionNotice({super.key, this.padding = const EdgeInsets.only(bottom: DsSpace.lg), this.scope})
      : profile = null,
        _reads = true;

  /// From the profile the screen already reads (null while it loads).
  const FinanceRestrictionNotice.of(this.profile, {super.key, this.padding = const EdgeInsets.only(bottom: DsSpace.lg), this.scope}) : _reads = false;

  @override
  State<FinanceRestrictionNotice> createState() => _FinanceRestrictionNoticeState();

  /// "Loans, Tontines": the restricted services, by name.
  static String scopeLabel(String scope) => switch (scope) {
        FinanceRestriction.loans => "Loans".tr,
        FinanceRestriction.tontines => "Tontines".tr,
        'savings' => "Savings".tr,
        'transfers' => "Transfers".tr,
        'payments' => "Payments".tr,
        'wallet' => "Wallet".tr,
        'cards' => "Virtual cards".tr,
        'investments' => "Investments".tr,
        'insurance' => "Insurance".tr,
        _ => scope,
      };
}

class _FinanceRestrictionNoticeState extends State<FinanceRestrictionNotice> {
  // One subscription for the notice's life (the stream is shared anyway).
  Stream<Map<String, dynamic>>? _profile;

  @override
  void initState() {
    super.initState();
    if (widget._reads && FinanceService.uid.isNotEmpty) _profile = FinanceService.myProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._reads) return _notice(widget.profile);
    final stream = _profile;
    if (stream == null) return const SizedBox.shrink();
    return StreamBuilder<Map<String, dynamic>>(stream: stream, builder: (context, snap) => _notice(snap.data));
  }

  Widget _notice(Map<String, dynamic>? profile) {
    final FinanceRestrictionInfo? r = FinanceRestriction.of(profile, toDate: (v) => v is Timestamp ? v.toDate() : null);
    if (r == null || (widget.scope != null && !r.covers(widget.scope!))) return const SizedBox.shrink();
    final List<String> lines = [
      r.isTotal
          ? "Your Spideli Finance account is restricted for all Spideli Finance services.".tr
          : "Your Spideli Finance account is restricted for: @services.".trParams({'services': r.scopes.map(FinanceRestrictionNotice.scopeLabel).join(', ')}),
      if (r.reason.isNotEmpty) '${"Reason".tr}: ${r.reason}',
      if (r.since != null) '${"Since".tr}: ${ltr(DateFormat('dd MMM yyyy').format(r.since!))}',
      "Contact support to find out more or to settle your situation.".tr,
    ];
    return Padding(
      padding: widget.padding,
      child: DsInlineAlert(
        tone: DsTone.danger,
        icon: Icons.gpp_bad_outlined,
        title: "Account restricted".tr,
        message: lines.join('\n'),
        actionLabel: "Contact support".tr,
        onAction: () => Get.to(HelpSupportScreen(isNavigateViaNotification: false)),
      ),
    );
  }
}
