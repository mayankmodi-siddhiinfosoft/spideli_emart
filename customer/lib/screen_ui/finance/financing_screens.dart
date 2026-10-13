import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/service/finance_financing_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_financing_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Form sections: every field carries its own bottom spacing.
const EdgeInsets _formPadding = EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0);

/// List sections: rows carry their own vertical padding.
const EdgeInsets _listPadding = EdgeInsets.symmetric(horizontal: DsSpace.lg);

/// Where the text of a list row starts (icon 40 + gap 12), for lines under a row.
const double _rowTextStart = 52;

/// Sheets open above the screen (outside its accent scope): keep them navy.
Widget _navy(Widget child) => Builder(
      builder: (context) => DsAccentScope(color: Theme.of(context).brightness == Brightness.dark ? FinColors.navyDark : FinColors.navy, child: child),
    );

IconData _resourceIcon(String? type) => switch (type) {
      'template' => Icons.description_outlined,
      'faq' => Icons.help_outline_rounded,
      'regulation' => Icons.gavel_rounded,
      _ => Icons.menu_book_outlined,
    };

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
        return FinScaffold(
          title: "Project financing".tr,
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
          body: FinBody(children: [
            if (cfgSnap.connectionState == ConnectionState.waiting)
              FinState.loading()
            else if (cfg == null)
              FinState.empty(Icons.business_center_outlined, "Project financing is not available yet.".tr)
            else ...[
              DsSegmentedTabs(
                segments: [DsSegment("Applications".tr), DsSegment("Projects".tr), DsSegment("Resources".tr)],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              switch (_tab) {
                0 => _Applications(config: cfg),
                1 => _Projects(config: cfg),
                _ => const _Resources(),
              },
            ],
          ]),
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
        if (snap.hasError) return FinState.error("Could not load your applications.".tr);
        if (!snap.hasData) return FinState.loading();
        if (snap.data!.isEmpty) {
          return FinState.empty(
            Icons.business_center_outlined,
            "You have no financing application yet.".tr,
            message: "Describe your project, choose the financing you need, add your business plan and financial statements, then follow the review here.".tr,
          );
        }
        return FinSection(
          divided: true,
          padding: _listPadding,
          children: [
            for (final a in snap.data!)
              FinListTile(
                icon: Icons.business_center_outlined,
                iconTone: DsTone.brand,
                title: a['projectName']?.toString() ?? '-',
                subtitle: [
                  FinancingLabels.type(a['financingType']?.toString()).tr,
                  if (a['durationMonths'] != null) '${a['durationMonths']} ${"months".tr}',
                  if (a['submittedAt'] != null) '${"Submitted on".tr} ${FinanceUi.day(a['submittedAt'])}',
                ].join(' · '),
                amount: FinanceMoney.format(FinanceSummary.intOf(a['amount']), a['currency']?.toString() ?? ''),
                status: a['status']?.toString(),
                statusLabel: a['status'] == null ? null : FinancingStatus.label(a['status'].toString()).tr,
                chevron: true,
                onTap: () => Get.to(() => ApplicationScreen(applicationId: a['id'].toString(), config: config)),
              ),
          ],
        );
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
        if (snap.hasError) return FinState.error("Could not load your projects.".tr);
        if (!snap.hasData) return FinState.loading(rows: 2);
        if (snap.data!.isEmpty) return FinState.empty(Icons.add_business_outlined, "You have no project yet.".tr);
        return FinSection(
          divided: true,
          padding: _listPadding,
          children: [
            for (final p in snap.data!)
              FinListTile(
                icon: Icons.storefront_outlined,
                iconTone: DsTone.brand,
                title: p['name']?.toString() ?? '-',
                subtitle: [
                  FinancingLabels.sector(p['sector']?.toString()).tr,
                  if ((p['stage'] ?? '').toString().isNotEmpty) FinancingLabels.stage(p['stage'].toString()).tr,
                  if ((p['city'] ?? '').toString().isNotEmpty) p['city'].toString(),
                ].join(' · '),
                chevron: true,
                onTap: () => Get.to(() => ProjectFormScreen(config: config, project: p)),
              ),
          ],
        );
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
        if (snap.hasError) return FinState.error("Could not load the resources.".tr);
        if (!snap.hasData) return FinState.loading();
        final all = snap.data!;
        final types = {for (final r in all) r['type']?.toString() ?? 'guide'}.toList();
        final list = all.where((r) => _type == null || r['type'] == _type).toList();
        if (all.isEmpty) return FinState.empty(Icons.menu_book_outlined, "No resource is published yet.".tr);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (types.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: DsSpace.lg),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final t in [null, ...types])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                        child: ChoiceChip(
                          label: Text(t == null ? "All".tr : FinancingLabels.resource(t).tr),
                          selected: _type == t,
                          onSelected: (_) => setState(() => _type = t),
                        ),
                      ),
                  ]),
                ),
              ),
            FinSection(
              top: types.length > 1 ? DsSpace.md : FinSpace.section,
              divided: true,
              padding: _listPadding,
              children: [
                for (final r in list)
                  FinListTile(
                    icon: _resourceIcon(r['type']?.toString()),
                    iconTone: DsTone.brand,
                    title: r['title']?.toString() ?? '-',
                    subtitle: r['summary']?.toString(),
                    chevron: true,
                    onTap: () => Get.to(() => ResourceScreen(resource: r)),
                  ),
              ],
            ),
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
    final c = DsColors.of(context);
    final r = resource;
    final String path = (r['storagePath'] ?? '').toString();
    final String url = (r['url'] ?? '').toString();
    final String summary = (r['summary'] ?? '').toString();
    final String body = (r['body'] ?? '').toString();
    final bool downloadable = path.isNotEmpty || url.startsWith('https://');
    return FinScaffold(
      title: FinancingLabels.resource(r['type']?.toString()).tr,
      bottomBar: !downloadable
          ? null
          : DsStickyBar(
              child: DsButton.primary(
                label: (r['type'] == 'template' ? "Download the template" : "Open the document").tr,
                icon: Icons.download_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () => _open(storagePath: path.isEmpty ? null : path, url: path.isEmpty ? url : null),
              ),
            ),
      body: FinBody(children: [
        FinHeader(
          icon: _resourceIcon(r['type']?.toString()),
          title: r['title']?.toString() ?? '-',
          subtitle: summary.isEmpty ? null : summary,
          below: r['updatedAt'] == null ? null : finFreshness(context, '${"Updated".tr} ${FinanceUi.day(r['updatedAt'])}'),
        ),
        if (body.isNotEmpty)
          FinSection(
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [SelectableText(body, style: DsTypography.body.copyWith(color: c.textPrimary, height: 1.5))],
          ),
        FinNotice("For information only. Check with the financing institution or a qualified adviser before you decide.".tr),
      ]),
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
    final c = DsColors.of(context);
    final cfg = widget.config;
    return FinScaffold(
      title: (widget.project == null ? "Add a project" : "Edit the project").tr,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, onPressed: _save)),
      body: FinBody(children: [
        FinSection(
          title: "The project".tr,
          top: 0,
          padding: _formPadding,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.md),
              child: Text("The company or activity that needs the financing.".tr, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
            ),
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
        FinSection(
          title: "Details".tr,
          padding: _formPadding,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: DsTextField(label: "Country".tr, controller: _country)),
              const DsGap(DsSpace.sm),
              Expanded(child: DsTextField(label: "City".tr, controller: _city)),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: DsTextField(label: "Employees".tr, controller: _employees, keyboardType: TextInputType.number)),
              const DsGap(DsSpace.sm),
              Expanded(child: DsTextField(label: "Year founded".tr, controller: _founded, keyboardType: TextInputType.number)),
            ]),
            DsTextField(label: "Website (optional)".tr, controller: _website, keyboardType: TextInputType.url),
          ],
        ),
      ]),
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
    final c = DsColors.of(context);
    final cfg = widget.config;
    final int? amount = FinanceAmount.parse(_amount.text, _currency);
    final required = cfg.requiredFor(_type);
    final String next = "You add your documents and submit the application on the next screen.".tr;
    return FinScaffold(
      title: (widget.application == null ? "New application" : "Edit the application").tr,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, onPressed: _save)),
      body: FinBody(children: [
        FinSection(
          title: "Financing".tr,
          top: 0,
          padding: _formPadding,
          children: [
            DsDropdown<String>(
              label: "Project".tr,
              requiredMark: true,
              value: _project,
              items: [for (final p in widget.projects) DropdownMenuItem(value: p['id'].toString(), child: Text(p['name']?.toString() ?? '-'))],
              onChanged: widget.application == null ? (v) => setState(() => _project = v) : null,
            ),
            DsFieldLabel("Type of financing".tr, required: true),
            Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: [
              for (final t in cfg.financingTypes) ChoiceChip(label: Text(FinancingLabels.type(t).tr), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
            ]),
            const DsGap(DsSpace.lg),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: DsTextField(
                  label: "Amount requested".tr,
                  controller: _amount,
                  requiredMark: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  errorText: _amount.text.isEmpty ? null : cfg.amountProblem(amount, _currency)?.tr,
                  helper: [
                    if (cfg.minAmount[_currency] != null) FinanceMoney.format(cfg.minAmount[_currency]!, _currency),
                    if (cfg.maxAmount[_currency] != null) FinanceMoney.format(cfg.maxAmount[_currency]!, _currency),
                  ].join(' - '),
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
                    items: [for (final cur in cfg.currencies) DropdownMenuItem(value: cur, child: Text(cur))],
                    onChanged: (v) => setState(() => _currency = v ?? _currency),
                  ),
                ),
              ],
            ]),
            if (cfg.hasDuration(_type)) ...[
              DsFieldLabel("Duration".tr, required: true),
              Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: [
                for (final m in cfg.durationsMonths) ChoiceChip(label: Text('$m ${"months".tr}'), selected: _months == m, onSelected: (_) => setState(() => _months = m)),
              ]),
              const DsGap(DsSpace.lg),
            ],
            DsTextField(
              label: "Use of the funds".tr,
              hint: "Equipment, stock, working capital, hiring... with the main amounts.".tr,
              controller: _use,
              maxLines: 6,
              requiredMark: true,
            ),
          ],
        ),
        // What the application will need, from the admin's rules, before the user saves.
        if (required.isNotEmpty)
          FinSection(
            title: "Required documents".tr,
            footnote: next,
            children: [
              for (final t in required)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                  child: Row(children: [
                    Icon(Icons.description_outlined, size: 18, color: c.textSecondary),
                    const DsGap(DsSpace.md),
                    Expanded(child: Text(FinancingLabels.document(t).tr, style: DsTypography.body.copyWith(color: c.textPrimary))),
                  ]),
                ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.md, left: DsSpace.xxs, right: DsSpace.xxs),
            child: Text(next, style: DsTypography.caption.copyWith(color: c.textSecondary)),
          ),
      ]),
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
    final type = await finSheet<String>(
      title: "Which document?".tr,
      child: _navy(Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in widget.config.documentTypes)
            FinListTile(icon: Icons.description_outlined, iconTone: DsTone.brand, title: FinancingLabels.document(t).tr, chevron: true, onTap: () => Get.back(result: t)),
        ],
      )),
    );
    if (type != null) await _upload(type);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceFinancingService.application(widget.applicationId),
      builder: (context, snap) {
        final a = snap.data;
        return FinScaffold(
          title: "Financing application".tr,
          body: snap.hasError
              ? FinBody(children: [FinState.error("Could not load this application.".tr)])
              : a == null
                  ? FinBody(children: [FinState.loading(rows: 4)])
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: FinanceFinancingService.documents(widget.applicationId),
                      builder: (context, ds) => _body(context, a, ds.data ?? const []),
                    ),
        );
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> a, List<Map<String, dynamic>> docs) {
    final c = DsColors.of(context);
    final cfg = widget.config;
    final String status = a['status']?.toString() ?? 'draft';
    final String cur = a['currency']?.toString() ?? '';
    final String type = a['financingType']?.toString() ?? '';
    final required = cfg.requiredFor(type);
    final missing = missingDocuments(required, docs);
    final bool editable = FinancingStatus.editable(status);
    final bool infoRequested = status == 'additional_info_required';
    final bool ended = status == 'rejected' || status == 'withdrawn';
    // A request for more information happens during the review.
    final int at = FinancingStatus.steps.indexOf(infoRequested ? 'under_review' : status);
    final String project = a['projectName']?.toString() ?? '-';
    final String? months = a['durationMonths'] == null ? null : '${a['durationMonths']} ${"months".tr}';
    String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), cur);
    return FinBody(children: [
      FinHeader(
        overline: project,
        title: m(a['amount']),
        subtitle: [FinancingLabels.type(type).tr, ?months].join(' · '),
        status: status,
        statusLabel: FinancingStatus.label(status).tr,
        icon: Icons.business_center_outlined,
        below: !ended && at < 0
            ? null
            : FinTrack(
                steps: [for (final s in FinancingStatus.steps) FinancingStatus.label(s).tr],
                // An ended application shows only what is certain: it was submitted.
                current: ended ? (a['submittedAt'] == null ? -1 : 0) : at,
                ended: ended,
                endedLabel: FinancingStatus.label(status).tr,
              ),
      ),
      if ((a['reason'] ?? '').toString().isNotEmpty)
        FinNotice(a['reason'].toString(), title: (infoRequested ? "What the reviewers need" : "Reason").tr, tone: FinStatus.tone(status)),
      FinSection(
        title: "Details".tr,
        actionLabel: editable ? "Edit".tr : null,
        onAction: !editable
            ? null
            : () async {
                final projects = await FinanceFinancingService.projects().first;
                Get.to(() => ApplicationFormScreen(config: cfg, projects: projects, application: a));
              },
        children: [
          FinRow("Project".tr, project),
          FinRow("Type of financing".tr, FinancingLabels.type(type).tr),
          FinRow("Amount requested".tr, m(a['amount'])),
          if (months != null) FinRow("Duration".tr, months),
          if (a['approvedAmount'] != null) FinRow("Amount approved".tr, m(a['approvedAmount'])),
          if (a['fundedAmount'] != null) FinRow("Amount funded".tr, m(a['fundedAmount'])),
          if ((a['institutionName'] ?? '').toString().isNotEmpty) FinRow("Financing institution".tr, a['institutionName'].toString()),
          if (a['submittedAt'] != null) FinRow("Submitted on".tr, FinanceUi.day(a['submittedAt'])),
          if (a['fundedAt'] != null) FinRow("Funded on".tr, FinanceUi.day(a['fundedAt'])),
          if ((a['useOfFunds'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Use of the funds".tr, style: DsTypography.body.copyWith(color: c.textSecondary)),
                const DsGap(DsSpace.xxs),
                Text(a['useOfFunds'].toString(), style: DsTypography.body.copyWith(color: c.textPrimary)),
              ]),
            ),
        ],
      ),
      if (required.isNotEmpty)
        FinSection(
          title: "Required documents".tr,
          divided: true,
          padding: _listPadding,
          children: [
            for (final t in required)
              if (missing.contains(t))
                FinListTile(
                  icon: Icons.radio_button_unchecked_rounded,
                  iconTone: DsTone.warning,
                  title: FinancingLabels.document(t).tr,
                  subtitle: editable ? "Required".tr : null,
                  status: editable ? null : 'pending',
                  statusLabel: editable ? null : "Missing".tr,
                  trailing: editable ? DsButton.ghost(label: "Add".tr, icon: Icons.upload_file_rounded, size: DsButtonSize.sm, onPressed: () => _upload(t)) : null,
                )
              else
                FinListTile(
                  icon: Icons.check_circle_rounded,
                  iconTone: DsTone.success,
                  title: FinancingLabels.document(t).tr,
                  status: 'completed',
                  statusLabel: "Added".tr,
                ),
          ],
        ),
      if (docs.isNotEmpty || editable)
        FinSection(
          title: "Uploaded documents".tr,
          divided: true,
          padding: _listPadding,
          footnote:
              '${"Only you and the authorised reviewers can see them.".tr} ${"PDF or photo".tr}, ${"up to".tr} ${ltr('${(cfg.maxFileBytes / (1024 * 1024)).round()} MB')}',
          children: [
            for (final d in docs) _document(context, d, editable),
            if (editable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsButton.ghost(label: "Add another document".tr, icon: Icons.add_rounded, onPressed: _addOther),
                ),
              ),
          ],
        ),
      if (editable)
        FinSection(
          title: (infoRequested ? "Send back to the reviewers" : "Submit the application").tr,
          padding: const EdgeInsets.all(DsSpace.lg),
          children: [
            if (infoRequested) DsTextField(label: "Message to the reviewers (optional)".tr, controller: _message, maxLines: 3),
            if (missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.sm),
                child: DsInlineAlert(tone: DsTone.warning, message: '${"Still missing".tr}: ${missing.map((t) => FinancingLabels.document(t).tr).join(', ')}'),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _declared,
              onChanged: (v) => setState(() => _declared = v ?? false),
              title: Text(
                "I confirm that the information and documents are accurate and that I am authorised to apply for this company.".tr,
                style: DsTypography.bodySm.copyWith(color: c.textPrimary),
              ),
            ),
            const DsGap(DsSpace.sm),
            FinanceKycGate(
              builder: (context, verified) => DsButton.primary(
                label: (infoRequested ? "Send" : "Submit").tr,
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
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: FinanceFinancingService.reviews(widget.applicationId),
        builder: (context, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) return const SizedBox.shrink();
          return FinSection(
            title: "History".tr,
            divided: true,
            padding: _listPadding,
            children: [for (final r in list) _review(context, r)],
          );
        },
      ),
      if (FinancingStatus.canWithdraw(status))
        Padding(
          padding: const EdgeInsets.only(top: FinSpace.section),
          child: DsButton.ghost(
            label: "Withdraw this application".tr,
            icon: Icons.close_rounded,
            expand: true,
            color: c.danger,
            onPressed: () async {
              final ok = await finConfirm(
                title: "Withdraw this application?".tr,
                lines: [("Project".tr, project), ("Amount requested".tr, m(a['amount']))],
                confirmLabel: "Withdraw".tr,
                destructive: true,
              );
              if (ok) await FinanceUi.run(() => FinanceFinancingService.withdraw(widget.applicationId), success: "Application withdrawn");
            },
          ),
        ),
    ]);
  }

  /// An uploaded document: open it, see the reviewers' status and note, remove it while editable.
  Widget _document(BuildContext context, Map<String, dynamic> d, bool editable) {
    final c = DsColors.of(context);
    final String? status = d['status']?.toString();
    final String note = (d['note'] ?? '').toString();
    final String path = (d['storagePath'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinListTile(
          icon: d['contentType'] == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
          iconTone: status == null ? DsTone.neutral : FinStatus.tone(status),
          title: d['name']?.toString() ?? '-',
          subtitle: FinancingLabels.document(d['type']?.toString()).tr,
          status: status,
          statusLabel: status == null ? null : FinancingLabels.documentStatus(status).tr,
          onTap: path.isEmpty ? null : () => _open(storagePath: path),
          trailing: !editable
              ? null
              : DsIconButton(
                  icon: Icons.delete_outline_rounded,
                  semanticLabel: "Remove".tr,
                  onPressed: () => FinanceUi.run(() => FinanceFinancingService.removeDocument(d['id'].toString())),
                ),
        ),
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: _rowTextStart, bottom: DsSpace.md),
            child: Text(note, style: DsTypography.bodySm.copyWith(color: status == 'rejected' ? c.dangerStrong : c.textSecondary)),
          ),
      ],
    );
  }

  /// A step of the review, with the reviewers' public note in full.
  Widget _review(BuildContext context, Map<String, dynamic> r) {
    final c = DsColors.of(context);
    final String? to = r['toStatus']?.toString();
    final String note = (r['publicNote'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinListTile(
          icon: FinStatus.icon(to),
          iconTone: FinStatus.tone(to),
          title: FinancingStatus.label(to).tr,
          subtitle: FinanceUi.date(r['at']),
        ),
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: _rowTextStart, bottom: DsSpace.md),
            child: Text(note, style: DsTypography.bodySm.copyWith(color: c.textPrimary)),
          ),
      ],
    );
  }
}
