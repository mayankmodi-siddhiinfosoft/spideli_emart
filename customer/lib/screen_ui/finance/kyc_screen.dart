import 'dart:io';

import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Inner padding of a form section (each field carries its own bottom spacing).
const EdgeInsets _formPadding = EdgeInsets.all(DsSpace.lg);

/// Spideli Finance > Identity verification (KYC). The server
/// (finance/functions kyc) owns every status: this screen shows the user's
/// application live and sends what the user enters. Requirements come from
/// `platform_settings/kyc`.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  KycSettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    FinanceService.kycSettings().then((s) {
      if (mounted) setState(() => _settings = s);
    }).catchError((_) {}).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Identity verification".tr,
      body: _loading
          ? FinBody(children: [FinState.loading(rows: 4)])
          : _settings == null
              ? FinBody(children: [FinState.empty(Icons.hourglass_empty_rounded, "Identity verification is not available yet. Please try again later.".tr)])
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FinanceService.myApplications(),
                  builder: (context, snap) {
                    if (snap.hasError) return FinBody(children: [FinState.error("Could not load your verification.".tr)]);
                    if (!snap.hasData) return FinBody(children: [FinState.loading(rows: 4)]);
                    final apps = snap.data!;
                    final open = apps.where((a) => KycStatus.isOpen(a['status']?.toString())).toList();
                    if (open.isNotEmpty) return _ApplicationView(app: open.first, settings: _settings!);
                    final latest = apps.isEmpty ? null : apps.first;
                    final approvedLevels = apps.where((a) => a['status'] == KycStatus.approved).map((a) => a['level'].toString()).toSet();
                    return _StartView(settings: _settings!, latest: latest, approvedLevels: approvedLevels);
                  },
                ),
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
/// details form, the documents and the submit bar.
class _ApplicationView extends StatelessWidget {
  final Map<String, dynamic> app;
  final KycSettings settings;

  const _ApplicationView({required this.app, required this.settings});

  @override
  Widget build(BuildContext context) {
    final String id = app['id'].toString();
    final bool editable = KycStatus.ownerMayEdit(app['status']?.toString());
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceService.documents(id),
      builder: (context, docsSnap) {
        final docs = docsSnap.data ?? const [];
        final refs = docs.map((d) => KycDocumentRef(d['type'].toString(), d['side'].toString(), d['status'].toString())).toList();
        final missing = settings.missingGroups(app['level'].toString(), refs);
        return Column(
          children: [
            Expanded(
              child: FinBody(
                children: [
                  _StatusHeader(app: app),
                  if (editable) ...[
                    _DetailsForm(key: ValueKey('$id-${app['revision']}'), app: app),
                    _DocumentsSection(app: app, settings: settings, docs: docs),
                  ],
                  _History(applicationId: id),
                ],
              ),
            ),
            if (editable)
              DsStickyBar(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (missing.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.sm),
                        child: Text(
                          "${"Still missing".tr}: ${missing.map((g) => g.map((t) => KycLabels.documentType(t).tr).join(' ${"or".tr} ')).join(', ')}",
                          style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary),
                        ),
                      ),
                    DsButton.primary(
                      label: "Submit for review".tr,
                      icon: Icons.send_rounded,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: missing.isNotEmpty
                          ? null
                          : () => FinanceUi.run(() async {
                                await _DetailsForm.saveCurrent(id);
                                await FinanceService.submit(id);
                              }, success: "Submitted. We will review it shortly."),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Personal (and business) details. The values are sent to the server, which
/// keeps only the fields it knows.
class _DetailsForm extends StatefulWidget {
  final Map<String, dynamic> app;

  const _DetailsForm({super.key, required this.app});

  /// The form on screen, so the submit bar can save it first.
  static _DetailsFormState? _current;

  static Future<void> saveCurrent(String applicationId) async {
    final form = _current;
    if (form != null && form.widget.app['id'] == applicationId) await form.save(silent: true);
  }

  @override
  State<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends State<_DetailsForm> {
  static const List<String> _personal = ['fullName', 'dateOfBirth', 'nationality', 'idNumber', 'address', 'city', 'country'];
  static const List<String> _business = ['companyName', 'registrationNumber', 'taxNumber', 'registeredAddress', 'country'];
  final Map<String, TextEditingController> _p = {};
  final Map<String, TextEditingController> _b = {};

  bool get _isBusiness => widget.app['accountType'] == 'business';

  @override
  void initState() {
    super.initState();
    _DetailsForm._current = this;
    final personal = Map<String, dynamic>.from((widget.app['personal'] as Map?) ?? const {});
    final business = Map<String, dynamic>.from((widget.app['business'] as Map?) ?? const {});
    for (final f in _personal) {
      _p[f] = TextEditingController(text: personal[f]?.toString() ?? '');
    }
    for (final f in _business) {
      _b[f] = TextEditingController(text: business[f]?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    if (_DetailsForm._current == this) _DetailsForm._current = null;
    for (final c in [..._p.values, ..._b.values]) {
      c.dispose();
    }
    super.dispose();
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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_p['dateOfBirth']!.text) ?? DateTime(now.year - 25);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1900), lastDate: DateTime(now.year - 16, now.month, now.day));
    if (picked != null) setState(() => _p['dateOfBirth']!.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinSection(
          title: "Your details".tr,
          padding: _formPadding,
          children: [
            DsTextField(label: "Full name (as on your document)".tr, controller: _p['fullName'], requiredMark: true, textCapitalization: TextCapitalization.words),
            DsTextField(label: "Date of birth".tr, controller: _p['dateOfBirth'], readOnly: true, onTap: _pickBirthDate, suffix: const Icon(Icons.calendar_today_outlined, size: 18)),
            DsTextField(label: "Nationality".tr, controller: _p['nationality']),
            DsTextField(label: "Document number".tr, controller: _p['idNumber']),
            DsTextField(label: "Address".tr, controller: _p['address']),
            DsTextField(label: "City".tr, controller: _p['city']),
            DsTextField(label: "Country".tr, controller: _p['country'], bottomSpacing: 0),
          ],
        ),
        if (_isBusiness)
          FinSection(
            title: "Company details".tr,
            padding: _formPadding,
            children: [
              DsTextField(label: "Company name".tr, controller: _b['companyName'], requiredMark: true),
              DsTextField(label: "Registration number".tr, controller: _b['registrationNumber'], requiredMark: true),
              DsTextField(label: "Tax number".tr, controller: _b['taxNumber']),
              DsTextField(label: "Registered address".tr, controller: _b['registeredAddress']),
              DsTextField(label: "Country".tr, controller: _b['country'], bottomSpacing: 0),
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

/// The required documents, grouped as the configuration asks ("one of").
class _DocumentsSection extends StatelessWidget {
  final Map<String, dynamic> app;
  final KycSettings settings;
  final List<Map<String, dynamic>> docs;

  const _DocumentsSection({required this.app, required this.settings, required this.docs});

  /// The latest live upload of a type and side.
  Map<String, dynamic>? _latest(String type, String side) {
    final live = docs.where((d) => d['type'] == type && d['side'] == side && d['status'] != 'superseded').toList();
    return live.isEmpty ? null : live.last;
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
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2400, preferredCameraDevice: type == 'selfie' ? CameraDevice.front : CameraDevice.rear);
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
    return FinSection(
      title: "Documents".tr,
      divided: true,
      footnote: "Clear photos, all four corners visible, no glare.".tr,
      children: [
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

  Widget _row(BuildContext context, String type, String side) {
    final doc = _latest(type, side);
    final String status = doc?['status']?.toString() ?? '';
    final multiSide = (settings.documentSides[type]?.length ?? 1) > 1;
    // An upload waiting for review reads as "in progress" in the status catalogue.
    final String chip = status == 'uploaded' ? 'submitted' : status;
    final String label = switch (status) { 'accepted' => 'Accepted', 'rejected' => 'Rejected', 'uploaded' => 'Added', _ => 'Missing' };
    return FinListTile(
      icon: type == 'selfie' ? Icons.face_retouching_natural_outlined : Icons.badge_outlined,
      iconTone: FinStatus.tone(chip),
      title: multiSide ? '${KycLabels.documentType(type).tr} · ${KycLabels.side(side).tr}' : KycLabels.documentType(type).tr,
      status: chip,
      statusLabel: label.tr,
      trailing: DsIconButton(
        icon: Icons.add_a_photo_outlined,
        variant: DsIconButtonVariant.brand,
        semanticLabel: (doc == null ? 'Add' : 'Replace').tr,
        onPressed: () => _upload(context, type, side),
      ),
    );
  }
}

/// The application's history (kyc_reviews), oldest first.
class _History extends StatelessWidget {
  final String applicationId;

  const _History({required this.applicationId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceService.history(applicationId),
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
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.tone(tone).soft, borderRadius: DsRadius.brSm),
              child: Icon(icon, size: 20, color: tone == DsTone.neutral ? c.textSecondary : c.tone(tone).strong),
            ),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(KycLabels.action(action).tr, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
                  const DsGap(DsSpace.xxs),
                  Text(FinanceUi.date(event['at']), style: DsTypography.caption.copyWith(color: c.textSecondary)),
                  if (reason.isNotEmpty) ...[
                    const DsGap(DsSpace.xs),
                    Text(reason, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
