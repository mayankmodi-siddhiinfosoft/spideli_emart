import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/service/finance_financing_service.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_financing_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

DsTone _tone(String? s) => switch (s) {
      'approved' || 'funded' || 'accepted' => DsTone.success,
      'rejected' => DsTone.danger,
      'additional_info_required' || 'draft' => DsTone.warning,
      'submitted' || 'under_review' || 'received' => DsTone.info,
      _ => DsTone.neutral,
    };

String _date(dynamic v) {
  final d = FinanceGroupService.toDate(v);
  return d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));
}

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

Future<void> _open({String? storagePath, String? url}) async {
  ShowToastDialog.showLoader("Please wait...".tr);
  try {
    await FinanceFinancingService.open(storagePath: storagePath, url: url);
    ShowToastDialog.closeLoader();
  } catch (_) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Could not open this document.".tr);
  }
}

/// Starts an application: the project first when the user has none.
Future<void> _newApplication(FinancingConfig cfg) async {
  final projects = await FinanceFinancingService.projects().first;
  if (projects.isEmpty) {
    Get.to(() => ProjectFormScreen(config: cfg, thenApply: true));
  } else {
    Get.to(() => ApplicationFormScreen(config: cfg, projects: projects));
  }
}

/// Spideli Finance > Project financing: applications, projects and
/// resources. `platform_settings/financing` must exist (admin).
class FinancingScreen extends StatefulWidget {
  const FinancingScreen({super.key});

  @override
  State<FinancingScreen> createState() => _FinancingScreenState();
}

class _FinancingScreenState extends State<FinancingScreen> {
  int _tab = 0;
  final Future<FinancingConfig?> _config = FinanceFinancingService.config();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FinancingConfig?>(
      future: _config,
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        return DsScaffold(
          title: "Project financing".tr,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: cfg == null || _tab == 2
              ? null
              : DsStickyBar(
                  child: _tab == 0
                      ? FinanceKycGate(
                          builder: (context, verified) => DsButton.primary(
                            label: "New application".tr,
                            icon: Icons.add_rounded,
                            size: DsButtonSize.lg,
                            expand: true,
                            onPressed: verified ? () => _newApplication(cfg) : null,
                          ),
                        )
                      : DsButton.primary(
                          label: "Add a project".tr,
                          icon: Icons.add_business_outlined,
                          size: DsButtonSize.lg,
                          expand: true,
                          onPressed: () => Get.to(() => ProjectFormScreen(config: cfg)),
                        ),
                ),
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3))
              : cfg == null
                  ? DsEmptyState(icon: Icons.business_center_outlined, title: "Project financing is not available yet.".tr)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: [
                        DsSegmentedTabs(
                          segments: [DsSegment("Applications".tr), DsSegment("Projects".tr), DsSegment("Resources".tr)],
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                        const DsGap(DsSpace.lg),
                        switch (_tab) {
                          0 => _Applications(config: cfg),
                          1 => _Projects(config: cfg),
                          _ => const _Resources(),
                        },
                      ],
                    ),
        );
      },
    );
  }
}

class _Applications extends StatelessWidget {
  final FinancingConfig config;

  const _Applications({required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceFinancingService.applications(),
      builder: (context, snap) {
        if (snap.hasError) return DsErrorState(message: "Could not load your applications.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
        if (snap.data!.isEmpty) {
          return DsEmptyState(
            icon: Icons.business_center_outlined,
            title: "You have no financing application yet.".tr,
            message: "Describe your project, choose the financing you need, add your business plan and financial statements, then follow the review here.".tr,
            compact: true,
          );
        }
        return Column(children: [
          for (final a in snap.data!)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.sm),
              child: DsCard.outlined(
                onTap: () => Get.to(() => ApplicationScreen(applicationId: a['id'].toString(), config: config)),
                child: Row(children: [
                  DsIconWell(icon: Icons.business_center_outlined, tone: _tone(a['status']?.toString())),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a['projectName']?.toString() ?? '-', style: DsTypography.titleSm),
                      Text(
                        '${FinancingLabels.type(a['financingType']?.toString()).tr} · ${FinanceMoney.format(FinanceSummary.intOf(a['amount']), a['currency']?.toString() ?? '')}',
                        style: DsTypography.caption.tabular,
                      ),
                    ]),
                  ),
                  DsBadge(label: FinancingStatus.label(a['status']?.toString()).tr, tone: _tone(a['status']?.toString()), small: true),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _Projects extends StatelessWidget {
  final FinancingConfig config;

  const _Projects({required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceFinancingService.projects(),
      builder: (context, snap) {
        if (snap.hasError) return DsErrorState(message: "Could not load your projects.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 2);
        if (snap.data!.isEmpty) return DsEmptyState(icon: Icons.add_business_outlined, title: "You have no project yet.".tr, compact: true);
        return DsTileGroup(children: [
          for (final p in snap.data!)
            DsListTile(
              leadingIcon: Icons.storefront_outlined,
              leadingTone: DsTone.brand,
              title: p['name']?.toString() ?? '-',
              subtitle: [
                FinancingLabels.sector(p['sector']?.toString()).tr,
                if ((p['stage'] ?? '').toString().isNotEmpty) FinancingLabels.stage(p['stage'].toString()).tr,
                if ((p['city'] ?? '').toString().isNotEmpty) p['city'].toString(),
              ].join(' · '),
              showChevron: true,
              onTap: () => Get.to(() => ProjectFormScreen(config: config, project: p)),
            ),
        ]);
      },
    );
  }
}

class _Resources extends StatefulWidget {
  const _Resources();

  @override
  State<_Resources> createState() => _ResourcesState();
}

class _ResourcesState extends State<_Resources> {
  String? _type;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceFinancingService.resources(),
      builder: (context, snap) {
        if (snap.hasError) return DsErrorState(message: "Could not load the resources.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
        final all = snap.data!;
        final types = {for (final r in all) r['type']?.toString() ?? 'guide'}.toList();
        final list = all.where((r) => _type == null || r['type'] == _type).toList();
        if (all.isEmpty) return DsEmptyState(icon: Icons.menu_book_outlined, title: "No resource is published yet.".tr, compact: true);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (types.length > 1)
              Wrap(spacing: DsSpace.sm, children: [
                for (final t in [null, ...types])
                  ChoiceChip(label: Text(t == null ? "All".tr : FinancingLabels.resource(t).tr), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
              ]),
            const DsGap(DsSpace.md),
            DsTileGroup(children: [
              for (final r in list)
                DsListTile(
                  leadingIcon: switch (r['type']) {
                    'template' => Icons.description_outlined,
                    'faq' => Icons.help_outline_rounded,
                    'regulation' => Icons.gavel_rounded,
                    _ => Icons.menu_book_outlined,
                  },
                  leadingTone: DsTone.brand,
                  title: r['title']?.toString() ?? '-',
                  subtitle: r['summary']?.toString(),
                  showChevron: true,
                  onTap: () => Get.to(() => ResourceScreen(resource: r)),
                ),
            ]),
          ],
        );
      },
    );
  }
}

/// A guide, template, FAQ or regulation published by the admin.
class ResourceScreen extends StatelessWidget {
  final Map<String, dynamic> resource;

  const ResourceScreen({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    final r = resource;
    final String path = (r['storagePath'] ?? '').toString();
    final String url = (r['url'] ?? '').toString();
    return DsScaffold(
      title: FinancingLabels.resource(r['type']?.toString()).tr,
      maxContentWidth: DsLayout.contentMax,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          Text(r['title']?.toString() ?? '-', style: DsTypography.title),
          if ((r['summary'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.xs), child: Text(r['summary'].toString(), style: DsTypography.bodyStrong)),
          if ((r['body'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.md), child: SelectableText(r['body'].toString(), style: DsTypography.body)),
          if (path.isNotEmpty || url.startsWith('https://')) ...[
            const DsGap(DsSpace.lg),
            DsButton.secondary(
              label: (r['type'] == 'template' ? "Download the template" : "Open the document").tr,
              icon: Icons.download_rounded,
              expand: true,
              onPressed: () => _open(storagePath: path.isEmpty ? null : path, url: path.isEmpty ? url : null),
            ),
          ],
          if (r['updatedAt'] != null) Padding(padding: const EdgeInsets.only(top: DsSpace.md), child: Text('${"Updated".tr} ${_date(r['updatedAt'])}', style: DsTypography.caption)),
          const DsGap(DsSpace.md),
          Text("For information only. Check with the financing institution or a qualified adviser before you decide.".tr, style: DsTypography.caption),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ project

class ProjectFormScreen extends StatefulWidget {
  final FinancingConfig config;
  final Map<String, dynamic>? project;

  /// Go on to the application form once the project is saved.
  final bool thenApply;

  const ProjectFormScreen({super.key, required this.config, this.project, this.thenApply = false});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  late final Map<String, dynamic> _p = widget.project ?? const {};
  late final _name = TextEditingController(text: _p['name']?.toString() ?? '');
  late final _country = TextEditingController(text: _p['country']?.toString() ?? '');
  late final _city = TextEditingController(text: _p['city']?.toString() ?? '');
  late final _description = TextEditingController(text: _p['description']?.toString() ?? '');
  late final _employees = TextEditingController(text: _p['employees']?.toString() ?? '');
  late final _founded = TextEditingController(text: _p['foundedYear']?.toString() ?? '');
  late final _website = TextEditingController(text: _p['website']?.toString() ?? '');
  late String _sector = widget.config.sectors.contains(_p['sector']) ? _p['sector'].toString() : widget.config.sectors.first;
  late String? _stage = widget.config.stages.contains(_p['stage']) ? _p['stage'].toString() : (widget.config.stages.isEmpty ? null : widget.config.stages.first);

  @override
  void dispose() {
    for (final c in [_name, _country, _city, _description, _employees, _founded, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) return ShowToastDialog.showToast("Enter the project or company name.".tr);
    if (_description.text.trim().length < 30) return ShowToastDialog.showToast("Describe the project in a few sentences.".tr);
    final int? year = int.tryParse(_founded.text.trim());
    if (_founded.text.trim().isNotEmpty && (year == null || year < 1900 || year > DateTime.now().year)) return ShowToastDialog.showToast("Check the year.".tr);
    String? id;
    final ok = await FinanceUi.run(() async {
      id = await FinanceFinancingService.saveProject(widget.project?['id']?.toString(), {
        'name': _name.text.trim(),
        'sector': _sector,
        'stage': ?_stage,
        'country': _country.text.trim(),
        'city': _city.text.trim(),
        'description': _description.text.trim(),
        'employees': ?int.tryParse(_employees.text.trim()),
        'foundedYear': ?year,
        if (_website.text.trim().isNotEmpty) 'website': _website.text.trim(),
      });
    }, success: "Project saved");
    if (!ok || id == null) return;
    if (widget.thenApply) {
      Get.off(() => ApplicationFormScreen(config: widget.config, projects: [
            {'id': id, 'name': _name.text.trim()},
          ]));
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    return DsScaffold(
      title: (widget.project == null ? "Add a project" : "Edit the project").tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsFormSection(
            title: "The project".tr,
            subtitle: "The company or activity that needs the financing.".tr,
            icon: Icons.storefront_outlined,
            children: [
              DsTextField(label: "Project or company name".tr, controller: _name, requiredMark: true, textCapitalization: TextCapitalization.words),
              DsDropdown<String>(
                label: "Sector".tr,
                value: _sector,
                items: [for (final s in cfg.sectors) DropdownMenuItem(value: s, child: Text(FinancingLabels.sector(s).tr))],
                onChanged: (v) => setState(() => _sector = v ?? _sector),
              ),
              if (cfg.stages.isNotEmpty)
                DsDropdown<String>(
                  label: "Stage".tr,
                  value: _stage,
                  items: [for (final s in cfg.stages) DropdownMenuItem(value: s, child: Text(FinancingLabels.stage(s).tr))],
                  onChanged: (v) => setState(() => _stage = v),
                ),
              DsTextField(
                label: "Description".tr,
                hint: "What you do, for whom, and what makes it work.".tr,
                controller: _description,
                maxLines: 6,
                requiredMark: true,
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Details".tr,
            icon: Icons.info_outline_rounded,
            children: [
              Row(children: [
                Expanded(child: DsTextField(label: "Country".tr, controller: _country)),
                const DsGap(DsSpace.sm),
                Expanded(child: DsTextField(label: "City".tr, controller: _city)),
              ]),
              Row(children: [
                Expanded(child: DsTextField(label: "Employees".tr, controller: _employees, keyboardType: TextInputType.number)),
                const DsGap(DsSpace.sm),
                Expanded(child: DsTextField(label: "Year founded".tr, controller: _founded, keyboardType: TextInputType.number)),
              ]),
              DsTextField(label: "Website (optional)".tr, controller: _website, keyboardType: TextInputType.url, bottomSpacing: 0),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- application

/// The financing requested: project, type, amount, duration and use of funds.
class ApplicationFormScreen extends StatefulWidget {
  final FinancingConfig config;
  final List<Map<String, dynamic>> projects;
  final Map<String, dynamic>? application;

  const ApplicationFormScreen({super.key, required this.config, required this.projects, this.application});

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  late final Map<String, dynamic> _a = widget.application ?? const {};
  late String? _project = _a['projectId']?.toString() ?? (widget.projects.isEmpty ? null : widget.projects.first['id'].toString());
  late String _type = widget.config.financingTypes.contains(_a['financingType']) ? _a['financingType'].toString() : widget.config.financingTypes.first;
  late String _currency = widget.config.currencies.contains(_a['currency']) ? _a['currency'].toString() : widget.config.currencies.first;
  late int? _months = widget.config.durationsMonths.contains(FinanceSummary.intOf(_a['durationMonths'])) ? FinanceSummary.intOf(_a['durationMonths']) : null;
  late final _amount = TextEditingController(
      text: _a['amount'] != null && FinanceMoney.exponent(_currency) == 0 ? '${FinanceSummary.intOf(_a['amount'])}' : '');
  late final _use = TextEditingController(text: _a['useOfFunds']?.toString() ?? '');

  @override
  void dispose() {
    _amount.dispose();
    _use.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cfg = widget.config;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    if (_project == null) return ShowToastDialog.showToast("Choose the project.".tr);
    final problem = cfg.amountProblem(amount, _currency);
    if (problem != null) return ShowToastDialog.showToast(problem.tr);
    if (cfg.hasDuration(_type) && _months == null) return ShowToastDialog.showToast("Choose the duration.".tr);
    if (_use.text.trim().length < 30) return ShowToastDialog.showToast("Explain how the money will be used.".tr);
    final fields = {
      'projectId': _project,
      'financingType': _type,
      'amount': amount,
      'currency': _currency,
      if (cfg.hasDuration(_type)) 'durationMonths': _months,
      'useOfFunds': _use.text.trim(),
    };
    final String? existing = widget.application?['id']?.toString();
    String? id = existing;
    final ok = await FinanceUi.run(() async {
      if (existing == null) {
        id = await FinanceFinancingService.createApplication(fields);
      } else {
        await FinanceFinancingService.updateApplication(existing, fields);
      }
    }, success: "Application saved");
    if (!ok || id == null) return;
    if (existing == null) {
      Get.off(() => ApplicationScreen(applicationId: id!, config: cfg));
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    return DsScaffold(
      title: (widget.application == null ? "New application" : "Edit the application").tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsFormSection(
            title: "Financing".tr,
            icon: Icons.business_center_outlined,
            children: [
              DsDropdown<String>(
                label: "Project".tr,
                value: _project,
                items: [for (final p in widget.projects) DropdownMenuItem(value: p['id'].toString(), child: Text(p['name']?.toString() ?? '-'))],
                onChanged: widget.application == null ? (v) => setState(() => _project = v) : null,
              ),
              Text("Type of financing".tr, style: DsTypography.label),
              const DsGap(DsSpace.xs),
              Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: [
                for (final t in cfg.financingTypes) ChoiceChip(label: Text(FinancingLabels.type(t).tr), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
              ]),
              const DsGap(DsSpace.md),
              Row(children: [
                Expanded(
                  child: DsTextField(
                    label: "Amount requested".tr,
                    controller: _amount,
                    requiredMark: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    errorText: _amount.text.isEmpty ? null : cfg.amountProblem(amount, _currency)?.tr,
                    helper: [
                      if (cfg.minAmount[_currency] != null) '${"Minimum".tr} ${FinanceMoney.format(cfg.minAmount[_currency]!, _currency)}',
                      if (cfg.maxAmount[_currency] != null) '${"Maximum".tr} ${FinanceMoney.format(cfg.maxAmount[_currency]!, _currency)}',
                    ].join(' · '),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (cfg.currencies.length > 1) ...[
                  const DsGap(DsSpace.sm),
                  SizedBox(
                    width: 110,
                    child: DsDropdown<String>(
                      label: "Currency".tr,
                      value: _currency,
                      items: [for (final c in cfg.currencies) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ]),
              if (cfg.hasDuration(_type)) ...[
                Text("Duration".tr, style: DsTypography.label),
                const DsGap(DsSpace.xs),
                Wrap(spacing: DsSpace.sm, children: [
                  for (final m in cfg.durationsMonths) ChoiceChip(label: Text('$m ${"months".tr}'), selected: _months == m, onSelected: (_) => setState(() => _months = m)),
                ]),
                const DsGap(DsSpace.md),
              ],
              DsTextField(
                label: "Use of the funds".tr,
                hint: "Equipment, stock, working capital, hiring... with the main amounts.".tr,
                controller: _use,
                maxLines: 6,
                requiredMark: true,
                bottomSpacing: 0,
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          Text("You add your documents and submit the application on the next screen.".tr, style: DsTypography.caption),
        ],
      ),
    );
  }
}

/// One application: details, documents, submission and the review.
class ApplicationScreen extends StatefulWidget {
  final String applicationId;
  final FinancingConfig config;

  const ApplicationScreen({super.key, required this.applicationId, required this.config});

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  final _message = TextEditingController();
  bool _declared = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _upload(String type) async {
    final cfg = widget.config;
    final PlatformFile? file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: extensionsFor(cfg.allowedContentTypes));
    if (file == null) return;
    final String contentType = contentTypeOf(file.name);
    final int size = file.lengthSync() ?? await file.length() ?? 0;
    final problem = cfg.fileProblem(contentType, size);
    if (problem != null) return ShowToastDialog.showToast(problem.tr);
    await FinanceUi.run(() async {
      await FinanceFinancingService.addDocument(
        applicationId: widget.applicationId,
        type: type,
        name: file.name,
        contentType: contentType,
        size: size,
        path: file.path,
        bytes: file.path == null ? await file.readAsBytes() : null,
      );
    }, success: "Document added");
  }

  Future<void> _addOther() async {
    final type = await DsBottomSheet.show<String>(
      title: "Which document?".tr,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final t in widget.config.documentTypes)
          DsListTile(padding: EdgeInsets.zero, leadingIcon: Icons.description_outlined, title: FinancingLabels.document(t).tr, onTap: () => Get.back(result: t)),
      ]),
    );
    if (type != null) await _upload(type);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceFinancingService.application(widget.applicationId),
      builder: (context, snap) {
        final a = snap.data;
        return DsScaffold(
          title: "Financing application".tr,
          maxContentWidth: DsLayout.contentMax,
          body: snap.hasError
              ? DsErrorState(message: "Could not load this application.".tr)
              : a == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: FinanceFinancingService.documents(widget.applicationId),
                      builder: (context, ds) => _body(context, a, ds.data ?? const []),
                    ),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> a, List<Map<String, dynamic>> docs) {
    final cfg = widget.config;
    final String status = a['status']?.toString() ?? 'draft';
    final String cur = a['currency']?.toString() ?? '';
    final String type = a['financingType']?.toString() ?? '';
    final required = cfg.requiredFor(type);
    final missing = missingDocuments(required, docs);
    final bool editable = FinancingStatus.editable(status);
    final int at = FinancingStatus.steps.indexOf(status);
    String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), cur);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        DsCard.tinted(
          tone: _tone(status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(a['projectName']?.toString() ?? '-', style: DsTypography.titleSm)),
                DsBadge(label: FinancingStatus.label(status).tr, tone: _tone(status)),
              ]),
              Text('${FinancingLabels.type(type).tr} · ${m(a['amount'])}${a['durationMonths'] == null ? '' : ' · ${a['durationMonths']} ${"months".tr}'}', style: DsTypography.body.tabular),
              if ((a['reason'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.sm),
                  child: DsInlineAlert(tone: _tone(status), title: (status == 'additional_info_required' ? "What the reviewers need" : "Reason").tr, message: a['reason'].toString()),
                ),
            ],
          ),
        ),
        const DsGap(DsSpace.md),
        if (at >= 0)
          DsTimeline(steps: [
            for (final (i, s) in FinancingStatus.steps.indexed)
              DsTimelineStep(
                title: FinancingStatus.label(s).tr,
                state: i < at || (i == at && i == FinancingStatus.steps.length - 1) ? DsStepState.done : (i == at ? DsStepState.current : DsStepState.upcoming),
              ),
          ]),
        const DsGap(DsSpace.md),
        DsFormSection(
          title: "Details".tr,
          icon: Icons.receipt_long_outlined,
          trailing: !editable
              ? null
              : DsButton.ghost(
                  label: "Edit".tr,
                  size: DsButtonSize.sm,
                  onPressed: () async {
                    final projects = await FinanceFinancingService.projects().first;
                    Get.to(() => ApplicationFormScreen(config: cfg, projects: projects, application: a));
                  },
                ),
          children: [
            _row(context, "Amount requested".tr, m(a['amount'])),
            if (a['approvedAmount'] != null) _row(context, "Amount approved".tr, m(a['approvedAmount'])),
            if (a['fundedAmount'] != null) _row(context, "Amount funded".tr, m(a['fundedAmount'])),
            if ((a['institutionName'] ?? '').toString().isNotEmpty) _row(context, "Financing institution".tr, a['institutionName'].toString()),
            if (a['submittedAt'] != null) _row(context, "Submitted on".tr, _date(a['submittedAt'])),
            if (a['fundedAt'] != null) _row(context, "Funded on".tr, _date(a['fundedAt'])),
            if ((a['useOfFunds'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: Text(a['useOfFunds'].toString(), style: DsTypography.body)),
          ],
        ),
        const DsGap(DsSpace.md),
        DsFormSection(
          title: "Documents".tr,
          subtitle: "Only you and the authorised reviewers can see them.".tr,
          icon: Icons.folder_open_outlined,
          children: [
            for (final t in required)
              DsListTile(
                padding: const EdgeInsets.symmetric(vertical: 2),
                leadingIcon: missing.contains(t) ? Icons.radio_button_unchecked_rounded : Icons.check_circle_rounded,
                leadingTone: missing.contains(t) ? DsTone.warning : DsTone.success,
                title: FinancingLabels.document(t).tr,
                subtitle: missing.contains(t) ? "Required".tr : null,
                trailing: editable && missing.contains(t) ? DsButton.ghost(label: "Add".tr, icon: Icons.upload_file_rounded, size: DsButtonSize.sm, onPressed: () => _upload(t)) : null,
              ),
            if (docs.isNotEmpty) const Divider(),
            for (final d in docs)
              DsListTile(
                padding: const EdgeInsets.symmetric(vertical: 2),
                leadingIcon: d['contentType'] == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
                leadingTone: _tone(d['status']?.toString()),
                title: d['name']?.toString() ?? '-',
                subtitle: [
                  FinancingLabels.document(d['type']?.toString()).tr,
                  if (d['status'] != null) FinancingLabels.documentStatus(d['status']?.toString()).tr,
                  if ((d['note'] ?? '').toString().isNotEmpty) d['note'].toString(),
                ].join(' · '),
                subtitleMaxLines: 3,
                onTap: (d['storagePath'] ?? '').toString().isEmpty ? null : () => _open(storagePath: d['storagePath'].toString()),
                trailing: !editable
                    ? null
                    : DsIconButton(
                        icon: Icons.delete_outline_rounded,
                        semanticLabel: "Remove".tr,
                        onPressed: () => FinanceUi.run(() => FinanceFinancingService.removeDocument(d['id'].toString())),
                      ),
              ),
            if (editable)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DsButton.ghost(label: "Add another document".tr, icon: Icons.add_rounded, onPressed: _addOther),
              ),
            Text('${"PDF or photo".tr}, ${"up to".tr} ${(cfg.maxFileBytes / (1024 * 1024)).round()} MB', style: DsTypography.caption),
          ],
        ),
        if (editable) ...[
          const DsGap(DsSpace.md),
          DsFormSection(
            title: (status == 'additional_info_required' ? "Send back to the reviewers" : "Submit the application").tr,
            icon: Icons.send_rounded,
            children: [
              if (status == 'additional_info_required') DsTextField(label: "Message to the reviewers (optional)".tr, controller: _message, maxLines: 3),
              if (missing.isNotEmpty)
                DsInlineAlert(tone: DsTone.warning, message: '${"Still missing".tr}: ${missing.map((t) => FinancingLabels.document(t).tr).join(', ')}'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _declared,
                onChanged: (v) => setState(() => _declared = v ?? false),
                title: Text("I confirm that the information and documents are accurate and that I am authorised to apply for this company.".tr),
              ),
              FinanceKycGate(
                builder: (context, verified) => DsButton.primary(
                  label: (status == 'additional_info_required' ? "Send" : "Submit").tr,
                  icon: Icons.send_rounded,
                  expand: true,
                  onPressed: verified && _declared && FinancingStatus.canSubmit(status, missing)
                      ? () async {
                          if (await FinanceUi.run(() => FinanceFinancingService.submit(widget.applicationId, _message.text.trim()), success: "Application submitted")) {
                            setState(() {
                              _declared = false;
                              _message.clear();
                            });
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceFinancingService.reviews(widget.applicationId),
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: DsFormSection(
                title: "History".tr,
                icon: Icons.history_rounded,
                children: [
                  for (final r in list)
                    DsListTile(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      leadingIcon: Icons.circle,
                      leadingTone: _tone(r['toStatus']?.toString()),
                      title: FinancingStatus.label(r['toStatus']?.toString()).tr,
                      subtitle: [_date(r['at']), if ((r['publicNote'] ?? '').toString().isNotEmpty) r['publicNote'].toString()].join(' · '),
                      subtitleMaxLines: 4,
                    ),
                ],
              ),
            );
          },
        ),
        if (FinancingStatus.canWithdraw(status))
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.lg),
            child: DsButton.ghost(
              label: "Withdraw this application".tr,
              icon: Icons.close_rounded,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text("Withdraw this application?".tr),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: Text("Keep it".tr)),
                      TextButton(onPressed: () => Navigator.pop(d, true), child: Text("Withdraw".tr)),
                    ],
                  ),
                );
                if (ok == true) await FinanceUi.run(() => FinanceFinancingService.withdraw(widget.applicationId), success: "Application withdrawn");
              },
            ),
          ),
      ],
    );
  }
}
