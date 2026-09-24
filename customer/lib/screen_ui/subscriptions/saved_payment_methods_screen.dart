import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/region_service.dart';
import 'package:customer/utils/saved_payment_methods.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Profile > Payment methods (spec 3.4 / 7.8): saved Mobile Money numbers
/// and Wave accounts; set a default, delete. Only methods usable in the
/// current region are listed. Cards are not saved (see [SavedPaymentMethods]).
///
/// Archetype **H — settings list**: method cards with a default badge and an
/// overflow menu, an "Add" FAB and a DS sheet for the form.
class SavedPaymentMethodsScreen extends StatefulWidget {
  const SavedPaymentMethodsScreen({super.key});

  @override
  State<SavedPaymentMethodsScreen> createState() => _SavedPaymentMethodsScreenState();
}

class _SavedPaymentMethodsScreenState extends State<SavedPaymentMethodsScreen> {
  bool _loading = true;
  List<SavedPaymentMethod> _methods = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await RegionService.ensureLoaded();
      await SavedPaymentMethods.load();
      _methods = SavedPaymentMethods.usable();
    } catch (e) {
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _run(Future<void> Function() action) async {
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      await action();
    } catch (e) {
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
    ShowToastDialog.closeLoader();
    await _load();
  }

  Future<void> _add() async {
    final method = await Get.bottomSheet<SavedPaymentMethod>(const _AddMethodSheet(), isScrollControlled: true, backgroundColor: Colors.transparent);
    if (method != null) await _run(() => SavedPaymentMethods.add(method));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsScaffold(
      title: "Payment methods".tr,
      maxContentWidth: DsLayout.contentMax,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: Text("Add".tr, style: DsTypography.label.copyWith(color: c.onBrand)),
      ),
      body: DsAsync(
        isLoading: _loading,
        skeleton: const DsSkeletonList(itemCount: 3, trailing: false),
        builder: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 96),
          children: DsFadeSlideIn.stagger([
            if (_methods.isEmpty)
              DsEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: "Payment methods".tr,
                message: "No saved Mobile Money number or Wave account.".tr,
                actionLabel: "Add".tr,
                onAction: _add,
              ),
            ..._methods.map(
              (m) => SubUi.card(
                context,
                Row(
                  children: [
                    DsIconWell(icon: m.type == SavedPaymentMethod.typeWave ? Icons.waves_rounded : Icons.smartphone_rounded, tone: DsTone.brand, size: 44),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: SubUi.title(context, (m.label ?? '').isNotEmpty ? m.label! : m.title)),
                              if (m.isDefault) ...[const DsGap(DsSpace.sm), SubUi.chip("Default".tr, DsTone.success)],
                            ],
                          ),
                          const DsGap(DsSpace.xxs),
                          Text("${m.title} · ${m.number}", style: t.bodySm.tabular),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: c.textMuted),
                      tooltip: "Payment methods".tr,
                      onSelected: (v) {
                        if (v == 'default') _run(() => SavedPaymentMethods.setDefault(m.id));
                        if (v == 'delete') _run(() => SavedPaymentMethods.remove(m.id));
                      },
                      itemBuilder: (_) => [
                        if (!m.isDefault) PopupMenuItem(value: 'default', child: Text("Set as default".tr, style: t.body)),
                        PopupMenuItem(value: 'delete', child: Text("Delete".tr, style: t.body.withColor(c.dangerStrong))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const DsGap(DsSpace.sm),
            DsInlineAlert(
              tone: DsTone.info,
              icon: Icons.shield_outlined,
              message:
                  "The default number is prefilled when a payment gateway asks for a phone number. Bank cards are never saved in the app: card storage requires the payment gateway's tokenisation service, which is not available yet."
                      .tr,
            ),
          ]),
        ),
      ),
    );
  }
}

class _AddMethodSheet extends StatefulWidget {
  const _AddMethodSheet();

  @override
  State<_AddMethodSheet> createState() => _AddMethodSheetState();
}

class _AddMethodSheetState extends State<_AddMethodSheet> {
  String _type = SavedPaymentMethod.typeMobileMoney;
  String _operator = SavedPaymentMethod.operators.first;
  final _number = TextEditingController();
  final _label = TextEditingController();
  bool _default = true;

  @override
  void dispose() {
    _number.dispose();
    _label.dispose();
    super.dispose();
  }

  void _save() {
    final number = _number.text.replaceAll(' ', '').trim();
    if (!RegExp(r'^\+?[0-9]{6,15}$').hasMatch(number)) {
      ShowToastDialog.showToast("Please enter a valid phone number".tr);
      return;
    }
    Get.back(
      result: SavedPaymentMethod(
        id: Constant.getUuid(),
        type: _type,
        operator: _type == SavedPaymentMethod.typeMobileMoney ? _operator : null,
        number: number,
        label: _label.text.trim(),
        isDefault: _default,
        regionId: RegionService.customerRegionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsSheet(
      title: "Add payment method".tr,
      showClose: true,
      actions: DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, icon: Icons.check_rounded, onPressed: _save),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSegmentedTabs(
              segments: [DsSegment("Mobile Money".tr), const DsSegment("Wave")],
              index: _type == SavedPaymentMethod.typeMobileMoney ? 0 : 1,
              onChanged: (i) => setState(() => _type = i == 0 ? SavedPaymentMethod.typeMobileMoney : SavedPaymentMethod.typeWave),
            ),
            const DsGap(DsSpace.xl),
            if (_type == SavedPaymentMethod.typeMobileMoney)
              DsDropdown<String>(
                label: "Operator".tr,
                value: _operator,
                items: SavedPaymentMethod.operators.map((o) => DropdownMenuItem(value: o, child: Text(o.tr, style: t.body))).toList(),
                onChanged: (v) => setState(() => _operator = v ?? _operator),
              ),
            DsTextField(
              label: "Phone number (with country code)".tr,
              controller: _number,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.smartphone_rounded,
              requiredMark: true,
            ),
            DsTextField(label: "Label (optional)".tr, controller: _label, prefixIcon: Icons.label_outline_rounded),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _default,
              activeColor: c.brand,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => _default = v ?? false),
              title: Text("Use as default".tr, style: t.bodyStrong),
            ),
          ],
        ),
      ),
    );
  }
}
