import 'dart:io';

import 'package:customer/screen_ui/finance/fin_ds.dart';
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
  return d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));
}

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

String _m(dynamic v, String currency) => FinanceMoney.format(FinanceSummary.intOf(v), currency);

/// Padding of a form section: fields carry their own bottom spacing.
const EdgeInsets _form = EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs);

/// Sheets open in their own route, outside [FinScaffold]: pin the finance accent there too.
Widget _finAccent(Widget child) => Builder(
      builder: (context) => DsAccentScope(color: Theme.of(context).brightness == Brightness.dark ? FinColors.navyDark : FinColors.navy, child: child),
    );

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

/// A full-page state (loading / error / empty) inside the standard body.
Widget _page(Widget state) => FinBody(children: [state]);

class _Documents extends StatelessWidget {
  final List<InsuranceDocument> docs;

  const _Documents(this.docs);

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return FinSection(
      title: "Documents".tr,
      divided: true,
      children: [
        for (final d in docs)
          FinListTile(
            icon: Icons.description_outlined,
            iconTone: DsTone.brand,
            title: d.name,
            trailing: Icon(Icons.open_in_new_rounded, size: 18, color: c.textMuted),
            onTap: () => _open(storagePath: d.storagePath, url: d.url),
          ),
      ],
    );
  }
}

/// One line of cover (or an exclusion): what, the detail, and the limit.
class _CoverRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String? limit;

  const _CoverRow({required this.icon, required this.color, required this.title, this.description = '', this.limit});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: color)),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
                if (description.isNotEmpty) ...[
                  const DsGap(DsSpace.xxs),
                  Text(description, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
                ],
              ]),
            ),
            if (limit != null) ...[
              const DsGap(DsSpace.md),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text("Up to".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
                Text(limit!, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary).tabular),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Coverages extends StatelessWidget {
  final List<Coverage> coverages;
  final String currency;

  const _Coverages(this.coverages, this.currency);

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return FinSection(
      title: "What is covered".tr,
      divided: true,
      children: [
        for (final cv in coverages)
          _CoverRow(
            icon: Icons.check_circle_outline_rounded,
            color: c.successStrong,
            title: cv.name,
            description: cv.description,
            limit: cv.limit == null ? null : FinanceMoney.format(cv.limit!, currency),
          ),
      ],
    );
  }
}

/// A date field with the DS input look; opens a picker.
class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final String? placeholder;
  final bool required;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.onTap, this.placeholder, this.required = false});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsFieldLabel(label, required: required),
          Semantics(
            button: true,
            label: '$label: ${value ?? placeholder ?? ''}',
            onTap: onTap,
            child: ExcludeSemantics(
              child: Material(
                color: c.surfaceAlt,
                borderRadius: DsRadius.brMd,
                child: InkWell(
                  borderRadius: DsRadius.brMd,
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: 14),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            value ?? placeholder ?? '',
                            style: value == null ? DsTypography.body.copyWith(color: c.textMuted) : DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                          ),
                        ),
                        Icon(Icons.calendar_today_outlined, size: 20, color: c.textMuted),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks up to [max] photos (claim evidence).
class _PhotoPicker extends StatelessWidget {
  final List<File> files;
  final int max;
  final VoidCallback changed;

  const _PhotoPicker({required this.files, required this.max, required this.changed});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, f) in files.indexed) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
          FinListTile(
            icon: Icons.image_outlined,
            iconTone: DsTone.brand,
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
        ],
        if (files.length < max)
          Padding(
            padding: EdgeInsets.only(top: files.isEmpty ? 0 : DsSpace.sm),
            child: Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.sm, children: [
              for (final (source, label, icon) in [
                (ImageSource.camera, "Take a photo", Icons.photo_camera_outlined),
                (ImageSource.gallery, "Add a photo", Icons.add_photo_alternate_outlined),
              ])
                DsButton.secondary(
                  label: label.tr,
                  icon: icon,
                  size: DsButtonSize.sm,
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2400);
                    if (picked != null) {
                      files.add(File(picked.path));
                      changed();
                    }
                  },
                ),
            ]),
          ),
      ],
    );
  }
}

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
        return FinScaffold(
          title: "Insurance".tr,
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? _page(FinState.loading())
              : cfg == null
                  ? _page(FinState.empty(Icons.health_and_safety_outlined, "Insurance is not available yet.".tr))
                  : FinBody(
                      children: [
                        DsSegmentedTabs(
                          scrollable: true,
                          segments: [DsSegment("My policies".tr), DsSegment("Quotes".tr), DsSegment("Claims".tr), DsSegment("Insurance offers".tr)],
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                        switch (_tab) {
                          0 => _DocList(
                              key: const ValueKey('policies'),
                              stream: FinanceInsuranceService.policies(),
                              empty: "You have no insurance policy yet.",
                              onEmpty: () => setState(() => _tab = 3),
                              tile: (p) => FinListTile(
                                icon: _icon(p['category']?.toString()),
                                iconTone: DsTone.brand,
                                title: p['productName']?.toString() ?? '-',
                                subtitle: [
                                  if ((p['partnerName'] ?? '').toString().isNotEmpty) p['partnerName'].toString(),
                                  if ((p['policyNumber'] ?? '').toString().isNotEmpty) '${"No.".tr} ${ltrRef(p['policyNumber'])}',
                                ].join(' · '),
                                status: p['status']?.toString(),
                                statusLabel: InsuranceLabels.policy(p['status']?.toString()).tr,
                                chevron: true,
                                onTap: () => Get.to(() => PolicyScreen(policyId: p['id'].toString(), config: cfg)),
                              ),
                            ),
                          1 => _DocList(
                              key: const ValueKey('quotes'),
                              stream: FinanceInsuranceService.quotes(),
                              empty: "You have no quote yet.",
                              onEmpty: () => setState(() => _tab = 3),
                              tile: (q) => FinListTile(
                                icon: _icon(q['category']?.toString()),
                                iconTone: DsTone.brand,
                                title: q['productName']?.toString() ?? '-',
                                subtitle: q['status'] == 'quoted'
                                    ? PremiumFrequency.label(q['frequency']?.toString() ?? 'annual').tr
                                    : '${"Requested on".tr} ${_date(q['createdAt'])}',
                                amount: q['status'] == 'quoted' ? _m(q['installmentAmount'] ?? q['premium'], q['currency']?.toString() ?? '') : null,
                                status: q['status']?.toString(),
                                statusLabel: InsuranceLabels.quote(q['status']?.toString()).tr,
                                chevron: true,
                                onTap: () => Get.to(() => QuoteScreen(quoteId: q['id'].toString(), config: cfg)),
                              ),
                            ),
                          2 => _DocList(
                              key: const ValueKey('claims'),
                              stream: FinanceInsuranceService.claims(),
                              empty: "You have no claim.",
                              icon: Icons.assignment_outlined,
                              tile: (c) => FinListTile(
                                icon: Icons.assignment_outlined,
                                iconTone: DsTone.brand,
                                title: (c['productName'] ?? '').toString().isEmpty ? "Claim".tr : c['productName'].toString(),
                                subtitle: _date(c['incidentDate']),
                                amount: _m(c['amountClaimed'], c['currency']?.toString() ?? ''),
                                status: c['status']?.toString(),
                                statusLabel: InsuranceLabels.claim(c['status']?.toString()).tr,
                                chevron: true,
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
  final IconData icon;
  final VoidCallback? onEmpty;
  final Widget Function(Map<String, dynamic>) tile;

  const _DocList({super.key, required this.stream, required this.empty, required this.tile, this.onEmpty, this.icon = Icons.health_and_safety_outlined});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load this list.".tr);
        if (!snap.hasData) return FinState.loading();
        if (snap.data!.isEmpty) {
          return FinState.empty(icon, empty.tr, actionLabel: onEmpty == null ? null : "See the insurance offers".tr, onAction: onEmpty);
        }
        return FinSection(top: DsSpace.lg, divided: true, children: [for (final d in snap.data!) tile(d)]);
      },
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
        if (snap.hasError) return FinState.error("Could not load the insurance offers.".tr);
        if (!snap.hasData) return FinState.loading();
        final all = snap.data!;
        final categories = widget.config.categories.where((c) => all.any((p) => p.category == c)).toList();
        final list = all.where((p) => _category == null || p.category == _category).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (categories.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: DsSpace.lg),
                child: SingleChildScrollView(
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
              ),
            if (list.isEmpty)
              FinState.empty(Icons.health_and_safety_outlined, "No insurance offer is available yet.".tr)
            else
              FinSection(
                top: categories.length > 1 ? DsSpace.md : DsSpace.lg,
                divided: true,
                children: [
                  for (final p in list)
                    FinListTile(
                      icon: _icon(p.category),
                      iconTone: DsTone.brand,
                      title: p.name,
                      subtitle: [
                        '${InsuranceLabels.category(p.category).tr}${p.partnerName.isEmpty ? '' : ' · ${p.partnerName}'}',
                        if (p.summary.isNotEmpty) p.summary,
                      ].join('\n'),
                      status: p.acceptsQuotes ? null : 'closed',
                      statusLabel: p.acceptsQuotes ? null : "Unavailable".tr,
                      chevron: true,
                      onTap: () => Get.to(() => InsuranceProductScreen(productId: p.id, config: widget.config)),
                    ),
                ],
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
        return FinScaffold(
          title: p == null ? "Insurance".tr : InsuranceLabels.category(p.category).tr,
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
              ? _page(FinState.error("Could not load this insurance.".tr))
              : p == null
                  ? _page(FinState.loading(rows: 4))
                  : _body(context, p),
        );
      },
    );
  }

  Widget _body(BuildContext context, InsuranceProduct p) {
    final c = DsColors.of(context);
    return FinBody(
      children: [
        FinHeader(
          overline: p.partnerName.isEmpty ? null : '${"Insurer".tr}: ${p.partnerName}',
          title: p.name,
          subtitle: p.summary,
          icon: _icon(p.category),
          status: p.acceptsQuotes ? null : 'closed',
          statusLabel: p.acceptsQuotes ? null : "Unavailable".tr,
          below: p.description.isEmpty ? null : Text(p.description, style: DsTypography.body.copyWith(color: c.textPrimary)),
        ),
        FinSection(
          title: "Key facts".tr,
          children: [
            FinRow("Cover period".tr, '${ltr('${p.termMonths}')} ${"months".tr}'),
            FinRow("Deductible".tr, p.deductible == 0 ? "None".tr : FinanceMoney.format(p.deductible, p.currency)),
            FinRow("Waiting period".tr, p.waitingPeriodDays == 0 ? "None".tr : '${ltr('${p.waitingPeriodDays}')} ${"days".tr}'),
            FinRow("Payment".tr, p.frequencies.keys.map((f) => PremiumFrequency.label(f).tr).join(', ')),
          ],
        ),
        if (p.coverages.isNotEmpty) _Coverages(p.coverages, p.currency),
        if (p.exclusions.isNotEmpty)
          FinSection(
            title: "What is not covered".tr,
            divided: true,
            children: [for (final e in p.exclusions) _CoverRow(icon: Icons.remove_circle_outline_rounded, color: c.textMuted, title: e)],
          ),
        if (p.documents.isNotEmpty) _Documents(p.documents),
        if (p.terms.isNotEmpty)
          FinSection(
            title: "Terms".tr,
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [
              Text('${"Version".tr} ${ltr('${p.termsVersion}')}', style: DsTypography.caption.copyWith(color: c.textSecondary)),
              const DsGap(DsSpace.sm),
              Text(p.terms, style: DsTypography.body.copyWith(color: c.textPrimary)),
            ],
          ),
      ],
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
    final c = DsColors.of(context);
    final estimate = RateSimulator.estimate(p, _answers, _frequency);
    return FinScaffold(
      title: "Get a quote".tr,
      subtitle: p.name,
      bottomBar: DsStickyBar(
        child: FinanceKycGate(
          builder: (context, verified) => DsButton.primary(label: "Request my quote".tr, size: DsButtonSize.lg, expand: true, onPressed: verified && _complete ? _submit : null),
        ),
      ),
      body: FinBody(
        children: [
          if (p.factors.isNotEmpty)
            FinSection(
              title: "About you and what to insure".tr,
              top: 0,
              padding: _form,
              children: [
                for (final f in p.factors)
                  if (f.type == 'select')
                    DsDropdown<String>(
                      label: f.label,
                      requiredMark: true,
                      value: _answers[f.key] as String?,
                      items: [for (final o in f.options) DropdownMenuItem(value: o.value, child: Text(o.label))],
                      onChanged: (v) => setState(() => _answers[f.key] = v),
                    )
                  else
                    DsTextField(
                      label: '${f.label}${f.unit.isEmpty ? '' : ' (${f.unit})'}',
                      requiredMark: true,
                      controller: _numbers.putIfAbsent(f.key, TextEditingController.new),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      helper: f.min == null && f.max == null ? null : ltr('${f.min?.toStringAsFixed(0) ?? ''} - ${f.max?.toStringAsFixed(0) ?? ''}'),
                      errorText: _numbers[f.key]?.text.isNotEmpty == true && f.multiplierFor(_answers[f.key]) == null ? "Outside the accepted range".tr : null,
                      onChanged: (v) => setState(() => _answers[f.key] = double.tryParse(v.replaceAll(',', '.'))),
                    ),
              ],
            ),
          FinSection(
            title: "Cover".tr,
            top: p.factors.isEmpty ? 0 : FinSpace.section,
            padding: _form,
            children: [
              DsFieldLabel("Pay".tr),
              Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.sm, children: [
                for (final f in p.frequencies.keys) ChoiceChip(label: Text(PremiumFrequency.label(f).tr), selected: _frequency == f, onSelected: (_) => setState(() => _frequency = f)),
              ]),
              const DsGap(DsSpace.lg),
              _DateField(
                label: "Cover starts on".tr,
                value: _date(_start),
                onTap: () async {
                  final today = DateUtils.dateOnly(DateTime.now());
                  final d = await showDatePicker(context: context, initialDate: _start, firstDate: today, lastDate: today.add(const Duration(days: 180)));
                  if (d != null) setState(() => _start = d);
                },
              ),
            ],
          ),
          if (p.canSimulate) ...[
            FinSection(
              title: "Estimated premium".tr,
              children: [
                if (estimate == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                    child: Text("Answer the questions to see an estimate.".tr, style: DsTypography.body.copyWith(color: c.textSecondary)),
                  )
                else ...[
                  FinRow(PremiumFrequency.label(_frequency).tr, FinanceMoney.format(estimate.installment, p.currency), strong: true),
                  if (estimate.installmentsPerYear > 1) FinRow("Total for the year".tr, FinanceMoney.format(estimate.yearlyTotal, p.currency)),
                ],
              ],
            ),
            FinNotice(
              "This is an estimate from the published rates. The insurer confirms the price in your quote.".tr,
              title: "Estimate".tr,
              tone: DsTone.info,
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

  Future<void> _decline(String? priceLabel, String? price) async {
    final ok = await finConfirm(
      title: "Decline this quote".tr,
      lines: [if (priceLabel != null && price != null) (priceLabel, price)],
      confirmLabel: "Decline".tr,
      destructive: true,
    );
    if (ok) await FinanceUi.run(() => FinanceInsuranceService.declineQuote(widget.quoteId), success: "Quote declined");
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
        return FinScaffold(
          title: "Quote".tr,
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
              ? _page(FinState.error("Could not load this quote.".tr))
              : q == null
                  ? _page(FinState.loading(rows: 4))
                  : _body(context, q, quote!, canAccept, amount, cur),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> q, Quote quote, bool canAccept, int amount, String cur) {
    final c = DsColors.of(context);
    final bool priced = quote.status == 'quoted' && amount > 0;
    final String product = q['productName']?.toString() ?? '-';
    final String partner = (q['partnerName'] ?? '').toString();
    final String frequency = PremiumFrequency.label(q['frequency']?.toString() ?? 'annual').tr;
    final bool validityInHeader = quote.status == 'quoted' && q['validUntil'] != null;
    return FinBody(
      children: [
        FinHeader(
          overline: priced ? product : (partner.isEmpty ? null : '${"Insurer".tr}: $partner'),
          title: priced ? FinanceMoney.format(amount, cur) : product,
          subtitle: priced ? [frequency, if (partner.isNotEmpty) '${"Insurer".tr}: $partner'].join(' · ') : null,
          status: quote.status,
          statusLabel: InsuranceLabels.quote(quote.status).tr,
          icon: _icon(q['category']?.toString()),
          below: !validityInHeader
              ? null
              : Row(children: [
                  Icon(Icons.schedule_rounded, size: 16, color: canAccept ? c.textSecondary : c.warningStrong),
                  const DsGap(DsSpace.xs),
                  Expanded(
                    child: Text(
                      '${"Quote valid until".tr} ${_date(q['validUntil'])}',
                      style: DsTypography.bodySm.copyWith(color: canAccept ? c.textSecondary : c.warningStrong),
                    ),
                  ),
                ]),
        ),
        if ((q['reason'] ?? '').toString().isNotEmpty) FinNotice(q['reason'].toString(), title: "Reason".tr, tone: FinStatus.tone(quote.status)),
        if (quote.status == 'requested') FinNotice("The insurer is preparing your quote. You are notified when it is ready.".tr, tone: DsTone.info),
        if (quote.status == 'quoted' && !canAccept) FinNotice("This quote is no longer valid. Request a new one.".tr, tone: DsTone.warning),
        FinSection(
          title: "Details".tr,
          children: [
            if (q['premium'] != null) FinRow("Premium for the year".tr, _m(q['premium'], cur)),
            if (q['deductible'] != null) FinRow("Deductible".tr, _m(q['deductible'], cur)),
            if (q['coverStart'] != null) FinRow("Cover starts on".tr, _date(q['coverStart'])),
            if (q['coverEnd'] != null) FinRow("Cover ends on".tr, _date(q['coverEnd'])),
            if (q['validUntil'] != null && !validityInHeader) FinRow("Quote valid until".tr, _date(q['validUntil'])),
            if ((q['insurerReference'] ?? '').toString().isNotEmpty) FinRow("Reference".tr, ltrRef(q['insurerReference'])),
          ],
        ),
        if (Coverage.list(q['coverages']).isNotEmpty) _Coverages(Coverage.list(q['coverages']), cur),
        if (InsuranceDocument.list(q['documents']).isNotEmpty) _Documents(InsuranceDocument.list(q['documents'])),
        if (canAccept)
          FinSection(
            title: "Subscription".tr,
            padding: _form,
            children: [
              Text('${"Terms version".tr} ${ltr('${q['termsVersion'] ?? '-'}')}', style: DsTypography.caption.copyWith(color: c.textSecondary)),
              const DsGap(DsSpace.sm),
              if ((q['terms'] ?? '').toString().isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(color: c.isDark ? c.surfaceAlt : FinColors.page(context), borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(DsSpace.md),
                      child: Text(q['terms'].toString(), style: DsTypography.bodySm.copyWith(color: c.textPrimary)),
                    ),
                  ),
                ),
                const DsGap(DsSpace.xs),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                title: Text("I have read the quote, the cover, the exclusions and the terms, and I accept them.".tr, style: DsTypography.body.copyWith(color: c.textPrimary)),
              ),
              const DsGap(DsSpace.sm),
              DsTextField(
                label: "Full name".tr,
                helper: "Type your full name to sign. It is recorded with the date and the terms version.".tr,
                controller: _signature,
                requiredMark: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                bottomSpacing: DsSpace.md,
              ),
              Text("Your policy starts once the insurer confirms it, after your payment.".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
              const DsGap(DsSpace.md),
            ],
          ),
        if ((q['policyId'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.secondary(
              label: "See my policy".tr,
              icon: Icons.verified_user_outlined,
              expand: true,
              onPressed: () => Get.off(() => PolicyScreen(policyId: q['policyId'].toString(), config: widget.config)),
            ),
          ),
        if (quote.canDecline)
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.ghost(
              label: "Decline this quote".tr,
              icon: Icons.close_rounded,
              color: c.dangerStrong,
              expand: true,
              onPressed: () => _decline(priced ? frequency : null, priced ? FinanceMoney.format(amount, cur) : null),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------- policy

/// A policy: cover, documents, premiums, renewal, cancellation and claims.
class PolicyScreen extends StatelessWidget {
  final String policyId;
  final InsuranceConfig config;

  const PolicyScreen({super.key, required this.policyId, required this.config});

  /// The cancellation takes an optional reason, so it is its own sheet
  /// (a confirmation with an input), not [finConfirm].
  Future<void> _cancel(BuildContext context) async {
    final reason = TextEditingController();
    final ok = await finSheet<bool>(
      title: "Cancel this policy".tr,
      child: _finAccent(
        Builder(
          builder: (context) {
            final c = DsColors.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("The insurer handles the cancellation under the policy terms (notice period, any refund of premium).".tr,
                    style: DsTypography.body.copyWith(color: c.textSecondary)),
                const DsGap(DsSpace.lg),
                DsTextField(label: "Reason (optional)".tr, controller: reason, maxLines: 3),
                DsButton.primary(label: "Request the cancellation".tr, expand: true, color: c.danger, onPressed: () => Get.back(result: true)),
                DsButton.ghost(label: "Cancel".tr, expand: true, onPressed: () => Get.back(result: false)),
              ],
            );
          },
        ),
      ),
    );
    if (ok == true) await FinanceUi.run(() => FinanceInsuranceService.requestCancellation(policyId, reason.text.trim()), success: "Cancellation requested");
  }

  Future<void> _renew(BuildContext context, int renewalPremium, String cur) async {
    final key = FinanceGroupService.newRequestKey();
    await FinancePaySheet.show(context,
        title: "Renewal".tr, amount: renewalPremium, currency: cur, methods: config.paymentMethods, submit: (pay) => FinanceInsuranceService.renew(policyId, pay, key));
  }

  Future<void> _payPremium(BuildContext context, Map<String, dynamic> pr, String cur) async {
    final key = FinanceGroupService.newRequestKey();
    final int amount = FinanceSummary.intOf(pr['amount']);
    await FinancePaySheet.show(context,
        title: "Premium".tr,
        amount: amount,
        currency: cur,
        methods: config.paymentMethods,
        submit: (pay) => FinanceInsuranceService.payPremium(policyId, pr['id'].toString(), pay, key));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceInsuranceService.doc('insurance_policies', policyId),
      builder: (context, snap) {
        final p = snap.data;
        final String status = p?['status']?.toString() ?? '';
        return FinScaffold(
          title: "Policy".tr,
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
              ? _page(FinState.error("Could not load this policy.".tr))
              : p == null
                  ? _page(FinState.loading(rows: 4))
                  : _body(context, p, status),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> p, String status) {
    final c = DsColors.of(context);
    final String cur = p['currency']?.toString() ?? '';
    final int renewalPremium = FinanceSummary.intOf(p['renewalPremium']);
    final String partner = (p['partnerName'] ?? '').toString();
    final String number = (p['policyNumber'] ?? '').toString();
    final bool hasPremium = p['installmentAmount'] != null || p['premium'] != null;
    final bool canRenew = PolicyActions.canRenew(status, renewalPremium);
    final bool canAutoRenew = PolicyActions.canSetAutoRenew(status);
    return FinBody(
      children: [
        FinHeader(
          overline: partner.isEmpty ? InsuranceLabels.category(p['category']?.toString()).tr : '${"Insurer".tr}: $partner',
          title: p['productName']?.toString() ?? '-',
          subtitle: number.isEmpty ? null : '${"Policy number".tr} ${ltrRef(number)}',
          status: status,
          statusLabel: InsuranceLabels.policy(status).tr,
          icon: _icon(p['category']?.toString()),
        ),
        if ((p['reason'] ?? '').toString().isNotEmpty) FinNotice(p['reason'].toString(), title: "Reason".tr, tone: FinStatus.tone(status)),
        if (status == 'pending_activation') FinNotice("We are waiting for the insurer to confirm your policy. You are covered only once it is active.".tr, tone: DsTone.info),
        if (status == 'lapsed') FinNotice("A premium was not paid: you are not covered. Pay it to restore your cover if the insurer allows it.".tr, tone: DsTone.danger),
        if (hasPremium || p['nextPremiumDue'] != null) ...[
          const DsGap(DsSpace.md),
          FinMetrics(items: [
            if (hasPremium)
              FinMetric("Premium".tr, _m(p['installmentAmount'] ?? p['premium'], cur), sub: PremiumFrequency.label(p['frequency']?.toString() ?? 'annual').tr),
            if (p['nextPremiumDue'] != null) FinMetric("Next payment".tr, _date(p['nextPremiumDue'])),
          ]),
        ],
        FinSection(
          title: "Details".tr,
          children: [
            FinRow("Cover period".tr, '${_date(p['coverStart'])} – ${_date(p['coverEnd'])}'),
            if (p['deductible'] != null) FinRow("Deductible".tr, _m(p['deductible'], cur)),
          ],
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceInsuranceService.premiums(policyId),
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            Widget rows(bool verified) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, pr) in list.indexed) ...[
                      if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
                      _premiumRow(context, pr, cur, verified),
                    ],
                  ],
                );
            final bool payable = list.any((pr) => PolicyActions.premiumPayable(pr['status']?.toString()));
            return FinSection(
              title: "Premiums".tr,
              children: [payable ? FinanceKycGate(builder: (context, verified) => rows(verified)) : rows(false)],
            );
          },
        ),
        if (canRenew || canAutoRenew)
          FinSection(
            title: "Renewal".tr,
            children: [
              if (canRenew) ...[
                FinRow("Premium for the next period".tr, FinanceMoney.format(renewalPremium, cur), strong: true),
                if (p['renewalDate'] != null) FinRow("Renew before".tr, _date(p['renewalDate'])),
                const DsGap(DsSpace.sm),
                FinanceKycGate(
                  builder: (context, verified) => DsButton.primary(
                    label: "${"Renew and pay".tr} ${FinanceMoney.format(renewalPremium, cur)}",
                    expand: true,
                    onPressed: !verified ? null : () => _renew(context, renewalPremium, cur),
                  ),
                ),
                const DsGap(DsSpace.sm),
              ],
              if (canRenew && canAutoRenew) Divider(height: 1, thickness: 1, color: c.divider),
              if (canAutoRenew)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: p['autoRenew'] == true,
                  title: Text("Renew automatically".tr, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
                  subtitle: Text("You are notified before each renewal and can pay or stop it.".tr, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
                  onChanged: (v) => FinanceUi.run(() => FinanceInsuranceService.setAutoRenew(policyId, v), success: v ? "Automatic renewal on" : "Automatic renewal off"),
                ),
            ],
          ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceInsuranceService.policyClaims(policyId),
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            return FinSection(
              title: "Claims".tr,
              divided: true,
              children: [
                for (final cl in list)
                  FinListTile(
                    icon: Icons.assignment_outlined,
                    iconTone: DsTone.brand,
                    title: _date(cl['incidentDate']),
                    subtitle: (cl['description'] ?? '').toString(),
                    amount: _m(cl['amountClaimed'], cur),
                    status: cl['status']?.toString(),
                    statusLabel: InsuranceLabels.claim(cl['status']?.toString()).tr,
                    chevron: true,
                    onTap: () => Get.to(() => ClaimScreen(claimId: cl['id'].toString(), config: config)),
                  ),
              ],
            );
          },
        ),
        if (Coverage.list(p['coverages']).isNotEmpty) _Coverages(Coverage.list(p['coverages']), cur),
        if (InsuranceDocument.list(p['documents']).isNotEmpty) _Documents(InsuranceDocument.list(p['documents'])),
        if (PolicyActions.canCancel(status))
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.ghost(label: "Cancel this policy".tr, icon: Icons.close_rounded, color: c.dangerStrong, expand: true, onPressed: () => _cancel(context)),
          ),
      ],
    );
  }

  Widget _premiumRow(BuildContext context, Map<String, dynamic> pr, String cur, bool verified) {
    final String? status = pr['status']?.toString();
    final bool payable = PolicyActions.premiumPayable(status);
    return FinListTile(
      icon: Icons.event_outlined,
      iconTone: payable ? FinStatus.tone(status) : DsTone.neutral,
      title: _date(pr['dueDate']),
      amount: _m(pr['amount'], cur),
      status: status,
      statusLabel: InsuranceLabels.premium(status).tr,
      trailing: !payable
          ? null
          : DsButton.primary(
              label: "Pay".tr,
              size: DsButtonSize.sm,
              onPressed: !verified ? null : () => _payPremium(context, pr, cur),
            ),
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
    final c = DsColors.of(context);
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime first = FinanceGroupService.toDate(widget.policy['coverStart']) ?? today.subtract(const Duration(days: 365));
    return FinScaffold(
      title: "Make a claim".tr,
      subtitle: widget.policy['productName']?.toString(),
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Send my claim".tr, size: DsButtonSize.lg, expand: true, onPressed: _submit)),
      body: FinBody(
        children: [
          FinSection(
            title: "What happened".tr,
            top: 0,
            padding: _form,
            children: [
              _DateField(
                label: "Date of the incident".tr,
                value: _incident == null ? null : _date(_incident),
                placeholder: "Choose a date".tr,
                required: true,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: today.isBefore(first) ? first : today, firstDate: first.isAfter(today) ? today : first, lastDate: today);
                  if (d != null) setState(() => _incident = d);
                },
              ),
              DsTextField(label: "Description".tr, hint: "Where, how, and what was damaged or lost.".tr, controller: _description, maxLines: 5, requiredMark: true),
              DsTextField(
                label: "${"Amount claimed".tr} ($_currency)",
                controller: _amount,
                requiredMark: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          FinSection(
            title: "Evidence".tr,
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [
              Text("Photos of the damage, receipts, a police or medical report... Only the insurer sees them.".tr, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
              const DsGap(DsSpace.md),
              _PhotoPicker(files: _files, max: widget.config.maxClaimFiles, changed: () => setState(() {})),
            ],
          ),
          FinNotice("The insurer decides on your claim. You can follow it here and you are notified of each step.".tr, tone: DsTone.info),
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

  Future<void> _withdraw() async {
    final ok = await finConfirm(title: "Withdraw this claim?".tr, confirmLabel: "Withdraw".tr, destructive: true);
    if (ok) await FinanceUi.run(() => FinanceInsuranceService.withdrawClaim(widget.claimId), success: "Claim withdrawn");
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceInsuranceService.doc('insurance_claims', widget.claimId),
      builder: (context, snap) {
        final c = snap.data;
        return FinScaffold(
          title: "Claim".tr,
          body: snap.hasError
              ? _page(FinState.error("Could not load this claim.".tr))
              : c == null
                  ? _page(FinState.loading(rows: 4))
                  : _body(context, c),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> c) {
    final colors = DsColors.of(context);
    final String status = c['status']?.toString() ?? '';
    final String cur = c['currency']?.toString() ?? '';
    final steps = InsuranceLabels.claimSteps;
    final int at = steps.indexOf(status == 'info_requested' ? 'under_review' : status);
    final bool ended = status == 'rejected' || status == 'withdrawn';
    // The current step reads "More information needed" while the insurer waits for the user.
    final labels = [for (final s in steps) InsuranceLabels.claim(s == 'under_review' && status == 'info_requested' ? 'info_requested' : s).tr];
    final docs = InsuranceDocument.list(c['documents']);
    final String product = (c['productName'] ?? '').toString();
    final String policyNo = (c['policyNumber'] ?? '').toString();
    final String overline = [if (product.isNotEmpty) product, if (policyNo.isNotEmpty) '${"No.".tr} ${ltrRef(policyNo)}'].join(' · ');
    return FinBody(
      children: [
        FinHeader(
          overline: overline.isEmpty ? null : overline,
          title: _m(c['amountClaimed'], cur),
          subtitle: "Amount claimed".tr,
          status: status,
          statusLabel: InsuranceLabels.claim(status).tr,
          icon: Icons.assignment_outlined,
          below: ended
              ? FinTrack(steps: labels, current: 0, ended: true, endedLabel: InsuranceLabels.claim(status).tr)
              : at >= 0
                  ? FinTrack(steps: labels, current: at)
                  : null,
        ),
        if ((c['reason'] ?? '').toString().isNotEmpty)
          FinNotice(c['reason'].toString(), title: (status == 'info_requested' ? "The insurer asks" : "Reason").tr, tone: FinStatus.tone(status)),
        FinSection(
          title: "Details".tr,
          children: [
            FinRow("Date of the incident".tr, _date(c['incidentDate'])),
            FinRow("Declared on".tr, _date(c['createdAt'])),
            if (c['approvedAmount'] != null) FinRow("Amount approved".tr, _m(c['approvedAmount'], cur)),
            if (c['paidAmount'] != null) FinRow("Amount paid".tr, _m(c['paidAmount'], cur), valueColor: colors.successStrong),
            if (c['paidAt'] != null) FinRow("Paid on".tr, _date(c['paidAt'])),
            if ((c['insurerReference'] ?? '').toString().isNotEmpty) FinRow("Reference".tr, ltrRef(c['insurerReference'])),
          ],
        ),
        if ((c['description'] ?? '').toString().isNotEmpty)
          FinSection(
            title: "Description".tr,
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [Text(c['description'].toString(), style: DsTypography.body.copyWith(color: colors.textPrimary))],
          ),
        if (docs.isNotEmpty) _Documents(docs),
        if (PolicyActions.canRespondToClaim(status))
          FinSection(
            title: "Send more information".tr,
            padding: _form,
            children: [
              DsTextField(label: "Message".tr, controller: _message, maxLines: 4),
              _PhotoPicker(files: _files, max: widget.config.maxClaimFiles, changed: () => setState(() {})),
              const DsGap(DsSpace.lg),
              DsButton.primary(label: "Send".tr, icon: Icons.send_rounded, expand: true, onPressed: _respond),
              const DsGap(DsSpace.md),
            ],
          ),
        if (PolicyActions.canWithdrawClaim(status))
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.ghost(label: "Withdraw this claim".tr, icon: Icons.close_rounded, color: colors.dangerStrong, expand: true, onPressed: _withdraw),
          ),
      ],
    );
  }
}
