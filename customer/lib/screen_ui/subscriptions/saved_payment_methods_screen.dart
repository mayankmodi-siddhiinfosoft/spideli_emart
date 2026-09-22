import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/region_service.dart';
import 'package:customer/utils/saved_payment_methods.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Profile > Payment methods (spec 3.4 / 7.8): saved Mobile Money numbers
/// and Wave accounts; set a default, delete. Only methods usable in the
/// current region are listed. Cards are not saved (see [SavedPaymentMethods]).
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
    final method = await Get.bottomSheet<SavedPaymentMethod>(const _AddMethodSheet(), isScrollControlled: true);
    if (method != null) await _run(() => SavedPaymentMethods.add(method));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    return Scaffold(
      backgroundColor: SubUi.surface(isDark),
      appBar: SubUi.appBar("Payment methods".tr, isDark),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: AppThemeData.primary300, onPressed: _add, icon: const Icon(Icons.add, color: Colors.white), label: Text("Add".tr, style: const TextStyle(color: Colors.white))),
      body:
          _loading
              ? Constant.loader()
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  if (_methods.isEmpty) SubUi.empty("No saved Mobile Money number or Wave account.".tr, isDark),
                  ..._methods.map(
                    (m) => SubUi.card(
                      isDark,
                      Row(
                        children: [
                          Icon(m.type == SavedPaymentMethod.typeWave ? Icons.waves : Icons.phone_android, color: AppThemeData.primary300),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [Flexible(child: SubUi.title((m.label ?? '').isNotEmpty ? m.label! : m.title, isDark)), if (m.isDefault) ...[const SizedBox(width: 6), SubUi.chip("Default".tr, AppThemeData.success400)]]),
                                SubUi.body("${m.title} · ${m.number}", isDark),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'default') _run(() => SavedPaymentMethods.setDefault(m.id));
                              if (v == 'delete') _run(() => SavedPaymentMethods.remove(m.id));
                            },
                            itemBuilder: (_) => [if (!m.isDefault) PopupMenuItem(value: 'default', child: Text("Set as default".tr)), PopupMenuItem(value: 'delete', child: Text("Delete".tr))],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SubUi.body("The default number is prefilled when a payment gateway asks for a phone number. Bank cards are never saved in the app: card storage requires the payment gateway's tokenisation service, which is not available yet.".tr, isDark),
                ],
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
    final isDark = Get.find<ThemeController>().isDark.value;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: SubUi.surface(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SubUi.title("Add payment method".tr, isDark),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [ButtonSegment(value: SavedPaymentMethod.typeMobileMoney, label: Text("Mobile Money".tr)), const ButtonSegment(value: SavedPaymentMethod.typeWave, label: Text("Wave"))],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            if (_type == SavedPaymentMethod.typeMobileMoney)
              DropdownButtonFormField<String>(
                initialValue: _operator,
                decoration: InputDecoration(labelText: "Operator".tr),
                items: SavedPaymentMethod.operators.map((o) => DropdownMenuItem(value: o, child: Text(o.tr))).toList(),
                onChanged: (v) => setState(() => _operator = v ?? _operator),
              ),
            TextField(controller: _number, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Phone number (with country code)".tr)),
            TextField(controller: _label, decoration: InputDecoration(labelText: "Label (optional)".tr)),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _default, onChanged: (v) => setState(() => _default = v ?? false), title: Text("Use as default".tr)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppThemeData.primary300), onPressed: _save, child: Text("Save".tr, style: const TextStyle(color: Colors.white))),
            ),
          ],
        ),
      ),
    );
  }
}
