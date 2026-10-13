import 'dart:io';

import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
    return DsScaffold(
      title: "Identity verification".tr,
      maxContentWidth: DsLayout.contentMax,
      body: _loading
          ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
          : _settings == null
              ? DsEmptyState(icon: Icons.hourglass_empty_rounded, title: "Identity verification is not available yet. Please try again later.".tr)
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FinanceService.myApplications(),
                  builder: (context, snap) {
                    if (snap.hasError) return DsErrorState(message: "Could not load your verification.".tr);
                    if (!snap.hasData) return const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4));
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
    final levels = widget.settings
        .levelsFor(_accountType)
        .where((l) => !widget.approvedLevels.contains(l.id) && !approved.any((a) => l.coveredBy(a)))
        .toList();
    final bool hasBusiness = widget.settings.levelsFor('business').isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        if (latest != null) ...[
          _StatusCard(app: latest),
          const DsGap(DsSpace.lg),
        ] else ...[
          DsCard.tinted(
            tone: DsTone.brand,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DsIconWell(icon: Icons.verified_user_outlined, tone: DsTone.brand),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Text(
                    "Verify your identity once to use Spideli Finance. Your documents are only seen by our verification team.".tr,
                    style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const DsGap(DsSpace.lg),
        ],
        if (hasBusiness)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.md),
            child: DsSegmentedTabs(
              segments: [DsSegment("Individual".tr), DsSegment("Business".tr)],
              index: _accountType == 'individual' ? 0 : 1,
              onChanged: (i) => setState(() => _accountType = i == 0 ? 'individual' : 'business'),
            ),
          ),
        if (levels.isEmpty)
          DsEmptyState(icon: Icons.verified_rounded, tone: DsTone.success, title: "You have no further verification to do.".tr, compact: true)
        else
          for (final level in levels)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.md),
              child: DsCard.outlined(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(KycLabels.level(level.id).tr, style: DsTypography.titleSm.copyWith(color: DsColors.of(context).textPrimary)),
                    const DsGap(DsSpace.xs),
                    for (final group in level.requiredDocuments)
                      Text('• ${group.map((t) => KycLabels.documentType(t).tr).join(' ${"or".tr} ')}',
                          style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary)),
                    const DsGap(DsSpace.md),
                    DsButton.primary(
                      label: "Start verification".tr,
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => FinanceUi.run(() => FinanceService.createApplication(level: level.id, accountType: _accountType)),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// The status of an application, with the reviewer's reason when there is one.
class _StatusCard extends StatelessWidget {
  final Map<String, dynamic> app;

  const _StatusCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final String status = app['status']?.toString() ?? '';
    final DsTone tone = FinanceUi.tone(KycStatus.tone(status));
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
    return DsCard.tinted(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DsIconWell(icon: status == KycStatus.approved ? Icons.verified_rounded : Icons.badge_outlined, tone: tone),
              const DsGap(DsSpace.md),
              Expanded(child: Text(KycLabels.level(app['level']?.toString()).tr, style: DsTypography.titleSm.copyWith(color: DsColors.of(context).textPrimary))),
              FinanceUi.kycBadge(status),
            ],
          ),
          if (note.isNotEmpty) ...[
            const DsGap(DsSpace.sm),
            Text(note.tr, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary)),
          ],
          if (reason.isNotEmpty && (status == KycStatus.additionalInfo || status == KycStatus.rejected)) ...[
            const DsGap(DsSpace.md),
            DsInlineAlert(tone: tone, title: "Reason".tr, message: reason),
          ],
          if (status == KycStatus.rejected) ...[
            const DsGap(DsSpace.md),
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                children: [
                  _StatusCard(app: app),
                  const DsGap(DsSpace.lg),
                  if (editable) ...[
                    _DetailsForm(key: ValueKey('$id-${app['revision']}'), app: app),
                    const DsGap(DsSpace.lg),
                    _DocumentsSection(app: app, settings: settings, docs: docs),
                    const DsGap(DsSpace.lg),
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
      children: [
        DsFormSection(
          title: "Your details".tr,
          icon: Icons.person_outline_rounded,
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
        if (_isBusiness) ...[
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Company details".tr,
            icon: Icons.business_outlined,
            children: [
              DsTextField(label: "Company name".tr, controller: _b['companyName'], requiredMark: true),
              DsTextField(label: "Registration number".tr, controller: _b['registrationNumber'], requiredMark: true),
              DsTextField(label: "Tax number".tr, controller: _b['taxNumber']),
              DsTextField(label: "Registered address".tr, controller: _b['registeredAddress']),
              DsTextField(label: "Country".tr, controller: _b['country'], bottomSpacing: 0),
            ],
          ),
        ],
        const DsGap(DsSpace.sm),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: DsButton.secondary(label: "Save details".tr, icon: Icons.save_outlined, size: DsButtonSize.sm, onPressed: () => save()),
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
    final ImageSource? source = await DsBottomSheet.show<ImageSource>(
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
    return DsFormSection(
      title: "Documents".tr,
      subtitle: "Clear photos, all four corners visible, no glare.".tr,
      icon: Icons.document_scanner_outlined,
      children: [
        for (final group in level.requiredDocuments)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.md),
            child: DsCard.outlined(
              padding: const EdgeInsets.all(DsSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (group.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: DsSpace.sm),
                      child: Text("Provide one of these".tr, style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary)),
                    ),
                  for (final type in group)
                    for (final side in settings.documentSides[type] ?? const <String>[]) _row(context, type, side),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, String type, String side) {
    final doc = _latest(type, side);
    final String status = doc?['status']?.toString() ?? '';
    final multiSide = (settings.documentSides[type]?.length ?? 1) > 1;
    final DsTone tone = switch (status) { 'accepted' => DsTone.success, 'rejected' => DsTone.danger, 'uploaded' => DsTone.info, _ => DsTone.neutral };
    final String label = switch (status) { 'accepted' => 'Accepted', 'rejected' => 'Rejected', 'uploaded' => 'Added', _ => 'Missing' };
    return DsListTile(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
      leadingIcon: type == 'selfie' ? Icons.face_retouching_natural_outlined : Icons.badge_outlined,
      leadingTone: tone,
      title: multiSide ? '${KycLabels.documentType(type).tr} · ${KycLabels.side(side).tr}' : KycLabels.documentType(type).tr,
      subtitle: label.tr,
      trailing: DsButton.ghost(
        label: (doc == null ? 'Add' : 'Replace').tr,
        icon: Icons.add_a_photo_outlined,
        size: DsButtonSize.sm,
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
        return DsFormSection(
          title: "History".tr,
          icon: Icons.history_rounded,
          children: [
            DsTimeline(
              steps: [
                for (final e in events)
                  DsTimelineStep(
                    title: KycLabels.action(e['action']?.toString()).tr,
                    subtitle: (e['reason']?.toString() ?? '').isEmpty ? null : e['reason'].toString(),
                    meta: FinanceUi.date(e['at']),
                    state: e['action'] == 'reject' ? DsStepState.error : DsStepState.done,
                  ),
              ],
            ),
          ],
        );
      },
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
