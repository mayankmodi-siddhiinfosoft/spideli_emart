import 'package:spideliworker/controller/terms_condition_controller.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Reading page: a width-capped document card holding the HTML from settings,
/// with a text skeleton while it loads.
class TermsAndCondition extends StatelessWidget {
  const TermsAndCondition({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX<TermsConditionController>(
        init: TermsConditionController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;
          final l = context.dsLayout;
          final bool hasContent = controller.termsAndCondition.isNotEmpty;
          return DsScaffold(
            title: 'Terms & condition',
            onBack: () {
              Get.back();
            },
            maxContentWidth: null,
            body: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.huge),
              child: DsResponsive(
                maxWidth: DsLayout.contentMax,
                child: DsAsync(
                  isLoading: !hasContent,
                  skeleton: const _DocumentSkeleton(),
                  builder: (_) => DsFadeSlideIn(
                    child: DsCard.outlined(
                      padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.xl, DsSpace.xl, DsSpace.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const DsIconWell(icon: Icons.gavel_rounded, size: 40),
                              const DsGap(DsSpace.md),
                              Expanded(child: Text('Terms & condition', style: t.titleSm)),
                            ],
                          ),
                          const DsGap(DsSpace.lg),
                          Divider(height: 1, color: c.divider),
                          const DsGap(DsSpace.lg),
                          DefaultTextStyle.merge(
                            style: t.body.copyWith(height: 1.6),
                            child: HtmlWidget(
                              '''
                  ${controller.termsAndCondition.value}
                   ''',
                              textStyle: t.body.copyWith(height: 1.6),
                              onErrorBuilder: (context, element, error) => Text('$element ${"error: "}$error'),
                              onLoadingBuilder: (context, element, loadingProgress) => const Center(child: DsSpinner()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
  }
}

class _DocumentSkeleton extends StatelessWidget {
  const _DocumentSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [DsSkeleton.box(width: 40, height: 40), const DsGap(DsSpace.md), DsSkeleton.line(width: 160, height: 16)]),
          const DsGap(DsSpace.xxl),
          for (int i = 0; i < 14; i++) ...[
            DsSkeleton.line(width: i % 4 == 3 ? 180 : double.infinity),
            const DsGap(DsSpace.md),
          ],
        ],
      ),
    );
  }
}
