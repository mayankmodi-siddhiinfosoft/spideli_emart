import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/service/finance_region_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/tax_country.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Inner padding of a form section: each field carries its own bottom
/// spacing (as the transfer and bill forms).
const EdgeInsets _formPadding = EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0);

/// Spideli Finance > Identity verification (KYC). The user's own steps
/// (start, details, documents, submit, start again) are written to Firestore
/// directly (FinanceService, .claude/FINANCE-DIRECT-FIRESTORE.md 3.1) and
/// checked by the security rules; the review and its decisions are the admin
/// panel's. The status shown is that of the latest application, live.
/// Requirements come from the KYC settings of the customer's Finance region
/// (`finance_settings/{regionId}_kyc`); an application keeps those of the
/// region it was started in.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  late Stream<List<Map<String, dynamic>>> _apps = FinanceService.myApplications();

  Widget _page(Widget body) => FinScaffold(title: "Identity verification".tr, body: body);

  /// An open application follows the requirements of its own region (it
  /// may have been started in another one).
  Widget _openApplication(Map<String, dynamic> app, KycSettings current) {
    final String own = (app['regionId'] ?? '').toString();
    if (own.isEmpty || own == FinanceRegion.currentId) return _ApplicationView(key: ValueKey(app['id']), app: app, settings: current);
    return FinConfig<KycSettings>(
      key: ValueKey('kyc-settings-$own'),
      load: () => FinanceService.kycSettings(regionId: own),
      builder: (context, st) {
        final settings = st.config;
        final placeholder = st.placeholder(Icons.hourglass_empty_rounded, "Identity verification is not available yet. Please try again later.".tr);
        if (placeholder != null || settings == null) return _page(FinBody(children: [placeholder ?? FinState.loading(rows: 4)]));
        return _ApplicationView(key: ValueKey(app['id']), app: app, settings: settings);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FinConfig<KycSettings>(
      load: FinanceService.kycSettings,
      builder: (context, st) {
        final settings = st.config;
        final placeholder = st.placeholder(Icons.hourglass_empty_rounded, "Identity verification is not available yet. Please try again later.".tr);
        if (placeholder != null || settings == null) return _page(FinBody(children: [placeholder ?? FinState.loading(rows: 4)]));
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _apps,
          builder: (context, snap) {
            if (snap.hasError) {
              return _page(FinBody(children: [
                FinState.error("Could not load your verification.".tr, onRetry: () => setState(() => _apps = FinanceService.myApplications())),
              ]));
            }
            if (!snap.hasData) return _page(FinBody(children: [FinState.loading(rows: 4)]));
            final apps = snap.data!;
            final open = apps.where((a) => KycStatus.isOpen(a['status']?.toString())).toList();
            // Its own page: the submit bar sits in the scaffold's bottom bar.
            if (open.isNotEmpty) return _openApplication(open.first, settings);
            final latest = apps.isEmpty ? null : apps.first;
            final approvedLevels = apps.where((a) => a['status'] == KycStatus.approved).map((a) => a['level'].toString()).toSet();
            return _page(_StartView(settings: settings, latest: latest, approvedLevels: approvedLevels));
          },
        );
      },
    );
  }
}

/// No open application: the last outcome (if any) and the levels the user can start.
class _StartView extends StatefulWidget {
  final KycSettings settings;
  final Map<String, dynamic>? latest;
  final Set<String> approvedLevels;

  const _StartView({required this.settings, required this.latest, required this.approvedLevels});

  @override
  State<_StartView> createState() => _StartViewState();
}

class _StartViewState extends State<_StartView> {
  String _accountType = 'individual';

  @override
  Widget build(BuildContext context) {
    final latest = widget.latest;
    final approved = [for (final id in widget.approvedLevels) ?widget.settings.levels[id]];
    // A level already approved, or covered by an approved one, is not offered again.
    final levels = widget.settings
        .levelsFor(_accountType)
        .where((l) => !widget.approvedLevels.contains(l.id) && !approved.any((a) => l.coveredBy(a)))
        .toList();
    final bool hasBusiness = widget.settings.levelsFor('business').isNotEmpty;
    return FinBody(
      children: [
        if (latest != null)
          _StatusHeader(app: latest)
        else
          FinHeader(
            icon: Icons.verified_user_outlined,
            title: KycStatus.label(null).tr,
            subtitle: "Verify your identity once to use Spideli Finance. Your documents are only seen by our verification team.".tr,
          ),
        if (hasBusiness)
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsSegmentedTabs(
              segments: [DsSegment("Individual".tr), DsSegment("Business".tr)],
              index: _accountType == 'individual' ? 0 : 1,
              onChanged: (i) => setState(() => _accountType = i == 0 ? 'individual' : 'business'),
            ),
          ),
        if (levels.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsEmptyState(icon: Icons.verified_rounded, tone: DsTone.success, title: "You have no further verification to do.".tr, compact: true),
          )
        else
          FinSection(
            title: "Verification levels".tr,
            top: hasBusiness ? DsSpace.lg : FinSpace.section,
            divided: true,
            children: [
              for (final (i, level) in levels.indexed)
                _LevelTile(
                  level: level,
                  primary: i == 0,
                  onStart: () => FinanceUi.run(() => FinanceService.createApplication(level: level.id, accountType: _accountType)),
                ),
            ],
          ),
      ],
    );
  }
}

/// One level the user can start: its name, the documents it asks for
/// ("one of" groups on one line) and the start action.
class _LevelTile extends StatelessWidget {
  final KycLevel level;
  final bool primary;
  final VoidCallback onStart;

  const _LevelTile({required this.level, required this.primary, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DsIconWell(icon: level.id == 'business' ? Icons.business_outlined : Icons.badge_outlined, tone: DsTone.brand, size: 40),
              const DsGap(DsSpace.md),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(KycLabels.level(level.id).tr, style: DsTypography.titleSm.copyWith(color: c.textPrimary)),
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.sm),
          for (final group in level.requiredDocuments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.description_outlined, size: 16, color: c.textMuted),
                  ),
                  const DsGap(DsSpace.sm),
                  Expanded(
                    child: Text(
                      group.map((t) => KycLabels.documentType(t).tr).join(' ${"or".tr} '),
                      style: DsTypography.body.copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          const DsGap(DsSpace.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: primary
                ? DsButton.primary(label: "Start verification".tr, icon: Icons.arrow_forward_rounded, onPressed: onStart)
                : DsButton.secondary(label: "Start verification".tr, icon: Icons.arrow_forward_rounded, onPressed: onStart),
          ),
        ],
      ),
    );
  }
}

/// The status of an application as the screen's headline: the level, the
/// status, what it means, and the reviewer's reason when there is one.
class _StatusHeader extends StatelessWidget {
  final Map<String, dynamic> app;

  const _StatusHeader({required this.app});

  @override
  Widget build(BuildContext context) {
    final String status = app['status']?.toString() ?? '';
    final String reason = app['reason']?.toString() ?? '';
    final String note = switch (status) {
      KycStatus.draft => "Add your details and documents, then submit.",
      KycStatus.submitted => "Submitted. Our team will review it shortly.",
      KycStatus.underReview => "Our team is reviewing your documents.",
      KycStatus.additionalInfo => "Our team needs more information. Please update your verification and submit it again.",
      KycStatus.approved => "Your identity is verified.",
      KycStatus.rejected => "Your verification was not approved. You can start again.",
      _ => "",
    };
    final bool showReason = reason.isNotEmpty && (status == KycStatus.additionalInfo || status == KycStatus.rejected);
    final bool restart = status == KycStatus.rejected;
    return FinHeader(
      overline: KycLabels.level(app['level']?.toString()).tr,
      title: KycStatus.label(status).tr,
      subtitle: note.isEmpty ? null : note.tr,
      // The status gives the icon its tone; the title already names it.
      status: status.isEmpty ? null : status,
      icon: status == KycStatus.approved ? Icons.verified_rounded : Icons.badge_outlined,
      below: !showReason && !restart
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showReason) DsInlineAlert(tone: FinStatus.tone(status), title: "Reason".tr, message: reason),
                if (restart) ...[
                  if (showReason) const DsGap(DsSpace.md),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DsButton.tonal(
                      label: "Start again".tr,
                      icon: Icons.replay_rounded,
                      size: DsButtonSize.sm,
                      onPressed: () => FinanceUi.run(() => FinanceService.reopen(app['id'].toString())),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// An open application: status, history, and (while the user may edit) the
/// details form, the documents and, in the bottom bar, what is still
/// missing and the submit action.
class _ApplicationView extends StatefulWidget {
  final Map<String, dynamic> app;
  final KycSettings settings;

  const _ApplicationView({super.key, required this.app, required this.settings});

  @override
  State<_ApplicationView> createState() => _ApplicationViewState();
}

class _ApplicationViewState extends State<_ApplicationView> {
  late Stream<List<Map<String, dynamic>>> _docs = FinanceService.documents(_id);

  /// The form on screen. A new revision (after a review) gets a new form,
  /// filled with what is now stored.
  GlobalKey<_DetailsFormState> _form = GlobalKey();

  String get _id => widget.app['id'].toString();

  @override
  void didUpdateWidget(_ApplicationView old) {
    super.didUpdateWidget(old);
    if (old.app['revision'] != widget.app['revision']) _form = GlobalKey();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final settings = widget.settings;
    final bool editable = KycStatus.ownerMayEdit(app['status']?.toString());
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _docs,
      builder: (context, docsSnap) {
        // Until the documents are read, nothing is said to be missing.
        final bool docsReady = docsSnap.hasData;
        final docs = docsSnap.data ?? const [];
        final refs = docs.map((d) => KycDocumentRef(d['type'].toString(), d['side'].toString(), d['status'].toString())).toList();
        final missingDocs = docsReady ? settings.missingGroups(app['level'].toString(), refs) : const <List<String>>[];
        final missingFields = editable ? (_form.currentState?.missingFields() ?? _DetailsFormState.missingIn(app)) : const <String>[];
        final missing = [
          ...missingFields,
          for (final g in missingDocs) g.map((t) => KycLabels.documentType(t).tr).join(' ${"or".tr} '),
        ];
        return FinScaffold(
          title: "Identity verification".tr,
          bottomBar: !editable
              ? null
              : DsStickyBar(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FinMissing(missing),
                      DsButton.primary(
                        label: "Submit for review".tr,
                        icon: Icons.send_rounded,
                        size: DsButtonSize.lg,
                        expand: true,
                        onPressed: !docsReady || missing.isNotEmpty
                            ? null
                            : () => FinanceUi.run(() async {
                                  await _form.currentState?.save(silent: true);
                                  await FinanceService.submit(_id);
                                }, success: "Submitted. We will review it shortly."),
                      ),
                    ],
                  ),
                ),
          body: FinBody(
            children: [
              _StatusHeader(app: app),
              if (editable) ...[
                _DetailsForm(key: _form, app: app, onChanged: () => setState(() {})),
                if (docsSnap.hasError)
                  FinState.error(
                    "Could not load your documents.".tr,
                    onRetry: () => setState(() => _docs = FinanceService.documents(_id)),
                  )
                else if (!docsReady)
                  FinState.loading()
                else
                  _DocumentsSection(app: app, settings: settings, docs: docs, missingGroups: missingDocs.length),
              ],
              _History(applicationId: _id),
            ],
          ),
        );
      },
    );
  }
}

/// Personal (and business) details. Only the known fields are stored
/// (KycWrites.clean).
class _DetailsForm extends StatefulWidget {
  final Map<String, dynamic> app;

  /// A field changed: the page re-counts what is missing.
  final VoidCallback onChanged;

  const _DetailsForm({super.key, required this.app, required this.onChanged});

  @override
  State<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends State<_DetailsForm> with AutomaticKeepAliveClientMixin {
  static const List<String> _personal = ['fullName', 'dateOfBirth', 'nationality', 'idNumber', 'address', 'city', 'country'];
  static const List<String> _business = ['companyName', 'registrationNumber', 'taxNumber', 'registeredAddress', 'country'];

  /// The fields marked required, with the name the missing list uses.
  static const Map<String, String> _requiredPersonal = {'fullName': "Full name"};
  static const Map<String, String> _requiredBusiness = {'companyName': "Company name", 'registrationNumber': "Registration number"};

  final Map<String, TextEditingController> _p = {};
  final Map<String, TextEditingController> _b = {};

  /// The date of birth as read ("05 Oct 1990"); the value sent stays yyyy-MM-dd.
  final TextEditingController _birthShown = TextEditingController();

  /// Required fields the user has edited: an empty one then says so.
  final Set<String> _touched = {};

  bool get _isBusiness => widget.app['accountType'] == 'business';

  /// Kept while scrolled out of the list: what the user typed, unsaved,
  /// must not be lost (and the submit bar reads it).
  @override
  bool get wantKeepAlive => true;

  /// The required fields still empty in [app] as stored (before the form is
  /// on screen), translated.
  static List<String> missingIn(Map<String, dynamic> app) {
    String of(String group, String f) => (((app[group] as Map?) ?? const {})[f] ?? '').toString().trim();
    return [
      for (final e in _requiredPersonal.entries)
        if (of('personal', e.key).isEmpty) e.value.tr,
      if (app['accountType'] == 'business')
        for (final e in _requiredBusiness.entries)
          if (of('business', e.key).isEmpty) e.value.tr,
    ];
  }

  /// The required fields still empty in the form, translated.
  List<String> missingFields() => [
        for (final e in _requiredPersonal.entries)
          if (_p[e.key]!.text.trim().isEmpty) e.value.tr,
        if (_isBusiness)
          for (final e in _requiredBusiness.entries)
            if (_b[e.key]!.text.trim().isEmpty) e.value.tr,
      ];

  @override
  void initState() {
    super.initState();
    final personal = Map<String, dynamic>.from((widget.app['personal'] as Map?) ?? const {});
    final business = Map<String, dynamic>.from((widget.app['business'] as Map?) ?? const {});
    for (final f in _personal) {
      _p[f] = TextEditingController(text: personal[f]?.toString() ?? '');
    }
    for (final f in _business) {
      _b[f] = TextEditingController(text: business[f]?.toString() ?? '');
    }
    _birthShown.text = _readable(_p['dateOfBirth']!.text);
  }

  @override
  void dispose() {
    for (final c in [..._p.values, ..._b.values, _birthShown]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _readable(String stored) {
    final d = DateTime.tryParse(stored);
    return d == null ? stored : FinanceUi.day(Timestamp.fromDate(d));
  }

  Map<String, String> _values(Map<String, TextEditingController> m) => {
        for (final e in m.entries)
          if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
      };

  Future<void> save({bool silent = false}) async {
    final call = FinanceService.updateApplication(
      widget.app['id'].toString(),
      personal: _values(_p),
      business: _isBusiness ? _values(_b) : null,
    );
    if (silent) {
      await call;
    } else {
      await FinanceUi.run(() => call, success: "Saved");
    }
  }

  void _changed(String field) {
    setState(() => _touched.add(field));
    widget.onChanged();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_p['dateOfBirth']!.text) ?? DateTime(now.year - 25);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1900), lastDate: DateTime(now.year - 16, now.month, now.day));
    if (picked == null) return;
    _p['dateOfBirth']!.text = DateFormat('yyyy-MM-dd').format(picked);
    _birthShown.text = _readable(_p['dateOfBirth']!.text);
    _changed('dateOfBirth');
  }

  /// The countries of the app's list (English names, as the admin panel
  /// saves them); a value typed before the list existed stays choosable.
  static final List<String> _countries = TaxCountry.isoEnglishNames.values.map((n) => n.first).toList()..sort();

  Widget _country(String label, TextEditingController ctrl, String field) {
    final String value = ctrl.text.trim();
    return FinPickerField<String>(
      label: label,
      value: value.isEmpty ? null : value,
      searchHint: "Search for a country".tr,
      options: [
        if (value.isNotEmpty && !_countries.contains(value)) (value, value),
        for (final n in _countries) (n, n),
      ],
      onChanged: (v) {
        ctrl.text = v;
        _changed(field);
      },
    );
  }

  /// A required field: "Enter ..." once the user has left it empty.
  Widget _required(String label, TextEditingController ctrl, String field, String error, {TextCapitalization caps = TextCapitalization.none}) => DsTextField(
        label: label,
        controller: ctrl,
        requiredMark: true,
        textCapitalization: caps,
        errorText: _touched.contains(field) && ctrl.text.trim().isEmpty ? error : null,
        onChanged: (_) => _changed(field),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinSection(
          title: "Your details".tr,
          padding: _formPadding,
          children: [
            _required("Full name (as on your document)".tr, _p['fullName']!, 'fullName', "Enter your full name as on your document.".tr, caps: TextCapitalization.words),
            DsTextField(
              label: "Date of birth".tr,
              controller: _birthShown,
              readOnly: true,
              onTap: _pickBirthDate,
              suffix: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            _country("Nationality".tr, _p['nationality']!, 'nationality'),
            DsTextField(label: "Document number".tr, controller: _p['idNumber']),
            DsTextField(label: "Address".tr, controller: _p['address']),
            DsTextField(label: "City".tr, controller: _p['city']),
            _country("Country".tr, _p['country']!, 'country'),
          ],
        ),
        if (_isBusiness)
          FinSection(
            title: "Company details".tr,
            padding: _formPadding,
            children: [
              _required("Company name".tr, _b['companyName']!, 'companyName', "Enter the company name.".tr),
              _required("Registration number".tr, _b['registrationNumber']!, 'registrationNumber', "Enter the registration number.".tr),
              DsTextField(label: "Tax number".tr, controller: _b['taxNumber']),
              DsTextField(label: "Registered address".tr, controller: _b['registeredAddress']),
              _country("Country".tr, _b['country']!, 'businessCountry'),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.md),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DsButton.secondary(label: "Save details".tr, icon: Icons.save_outlined, size: DsButtonSize.sm, onPressed: () => save()),
          ),
        ),
      ],
    );
  }
}

/// The required documents, grouped as the configuration asks ("one of"),
/// with how many of them are provided.
class _DocumentsSection extends StatelessWidget {
  final Map<String, dynamic> app;
  final KycSettings settings;
  final List<Map<String, dynamic>> docs;

  /// Required groups not provided yet.
  final int missingGroups;

  const _DocumentsSection({required this.app, required this.settings, required this.docs, required this.missingGroups});

  /// The latest live upload of a type and side.
  Map<String, dynamic>? _latest(String type, String side) {
    final live = docs.where((d) => d['type'] == type && d['side'] == side && d['status'] != 'superseded').toList();
    return live.isEmpty ? null : live.last;
  }

  /// The camera or the photos were refused (now or for good): say how to
  /// allow them instead of failing silently.
  Future<void> _accessRefused(ImageSource source, PlatformException e) async {
    if (e.code == 'no_available_camera') {
      ShowToastDialog.showToast("No camera is available on this device. Choose a photo from the gallery.".tr);
      return;
    }
    final bool camera = source == ImageSource.camera;
    await finSheet(
      title: (camera ? "Allow the camera" : "Allow access to your photos").tr,
      child: Builder(builder: (context) {
        final c = DsColors.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              (camera
                      ? "Spideli needs the camera to photograph your document. Allow it in your phone's settings for Spideli, then try again."
                      : "Spideli needs access to your photos to add your document. Allow it in your phone's settings for Spideli, then try again.")
                  .tr,
              style: DsTypography.body.copyWith(color: c.textSecondary),
            ),
            const DsGap(DsSpace.lg),
            DsButton.primary(
              label: "Open settings".tr,
              icon: Icons.settings_outlined,
              expand: true,
              onPressed: () async {
                Get.back();
                await Geolocator.openAppSettings();
              },
            ),
            DsButton.ghost(label: "Not now".tr, expand: true, onPressed: () => Get.back()),
          ],
        );
      }),
    );
  }

  Future<void> _upload(BuildContext context, String type, String side) async {
    final ImageSource? source = await finSheet<ImageSource>(
      title: "Add a photo".tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsListTile(leadingIcon: Icons.photo_camera_outlined, title: "Take a photo".tr, onTap: () => Get.back(result: ImageSource.camera)),
          DsListTile(leadingIcon: Icons.photo_library_outlined, title: "Choose from gallery".tr, onTap: () => Get.back(result: ImageSource.gallery)),
        ],
      ),
    );
    if (source == null) return;
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2400, preferredCameraDevice: type == 'selfie' ? CameraDevice.front : CameraDevice.rear);
    } on PlatformException catch (e) {
      return _accessRefused(source, e);
    }
    if (picked == null) return;
    final file = File(picked.path);
    if (await file.length() > settings.maxFileBytes) {
      ShowToastDialog.showToast(FinanceErrors.messageKey('kyc_file_size').tr);
      return;
    }
    await FinanceUi.run(() => FinanceService.uploadDocument(applicationId: app['id'].toString(), type: type, side: side, file: file), success: "Document added");
  }

  @override
  Widget build(BuildContext context) {
    final level = settings.levels[app['level']?.toString()];
    if (level == null) return const SizedBox.shrink();
    final int total = level.requiredDocuments.length;
    final int done = (total - missingGroups).clamp(0, total);
    return FinSection(
      title: "Documents".tr,
      divided: true,
      footnote: "Clear photos, all four corners visible, no glare.".tr,
      children: [
        if (total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
            child: FinProgress(
              value: done / total,
              label: "Documents provided".tr,
              trailing: "@done of @total".trParams({'done': '$done', 'total': '$total'}),
              tone: done == total ? DsTone.success : DsTone.brand,
            ),
          ),
        for (final group in level.requiredDocuments)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (group.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.md),
                  child: Text("Provide one of these".tr, style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary)),
                ),
              for (final type in group)
                for (final side in settings.documentSides[type] ?? const <String>[]) _row(context, type, side),
            ],
          ),
      ],
    );
  }

  /// One document: the whole row adds (or replaces) its photo.
  Widget _row(BuildContext context, String type, String side) {
    final doc = _latest(type, side);
    final String status = doc?['status']?.toString() ?? '';
    final multiSide = (settings.documentSides[type]?.length ?? 1) > 1;
    // An upload waiting for review reads as "in progress" in the status catalogue.
    final String chip = status == 'uploaded' ? 'submitted' : status;
    final String label = switch (status) { 'accepted' => 'Accepted', 'rejected' => 'Rejected', 'uploaded' => 'Added', _ => 'Missing' };
    final bool replace = doc != null;
    // The reviewer's note on a refused photo (what to fix before replacing it).
    final String note = status == 'rejected' ? (doc?['note'] ?? '').toString().trim() : '';
    void upload() => _upload(context, type, side);
    return FinListTile(
      icon: type == 'selfie' ? Icons.face_retouching_natural_outlined : Icons.badge_outlined,
      iconTone: FinStatus.tone(chip),
      title: multiSide ? '${KycLabels.documentType(type).tr} · ${KycLabels.side(side).tr}' : KycLabels.documentType(type).tr,
      subtitle: note.isEmpty ? null : note,
      status: chip,
      statusLabel: label.tr,
      onTap: upload,
      trailing: DsIconButton(
        icon: replace ? Icons.cached_rounded : Icons.add_a_photo_outlined,
        variant: replace ? DsIconButtonVariant.plain : DsIconButtonVariant.brand,
        semanticLabel: (replace ? 'Replace' : 'Add').tr,
        onPressed: upload,
      ),
    );
  }
}

/// The application's history (kyc_reviews), oldest first.
class _History extends StatefulWidget {
  final String applicationId;

  const _History({required this.applicationId});

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  late final Stream<List<Map<String, dynamic>>> _stream = FinanceService.history(widget.applicationId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final events = snap.data ?? const [];
        if (events.isEmpty) return const SizedBox.shrink();
        return FinSection(
          title: "History".tr,
          divided: true,
          children: [for (final e in events) _HistoryRow(event: e)],
        );
      },
    );
  }
}

/// One review event: what happened, when, and the reviewer's reason in full.
class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> event;

  const _HistoryRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final String? action = event['action']?.toString();
    final String reason = event['reason']?.toString() ?? '';
    final (IconData icon, DsTone tone) = switch (action) {
      'approve' => (Icons.verified_rounded, DsTone.success),
      'reject' => (Icons.error_outline_rounded, DsTone.danger),
      'request_info' => (Icons.info_outline_rounded, DsTone.warning),
      'submit' => (Icons.send_rounded, DsTone.neutral),
      'start_review' => (Icons.manage_search_rounded, DsTone.neutral),
      'reopen' => (Icons.replay_rounded, DsTone.neutral),
      _ => (Icons.history_rounded, DsTone.neutral),
    };
    final tile = FinListTile(icon: icon, iconTone: tone, title: KycLabels.action(action).tr, subtitle: FinanceUi.date(event['at']));
    if (reason.isEmpty) return tile;
    // The reason in full, under the line (a list subtitle would cut it).
    return MergeSemantics(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile,
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 40 + DsSpace.md, bottom: DsSpace.md),
          child: Text(reason, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
        ),
      ]),
    );
  }
}

/// Translation keys of the configured identifiers. An identifier the app does
/// not know is shown readable ("utility_bill" -> "Utility bill").
abstract final class KycLabels {
  static String _humanize(String? id) {
    final s = (id ?? '').replaceAll('_', ' ').trim();
    return s.isEmpty ? '-' : s[0].toUpperCase() + s.substring(1);
  }

  static String documentType(String? id) => const {
        'national_id': 'National ID card',
        'passport': 'Passport',
        'selfie': 'Photo of your face',
        'proof_of_address': 'Proof of address',
        'business_registration': 'Business registration document',
      }[id] ??
      _humanize(id);

  static String side(String? id) => const {'front': 'Front', 'back': 'Back'}[id] ?? _humanize(id);

  static String level(String? id) => const {
        'basic': 'Basic verification',
        'full': 'Full verification',
        'business': 'Business verification',
      }[id] ??
      _humanize(id);

  static String action(String? id) => const {
        'submit': 'Submitted',
        'start_review': 'Review started',
        'request_info': 'More information requested',
        'approve': 'Approved',
        'reject': 'Not approved',
        'reopen': 'Started again',
      }[id] ??
      _humanize(id);
}
