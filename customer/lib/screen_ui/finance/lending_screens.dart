import 'dart:io';
import 'dart:math' as math;

import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_restriction.dart' show FinanceRestrictionNotice;
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/screen_ui/finance/tontine_screens.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_lending_service.dart';
import 'package:customer/service/finance_region_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_lending_rules.dart';
import 'package:customer/utils/finance_rules.dart';
// Prefixed: finance_group_rules.dart has a FinanceRestriction of its own.
import 'package:customer/utils/finance_security_rules.dart' as security;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// "12%", "2.5%" (no trailing ".0").
String _pct(num v) => '${v == v.roundToDouble() ? v.round() : v}%';

/// A percentage stored by the server ("12%", "-" when missing).
String _pctOf(dynamic v) => v is num ? _pct(v) : (v == null ? '-' : '$v%');

String _date(DateTime? d) => d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));

String _monthsLabel(int n) => FinanceUi.count(n, "month", "months");

/// Inner padding of a form section (each field carries its own bottom spacing).
const EdgeInsets _formPadding = EdgeInsets.all(DsSpace.lg);

/// The message of a refused loan step (translated).
String _error(String? reason) => (LoanErrors.message(reason) ?? FinanceErrors.messageKey(reason)).tr;

/// A loan step behind the loader; a refusal is said in words.
Future<bool> _run(Future<void> Function() action, {String? success}) async {
  ShowToastDialog.showLoader("Please wait...".tr);
  try {
    await action();
    ShowToastDialog.closeLoader();
    if (success != null) ShowToastDialog.showToast(success.tr);
    return true;
  } on FinanceException catch (e) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(_error(e.reason));
    return false;
  } catch (_) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(_error(null));
    return false;
  }
}

/// The payment step of a loan (lend, repay): paid from the Spideli Finance
/// wallet or by a payment gateway, as [FinanceFunding].
Future<void> _pay(
  BuildContext context, {
  required String title,
  required int amount,
  required String currency,
  required List<String> methods,
  required Future<Map<String, dynamic>> Function(FinanceFunding funding) submit,
}) =>
    FinancePaySheet.show(context, title: title, amount: amount, currency: currency, methods: methods, submit: (payment) => submit(payment.funding));

/// The reason shown for a loan that ended: the group's vote, or the admin's words.
String _reason(String reason) => financeReasonText(reason).tr;

/// Builds with whether the admin's restriction blocks the user's loans
/// (`users/{uid}.financeRestriction`, scope loans or all).
class _LoanGate extends StatelessWidget {
  final Widget Function(BuildContext context, bool restricted) builder;

  const _LoanGate({required this.builder});

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
        stream: FinanceLendingService.profile(),
        builder: (context, snap) => builder(context, security.FinanceRestriction.blocks(snap.data, security.FinanceRestriction.loans)),
      );
}

/// The restriction notice, when the user's loans are blocked (what, why, since when, support).
class _RestrictionNotice extends StatelessWidget {
  const _RestrictionNotice();

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
        stream: FinanceLendingService.profile(),
        builder: (context, snap) => security.FinanceRestriction.blocks(snap.data, security.FinanceRestriction.loans)
            ? FinanceRestrictionNotice.of(snap.data, padding: const EdgeInsets.only(top: DsSpace.md))
            : const SizedBox.shrink(),
      );
}

/// Spideli Finance > Loans: borrow from, and lend to, the members of your
/// groups. `finance_settings/{regionId}_lending` must exist (admin), else "not
/// available"; a failed read offers Retry.
class LoansScreen extends StatefulWidget {
  /// The tab it opens on: 0 borrow, 1 group requests, 2 lent.
  final int initialTab;

  const LoansScreen({super.key, this.initialTab = 0});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  late int _tab = widget.initialTab.clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    // Read once, so switching tabs does not reload the configuration.
    return FinConfig<LendingConfig>(
      load: FinanceLendingService.config,
      builder: (context, st) {
        final cfg = st.config;
        final Widget? placeholder = st.placeholder(Icons.handshake_outlined, "Loans are not available yet.".tr);
        return FinScaffold(
          title: "Loan".tr,
          bottomBar: !st.ready || _tab != 0
              ? null
              : DsStickyBar(
                  child: _LoanGate(
                    builder: (context, restricted) => DsButton.primary(
                      label: "Request a loan".tr,
                      icon: Icons.add_rounded,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: restricted ? null : () => Get.to(() => LoanApplyScreen(config: cfg!)),
                    ),
                  ),
                ),
          body: FinBody(
            children: [
              if (placeholder != null)
                placeholder
              else ...[
                const _RestrictionNotice(),
                DsSegmentedTabs(
                  scrollable: true,
                  segments: [DsSegment("Borrow".tr), DsSegment("Group requests".tr), DsSegment("Lent".tr)],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                _LoanList(
                  key: ValueKey(_tab),
                  load: switch (_tab) {
                    0 => FinanceLendingService.borrowed,
                    1 => FinanceLendingService.groupRequests,
                    _ => FinanceLendingService.lent,
                  },
                  lent: _tab == 2,
                  empty: switch (_tab) {
                    0 => "You have no loan request.",
                    1 => "No loan request in your groups.",
                    _ => "You have not funded a loan yet.",
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LoanList extends StatefulWidget {
  final Stream<List<Loan>> Function() load;
  final String empty;

  /// The loans the user funded: each row says what they lent.
  final bool lent;

  const _LoanList({super.key, required this.load, required this.empty, this.lent = false});

  @override
  State<_LoanList> createState() => _LoanListState();
}

class _LoanListState extends State<_LoanList> {
  late Stream<List<Loan>> _stream = widget.load();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Loan>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load the loans.".tr, onRetry: () => setState(() => _stream = widget.load()));
        if (!snap.hasData) return FinState.loading();
        final loans = snap.data!;
        if (loans.isEmpty) return FinState.empty(Icons.handshake_outlined, widget.empty.tr);
        return FinSection(
          top: DsSpace.lg,
          divided: true,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
          children: [for (final l in loans) _LoanTile(loan: l, lent: widget.lent)],
        );
      },
    );
  }
}

/// One loan in a list: purpose, terms, amount and status; on the "Lent"
/// tab, what the user lent (their own fundings) and their share of the
/// repayments available to collect.
class _LoanTile extends StatelessWidget {
  final Loan loan;
  final bool lent;

  const _LoanTile({required this.loan, this.lent = false});

  /// "You lent 5 000 XAF · Available to collect 1 200 XAF", or the amount
  /// still being confirmed; null when none.
  static String? _myLending(Loan l, List<Map<String, dynamic>> fundings) {
    int sum(bool Function(String) f) => fundings.where((x) => f(x['status']?.toString() ?? '')).fold(0, (s, x) => s + FinanceSummary.intOf(x['amount']));
    final int done = sum((s) => s == 'succeeded');
    final int confirming = sum((s) => s == 'pending' || s == 'processing');
    final int available = LenderShare.available(l, fundings);
    if (done > 0) {
      return [
        '${"You lent".tr} ${FinanceMoney.format(done, l.currency)}',
        if (available > 0) '${"Available to collect".tr} ${FinanceMoney.format(available, l.currency)}',
      ].join(' · ');
    }
    if (confirming > 0) return "@amount being confirmed".trParams({'amount': FinanceMoney.format(confirming, l.currency)});
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!lent) return _tile(null);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceLendingService.myFundings(loan.id),
      builder: (context, snap) => _tile(snap.data == null ? null : _myLending(loan, snap.data!)),
    );
  }

  Widget _tile(String? mine) {
    final l = loan;
    final bool late = l.status == 'overdue' || l.status == 'defaulted';
    final bool closed = l.status == 'rejected' || l.status == 'cancelled';
    return FinListTile(
      icon: Icons.handshake_outlined,
      iconTone: late ? DsTone.danger : (closed ? DsTone.neutral : DsTone.brand),
      title: GroupLabels.purpose(l.purpose).tr,
      subtitle: [
        _monthsLabel(l.durationMonths),
        if (l.groupName.isNotEmpty) l.groupName,
        ?mine,
        if (l.outstandingAmount > 0) '${"Still to repay".tr} ${FinanceMoney.format(l.outstandingAmount, l.currency)}',
      ].join(' · '),
      amount: FinanceMoney.format(l.amount, l.currency),
      status: l.status,
      statusLabel: LoanActions.statusLabel(l.status).tr,
      chevron: true,
      onTap: () => Get.to(() => LoanScreen(loanId: l.id)),
    );
  }
}

/// A supporting photo of a loan request: sent once uploaded and added to the loan.
class _Doc {
  final File file;

  /// Its number in the names saved on the loan ("Document 2"), fixed once
  /// the request is created so a retry keeps the same names.
  int? number;

  /// Where it was uploaded (a retry only adds it to the loan).
  String? path;
  bool sent = false;

  _Doc(this.file);
}

/// A loan request: group, amount, terms and an estimated schedule.
class LoanApplyScreen extends StatefulWidget {
  final LendingConfig config;

  const LoanApplyScreen({super.key, required this.config});

  @override
  State<LoanApplyScreen> createState() => _LoanApplyScreenState();
}

class _LoanApplyScreenState extends State<LoanApplyScreen> {
  static const int _maxDocuments = 5;

  final _amount = TextEditingController();
  final _description = TextEditingController();
  late String _currency = widget.config.currencies.first;
  late String _purpose = widget.config.purposes.first;
  late int _months = widget.config.durationsMonths.first;
  late String _frequency = widget.config.repaymentFrequencies.first;
  String? _groupId;
  bool _showSchedule = false;
  final List<_Doc> _documents = [];
  late Stream<List<Tontine>> _groups = FinanceGroupService.myTontines();

  /// The id of this request, chosen once: a retry after a lost answer
  /// writes the same request (create-only), never a second one.
  late final String _newId = FinanceLendingService.newLoanId();

  /// The request once created. Once set, a retry only sends the documents
  /// still missing: the request is never sent twice.
  String? _loanId;

  /// The request or the document upload is under way: a second tap is ignored.
  bool _applying = false;

  /// The chosen group has no member but the user.
  bool _alone = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  /// The amount, when valid and within the configured limits.
  int? get _validAmount {
    final int? v = FinanceAmount.parse(_amount.text, _currency);
    final int? max = widget.config.maxFor(_currency);
    return v == null || v < widget.config.minFor(_currency) || (max != null && v > max) ? null : v;
  }

  List<String> _missing() => [
        if (_groupId == null || _alone) "Group".tr,
        if (_validAmount == null) "Amount".tr,
      ];

  Future<void> _addDocument(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2400);
      if (picked != null && mounted) setState(() => _documents.add(_Doc(File(picked.path))));
    } on PlatformException catch (e) {
      final bool denied = e.code.contains('denied');
      ShowToastDialog.showToast((denied
              ? (source == ImageSource.camera
                  ? "Allow access to the camera in your phone settings to take a photo."
                  : "Allow access to your photos in your phone settings to add a document.")
              : "Could not add this photo. Please try again.")
          .tr);
    } catch (_) {
      ShowToastDialog.showToast("Could not add this photo. Please try again.".tr);
    }
  }

  Future<void> _submit() async {
    final int? amount = _validAmount;
    // A double tap must not send it twice (the id keeps a retry to one request).
    if (_applying) return;
    if (_loanId == null) {
      if (_missing().isNotEmpty || amount == null) return;
      _applying = true;
      final ok = await _run(() => FinanceLendingService.apply(
            loanId: _newId,
            config: widget.config,
            amount: amount,
            currency: _currency,
            purpose: _purpose,
            durationMonths: _months,
            repaymentFrequency: _frequency,
            groupId: _groupId!,
            description: _description.text.trim(),
          ));
      _applying = false;
      if (!ok || !mounted) return;
      setState(() {
        _loanId = _newId;
        for (final (i, d) in _documents.indexed) {
          d.number = i + 1;
        }
      });
    }
    await _sendDocuments();
  }

  /// Uploads and adds every document not sent yet; a failed one stays to retry.
  Future<void> _sendDocuments() async {
    final String id = _loanId!;
    final pending = _documents.where((d) => !d.sent).toList();
    if (_applying) return;
    if (pending.isNotEmpty) {
      _applying = true;
      ShowToastDialog.showLoader("Please wait...".tr);
      for (final d in pending) {
        try {
          d.path ??= await FinanceLendingService.uploadDocument(id, d.file, d.number ?? 0);
          await FinanceLendingService.registerDocument(id, d.path!, '${"Document".tr} ${d.number}');
          d.sent = true;
        } catch (_) {
          // Kept for "Try again"; the others are still sent.
        }
      }
      ShowToastDialog.closeLoader();
      _applying = false;
    }
    if (!mounted) return;
    if (_documents.every((d) => d.sent)) {
      _open();
    } else {
      setState(() {});
    }
  }

  void _open() {
    ShowToastDialog.showToast("Loan request sent".tr);
    Get.off(() => LoanScreen(loanId: _loanId!));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final int? amount = _validAmount;
    final now = DateTime.now();
    final bool sent = _loanId != null;
    final int unsent = _documents.where((d) => !d.sent).length;
    final missing = _missing();
    final estimate = amount == null
        ? null
        : LoanCalculator.estimate(
            principal: amount,
            months: _months,
            frequency: _frequency,
            method: cfg.interestMethod,
            annualPercent: cfg.annualInterestPercent,
            feePercent: cfg.feePercent,
            firstDue: Frequency.next(now, _frequency),
          );
    return FinScaffold(
      title: "Request a loan".tr,
      bottomBar: DsStickyBar(
        child: sent
            // The request exists; only documents are left to send.
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsButton.primary(label: "Try again".tr, icon: Icons.refresh_rounded, size: DsButtonSize.lg, expand: true, onPressed: _sendDocuments),
                  DsButton.ghost(label: "Continue without them".tr, expand: true, onPressed: () => Get.off(() => LoanScreen(loanId: _loanId!))),
                ],
              )
            : FinanceKycGate(
                builder: (context, verified) => _LoanGate(
                  builder: (context, restricted) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FinMissing(missing),
                      DsButton.primary(
                        label: "Send my request".tr,
                        size: DsButtonSize.lg,
                        expand: true,
                        onPressed: verified && !restricted && missing.isEmpty ? _submit : null,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: FinBody(
        children: [
          if (!sent) const _RestrictionNotice(),
          if (sent)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.lg),
              child: DsInlineAlert(
                tone: DsTone.warning,
                title: "Your loan request was sent".tr,
                message: "@n of your documents could not be added. Try again, or continue without them.".trParams({'n': '$unsent'}),
              ),
            ),
          // Once the request is sent its terms can no longer change here.
          IgnorePointer(
            ignoring: sent,
            child: Opacity(
              opacity: sent ? 0.6 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _groupSection(),
                  FinSection(
                    title: "Loan".tr,
                    padding: _formPadding,
                    children: [
                      FinAmountField(
                        label: "Amount".tr,
                        controller: _amount,
                        currency: _currency,
                        currencies: cfg.currencies,
                        onCurrencyChanged: (v) => setState(() => _currency = v),
                        // The allowed range, before the user is refused.
                        min: cfg.minFor(_currency),
                        max: cfg.maxFor(_currency),
                        onChanged: (_) => setState(() {}),
                      ),
                      DsDropdown<String>(
                        label: "Purpose".tr,
                        value: _purpose,
                        items: [for (final p in cfg.purposes) DropdownMenuItem(value: p, child: Text(GroupLabels.purpose(p).tr))],
                        onChanged: (v) => setState(() => _purpose = v ?? _purpose),
                      ),
                      DsFieldLabel("Duration".tr, required: true),
                      Wrap(
                        spacing: DsSpace.sm,
                        runSpacing: DsSpace.xs,
                        children: [
                          for (final m in cfg.durationsMonths) ChoiceChip(label: Text(_monthsLabel(m)), selected: _months == m, onSelected: (_) => setState(() => _months = m)),
                        ],
                      ),
                      const DsGap(DsSpace.md),
                      DsDropdown<String>(
                        label: "Repayments".tr,
                        value: _frequency,
                        items: [for (final f in cfg.repaymentFrequencies) DropdownMenuItem(value: f, child: Text(Frequency.label(f).tr))],
                        onChanged: (v) => setState(() => _frequency = v ?? _frequency),
                      ),
                      DsTextField(label: "Why do you need this loan?".tr, controller: _description, maxLines: 3, bottomSpacing: 0),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (estimate != null) ...[
            FinSection(
              title: "Estimated repayments".tr,
              divided: true,
              children: [
                FinRow("Each installment".tr, FinanceMoney.format(estimate.installmentAmount, _currency), sub: Frequency.label(_frequency).tr),
                FinRow("Number of installments".tr, '${estimate.installments.length}'),
                FinRow(
                  "Interest".tr,
                  '${_pct(cfg.annualInterestPercent)} ${"a year".tr}',
                  sub: (cfg.interestMethod == 'flat' ? 'flat rate' : 'on the remaining balance').tr,
                ),
                if (cfg.latePenaltyPercent > 0) FinRow("Late payment penalty".tr, _pct(cfg.latePenaltyPercent)),
                FinRow("Total interest".tr, FinanceMoney.format(estimate.totalInterest, _currency)),
                FinRow("Fee".tr, FinanceMoney.format(estimate.fee, _currency)),
                FinRow("Total to repay".tr, FinanceMoney.format(estimate.totalRepaid, _currency), strong: true),
                _Toggle(
                  label: (_showSchedule ? "Hide the schedule" : "See the schedule").tr,
                  expanded: _showSchedule,
                  onTap: () => setState(() => _showSchedule = !_showSchedule),
                ),
                if (_showSchedule)
                  for (final i in estimate.installments) FinRow('${i.number}. ${_date(i.dueDate)}', FinanceMoney.format(i.total, _currency)),
              ],
            ),
            FinNotice(
              "This is an estimate. The binding amounts, dates and fees are in the loan agreement you accept before any money is paid out.".tr,
              title: "Estimate".tr,
            ),
          ],
          FinSection(
            title: "Supporting documents (optional)".tr,
            divided: true,
            footnote:
                '${"Payslips, invoices, a business plan... Only the reviewers and your group's voters see them.".tr} ${"Up to @n photos.".trParams({'n': '$_maxDocuments'})}',
            children: [
              for (final (i, d) in _documents.indexed)
                FinListTile(
                  icon: d.sent ? Icons.check_circle_rounded : Icons.image_outlined,
                  iconTone: d.sent ? DsTone.success : (sent ? DsTone.warning : DsTone.brand),
                  title: '${"Document".tr} ${d.number ?? i + 1}',
                  subtitle: sent ? (d.sent ? "Added".tr : "Not added yet".tr) : null,
                  trailing: d.sent
                      ? null
                      : DsIconButton(icon: Icons.close_rounded, semanticLabel: "Remove".tr, onPressed: () => setState(() => _documents.removeAt(i))),
                ),
              if (!sent && _documents.length < _maxDocuments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  child: Wrap(
                    spacing: DsSpace.sm,
                    runSpacing: DsSpace.xs,
                    children: [
                      DsButton.ghost(label: "Camera".tr, icon: Icons.photo_camera_outlined, onPressed: () => _addDocument(ImageSource.camera)),
                      DsButton.ghost(label: "Gallery".tr, icon: Icons.photo_library_outlined, onPressed: () => _addDocument(ImageSource.gallery)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The group whose members vote: loading, failed (Retry), none (go to the
  /// tontines), or the choice.
  Widget _groupSection() {
    return StreamBuilder<List<Tontine>>(
      stream: _groups,
      builder: (context, snap) {
        final groups = (snap.data ?? const <Tontine>[]).where((t) => t.isActive || t.isForming).toList();
        final Widget field;
        if (snap.hasError) {
          field = DsInlineAlert(
            tone: DsTone.danger,
            message: "Could not load your groups.".tr,
            actionLabel: "Try again".tr,
            onAction: () => setState(() => _groups = FinanceGroupService.myTontines()),
          );
        } else if (!snap.hasData) {
          field = DsDropdown<String>(label: "Group".tr, requiredMark: true, hint: "Loading your groups...".tr, value: null, items: const [], onChanged: null, bottomSpacing: 0);
        } else if (groups.isEmpty) {
          field = DsInlineAlert(
            tone: DsTone.warning,
            message: "You need to belong to a tontine group to borrow from its members.".tr,
            actionLabel: "Open tontines".tr,
            onAction: () => Get.to(() => const TontineListScreen()),
          );
        } else {
          field = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinPickerField<String>(
                label: "Group".tr,
                requiredMark: true,
                value: _groupId,
                options: [for (final g in groups) (g.id, g.name)],
                onChanged: (v) => setState(() {
                  _groupId = v;
                  // Nobody else in it: nobody to vote on the request.
                  final picked = groups.where((g) => g.id == v);
                  _alone = picked.isNotEmpty && LoanPlans.voters(picked.first.memberIds, FinanceService.uid).isEmpty;
                }),
              ),
              if (_alone) DsInlineAlert(tone: DsTone.warning, message: "Your group has no other member to vote on your request.".tr),
            ],
          );
        }
        return FinSection(
          title: "Group".tr,
          top: 0,
          padding: _formPadding,
          children: [_Hint("The members of this group vote on your request and can fund it.".tr), field],
        );
      },
    );
  }
}

/// One loan, for its borrower and for the members of its group. A loan that
/// no longer exists says so; a failed read offers Retry.
class LoanScreen extends StatefulWidget {
  final String loanId;

  const LoanScreen({super.key, required this.loanId});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  late Stream<Loan?> _loan = FinanceLendingService.loan(widget.loanId);
  late final Stream<List<Map<String, dynamic>>> _schedule = FinanceLendingService.schedule(widget.loanId);

  /// Live; without it the loan still shows (wallet payments only).
  late final Stream<LendingConfig?> _config = FinanceRegion.live(() => FinanceLendingService.config().catchError((_) => null));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LendingConfig?>(
      stream: _config,
      builder: (context, cfgSnap) => StreamBuilder<Loan?>(
        stream: _loan,
        builder: (context, snap) {
          final l = snap.data;
          final Widget? state = FinState.of(
            snap,
            gone: "This loan is no longer available.",
            onRetry: () => setState(() => _loan = FinanceLendingService.loan(widget.loanId)),
          );
          if (state != null || l == null) {
            return FinScaffold(title: "Loan".tr, body: FinBody(children: [state ?? FinState.loading(rows: 4)]));
          }
          final methods = cfgSnap.data?.paymentMethods ?? const ['wallet'];
          // The binding schedule (borrower and lenders only; empty for the others).
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _schedule,
            builder: (context, ss) {
              final installments = ss.data ?? const <Map<String, dynamic>>[];
              final bool repay = installments.isNotEmpty && LoanActions.canRepay(l, FinanceService.uid);
              return FinScaffold(
                title: "Loan".tr,
                bottomBar: repay ? DsStickyBar(child: _RepayButton(loan: l, next: nextInstallment(installments), methods: methods)) : null,
                body: _LoanBody(loan: l, config: cfgSnap.data, installments: installments),
              );
            },
          );
        },
      ),
    );
  }
}

class _LoanBody extends StatelessWidget {
  final Loan loan;
  final LendingConfig? config;
  final List<Map<String, dynamic>> installments;

  const _LoanBody({required this.loan, required this.config, required this.installments});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final c = DsColors.of(context);
    final uid = FinanceService.uid;
    final bool borrower = uid == l.borrowerId;
    final methods = config?.paymentMethods ?? const ['wallet'];
    return FinBody(
      children: [
        _LoanHeader(loan: l, installments: installments),
        const _RestrictionNotice(),
        if (l.description.isNotEmpty)
          FinSection(
            title: "Description".tr,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                child: Text(l.description, style: DsTypography.body.copyWith(color: c.textPrimary)),
              ),
            ],
          ),
        if (borrower) _Assessment(loanId: l.id),
        if (l.status == 'voting') _Voting(loan: l, config: config),
        if (l.status == 'funding' || l.lenderIds.contains(uid)) _Funding(loan: l, methods: methods, config: config),
        _Agreement(loan: l, config: config),
        if (installments.isNotEmpty) ...[
          _Schedule(loan: l, installments: installments),
          _Repayments(loanId: l.id, currency: l.currency, borrower: borrower),
        ],
        if (LoanActions.canCancel(l, uid))
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.ghost(
              label: "Withdraw my request".tr,
              icon: Icons.close_rounded,
              expand: true,
              color: c.danger,
              onPressed: () async {
                final ok = await finConfirm(
                  title: "Withdraw this loan request?".tr,
                  lines: [
                    ("Amount".tr, FinanceMoney.format(l.amount, l.currency)),
                    if (l.groupName.isNotEmpty) ("Group".tr, l.groupName),
                  ],
                  confirmLabel: "Withdraw".tr,
                  destructive: true,
                );
                if (ok) await _run(() => FinanceLendingService.cancel(l.id), success: "Request withdrawn");
              },
            ),
          ),
      ],
    );
  }
}

/// The loan's headline: amount, terms, status, where it is in its workflow
/// and, while it is being repaid, what is left (server amounts only).
class _LoanHeader extends StatelessWidget {
  final Loan loan;
  final List<Map<String, dynamic>> installments;

  const _LoanHeader({required this.loan, required this.installments});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final c = DsColors.of(context);
    final bool ended = const ['rejected', 'cancelled', 'defaulted'].contains(l.status);
    // "overdue" is the active step running late; "defaulted" ended after the pay-out.
    final int stepIndex = LoanActions.steps.indexOf(l.status == 'overdue' || l.status == 'defaulted' ? 'active' : l.status);
    final String statusLabel = LoanActions.statusLabel(l.status).tr;
    // The total of the binding schedule; the repaid share is shown only against it.
    final int scheduleTotal = installments.fold(0, (s, i) => s + FinanceSummary.intOf(i['amount']));
    final bool repaying = l.outstandingAmount > 0;
    final below = <Widget>[
      if (ended || stepIndex >= 0)
        FinTrack(
          steps: [for (final s in LoanActions.steps) LoanActions.statusLabel(s).tr],
          current: stepIndex,
          ended: ended,
          endedLabel: statusLabel,
        ),
      if (repaying) ...[
        Divider(height: DsSpace.xl, thickness: 1, color: c.divider),
        FinRow("Still to repay".tr, FinanceMoney.format(l.outstandingAmount, l.currency), strong: true),
        if (scheduleTotal > 0) ...[
          const DsGap(DsSpace.xs),
          FinProgress(value: (scheduleTotal - l.outstandingAmount) / scheduleTotal, label: "Repaid".tr),
        ],
      ],
      if ((l.reason ?? '').isNotEmpty) FinNotice(_reason(l.reason!), title: "Reason".tr, tone: FinStatus.tone(l.status)),
    ];
    return FinHeader(
      overline: "Amount".tr,
      title: FinanceMoney.format(l.amount, l.currency),
      subtitle: '${GroupLabels.purpose(l.purpose).tr} · ${_monthsLabel(l.durationMonths)} · ${Frequency.label(l.frequency).tr}'
          '${l.groupName.isEmpty ? '' : '\n${"Group".tr}: ${l.groupName}'}',
      status: l.status,
      statusLabel: statusLabel,
      icon: Icons.handshake_outlined,
      below: below.isEmpty ? null : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: below),
    );
  }
}

/// The borrower's credit assessment: score, band and the main factors (explained).
class _Assessment extends StatelessWidget {
  final String loanId;

  const _Assessment({required this.loanId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceLendingService.creditAssessment(loanId),
      builder: (context, snap) {
        final a = snap.data;
        if (a == null) return const SizedBox.shrink();
        final factors = (a['factors'] as List?)?.whereType<Map>().toList() ?? const [];
        return FinSection(
          title: "Your credit assessment".tr,
          divided: true,
          footnote: "The main factors that shaped your score. Ask support if something looks wrong.".tr,
          children: [
            FinRow("Score".tr, '${a['score'] ?? '-'}', sub: a['band']?.toString(), strong: true),
            for (final f in factors)
              FinListTile(
                icon: f['impact'] == 'negative' ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                iconTone: f['impact'] == 'negative' ? DsTone.warning : DsTone.success,
                title: f['label']?.toString() ?? '-',
                subtitle: f['detail']?.toString(),
              ),
          ],
        );
      },
    );
  }
}

class _Voting extends StatelessWidget {
  final Loan loan;
  final LendingConfig? config;

  const _Voting({required this.loan, required this.config});

  Future<void> _vote(BuildContext context, bool approve) async {
    final comment = TextEditingController();
    final ok = await finSheet<bool>(
      title: (approve ? "Approve this loan" : "Decline this loan").tr,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(label: "Comment (optional)".tr, controller: comment, maxLines: 3),
            Text("Your vote is final and visible to the borrower as part of the result.".tr,
                style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary)),
            const DsGap(DsSpace.lg),
            DsButton.primary(label: "Confirm my vote".tr, expand: true, onPressed: () => Get.back(result: true)),
          ],
        ),
      ),
    );
    if (ok == true) await _run(() => FinanceLendingService.vote(loan.id, approve, comment.text.trim()), success: "Vote recorded");
  }

  /// Closes the vote once it ended (or everyone voted), with its outcome
  /// confirmed first: the members may fund it, or the request is not approved.
  Future<void> _close(VoteTally tally) async {
    final l = loan;
    final bool approved = tally.wouldApprove;
    final ok = await finConfirm(
      title: "Close the vote?".tr,
      message: (approved
              ? "The request is approved: the members of the group can now fund it."
              : "The request did not get enough votes or approvals: it will not be funded.")
          .tr,
      lines: [
        ("Votes".tr, '${tally.cast} / ${tally.eligible}'),
        ("Approve / decline".tr, '${tally.yes} / ${tally.no}'),
      ],
      confirmLabel: "Close the vote".tr,
    );
    if (ok) await _run(() => FinanceLendingService.closeVote(l.id), success: approved ? "The request is open for funding" : "The vote is closed");
  }

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final cfg = config;
    final now = DateTime.now();
    final tally = VoteTally(eligible: l.eligibleVoterIds.length, yes: l.votesYes, no: l.votesNo, quorumPercent: cfg?.quorumPercent ?? 50, approvalPercent: cfg?.approvalPercent ?? 50);
    final bool ended = LoanActions.votingEnded(l, now);
    // Closing counts with the admin's rules: not offered without them.
    final bool canClose = cfg != null && LoanActions.canCloseVote(l, FinanceService.uid, now: now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinSection(
          title: "Group vote".tr,
          divided: true,
          children: [
            FinRow("Votes".tr, '${tally.cast} / ${tally.eligible}', sub: '${"needed".tr}: ${tally.needed}'),
            FinRow("Approve / decline".tr, '${tally.yes} / ${tally.no}'),
            FinRow("Approval needed".tr, _pct(tally.approvalPercent)),
            if (l.votingEndsAt != null)
              FinRow((ended ? "Voting closed on" : "Voting closes").tr, ltr(DateFormat('dd MMM yyyy, HH:mm').format(l.votingEndsAt!))),
          ],
        ),
        if (canClose)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  (ended ? "The voting period is over: any member can close the vote." : "Everyone has voted: any member can close the vote.").tr,
                  style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary),
                ),
                const DsGap(DsSpace.sm),
                DsButton.secondary(label: "Close the vote".tr, icon: Icons.how_to_vote_outlined, expand: true, onPressed: () => _close(tally)),
              ],
            ),
          ),
        StreamBuilder<Map<String, dynamic>?>(
          stream: FinanceLendingService.myVote(l.id),
          builder: (context, snap) {
            // Until the user's own vote is read, no button: they may already have voted.
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const SizedBox.shrink();
            final mine = snap.data;
            if (mine != null) {
              return FinNotice((mine['approve'] == true ? "You voted to approve." : "You voted to decline.").tr);
            }
            if (!LoanActions.canVote(l, FinanceService.uid, alreadyVoted: false, now: DateTime.now())) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: FinanceKycGate(
                builder: (context, verified) => _LoanGate(
                  builder: (context, restricted) => Row(
                    children: [
                      Expanded(child: DsButton.secondary(label: "Decline".tr, onPressed: verified && !restricted ? () => _vote(context, false) : null)),
                      const DsGap(DsSpace.sm),
                      Expanded(child: DsButton.primary(label: "Approve".tr, onPressed: verified && !restricted ? () => _vote(context, true) : null)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Funding extends StatelessWidget {
  final Loan loan;
  final List<String> methods;
  final LendingConfig? config;

  const _Funding({required this.loan, required this.methods, required this.config});

  /// Lending is a risk: the amount, the terms and that risk, confirmed
  /// before the payment step.
  Future<void> _lend(BuildContext context) async {
    final l = loan;
    final amount = await askAmount(context, title: "How much do you lend?".tr, currency: l.currency, max: l.fundingRemaining);
    if (amount == null || !context.mounted) return;
    final cfg = config;
    final bool ok = await finConfirm(
      title: "Lend to this member?".tr,
      message: "Lending carries a risk: if the borrower does not repay, you can lose part or all of this money. Repayments are shared among the lenders in proportion to what each lent.".tr,
      lines: [
        if (cfg != null) ("Interest".tr, '${_pct(cfg.annualInterestPercent)} ${"a year".tr}'),
        ("Duration".tr, _monthsLabel(l.durationMonths)),
        ("Repayments".tr, Frequency.label(l.frequency).tr),
        if (l.groupName.isNotEmpty) ("Group".tr, l.groupName),
      ],
      total: ("Amount".tr, FinanceMoney.format(amount, l.currency)),
      confirmLabel: "Continue".tr,
    );
    if (!ok || !context.mounted) return;
    await _pay(
      context,
      title: "Lend".tr,
      amount: amount,
      currency: l.currency,
      methods: methods,
      // The same request (amount, payment) keeps its key until it went through.
      submit: (funding) => FinanceRequestKeys.send(
        'loan.fund',
        l.id,
        amount,
        {'method': funding.method, 'number': funding.reference ?? ''},
        (key) => FinanceLendingService.fund(l.id, amount, funding, key),
      ),
    );
  }

  /// The lender's share of the repayments received, into their wallet.
  Future<void> _collect(int available) async {
    final l = loan;
    final ok = await finConfirm(
      title: "Collect your share?".tr,
      message: "Your share of the repayments received so far is paid into your Spideli Finance wallet.".tr,
      total: ("Amount".tr, FinanceMoney.format(available, l.currency)),
      confirmLabel: "Collect".tr,
    );
    if (ok) await _run(() => FinanceLendingService.collect(l.id), success: "Paid into your wallet");
  }

  @override
  Widget build(BuildContext context) {
    final l = loan;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceLendingService.myFundings(l.id),
      builder: (context, snap) {
        final mine = snap.data ?? const [];
        int sum(bool Function(String) f) => mine.where((x) => f(x['status']?.toString() ?? '')).fold(0, (s, x) => s + FinanceSummary.intOf(x['amount']));
        final int lent = sum((s) => s == 'succeeded');
        // A funding still being confirmed is shown as such.
        final int confirming = sum((s) => s == 'pending' || s == 'processing');
        final int collected = LenderShare.collected(mine);
        final int available = LenderShare.available(l, mine);
        final bool collect = LoanActions.canCollect(l, FinanceService.uid, available);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSection(
              title: "Funding".tr,
              divided: true,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                  child: FinProgress(
                    value: l.fundingProgress,
                    label: '${FinanceMoney.format(l.fundedAmount, l.currency)} / ${FinanceMoney.format(l.amount, l.currency)}',
                  ),
                ),
                if (l.status == 'funding' && l.fundingRemaining > 0) FinRow("Left to fund".tr, FinanceMoney.format(l.fundingRemaining, l.currency)),
                if (lent > 0) FinRow("You lent".tr, FinanceMoney.format(lent, l.currency)),
                if (confirming > 0) FinRow("Being confirmed".tr, FinanceMoney.format(confirming, l.currency)),
                if (collected > 0) FinRow("Collected".tr, FinanceMoney.format(collected, l.currency)),
                if (lent > 0 && l.repaidAmount > 0)
                  FinRow("Available to collect".tr, FinanceMoney.format(available, l.currency), strong: available > 0, sub: "In proportion to what you lent".tr),
              ],
            ),
            if (collect)
              Padding(
                padding: const EdgeInsets.only(top: DsSpace.md),
                child: DsButton.primary(
                  label: '${"Collect".tr} ${FinanceMoney.format(available, l.currency)}',
                  icon: Icons.south_west_rounded,
                  expand: true,
                  onPressed: () => _collect(available),
                ),
              ),
            if (LoanActions.canFund(l, FinanceService.uid))
              Padding(
                padding: const EdgeInsets.only(top: DsSpace.md),
                child: FinanceKycGate(
                  builder: (context, verified) => _LoanGate(
                    builder: (context, restricted) => DsButton.primary(
                      label: "Lend to this member".tr,
                      icon: Icons.volunteer_activism_outlined,
                      expand: true,
                      onPressed: !verified || restricted ? null : () => _lend(context),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The loan agreement (issued when the loan is fully funded, from the
/// admin's terms), the repayments it commits the borrower to, and its
/// acceptance, which pays the loan out into the borrower's wallet.
class _Agreement extends StatefulWidget {
  final Loan loan;
  final LendingConfig? config;

  const _Agreement({required this.loan, required this.config});

  @override
  State<_Agreement> createState() => _AgreementState();
}

class _AgreementState extends State<_Agreement> {
  bool _accepted = false;
  bool _showSchedule = false;

  /// (number, due date, amount) of each installment: the agreement's own
  /// amounts when it lists them (binding), else estimated from its terms
  /// with the same rules as the request screen. The dates are set at the
  /// pay-out (the first one period after it): until then they are
  /// estimated from today. Second: whether the amounts are estimated;
  /// third: whether the dates are.
  (List<(int, DateTime?, int)>, bool, bool) _installments(Map<String, dynamic> a) {
    final l = widget.loan;
    final list = a['installments'] is List ? (a['installments'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const <Map<String, dynamic>>[];
    if (list.isNotEmpty) {
      final bool dated = list.every((m) => FinanceGroupService.toDate(m['dueDate']) != null);
      final dates = LoanCalculator.dueDates(Frequency.next(DateTime.now(), l.frequency), l.frequency, list.length);
      return (
        [
          for (final (i, m) in list.indexed)
            (
              m['number'] is num ? (m['number'] as num).toInt() : i + 1,
              dated ? FinanceGroupService.toDate(m['dueDate']) : dates[i],
              FinanceSummary.intOf(m['amount'] ?? m['amountDue']),
            ),
        ],
        false,
        !dated,
      );
    }
    final String? method = (a['interestMethod'] ?? widget.config?.interestMethod)?.toString();
    final num? rate = a['annualInterestPercent'] is num ? a['annualInterestPercent'] as num : widget.config?.annualInterestPercent;
    final int principal = FinanceSummary.intOf(a['principal']);
    if (rate == null || principal <= 0 || l.durationMonths <= 0 || (method != 'flat' && method != 'declining')) return (const [], true, true);
    final e = LoanCalculator.estimate(
      principal: principal,
      months: l.durationMonths,
      frequency: l.frequency,
      method: method!,
      annualPercent: rate.toDouble(),
      firstDue: Frequency.next(DateTime.now(), l.frequency),
    );
    return ([for (final i in e.installments) (i.number, i.dueDate, i.total)], true, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.loan;
    final c = DsColors.of(context);
    final bool borrower = FinanceService.uid == l.borrowerId;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceLendingService.agreement(l.id),
      builder: (context, snap) {
        final a = snap.data;
        if (a == null) return const SizedBox.shrink();
        final cur = a['currency']?.toString() ?? l.currency;
        final int version = FinanceSummary.intOf(a['version']);
        final bool accepted = a['acceptedAt'] != null;
        final bool canAccept = LoanActions.canAcceptAgreement(l, FinanceService.uid) && !accepted;
        final (installments, amountsEstimated, datesEstimated) = _installments(a);
        final String? estimate = amountsEstimated ? "Estimated".tr : null;
        final int principal = FinanceSummary.intOf(a['principal']);
        final int fee = FinanceSummary.intOf(a['fee']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSection(
              title: "Loan agreement".tr,
              divided: true,
              children: [
                FinRow("Amount".tr, FinanceMoney.format(principal, cur)),
                FinRow("Fee".tr, FinanceMoney.format(fee, cur), sub: fee > 0 ? "Taken from the pay-out".tr : null),
                // The fee is taken from the pay-out.
                if (fee > 0 && principal > fee) FinRow((borrower ? "You receive" : "Paid out to the borrower").tr, FinanceMoney.format(principal - fee, cur)),
                FinRow("Interest".tr, '${_pctOf(a['annualInterestPercent'])} ${"a year".tr}'),
                if (a['latePenaltyPercent'] != null) FinRow("Late payment penalty".tr, _pctOf(a['latePenaltyPercent'])),
                FinRow("Total to repay".tr, FinanceMoney.format(FinanceSummary.intOf(a['totalRepayable']), cur), strong: true),
                if ((a['terms'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                    child: Text(a['terms'].toString(), style: DsTypography.body.copyWith(color: c.textSecondary)),
                  ),
              ],
            ),
            // The repayments the borrower accepts with the agreement (once
            // paid out, the binding schedule below shows them with their dates).
            if (installments.isNotEmpty && !accepted)
              FinSection(
                title: "Repayment schedule".tr,
                divided: true,
                footnote: amountsEstimated
                    ? "Estimated from the agreement's terms. The binding dates are set when the loan is paid out.".tr
                    : (datesEstimated ? "The first installment is due one period after the loan is paid out: the dates shown are estimated from today.".tr : null),
                children: [
                  FinRow("Each installment".tr, FinanceMoney.format(installments.first.$3, cur), sub: estimate),
                  FinRow("Number of installments".tr, '${installments.length}'),
                  FinRow("Repayments".tr, Frequency.label(l.frequency).tr),
                  if (installments.first.$2 != null) FinRow("First installment".tr, _date(installments.first.$2), sub: datesEstimated ? "Estimated".tr : null),
                  _Toggle(
                    label: (_showSchedule ? "Hide the schedule" : "See the schedule").tr,
                    expanded: _showSchedule,
                    onTap: () => setState(() => _showSchedule = !_showSchedule),
                  ),
                  if (_showSchedule)
                    for (final (n, due, amount) in installments) FinRow('$n. ${_date(due)}', FinanceMoney.format(amount, cur)),
                ],
              ),
            if (accepted) FinNotice('${"Accepted on".tr} ${FinanceUi.date(a['acceptedAt'])}', tone: DsTone.success),
            if (canAccept) ...[
              const DsGap(DsSpace.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                title: Text("I have read the agreement and the repayment schedule, and I accept them.".tr, style: DsTypography.body.copyWith(color: c.textPrimary)),
              ),
              const DsGap(DsSpace.xs),
              _LoanGate(
                builder: (context, restricted) => DsButton.primary(
                  label: "Accept the agreement".tr,
                  expand: true,
                  onPressed: !_accepted || restricted
                      ? null
                      : () => _run(() => FinanceLendingService.acceptAgreement(l.id, version), success: "Agreement accepted. The loan was paid into your wallet."),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The binding schedule: one line per installment (number, date, amount, status).
class _Schedule extends StatelessWidget {
  final Loan loan;
  final List<Map<String, dynamic>> installments;

  const _Schedule({required this.loan, required this.installments});

  @override
  Widget build(BuildContext context) {
    return FinSection(
      title: "Repayment schedule".tr,
      divided: true,
      children: [for (final i in installments) _InstallmentRow(installment: i, currency: loan.currency)],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final Map<String, dynamic> installment;
  final String currency;

  const _InstallmentRow({required this.installment, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final i = installment;
    final String? status = i['status']?.toString();
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
        child: Row(
          children: [
            // At least 28 wide so the dates align; wider for "100" or large text.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 28),
              child: Text('${i['number'] ?? ''}', style: DsTypography.labelSm.copyWith(color: c.textSecondary).tabular),
            ),
            const DsGap(DsSpace.xs),
            Expanded(child: Text(_date(FinanceGroupService.toDate(i['dueDate'])), style: DsTypography.body.copyWith(color: c.textPrimary))),
            const DsGap(DsSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(FinanceMoney.format(FinanceSummary.intOf(i['amount']), currency), style: DsTypography.bodyStrong.copyWith(color: c.textPrimary).tabular),
                const DsGap(DsSpace.xxs),
                FinStatusChip(status: status ?? '', label: LoanActions.installmentLabel(status).tr),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The borrower's repayment action (sticky): the next installment due, or
/// any amount up to what is outstanding.
class _RepayButton extends StatelessWidget {
  final Loan loan;
  final Map<String, dynamic>? next;
  final List<String> methods;

  const _RepayButton({required this.loan, required this.next, required this.methods});

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final next = this.next;
    return FinanceKycGate(
      builder: (context, verified) => DsButton.primary(
        label: next == null || installmentRemaining(next) <= 0 ? "Repay".tr : "${"Repay".tr} ${FinanceMoney.format(math.min(installmentRemaining(next), l.outstandingAmount), l.currency)}",
        icon: Icons.payments_outlined,
        size: DsButtonSize.lg,
        expand: true,
        onPressed: !verified
            ? null
            : () async {
                final amount = await finSheet<int>(title: "Repay".tr, child: _RepaySheet(loan: l, next: next));
                if (amount == null || !context.mounted) return;
                await _pay(
                  context,
                  title: "Repay".tr,
                  amount: amount,
                  currency: l.currency,
                  methods: methods,
                  // The same request (amount, payment) keeps its key until it went through.
                  submit: (funding) => FinanceRequestKeys.send(
                    'loan.repay',
                    l.id,
                    amount,
                    {'method': funding.method, 'number': funding.reference ?? ''},
                    (key) => FinanceLendingService.repay(l.id, amount, funding, key),
                  ),
                );
              },
      ),
    );
  }
}

/// How much to repay: prefilled with the installment due, with what it is
/// made of and what remains; any amount up to the outstanding balance.
class _RepaySheet extends StatefulWidget {
  final Loan loan;
  final Map<String, dynamic>? next;

  const _RepaySheet({required this.loan, required this.next});

  @override
  State<_RepaySheet> createState() => _RepaySheetState();
}

class _RepaySheetState extends State<_RepaySheet> {
  /// What is left to pay on the next installment (less what was already paid on it).
  late final int _due = widget.next == null ? 0 : installmentRemaining(widget.next!);
  late final _ctrl = TextEditingController(
    text: _due > 0 ? FinanceAmount.input(_due > widget.loan.outstandingAmount ? widget.loan.outstandingAmount : _due, widget.loan.currency) : '',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.loan;
    final next = widget.next;
    final String cur = l.currency;
    final int? value = FinanceAmount.parse(_ctrl.text, cur);
    final bool ok = value != null && value <= l.outstandingAmount;
    final int penalty = next == null ? 0 : FinanceSummary.intOf(next['penalty']);
    final DateTime? dueDate = next == null ? null : FinanceGroupService.toDate(next['dueDate']);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_due > 0) FinRow("Next installment".tr, FinanceMoney.format(_due, cur), sub: dueDate == null ? null : '${"Due date".tr}: ${_date(dueDate)}'),
        if (penalty > 0) FinRow("Late payment penalty".tr, FinanceMoney.format(penalty, cur)),
        FinRow("Still to repay".tr, FinanceMoney.format(l.outstandingAmount, cur), strong: true),
        const DsGap(DsSpace.lg),
        FinAmountField(label: "Amount".tr, controller: _ctrl, currency: cur, max: l.outstandingAmount, onChanged: (_) => setState(() {})),
        DsButton.primary(label: "Continue".tr, expand: true, onPressed: ok ? () => Get.back(result: value) : null),
      ],
    );
  }
}

/// The repayments recorded by the server, newest first, worded from the
/// borrower's side (money paid out of their account).
class _Repayments extends StatelessWidget {
  final String loanId;
  final String currency;
  final bool borrower;

  const _Repayments({required this.loanId, required this.currency, required this.borrower});

  static String _label(String? s) =>
      const {'succeeded': 'Paid', 'pending': 'Awaiting payment', 'processing': 'Processing', 'failed': 'Failed'}[s] ?? GroupLabels.contribution(s);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceLendingService.repayments(loanId),
      builder: (context, rs) {
        final list = rs.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: "Repayments".tr,
          divided: true,
          children: [
            for (final r in list)
              FinListTile(
                icon: Icons.north_east_rounded,
                title: FinanceUi.date(r['createdAt']),
                subtitle: (r['reference'] ?? '').toString().isEmpty ? null : ltrRef(r['reference']),
                amount: borrower ? FinanceMoney.signed(-FinanceSummary.intOf(r['amount']), currency) : FinanceMoney.format(FinanceSummary.intOf(r['amount']), currency),
                amountColor: r['status'] == 'failed' ? DsColors.of(context).textMuted : null,
                status: r['status']?.toString(),
                statusLabel: _label(r['status']?.toString()).tr,
              ),
          ],
        );
      },
    );
  }
}

/// A supporting line at the top of a form section (what its fields are for).
class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: DsSpace.md),
        child: Text(text, style: DsTypography.bodySm.copyWith(color: DsColors.of(context).textSecondary)),
      );
}

/// A show / hide line inside a section, at least 48 px tall.
class _Toggle extends StatelessWidget {
  final String label;
  final bool expanded;
  final VoidCallback onTap;

  const _Toggle({required this.label, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brand = FinColors.brand(context);
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.brSm,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(child: Text(label, style: DsTypography.label.copyWith(color: brand))),
              Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: brand, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
