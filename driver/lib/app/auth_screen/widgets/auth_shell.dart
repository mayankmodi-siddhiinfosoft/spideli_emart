import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype H – shared auth layout for the driver app.
///
/// Phones get a focused card: brand mark, display title, supporting line and
/// the form. Tablets / iPad split into a brand panel (gradient, logo, value
/// props) and a 440-wide form card, so the form never stretches.
///
/// Purely presentational: every widget passed in is built by the calling
/// screen inside its own `GetX` / `Obx` builder, so observable reads stay
/// tracked by that observer.
class AuthShell extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Row under the subtitle (e.g. "Didn't have an account? Sign up").
  final Widget? link;

  /// The form body.
  final List<Widget> children;

  /// Icon shown in the brand mark on phones.
  final IconData icon;

  /// Short lines listed on the tablet brand panel.
  final List<String> highlights;

  const AuthShell({
    super.key,
    required this.title,
    this.subtitle,
    this.link,
    required this.children,
    this.icon = Icons.local_shipping_outlined,
    this.highlights = const [],
  });

  @override
  Widget build(BuildContext context) {
    return DsResponsiveBuilder(
      builder: (context, l) {
        final form = _Form(
          title: title,
          subtitle: subtitle,
          link: link,
          icon: icon,
          compact: l.isWide,
          children: children,
        );
        if (!l.isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.xxxl),
            child: DsResponsive(maxWidth: 520, child: form),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _BrandPanel(icon: icon, highlights: highlights)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DsSpace.xxl, DsSpace.xxl, DsSpace.xxl, DsSpace.huge),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: form,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Form extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? link;
  final IconData icon;
  final bool compact;
  final List<Widget> children;

  const _Form({
    required this.title,
    required this.subtitle,
    required this.link,
    required this.icon,
    required this.compact,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: DsFadeSlideIn.stagger(
        [
          if (!compact) ...[
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                gradient: DsGradients.brand(context),
                borderRadius: DsRadius.brLg,
                boxShadow: DsShadows.glow(context, color: c.brand),
              ),
              child: Icon(icon, color: c.onBrand, size: 28),
            ),
            const DsGap(DsSpace.xl),
          ],
          Text(title, style: t.display),
          if (subtitle != null) ...[
            const DsGap(DsSpace.xs),
            Text(subtitle!, style: t.bodySecondary),
          ],
          if (link != null) ...[
            const DsGap(DsSpace.md),
            link!,
          ],
          const DsGap(DsSpace.xxl),
          ...children,
        ],
        offset: const Offset(0, 18),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final IconData icon;
  final List<String> highlights;

  const _BrandPanel({required this.icon, required this.highlights});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: DsGradients.deep(context)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.huge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(DsSpace.lg),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: DsRadius.brXl,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Image.asset("assets/images/ic_logo.png", height: 56),
              ),
              const DsGap(DsSpace.xxl),
              Text(
                "spideli Driver",
                style: DsTypography.displayLg.copyWith(color: Colors.white),
              ),
              const DsGap(DsSpace.sm),
              Text(
                "Your Favorite Ride, Parcel, Rental & Item Delivered Fast!".tr,
                style: DsTypography.bodyLg.copyWith(color: Colors.white.withValues(alpha: 0.8)),
              ),
              if (highlights.isNotEmpty) ...[
                const DsGap(DsSpace.xxxl),
                for (final h in highlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.md),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: Text(h, style: DsTypography.body.copyWith(color: Colors.white.withValues(alpha: 0.86))),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
