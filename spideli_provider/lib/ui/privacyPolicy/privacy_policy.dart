import 'package:spideliprovider/controller/terms_condition_controller.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return GetX<TermsConditionController>(
      init: TermsConditionController(),
      builder: (controller) {
        final String html = controller.privacyPolicy.value;
        final bool ready = controller.privacyPolicy.isNotEmpty;
        return Scaffold(
          backgroundColor: c.background,
          body: SingleChildScrollView(
            child: DsResponsive(
              maxWidth: DsLayout.contentMax,
              padded: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: DsFadeSlideIn.stagger([
                  const DsGap(DsSpace.xxl),
                  // Shield crest header – deliberately different from the
                  // terms page banner.
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: c.infoSoft, borderRadius: DsRadius.brXl),
                      alignment: Alignment.center,
                      child: Icon(Icons.privacy_tip_outlined, size: 34, color: c.infoStrong),
                    ),
                  ),
                  const DsGap(DsSpace.lg),
                  Text('Privacy Policy'.tr, textAlign: TextAlign.center, style: t.headline),
                  const DsGap(DsSpace.xs),
                  Text('How we collect, use and protect your information.'.tr, textAlign: TextAlign.center, style: t.bodySecondary),
                  const DsGap(DsSpace.xl),
                  const DsDivider(),
                  const DsGap(DsSpace.sm),
                  ready
                      ? DefaultTextStyle(
                          style: t.bodyLg.copyWith(height: 1.65),
                          child: HtmlWidget(
                            '''
                  $html
                   ''',
                            onErrorBuilder: (context, element, error) => Text('$element ${"error: "}$error'),
                            onLoadingBuilder: (context, element, loadingProgress) => const CircularProgressIndicator(),
                          ),
                        )
                      : const _PolicySkeleton(),
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

/// Plain (card-less) reading skeleton for the policy body.
class _PolicySkeleton extends StatelessWidget {
  const _PolicySkeleton();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < 4; i++) ...[
            DsSkeleton.line(width: 150, height: 16),
            const DsGap(DsSpace.md),
            DsSkeleton.line(width: double.infinity),
            const DsGap(DsSpace.sm),
            DsSkeleton.line(width: double.infinity),
            const DsGap(DsSpace.sm),
            DsSkeleton.line(width: 180),
            const DsGap(DsSpace.xxl),
          ],
        ],
      ),
    );
  }
}
