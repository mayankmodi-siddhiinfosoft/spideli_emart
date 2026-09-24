import 'package:driver/models/cart_product_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Item manifest shared by the pickup and deliver screens: one row per
/// product with its photo, name, quantity and the chosen variants / addons.
///
/// Purely presentational — it is handed a plain list, never a controller, so
/// it can safely be a widget with its own `build`.
class OrderManifestCard extends StatelessWidget {
  final List<CartProductModel> products;

  const OrderManifestCard({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return DsCard(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: products.length,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (context, index) => const DsDivider(spacing: DsSpace.md),
        itemBuilder: (context, index) => _ManifestRow(product: products[index]),
      ),
    );
  }
}

class _ManifestRow extends StatelessWidget {
  final CartProductModel product;

  const _ManifestRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final variants = product.variantInfo?.variantOptions ?? {};
    final extras = product.extras ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DsImage(url: product.photo.toString(), width: 64, height: 64, radius: DsRadius.md),
              const DsGap(DsSpace.md),
              Expanded(child: Text("${product.name}", style: t.bodyStrong)),
              const DsGap(DsSpace.sm),
              DsBadge(label: "x ${product.quantity}", tone: DsTone.brand, small: true),
            ],
          ),
          if (variants.isNotEmpty) ...[
            const DsGap(DsSpace.md),
            Text("Variants".tr, style: t.labelSm),
            const DsGap(DsSpace.xs),
            Wrap(
              spacing: DsSpace.sm,
              runSpacing: DsSpace.sm,
              children: List.generate(
                variants.length,
                (i) => DsBadge(label: "${variants.keys.elementAt(i)} : ${variants[variants.keys.elementAt(i)]}", small: true),
              ).toList(),
            ),
          ],
          if (extras.isNotEmpty) ...[
            const DsGap(DsSpace.md),
            Text("Addons".tr, style: t.labelSm),
            const DsGap(DsSpace.xs),
            Wrap(
              spacing: DsSpace.sm,
              runSpacing: DsSpace.sm,
              children: List.generate(extras.length, (i) => DsBadge(label: extras[i].toString(), small: true)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// The "I have the goods" confirmation row used before the slide-to-confirm
/// action on both the pickup and deliver screens.
class OrderConfirmCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;

  const OrderConfirmCheck({super.key, required this.value, required this.onChanged, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.tinted(
      tone: value ? DsTone.success : DsTone.neutral,
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.sm, DsSpace.xs, DsSpace.lg, DsSpace.xs),
      child: Row(
        children: [
          Checkbox(
            side: BorderSide(color: c.success, width: 1.5),
            value: value,
            activeColor: c.success,
            focusColor: c.success,
            onChanged: onChanged,
          ),
          const DsGap(DsSpace.xs),
          Expanded(
            child: Text(label, style: t.bodyStrong.withColor(value ? c.successStrong : c.textPrimary)),
          ),
        ],
      ),
    );
  }
}
