import 'package:driver/constant/constant.dart';
import 'package:driver/services/order_history_export_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/order_history_export.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// App-bar action of the order-history screens: picks a period and a status
/// (all statuses by default), then exports the orders of [scope] in that
/// period with that status to a PDF and opens the share sheet.
///
/// [scope] is read when tapped (the owner's driver filter can change).
class ExportOrdersPdfButton extends StatelessWidget {
  final OrderExportScope Function() scope;

  const ExportOrdersPdfButton({super.key, required this.scope});

  /// The signed-in driver's own history (every service).
  const ExportOrdersPdfButton.currentDriver({super.key}) : scope = currentDriverScope;

  /// Delivery charge / tip columns follow the delivery history card, which
  /// shows them to a driver who is not a store's own driver.
  static OrderExportScope currentDriverScope() => DriverExportScope(
        driverId: Constant.userModel?.id ?? FireStoreUtils.getCurrentUid(),
        showEarnings: Constant.userModel?.vendorID?.isEmpty == true,
      );

  @override
  Widget build(BuildContext context) {
    return DsIconButton(
      icon: Icons.picture_as_pdf_outlined,
      semanticLabel: 'Export PDF'.tr,
      variant: DsIconButtonVariant.tonal,
      onPressed: () => exportOrdersPdf(scope()),
    );
  }
}

/// What the export sheet returns.
typedef OrderExportChoice = ({ExportDateRange range, OrderExportStatusFilter status});

/// Period and status sheet, then the export.
Future<void> exportOrdersPdf(OrderExportScope scope) async {
  final OrderExportChoice? choice = await DsBottomSheet.show<OrderExportChoice>(
    title: 'Export order history'.tr,
    subtitle: 'Choose a period of up to one year.'.tr,
    child: _ExportPeriodForm(initial: ExportDateRange.lastDays(DateTime.now())),
  );
  if (choice == null || !choice.range.isValid) return;
  await OrderHistoryExportService.export(scope, choice.range, status: choice.status);
}

class _ExportPeriodForm extends StatefulWidget {
  final ExportDateRange initial;

  const _ExportPeriodForm({required this.initial});

  @override
  State<_ExportPeriodForm> createState() => _ExportPeriodFormState();
}

class _ExportPeriodFormState extends State<_ExportPeriodForm> {
  late DateTime _from = widget.initial.from;
  late DateTime _to = widget.initial.to;
  OrderExportStatusFilter _status = OrderExportStatusFilter.all;

  ExportDateRange get _range => ExportDateRange(_from, _to);

  Future<void> _pick({required bool from}) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime current = from ? _from : _to;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(today.year - 10),
      lastDate: today,
      helpText: (from ? 'Start date' : 'End date').tr,
    );
    if (picked == null || !mounted) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat format = DateFormat('dd MMM yyyy');
    final String? error = _range.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsTileGroup(
          margin: EdgeInsets.zero,
          children: [
            DsListTile(
              title: 'Start date'.tr,
              subtitle: format.format(_from),
              leadingIcon: Icons.event_outlined,
              leadingTone: DsTone.brand,
              showChevron: true,
              onTap: () => _pick(from: true),
            ),
            DsListTile(
              title: 'End date'.tr,
              subtitle: format.format(_to),
              leadingIcon: Icons.event_available_outlined,
              leadingTone: DsTone.brand,
              showChevron: true,
              onTap: () => _pick(from: false),
            ),
          ],
        ),
        const DsGap(DsSpace.md),
        DsFieldLabel('Status'.tr),
        _StatusDropdown(value: _status, onChanged: (status) => setState(() => _status = status)),
        if (error != null) ...[
          const DsGap(DsSpace.md),
          DsInlineAlert(tone: DsTone.danger, message: error.tr),
        ],
        const DsGap(DsSpace.lg),
        DsButton.primary(
          label: 'Export PDF'.tr,
          icon: Icons.picture_as_pdf_outlined,
          expand: true,
          size: DsButtonSize.lg,
          onPressed: error != null ? null : () => Get.back(result: (range: _range, status: _status)),
        ),
      ],
    );
  }
}

/// Status filter: "All statuses", then each order-list tab (bold) followed
/// by its statuses (indented).
class _StatusDropdown extends StatelessWidget {
  final OrderExportStatusFilter value;
  final ValueChanged<OrderExportStatusFilter> onChanged;

  const _StatusDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final DsColors c = DsColors.of(context);
    final List<OrderExportStatusFilter> choices = OrderExportStatusFilter.choices;
    final TextStyle plain = DsTypography.bodyStrong.copyWith(color: c.textPrimary);
    final TextStyle heading = DsTypography.label.copyWith(color: c.textPrimary);
    return DropdownButtonFormField<OrderExportStatusFilter>(
      initialValue: value,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
      borderRadius: DsRadius.brMd,
      dropdownColor: c.surfaceRaised,
      style: plain,
      decoration: DsInputDecoration.of(context, prefixIcon: Icons.filter_list_rounded),
      // The closed field shows the choice without the list's indentation.
      selectedItemBuilder: (_) => [
        for (final OrderExportStatusFilter choice in choices) Text(choice.key.tr, style: plain, overflow: TextOverflow.ellipsis),
      ],
      items: [
        for (final OrderExportStatusFilter choice in choices)
          DropdownMenuItem<OrderExportStatusFilter>(
            value: choice,
            child: Padding(
              padding: EdgeInsets.only(left: choice.isGroup || choice.isAll ? 0 : DsSpace.lg),
              child: Text(choice.key.tr, style: choice.isGroup || choice.isAll ? heading : plain, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
      onChanged: (choice) {
        if (choice != null) onChanged(choice);
      },
    );
  }
}
