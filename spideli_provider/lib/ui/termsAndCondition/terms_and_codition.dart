import 'package:spideliprovider/controller/terms_condition_controller.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';

class TermsAndCondition extends StatelessWidget {
  const TermsAndCondition({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return GetX<TermsConditionController>(
      init: TermsConditionController(),
      builder: (controller) {
        final String html = controller.termsAndCondition.value;
        final bool ready = controller.termsAndCondition.isNotEmpty;
        return Scaffold(
          backgroundColor: c.background,
          body: SingleChildScrollView(
            child: DsResponsive(
              maxWidth: DsLayout.contentMax,
              padded: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: DsFadeSlideIn.stagger([
                  const DsGap(DsSpace.lg),
                  // Legal banner: brand-tinted, sets this page apart from the
                  // privacy policy (which uses an info tone).
                  DsCard.tinted(
                    tone: DsTone.brand,
                    padding: const EdgeInsets.all(DsSpace.xl),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DsIconWell(icon: Icons.gavel_rounded, tone: DsTone.brand, size: 48, circle: true),
                        const DsGap(DsSpace.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Terms & Conditions'.tr, style: t.title),
                              const DsGap(DsSpace.xs),
                              Text('Please read these terms carefully before using the app.'.tr, style: t.bodySm),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.lg),
                  ready
                      ? DsCard(
                          padding: const EdgeInsets.all(DsSpace.xl),
                          child: DefaultTextStyle(
                            style: t.bodyLg.copyWith(height: 1.6),
                            child: HtmlWidget(
                              '''
                  $html
                   ''',
                              onErrorBuilder: (context, element, error) => Text('$element ${"error: "}$error'),
                              onLoadingBuilder: (context, element, loadingProgress) => const CircularProgressIndicator(),
                            ),
                          ),
                        )
                      : const _LegalSkeleton(),
                  const DsGap(DsSpace.xxxl),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reading-page skeleton (title + paragraph lines) shown while the legal text
/// is still loading. Private to the legal screens.
class _LegalSkeleton extends StatelessWidget {
  const _LegalSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsCard(
      padding: const EdgeInsets.all(DsSpace.xl),
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSkeleton.line(width: 180, height: 18),
            const DsGap(DsSpace.lg),
            for (int i = 0; i < 3; i++) ...[
              DsSkeleton.line(width: double.infinity),
              const DsGap(DsSpace.sm),
              DsSkeleton.line(width: double.infinity),
              const DsGap(DsSpace.sm),
              DsSkeleton.line(width: 220),
              const DsGap(DsSpace.xl),
            ],
          ],
        ),
      ),
    );
  }
}
