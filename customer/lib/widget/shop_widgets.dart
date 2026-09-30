import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/screen_ui/subscriptions/business_account_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/wholesale_pricing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// Small shared pieces of the multivendor / e-commerce screens (spec 7.3).

/// Delivery / TakeAway as two toggle buttons.
class OrderTypeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const OrderTypeToggle({super.key, required this.value, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final String current = OrderTypeMode.normalise(value);
    Widget button(String type, IconData icon) {
      final bool selected = current == type;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(120),
          onTap: selected ? null : () => onChanged(type),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: ShapeDecoration(
              color: selected ? AppThemeData.primary300 : Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? AppThemeData.grey50 : (isDark ? AppThemeData.grey400 : AppThemeData.grey500)),
                const SizedBox(width: 6),
                Text(
                  type.tr,
                  style: TextStyle(
                    fontFamily: AppThemeData.semiBold,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: selected ? AppThemeData.grey50 : (isDark ? AppThemeData.grey300 : AppThemeData.grey700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
        shape: RoundedRectangleBorder(side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200), borderRadius: BorderRadius.circular(120)),
      ),
      child: Row(children: [button(OrderTypeMode.delivery, Icons.delivery_dining_outlined), button(OrderTypeMode.takeAway, Icons.storefront_outlined)]),
    );
  }
}

/// Round "next" arrow that replaces the "View all" text of horizontal lists.
class NextArrowButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color? color;

  const NextArrowButton({super.key, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? AppThemeData.primary300;
    return Semantics(
      button: true,
      label: 'View all'.tr,
      child: InkWell(
        borderRadius: BorderRadius.circular(120),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 1.2)),
          child: Icon(Icons.arrow_forward_ios_rounded, size: 15, color: c),
        ),
      ),
    );
  }
}

/// Round "+" button that replaces the "Add" button of product cards.
class PlusButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  final double size;

  const PlusButton({super.key, required this.onTap, required this.isDark, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add'.tr,
      child: InkWell(
        borderRadius: BorderRadius.circular(120),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Icon(Icons.add, color: AppThemeData.primary300, size: size * 0.62),
        ),
      ),
    );
  }
}

/// Search bar pinned at the bottom of a section home.
class BottomSearchBar extends StatelessWidget {
  final String hint;
  final VoidCallback onTap;
  final bool isDark;

  const BottomSearchBar({super.key, required this.hint, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: ShapeDecoration(
            color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
            shape: RoundedRectangleBorder(side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200), borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            children: [
              SvgPicture.asset("assets/icons/ic_search.svg"),
              const SizedBox(width: 12),
              Expanded(
                child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The wholesale pill every listing carries: the ENTRY tier's offer
/// ("Wholesale 3,500 from 15 units"), or the pack floor of a wholesale-only
/// product ("Sold in a minimum of 15 units"). Build the label with
/// [WholesalePricing.listingBadgeLabel] so every surface words it the same.
/// An empty label draws nothing.
class WholesaleBadge extends StatelessWidget {
  final String label;
  final bool small;

  const WholesaleBadge({super.key, required this.label, this.small = true});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return DsBadge(label: label, tone: DsTone.brand, icon: Icons.inventory_2_outlined, small: small);
  }
}

/// Price tiers side by side with their quantity ranges (spec 8.2), e.g.
/// "1000 (1-9)  700 (10-49)  650 (50+)".
class PriceTiersView extends StatelessWidget {
  final List<PriceBand> bands;
  final CurrencyModel? currency;
  final bool isDark;
  final bool compact;

  const PriceTiersView({super.key, required this.bands, required this.currency, required this.isDark, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (bands.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children:
          bands.map((b) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
              decoration: ShapeDecoration(
                color: b.isWholesale ? (isDark ? AppThemeData.primary600 : AppThemeData.primary50) : (isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1, color: b.isWholesale ? AppThemeData.primary300 : (isDark ? AppThemeData.grey700 : AppThemeData.grey200)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Constant.amountShow(amount: b.price.toString(), currency: currency),
                    style: TextStyle(fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600, fontSize: compact ? 12 : 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                  ),
                  Text(
                    '${b.rangeLabel} ${'pcs'.tr}',
                    style: TextStyle(fontFamily: AppThemeData.regular, fontSize: compact ? 10 : 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

/// **A wholesale-only product shows a price a customer can pay** (WEB spec §10,
/// 30 September): the headline is the ENTRY tier for the selected variant, with
/// the pack minimum beneath it —
///
/// ```
/// ₹959.00
/// per piece, from 10 units
/// ```
///
/// — because a single piece of such a product is not for sale at any price, so
/// the retail figure the page used to show was a price nobody could pay.
/// Retail and mixed products keep their retail headline and never draw this.
class WholesaleOnlyHeadline extends StatelessWidget {
  /// The entry tier of the selected variant, from
  /// [WholesalePricing.headlineTierFor]. null draws nothing.
  final WholesaleTier? tier;
  final CurrencyModel? currency;

  const WholesaleOnlyHeadline({super.key, required this.tier, required this.currency});

  @override
  Widget build(BuildContext context) {
    final WholesaleTier? entry = tier;
    if (entry == null) return const SizedBox.shrink();
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Constant.amountShow(amount: entry.price, currency: currency), style: t.titleSm.tabular.withColor(c.brandStrong)),
        Text(WholesalePricing.headlineMinimumLabel(entry.minQtyValue), style: t.caption),
      ],
    );
  }
}

/// **A size that cannot make up a pack says so** (WEB spec §10, 30 September):
/// a red note naming the shortfall, drawn beside a disabled Add to cart.
/// An empty shortfall draws nothing.
class PackShortfallNote extends StatelessWidget {
  /// Units this option holds.
  final int stock;

  /// Units the smallest pack needs.
  final int minQty;

  /// 0 = this option is workable.
  final int shortfall;

  const PackShortfallNote({super.key, required this.stock, required this.minQty, required this.shortfall});

  @override
  Widget build(BuildContext context) {
    if (shortfall <= 0) return const SizedBox.shrink();
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.xs),
      child: Text(WholesalePricing.shortfallLabel(stock, minQty), style: t.labelSm.withColor(c.dangerStrong)),
    );
  }
}

/// Refuses a **wholesale-only** product to a customer without an approved
/// business account (WEB spec §19) and points at the business-account
/// application. Returns true when the product was refused, so the caller does
/// not go on to open it.
///
/// The listing filter does not cover a banner, a shared link or anything else
/// that reaches a product detail directly, which is why the refusal lives at
/// the one place a product detail opens rather than only in the lists.
bool refuseWholesaleOnlyProduct(ProductModel product) {
  if (!product.hiddenForCustomer) return false;
  DsDialog.show(
    DsDialog(
      title: 'For business accounts'.tr,
      message: 'This product is sold wholesale only. Apply for a business account to see and buy wholesale products.'.tr,
      icon: Icons.storefront_outlined,
      primaryLabel: 'Apply now'.tr,
      onPrimary: () {
        Get.back();
        Get.to(() => const BusinessAccountScreen());
      },
      secondaryLabel: 'Close'.tr,
      onSecondary: () => Get.back(),
    ),
  );
  return true;
}
