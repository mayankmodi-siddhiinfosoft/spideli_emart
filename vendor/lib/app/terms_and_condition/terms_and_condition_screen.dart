import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/themes/ds/ds.dart';

class TermsAndConditionScreen extends StatelessWidget {
  final String? type;

  const TermsAndConditionScreen({super.key, this.type});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;
    final isPrivacy = type == "privacy";
    final title = type == "privacy" ? "Privacy Policy".tr : "Terms & Conditions".tr;
    return DsScaffold(
      title: title,
      onBack: () {
        Get.back();
      },
      maxContentWidth: DsLayout.contentMax,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: DsFadeSlideIn.stagger([
            // Document header
            DsCard.tinted(
              tone: isPrivacy ? DsTone.info : DsTone.brand,
              child: Row(
                children: [
                  DsIconWell(icon: isPrivacy ? Icons.privacy_tip_outlined : Icons.gavel_rounded, tone: isPrivacy ? DsTone.info : DsTone.brand, size: 52),
                  const DsGap(DsSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Legal'.tr, style: t.overline.withColor(c.textMuted)),
                        const DsGap(DsSpace.xxs),
                        Text(title, style: t.title.withColor(c.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const DsGap(DsSpace.lg),
            DsCard(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.lg),
              child: Html(
                shrinkWrap: true,
                data: type == "privacy" ? Constant.privacyPolicy : Constant.termsAndConditions,
                style: {
                  "body": Style(color: c.textPrimary, fontSize: FontSize(15), lineHeight: const LineHeight(1.6)),
                  "h1": Style(color: c.textPrimary),
                  "h2": Style(color: c.textPrimary),
                  "h3": Style(color: c.textPrimary),
                  "a": Style(color: c.brandStrong),
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
