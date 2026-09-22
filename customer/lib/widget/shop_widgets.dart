import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/themes/app_them_data.dart';
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
