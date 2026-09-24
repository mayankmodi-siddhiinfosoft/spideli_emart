import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/subscription_history_controller.dart';
import 'package:spideliprovider/model/subscription_history.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Purchase history (archetype J – subscription). A receipt ledger: each plan
/// purchase is a card headed by the plan identity and an active badge, with
/// the validity / price / payment facts as aligned key-value rows.
class SubscriptionHistoryScreen extends StatelessWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<SubscriptionHistoryController>(
      init: SubscriptionHistoryController(),
      builder: (controller) {
        // Read synchronously so this GetX tracks the list: the item builder
        // below runs later and would not be observed.
        final List<SubscriptionHistoryModel> rows = controller.subscriptionHistoryList.toList();
        return DsScaffold(
          body: DsAsync(
            isLoading: controller.isLoading.value,
            skeleton: const Padding(
              padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
              child: DsSkeletonList(itemCount: 4, trailing: false),
            ),
            isEmpty: rows.isEmpty,
            empty: DsEmptyState(icon: Icons.receipt_long_outlined, title: "Purchase History Not found".tr, message: "Plans you buy will be listed here with their validity and payment.".tr),
            builder: (context) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const DsGap(DsSpace.lg),
              itemBuilder: (context, index) {
                final SubscriptionHistoryModel subscriptionHistoryModel = rows[index];
                return DsFadeSlideIn(
                  index: index,
                  child: _HistoryCard(model: subscriptionHistoryModel, isActive: index == 0),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// One purchase receipt.
class _HistoryCard extends StatelessWidget {
  final SubscriptionHistoryModel model;
  final bool isActive;

  const _HistoryCard({required this.model, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard(
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: DsRadius.brMd,
                child: NetworkImageWidget(imageUrl: model.subscriptionPlan?.image ?? '', fit: BoxFit.cover, width: 45, height: 45),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Text(model.subscriptionPlan?.name ?? '', textAlign: TextAlign.start, style: t.titleSm),
              ),
              if (isActive) DsStatusChip(label: 'Active', tone: DsTone.success, pulse: true),
            ],
          ),
          const DsDivider(spacing: DsSpace.md),
          _Fact(label: 'Validity', value: model.subscriptionPlan?.expiryDay == '-1' ? "Unlimited" : '${model.subscriptionPlan?.expiryDay ?? '0'}  Days'),
          _Fact(
            label: 'Price',
            value: amountShow(amount: model.subscriptionPlan?.price ?? '0'),
            emphasise: true,
          ),
          _Fact(label: 'Payment Type', value: (model.paymentType ?? '').capitalizeString()),
          _Fact(label: 'Purchase Date', value: timestampToDateTime(model.subscriptionPlan!.createdAt!)),
          _Fact(label: 'Expiry Date', value: model.expiryDate == null ? "Unlimited" : timestampToDateTime(model.expiryDate!), last: true),
        ],
      ),
    );
  }
}

/// Label / value row that wraps instead of clipping at large text scale.
class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;
  final bool last;

  const _Fact({required this.label, required this.value, this.emphasise = false, this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : DsSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, textAlign: TextAlign.start, maxLines: 2, style: t.bodySecondary),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, maxLines: 2, style: emphasise ? t.bodyStrong.tabular.withColor(c.brandStrong) : t.bodyStrong),
          ),
        ],
      ),
    );
  }
}
