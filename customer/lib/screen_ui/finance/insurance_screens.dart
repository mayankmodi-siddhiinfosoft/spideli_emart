import 'dart:io';

import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_insurance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_insurance_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

String _date(dynamic v) {
  final d = v is DateTime ? v : FinanceGroupService.toDate(v);
  return d == null ? '-' : DateFormat('dd MMM yyyy').format(d);
}

DsTone _tone(String? s) => switch (s) {
      'active' || 'paid' || 'approved' || 'quoted' || 'accepted' => DsTone.success,
      'lapsed' || 'rejected' || 'overdue' || 'failed' => DsTone.danger,
      'renewal_due' || 'due' || 'info_requested' || 'cancellation_requested' => DsTone.warning,
      'requested' || 'pending_activation' || 'submitted' || 'under_review' || 'processing' => DsTone.info,
      _ => DsTone.neutral,
    };

IconData _icon(String? category) => switch (category) {
      'health' => Icons.local_hospital_outlined,
      'life' || 'funeral' => Icons.favorite_border_rounded,
      'auto' => Icons.directions_car_outlined,
      'home' => Icons.home_outlined,
      'travel' => Icons.flight_outlined,
      'business' => Icons.storefront_outlined,
      'agriculture' => Icons.agriculture_outlined,
      'device' => Icons.smartphone_outlined,
      _ => Icons.health_and_safety_outlined,
    };

Widget _row(BuildContext context, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary))),
          const DsGap(DsSpace.sm),
          Flexible(child: Align(alignment: AlignmentDirectional.centerEnd, child: Text(value, textAlign: TextAlign.end, style: DsTypography.bodyStrong.tabular))),
        ],
      ),
    );

Widget _caption(BuildContext context, String text) => Text(text, style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary));

String _m(dynamic v, String currency) => FinanceMoney.format(FinanceSummary.intOf(v), currency);

Future<void> _open({String? storagePath, String? url}) async {
  ShowToastDialog.showLoader("Please wait...".tr);
  try {
    await FinanceInsuranceService.open(storagePath: storagePath, url: url);
    ShowToastDialog.closeLoader();
  } catch (_) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Could not open this document.".tr);
  }
}

Widget _documents(List<InsuranceDocument> docs) => DsFormSection(
      title: "Documents".tr,
      icon: Icons.folder_open_outlined,
      children: [
        for (final d in docs)
          DsListTile(
            padding: const EdgeInsets.symmetric(vertical: 2),
            leadingIcon: Icons.description_outlined,
            title: d.name,
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => _open(storagePath: d.storagePath, url: d.url),
          ),
      ],
    );

Widget _coverages(BuildContext context, List<Coverage> coverages, String currency) => DsFormSection(
      title: "What is covered".tr,
      icon: Icons.verified_user_outlined,
      children: [
        for (final c in coverages)
          DsListTile(
            padding: const EdgeInsets.symmetric(vertical: 2),
            leadingIcon: Icons.check_circle_outline_rounded,
            leadingTone: DsTone.success,
            title: c.name,
            subtitle: [if (c.limit != null) '${"Up to".tr} ${FinanceMoney.format(c.limit!, currency)}', if (c.description.isNotEmpty) c.description].join(' · '),
            subtitleMaxLines: 4,
          ),
      ],
    );

/// Picks up to [max] photos (claim evidence).
Widget _photoPicker(BuildContext context, List<File> files, int max, VoidCallback changed) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, f) in files.indexed)
          DsListTile(
            padding: EdgeInsets.zero,
            leadingIcon: Icons.image_outlined,
            title: '${"Photo".tr} ${i + 1}',
            subtitle: f.path.split('/').last,
            trailing: DsIconButton(
              icon: Icons.close_rounded,
              semanticLabel: "Remove".tr,
              onPressed: () {
                files.removeAt(i);
                changed();
              },
            ),
          ),
        if (files.length < max)
          Wrap(spacing: DsSpace.sm, children: [
            for (final (source, label, icon) in [
              (ImageSource.camera, "Take a photo", Icons.photo_camera_outlined),
              (ImageSource.gallery, "Add a photo", Icons.add_photo_alternate_outlined),
            ])
              DsButton.ghost(
                label: label.tr,
                icon: icon,
                onPressed: () async {
                  final picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2400);
                  if (picked != null) {
                    files.add(File(picked.path));
                    changed();
                  }
                },
              ),
          ]),
      ],
    );

/// Spideli Finance > Insurance: policies, quotes, claims and the catalog.
/// `platform_settings/insurance` must exist (admin).
class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> {
  int _tab = 0;
  final Future<InsuranceConfig?> _config = FinanceInsuranceService.config();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InsuranceConfig?>(
      future: _config,
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        return DsScaffold(
          title: "Insurance".tr,
          maxContentWidth: DsLayout.contentMax,
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3))
              : cfg == null
                  ? DsEmptyState(icon: Icons.health_and_safety_outlined, title: "Insurance is not available yet.".tr)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: [
                        DsSegmentedTabs(
                          scrollable: true,
                          segments: [DsSegment("My policies".tr), DsSegment("Quotes".tr), DsSegment("Claims".tr), DsSegment("Insurance offers".tr)],
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                        const DsGap(DsSpace.lg),
                        switch (_tab) {
                          0 => _DocList(
                              key: const ValueKey('policies'),
                              stream: FinanceInsuranceService.policies(),
                              empty: "You have no insurance policy yet.",
                              onEmpty: () => setState(() => _tab = 3),
                              tile: (p) => _Tile(
                                icon: _icon(p['category']?.toString()),
                                title: p['productName']?.toString() ?? '-',
                                subtitle: [p['partnerName'], if ((p['policyNumber'] ?? '').toString().isNotEmpty) '${"No.".tr} ${p['policyNumber']}'].whereType<Object>().join(' · '),
                                status: p['status']?.toString(),
                                label: InsuranceLabels.policy(p['status']?.toString()),
                                onTap: () => Get.to(() => PolicyScreen(policyId: p['id'].toString(), config: cfg)),
                              ),
                            ),
                          1 => _DocList(
                              key: const ValueKey('quotes'),
                              stream: FinanceInsuranceService.quotes(),
                              empty: "You have no quote yet.",
                              onEmpty: () => setState(() => _tab = 3),
                              tile: (q) => _Tile(
                                icon: _icon(q['category']?.toString()),
                                title: q['productName']?.toString() ?? '-',
                                subtitle: q['status'] == 'quoted'
                                    ? '${_m(q['installmentAmount'] ?? q['premium'], q['currency']?.toString() ?? '')} · ${PremiumFrequency.label(q['frequency']?.toString() ?? 'annual').tr}'
                                    : '${"Requested on".tr} ${_date(q['createdAt'])}',
                                status: q['status']?.toString(),
                                label: InsuranceLabels.quote(q['status']?.toString()),
                                onTap: () => Get.to(() => QuoteScreen(quoteId: q['id'].toString(), config: cfg)),
                              ),
                            ),
                          2 => _DocList(
                              key: const ValueKey('claims'),
                              stream: FinanceInsuranceService.claims(),
                              empty: "You have no claim.",
                              tile: (c) => _Tile(
                                icon: Icons.assignment_outlined,
                                title: _m(c['amountClaimed'], c['currency']?.toString() ?? ''),
                                subtitle: '${c['productName'] ?? ''} · ${_date(c['incidentDate'])}',
                                status: c['status']?.toString(),
                                label: InsuranceLabels.claim(c['status']?.toString()),
                                onTap: () => Get.to(() => ClaimScreen(claimId: c['id'].toString(), config: cfg)),
                              ),
                            ),
                          _ => _Catalog(config: cfg),
                        },
                      ],
                    ),
        );
      },
    );
  }
}

class _DocList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  final String empty;
  final VoidCallback? onEmpty;
  final Widget Function(Map<String, dynamic>) tile;

  const _DocList({super.key, required this.stream, required this.empty, required this.tile, this.onEmpty});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return DsErrorState(message: "Could not load this list.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
        if (snap.data!.isEmpty) {
          return DsEmptyState(
            icon: Icons.health_and_safety_outlined,
            title: empty.tr,
            actionLabel: onEmpty == null ? null : "See the insurance offers".tr,
            onAction: onEmpty,
            compact: true,
          );
        }
        return Column(children: [for (final d in snap.data!) tile(d)]);
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? status;
  final String label;
  final VoidCallback onTap;

  const _Tile({required this.icon, required this.title, required this.subtitle, required this.status, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: DsCard.outlined(
        onTap: onTap,
        child: Row(children: [
          DsIconWell(icon: icon, tone: _tone(status)),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: DsTypography.titleSm.tabular),
              if (subtitle.isNotEmpty) _caption(context, subtitle),
            ]),
          ),
          DsBadge(label: label.tr, tone: _tone(status), small: true),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ catalog

class _Catalog extends StatefulWidget {
  final InsuranceConfig config;

  const _Catalog({required this.config});

  @override
  State<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<_Catalog> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InsuranceProduct>>(
      stream: FinanceInsuranceService.products(),
      builder: (context, snap) {
        if (snap.hasError) return DsErrorState(message: "Could not load the insurance offers.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
        final all = snap.data!;
        final categories = widget.config.categories.where((c) => all.any((p) => p.category == c)).toList();
        final list = all.where((p) => _category == null || p.category == _category).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (categories.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final c in [null, ...categories])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                      child: ChoiceChip(
                        label: Text(c == null ? "All".tr : InsuranceLabels.category(c).tr),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                ]),
              ),
            const DsGap(DsSpace.md),
            if (list.isEmpty)
              DsEmptyState(icon: Icons.health_and_safety_outlined, title: "No insurance offer is available yet.".tr, compact: true)
            else
              for (final p in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpace.sm),
                  child: DsCard.outlined(
                    onTap: () => Get.to(() => InsuranceProductScreen(productId: p.id, config: widget.config)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DsIconWell(icon: _icon(p.category), tone: DsTone.brand),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.name, style: DsTypography.titleSm),
                            _caption(context, '${InsuranceLabels.category(p.category).tr}${p.partnerName.isEmpty ? '' : ' · ${p.partnerName}'}'),
                            if (p.summary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.xs), child: Text(p.summary, style: DsTypography.body, maxLines: 3, overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                        if (!p.acceptsQuotes) DsBadge(label: "Unavailable".tr, small: true),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// An insurance product: cover, exclusions, terms and documents.
class InsuranceProductScreen extends StatelessWidget {
  final String productId;
  final InsuranceConfig config;

  const InsuranceProductScreen({super.key, required this.productId, required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<InsuranceProduct?>(
      stream: FinanceInsuranceService.product(productId),
      builder: (context, snap) {
        final p = snap.data;
        return DsScaffold(
          title: p?.name ?? "Insurance".tr,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: p == null || !p.acceptsQuotes
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Get a quote".tr,
                    icon: Icons.request_quote_outlined,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () => Get.to(() => QuoteRequestScreen(product: p, config: config)),
                  ),
                ),
          body: snap.hasError
              ? DsErrorState(message: "Could not load this insurance.".tr)
              : p == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 5))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: [
                        DsCard.tinted(
                          tone: DsTone.brand,
                          child: Row(children: [
                            DsIconWell(icon: _icon(p.category), tone: DsTone.brand),
                            const DsGap(DsSpace.md),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.name, style: DsTypography.title),
                                _caption(context, '${InsuranceLabels.category(p.category).tr}${p.partnerName.isEmpty ? '' : ' · ${"Insurer".tr}: ${p.partnerName}'}'),
                              ]),
                            ),
                          ]),
                        ),
                        if (p.summary.isNotEmpty || p.description.isNotEmpty) ...[
                          const DsGap(DsSpace.md),
                          if (p.summary.isNotEmpty) Text(p.summary, style: DsTypography.bodyStrong),
                          if (p.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.xs), child: Text(p.description, style: DsTypography.body)),
                        ],
                        if (p.coverages.isNotEmpty) ...[const DsGap(DsSpace.md), _coverages(context, p.coverages, p.currency)],
                        const DsGap(DsSpace.md),
                        DsFormSection(
                          title: "Key facts".tr,
                          icon: Icons.fact_check_outlined,
                          children: [
                            _row(context, "Cover period".tr, '${p.termMonths} ${"months".tr}'),
                            _row(context, "Deductible".tr, p.deductible == 0 ? "None".tr : FinanceMoney.format(p.deductible, p.currency)),
                            _row(context, "Waiting period".tr, p.waitingPeriodDays == 0 ? "None".tr : '${p.waitingPeriodDays} ${"days".tr}'),
                            _row(context, "Payment".tr, p.frequencies.keys.map((f) => PremiumFrequency.label(f).tr).join(', ')),
                          ],
                        ),
                        if (p.exclusions.isNotEmpty) ...[
                          const DsGap(DsSpace.md),
                          DsFormSection(
                            title: "What is not covered".tr,
                            icon: Icons.block_outlined,
                            children: [
                              for (final e in p.exclusions)
                                DsListTile(padding: const EdgeInsets.symmetric(vertical: 2), leadingIcon: Icons.remove_circle_outline_rounded, leadingTone: DsTone.danger, title: e, subtitleMaxLines: 4),
                            ],
                          ),
                        ],
                        if (p.documents.isNotEmpty) ...[const DsGap(DsSpace.md), _documents(p.documents)],
                        if (p.terms.isNotEmpty) ...[
                          const DsGap(DsSpace.md),
                          DsFormSection(title: "Terms".tr, subtitle: '${"Version".tr} ${p.termsVersion}', icon: Icons.gavel_rounded, children: [Text(p.terms, style: DsTypography.body)]),
                        ],
                      ],
                    ),
        );
      },
    );
  }
}

// ------------------------------------------------------------ quote request

/// The quote form: the product's questions, payment frequency and start
/// date, with a simulated premium when the product publishes its rating.
class QuoteRequestScreen extends StatefulWidget {
  final InsuranceProduct product;
  final InsuranceConfig config;

  const QuoteRequestScreen({super.key, required this.product, required this.config});

  @override
  State<QuoteRequestScreen> createState() => _QuoteRequestScreenState();
}

class _QuoteRequestScreenState extends State<QuoteRequestScreen> {
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _numbers = {};
  late String _frequency = widget.product.frequencies.keys.first;
  DateTime _start = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));

  @override
  void dispose() {
    for (final c in _numbers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _complete => widget.product.factors.every((f) => f.multiplierFor(_answers[f.key]) != null);

  Future<void> _submit() async {
    if (!_complete) return ShowToastDialog.showToast("Please answer every question with a valid value.".tr);
    String? id;
    final ok = await FinanceUi.run(() async {
      id = await FinanceInsuranceService.requestQuote(productId: widget.product.id, answers: _answers, frequency: _frequency, coverStart: _start);
    }, success: "Quote requested");
    if (ok && id != null) Get.off(() => QuoteScreen(quoteId: id!, config: widget.config));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final estimate = RateSimulator.estimate(p, _answers, _frequency);
    return DsScaffold(
      title: "Get a quote".tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: DsStickyBar(
        child: FinanceKycGate(
          builder: (context, verified) => DsButton.primary(label: "Request my quote".tr, size: DsButtonSize.lg, expand: true, onPressed: verified && _complete ? _submit : null),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          if (p.factors.isNotEmpty)
            DsFormSection(
              title: "About you and what to insure".tr,
              subtitle: p.name,
              icon: Icons.assignment_ind_outlined,
              children: [
                for (final f in p.factors)
                  if (f.type == 'select')
                    DsDropdown<String>(
                      label: f.label,
                      value: _answers[f.key] as String?,
                      items: [for (final o in f.options) DropdownMenuItem(value: o.value, child: Text(o.label))],
                      onChanged: (v) => setState(() => _answers[f.key] = v),
                    )
                  else
                    DsTextField(
                      label: '${f.label}${f.unit.isEmpty ? '' : ' (${f.unit})'}',
                      controller: _numbers.putIfAbsent(f.key, TextEditingController.new),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      helper: f.min == null && f.max == null ? null : '${f.min?.toStringAsFixed(0) ?? ''} - ${f.max?.toStringAsFixed(0) ?? ''}',
                      errorText: _numbers[f.key]?.text.isNotEmpty == true && f.multiplierFor(_answers[f.key]) == null ? "Outside the accepted range".tr : null,
                      onChanged: (v) => setState(() => _answers[f.key] = double.tryParse(v.replaceAll(',', '.'))),
                    ),
              ],
            ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Cover".tr,
            icon: Icons.event_outlined,
            children: [
              Text("Pay".tr, style: DsTypography.label),
              const DsGap(DsSpace.xs),
              Wrap(spacing: DsSpace.sm, children: [
                for (final f in p.frequencies.keys) ChoiceChip(label: Text(PremiumFrequency.label(f).tr), selected: _frequency == f, onSelected: (_) => setState(() => _frequency = f)),
              ]),
              const DsGap(DsSpace.md),
              DsListTile(
                padding: EdgeInsets.zero,
                leadingIcon: Icons.calendar_today_outlined,
                title: "Cover starts on".tr,
                subtitle: _date(_start),
                showChevron: true,
                onTap: () async {
                  final today = DateUtils.dateOnly(DateTime.now());
                  final d = await showDatePicker(context: context, initialDate: _start, firstDate: today, lastDate: today.add(const Duration(days: 180)));
                  if (d != null) setState(() => _start = d);
                },
              ),
            ],
          ),
          if (p.canSimulate) ...[
            const DsGap(DsSpace.lg),
            DsFormSection(
              title: "Estimated premium".tr,
              icon: Icons.calculate_outlined,
              children: [
                if (estimate == null)
                  _caption(context, "Answer the questions to see an estimate.".tr)
                else ...[
                  _row(context, PremiumFrequency.label(_frequency).tr, FinanceMoney.format(estimate.installment, p.currency)),
                  if (estimate.installmentsPerYear > 1) _row(context, "Total for the year".tr, FinanceMoney.format(estimate.yearlyTotal, p.currency)),
                ],
                const DsGap(DsSpace.xs),
                _caption(context, "This is an estimate from the published rates. The insurer confirms the price in your quote.".tr),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- quote

/// A quote from the insurer, and its acceptance (signature + first premium).
class QuoteScreen extends StatefulWidget {
  final String quoteId;
  final InsuranceConfig config;

  const QuoteScreen({super.key, required this.quoteId, required this.config});

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  final _signature = TextEditingController();
  bool _accepted = false;

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  Future<void> _accept(Map<String, dynamic> q, int amount, String cur) async {
    final key = FinanceGroupService.newRequestKey();
    await FinancePaySheet.show(
      context,
      title: "${"First premium".tr} · ${q['productName'] ?? ''}",
      amount: amount,
      currency: cur,
      methods: widget.config.paymentMethods,
      submit: (payment) => FinanceInsuranceService.acceptQuote(
        quoteId: widget.quoteId,
        termsVersion: FinanceSummary.intOf(q['termsVersion']),
        signatureName: _signature.text.trim(),
        payment: payment,
        requestKey: key,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceInsuranceService.doc('insurance_quotes', widget.quoteId),
      builder: (context, snap) {
        final q = snap.data;
        final quote = q == null ? null : Quote.fromMap(q, FinanceGroupService.toDate);
        final bool canAccept = quote?.canAccept(DateTime.now()) == true;
        final String cur = q?['currency']?.toString() ?? '';
        final int amount = FinanceSummary.intOf(q?['installmentAmount'] ?? q?['premium']);
        return DsScaffold(
          title: "Quote".tr,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: !canAccept
              ? null
              : DsStickyBar(
                  child: FinanceKycGate(
                    builder: (context, verified) => DsButton.primary(
                      label: "${"Accept and pay".tr} ${FinanceMoney.format(amount, cur)}",
                      icon: Icons.lock_outline_rounded,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: verified && _accepted && _signature.text.trim().length >= 3 ? () => _accept(q!, amount, cur) : null,
                    ),
                  ),
                ),
          body: snap.hasError
              ? DsErrorState(message: "Could not load this quote.".tr)
              : q == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: [
                        DsCard.tinted(
                          tone: _tone(quote!.status),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Expanded(child: Text(q['productName']?.toString() ?? '-', style: DsTypography.titleSm)),
                                DsBadge(label: InsuranceLabels.quote(quote.status).tr, tone: _tone(quote.status)),
                              ]),
                              if ((q['partnerName'] ?? '').toString().isNotEmpty) _caption(context, '${"Insurer".tr}: ${q['partnerName']}'),
                              if (quote.status == 'quoted' && amount > 0) ...[
                                const DsGap(DsSpace.sm),
                                Text('${FinanceMoney.format(amount, cur)} · ${PremiumFrequency.label(q['frequency']?.toString() ?? 'annual').tr}', style: DsTypography.title.tabular),
                              ],
                              if ((q['reason'] ?? '').toString().isNotEmpty)
                                Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: DsInlineAlert(tone: _tone(quote.status), title: "Reason".tr, message: q['reason'].toString())),
                            ],
                          ),
                        ),
                        if (quote.status == 'requested') ...[
                          const DsGap(DsSpace.md),
                          DsInlineAlert(tone: DsTone.info, message: "The insurer is preparing your quote. You are notified when it is ready.".tr),
                        ],
                        if (quote.status == 'quoted' && !canAccept) ...[
                          const DsGap(DsSpace.md),
                          DsInlineAlert(tone: DsTone.warning, message: "This quote is no longer valid. Request a new one.".tr),
                        ],
                        const DsGap(DsSpace.md),
                        DsFormSection(
                          title: "Details".tr,
                          icon: Icons.receipt_long_outlined,
                          children: [
                            if (q['premium'] != null) _row(context, "Premium for the year".tr, _m(q['premium'], cur)),
                            if (q['deductible'] != null) _row(context, "Deductible".tr, _m(q['deductible'], cur)),
                            if (q['coverStart'] != null) _row(context, "Cover starts on".tr, _date(q['coverStart'])),
                            if (q['coverEnd'] != null) _row(context, "Cover ends on".tr, _date(q['coverEnd'])),
                            if (q['validUntil'] != null) _row(context, "Quote valid until".tr, _date(q['validUntil'])),
                            if ((q['insurerReference'] ?? '').toString().isNotEmpty) _row(context, "Reference".tr, q['insurerReference'].toString()),
                          ],
                        ),
                        if (Coverage.list(q['coverages']).isNotEmpty) ...[const DsGap(DsSpace.md), _coverages(context, Coverage.list(q['coverages']), cur)],
                        if (InsuranceDocument.list(q['documents']).isNotEmpty) ...[const DsGap(DsSpace.md), _documents(InsuranceDocument.list(q['documents']))],
                        if (canAccept) ...[
                          const DsGap(DsSpace.md),
                          DsFormSection(
                            title: "Subscription".tr,
                            subtitle: '${"Terms version".tr} ${q['termsVersion'] ?? '-'}',
                            icon: Icons.draw_outlined,
                            children: [
                              if ((q['terms'] ?? '').toString().isNotEmpty)
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 220),
                                  child: Scrollbar(child: SingleChildScrollView(child: Text(q['terms'].toString(), style: DsTypography.body))),
                                ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _accepted,
                                onChanged: (v) => setState(() => _accepted = v ?? false),
                                title: Text("I have read the quote, the cover, the exclusions and the terms, and I accept them.".tr),
                              ),
                              DsTextField(
                                label: "Full name".tr,
                                helper: "Type your full name to sign. It is recorded with the date and the terms version.".tr,
                                controller: _signature,
                                requiredMark: true,
                                textCapitalization: TextCapitalization.words,
                                onChanged: (_) => setState(() {}),
                                bottomSpacing: 0,
                              ),
                              const DsGap(DsSpace.sm),
                              _caption(context, "Your policy starts once the insurer confirms it, after your payment.".tr),
                            ],
                          ),
                        ],
                        if (quote.canDecline)
                          Padding(
                            padding: const EdgeInsets.only(top: DsSpace.lg),
                            child: DsButton.ghost(
                              label: "Decline this quote".tr,
                              icon: Icons.close_rounded,
                              onPressed: () => FinanceUi.run(() => FinanceInsuranceService.declineQuote(widget.quoteId), success: "Quote declined"),
                            ),
                          ),
                        if ((q['policyId'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: DsSpace.lg),
                            child: DsButton.secondary(
                              label: "See my policy".tr,
                              icon: Icons.verified_user_outlined,
                              expand: true,
                              onPressed: () => Get.off(() => PolicyScreen(policyId: q['policyId'].toString(), config: widget.config)),
                            ),
                          ),
                      ],
                    ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------- policy

/// A policy: cover, documents, premiums, renewal, cancellation and claims.
class PolicyScreen extends StatelessWidget {
  final String policyId;
  final InsuranceConfig config;

  const PolicyScreen({super.key, required this.policyId, required this.config});

  Future<void> _cancel(BuildContext context) async {
    final reason = TextEditingController();
    final ok = await DsBottomSheet.show<bool>(
      title: "Cancel this policy".tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("The insurer handles the cancellation under the policy terms (notice period, any refund of premium).".tr, style: DsTypography.body),
          const DsGap(DsSpace.md),
          DsTextField(label: "Reason (optional)".tr, controller: reason, maxLines: 3),
          DsButton.primary(label: "Request the cancellation".tr, expand: true, onPressed: () => Get.back(result: true)),
        ],
      ),
    );
    if (ok == true) await FinanceUi.run(() => FinanceInsuranceService.requestCancellation(policyId, reason.text.trim()), success: "Cancellation requested");
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceInsuranceService.doc('insurance_policies', policyId),
      builder: (context, snap) {
        final p = snap.data;
        final String status = p?['status']?.toString() ?? '';
        return DsScaffold(
          title: "Policy".tr,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: p == null || !PolicyActions.canClaim(status)
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Make a claim".tr,
                    icon: Icons.assignment_outlined,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () => Get.to(() => ClaimFormScreen(policy: p, config: config)),
                  ),
                ),
          body: snap.hasError
              ? DsErrorState(message: "Could not load this policy.".tr)
              : p == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                  : _body(context, p, status),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> p, String status) {
    final String cur = p['currency']?.toString() ?? '';
    final int renewalPremium = FinanceSummary.intOf(p['renewalPremium']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        DsCard.tinted(
          tone: _tone(status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                DsIconWell(icon: _icon(p['category']?.toString()), tone: _tone(status)),
                const DsGap(DsSpace.md),
                Expanded(child: Text(p['productName']?.toString() ?? '-', style: DsTypography.titleSm)),
                DsBadge(label: InsuranceLabels.policy(status).tr, tone: _tone(status)),
              ]),
              const DsGap(DsSpace.sm),
              if ((p['partnerName'] ?? '').toString().isNotEmpty) _row(context, "Insurer".tr, p['partnerName'].toString()),
              if ((p['policyNumber'] ?? '').toString().isNotEmpty) _row(context, "Policy number".tr, p['policyNumber'].toString()),
              _row(context, "Cover".tr, '${_date(p['coverStart'])} - ${_date(p['coverEnd'])}'),
              if (p['installmentAmount'] != null || p['premium'] != null)
                _row(context, "Premium".tr, '${_m(p['installmentAmount'] ?? p['premium'], cur)} · ${PremiumFrequency.label(p['frequency']?.toString() ?? 'annual').tr}'),
              if (p['nextPremiumDue'] != null) _row(context, "Next payment".tr, _date(p['nextPremiumDue'])),
              if (p['deductible'] != null) _row(context, "Deductible".tr, _m(p['deductible'], cur)),
              if ((p['reason'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: DsInlineAlert(tone: _tone(status), title: "Reason".tr, message: p['reason'].toString())),
            ],
          ),
        ),
        if (status == 'pending_activation') ...[
          const DsGap(DsSpace.md),
          DsInlineAlert(tone: DsTone.info, message: "We are waiting for the insurer to confirm your policy. You are covered only once it is active.".tr),
        ],
        if (status == 'lapsed') ...[
          const DsGap(DsSpace.md),
          DsInlineAlert(tone: DsTone.danger, message: "A premium was not paid: you are not covered. Pay it to restore your cover if the insurer allows it.".tr),
        ],
        if (PolicyActions.canRenew(status, renewalPremium)) ...[
          const DsGap(DsSpace.md),
          DsCard.outlined(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text("Renewal".tr, style: DsTypography.titleSm),
              _row(context, "Premium for the next period".tr, FinanceMoney.format(renewalPremium, cur)),
              if (p['renewalDate'] != null) _row(context, "Renew before".tr, _date(p['renewalDate'])),
              const DsGap(DsSpace.sm),
              FinanceKycGate(
                builder: (context, verified) => DsButton.primary(
                  label: "${"Renew and pay".tr} ${FinanceMoney.format(renewalPremium, cur)}",
                  expand: true,
                  onPressed: !verified
                      ? null
                      : () async {
                          final key = FinanceGroupService.newRequestKey();
                          await FinancePaySheet.show(context,
                              title: "Renewal".tr, amount: renewalPremium, currency: cur, methods: config.paymentMethods, submit: (pay) => FinanceInsuranceService.renew(policyId, pay, key));
                        },
                ),
              ),
            ]),
          ),
        ],
        if (PolicyActions.canSetAutoRenew(status))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: p['autoRenew'] == true,
            title: Text("Renew automatically".tr),
            subtitle: Text("You are notified before each renewal and can pay or stop it.".tr),
            onChanged: (v) => FinanceUi.run(() => FinanceInsuranceService.setAutoRenew(policyId, v), success: v ? "Automatic renewal on" : "Automatic renewal off"),
          ),
        if (Coverage.list(p['coverages']).isNotEmpty) ...[const DsGap(DsSpace.md), _coverages(context, Coverage.list(p['coverages']), cur)],
        if (InsuranceDocument.list(p['documents']).isNotEmpty) ...[const DsGap(DsSpace.md), _documents(InsuranceDocument.list(p['documents']))],
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceInsuranceService.premiums(policyId),
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: DsFormSection(
                title: "Premiums".tr,
                icon: Icons.event_note_outlined,
                children: [
                  for (final pr in list)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(child: Text('${_date(pr['dueDate'])} · ${_m(pr['amount'], cur)}', style: DsTypography.body.tabular)),
                        if (PolicyActions.premiumPayable(pr['status']?.toString()))
                          FinanceKycGate(
                            builder: (context, verified) => DsButton.primary(
                              label: "Pay".tr,
                              size: DsButtonSize.sm,
                              onPressed: !verified
                                  ? null
                                  : () async {
                                      final key = FinanceGroupService.newRequestKey();
                                      final int amount = FinanceSummary.intOf(pr['amount']);
                                      await FinancePaySheet.show(context,
                                          title: "Premium".tr,
                                          amount: amount,
                                          currency: cur,
                                          methods: config.paymentMethods,
                                          submit: (pay) => FinanceInsuranceService.payPremium(policyId, pr['id'].toString(), pay, key));
                                    },
                            ),
                          )
                        else
                          DsBadge(label: InsuranceLabels.premium(pr['status']?.toString()).tr, tone: _tone(pr['status']?.toString()), small: true),
                      ]),
                    ),
                ],
              ),
            );
          },
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceInsuranceService.policyClaims(policyId),
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: DsFormSection(
                title: "Claims".tr,
                icon: Icons.assignment_outlined,
                children: [
                  for (final c in list)
                    DsListTile(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      leadingIcon: Icons.assignment_outlined,
                      leadingTone: _tone(c['status']?.toString()),
                      title: _m(c['amountClaimed'], cur),
                      subtitle: '${_date(c['incidentDate'])} · ${InsuranceLabels.claim(c['status']?.toString()).tr}',
                      showChevron: true,
                      onTap: () => Get.to(() => ClaimScreen(claimId: c['id'].toString(), config: config)),
                    ),
                ],
              ),
            );
          },
        ),
        if (PolicyActions.canCancel(status))
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.lg),
            child: DsButton.ghost(label: "Cancel this policy".tr, icon: Icons.close_rounded, onPressed: () => _cancel(context)),
          ),
      ],
    );
  }
}

// -------------------------------------------------------------------- claim

/// Declaring a claim: what happened, when, how much, and photos.
class ClaimFormScreen extends StatefulWidget {
  final Map<String, dynamic> policy;
  final InsuranceConfig config;

  const ClaimFormScreen({super.key, required this.policy, required this.config});

  @override
  State<ClaimFormScreen> createState() => _ClaimFormScreenState();
}

class _ClaimFormScreenState extends State<ClaimFormScreen> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final List<File> _files = [];
  DateTime? _incident;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  String get _currency => widget.policy['currency']?.toString() ?? '';

  Future<void> _submit() async {
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    if (_incident == null) return ShowToastDialog.showToast("Choose the date of the incident.".tr);
    if (_description.text.trim().length < 10) return ShowToastDialog.showToast("Describe what happened.".tr);
    if (amount == null) return ShowToastDialog.showToast("Enter the amount you claim.".tr);
    String? id;
    final ok = await FinanceUi.run(() async {
      id = await FinanceInsuranceService.submitClaim(
        policyId: widget.policy['id'].toString(),
        incidentDate: _incident!,
        description: _description.text.trim(),
        amountClaimed: amount,
        files: _files,
      );
    }, success: "Claim sent");
    if (ok && id != null) Get.off(() => ClaimScreen(claimId: id!, config: widget.config));
  }

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime first = FinanceGroupService.toDate(widget.policy['coverStart']) ?? today.subtract(const Duration(days: 365));
    return DsScaffold(
      title: "Make a claim".tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Send my claim".tr, size: DsButtonSize.lg, expand: true, onPressed: _submit)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsFormSection(
            title: "What happened".tr,
            subtitle: widget.policy['productName']?.toString(),
            icon: Icons.assignment_outlined,
            children: [
              DsListTile(
                padding: EdgeInsets.zero,
                leadingIcon: Icons.calendar_today_outlined,
                title: "Date of the incident".tr,
                subtitle: _incident == null ? "Choose a date".tr : _date(_incident),
                showChevron: true,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: today.isBefore(first) ? first : today, firstDate: first.isAfter(today) ? today : first, lastDate: today);
                  if (d != null) setState(() => _incident = d);
                },
              ),
              const DsGap(DsSpace.sm),
              DsTextField(label: "Description".tr, hint: "Where, how, and what was damaged or lost.".tr, controller: _description, maxLines: 5, requiredMark: true),
              DsTextField(
                label: "${"Amount claimed".tr} ($_currency)",
                controller: _amount,
                requiredMark: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                bottomSpacing: 0,
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Evidence".tr,
            subtitle: "Photos of the damage, receipts, a police or medical report... Only the insurer sees them.".tr,
            icon: Icons.photo_library_outlined,
            children: [_photoPicker(context, _files, widget.config.maxClaimFiles, () => setState(() {}))],
          ),
          const DsGap(DsSpace.md),
          _caption(context, "The insurer decides on your claim. You can follow it here and you are notified of each step.".tr),
        ],
      ),
    );
  }
}

/// A claim and its tracking.
class ClaimScreen extends StatefulWidget {
  final String claimId;
  final InsuranceConfig config;

  const ClaimScreen({super.key, required this.claimId, required this.config});

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final _message = TextEditingController();
  final List<File> _files = [];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _respond() async {
    if (_message.text.trim().isEmpty && _files.isEmpty) return ShowToastDialog.showToast("Add a message or a photo.".tr);
    final ok = await FinanceUi.run(() => FinanceInsuranceService.respondToClaim(widget.claimId, _message.text.trim(), List.of(_files)), success: "Information sent");
    if (ok) {
      setState(() {
        _message.clear();
        _files.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceInsuranceService.doc('insurance_claims', widget.claimId),
      builder: (context, snap) {
        final c = snap.data;
        return DsScaffold(
          title: "Claim".tr,
          maxContentWidth: DsLayout.contentMax,
          body: snap.hasError
              ? DsErrorState(message: "Could not load this claim.".tr)
              : c == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                  : _body(context, c),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> c) {
    final String status = c['status']?.toString() ?? '';
    final String cur = c['currency']?.toString() ?? '';
    final steps = InsuranceLabels.claimSteps;
    final int at = steps.indexOf(status == 'info_requested' ? 'under_review' : status);
    final docs = InsuranceDocument.list(c['documents']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        DsCard.tinted(
          tone: _tone(status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(_m(c['amountClaimed'], cur), style: DsTypography.title.tabular)),
                DsBadge(label: InsuranceLabels.claim(status).tr, tone: _tone(status)),
              ]),
              _caption(context, '${c['productName'] ?? ''}${(c['policyNumber'] ?? '').toString().isEmpty ? '' : ' · ${"No.".tr} ${c['policyNumber']}'}'),
              if ((c['reason'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.sm),
                  child: DsInlineAlert(tone: _tone(status), title: (status == 'info_requested' ? "The insurer asks" : "Reason").tr, message: c['reason'].toString()),
                ),
            ],
          ),
        ),
        const DsGap(DsSpace.md),
        if (at >= 0 && status != 'rejected' && status != 'withdrawn')
          DsTimeline(
            steps: [
              for (final (i, s) in steps.indexed)
                DsTimelineStep(
                  title: InsuranceLabels.claim(s).tr,
                  state: i < at || (i == at && i == steps.length - 1) ? DsStepState.done : (i == at ? DsStepState.current : DsStepState.upcoming),
                ),
            ],
          ),
        const DsGap(DsSpace.md),
        DsFormSection(
          title: "Details".tr,
          icon: Icons.receipt_long_outlined,
          children: [
            _row(context, "Date of the incident".tr, _date(c['incidentDate'])),
            _row(context, "Declared on".tr, _date(c['createdAt'])),
            if (c['approvedAmount'] != null) _row(context, "Amount approved".tr, _m(c['approvedAmount'], cur)),
            if (c['paidAmount'] != null) _row(context, "Amount paid".tr, _m(c['paidAmount'], cur)),
            if (c['paidAt'] != null) _row(context, "Paid on".tr, _date(c['paidAt'])),
            if ((c['insurerReference'] ?? '').toString().isNotEmpty) _row(context, "Reference".tr, c['insurerReference'].toString()),
            if ((c['description'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: Text(c['description'].toString(), style: DsTypography.body)),
          ],
        ),
        if (docs.isNotEmpty) ...[const DsGap(DsSpace.md), _documents(docs)],
        if (PolicyActions.canRespondToClaim(status)) ...[
          const DsGap(DsSpace.md),
          DsFormSection(
            title: "Send more information".tr,
            icon: Icons.reply_outlined,
            children: [
              DsTextField(label: "Message".tr, controller: _message, maxLines: 4),
              _photoPicker(context, _files, widget.config.maxClaimFiles, () => setState(() {})),
              const DsGap(DsSpace.sm),
              DsButton.primary(label: "Send".tr, expand: true, onPressed: _respond),
            ],
          ),
        ],
        if (PolicyActions.canWithdrawClaim(status))
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.lg),
            child: DsButton.ghost(
              label: "Withdraw this claim".tr,
              icon: Icons.close_rounded,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text("Withdraw this claim?".tr),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: Text("Keep it".tr)),
                      TextButton(onPressed: () => Navigator.pop(d, true), child: Text("Withdraw".tr)),
                    ],
                  ),
                );
                if (ok == true) await FinanceUi.run(() => FinanceInsuranceService.withdrawClaim(widget.claimId), success: "Claim withdrawn");
              },
            ),
          ),
      ],
    );
  }
}
