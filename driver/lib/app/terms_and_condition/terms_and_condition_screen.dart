import 'package:driver/constant/constant.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';

/// Archetype K – legal document: a readable, centered "paper" card with a
/// small document header. Light and dark aware (the HTML inherits DS colors).
class TermsAndConditionScreen extends StatelessWidget {
  final String? type;

  const TermsAndConditionScreen({super.key, this.type});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final isPrivacy = type == "privacy";
    final data = isPrivacy ? Constant.privacyPolicy : Constant.termsAndConditions;

    return Scaffold(
      backgroundColor: c.background,
      body: data.trim().isEmpty
          ? Center(
              child: DsEmptyState(
                icon: Icons.description_outlined,
                title: isPrivacy ? "Privacy Policy".tr : "Terms and Conditions".tr,
                message: "Not available right now.".tr,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
              child: DsResponsive(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: DsFadeSlideIn.stagger([
                    Row(
                      children: [
                        DsIconWell(
                          icon: isPrivacy ? Icons.shield_outlined : Icons.gavel_rounded,
                          tone: DsTone.brand,
                          size: 44,
                        ),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPrivacy ? "Privacy Policy".tr : "Terms and Conditions".tr,
                                style: t.title,
                              ),
                              Text(
                                "Please read carefully".tr,
                                style: t.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const DsGap(DsSpace.lg),
                    DsCard(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
                      child: Html(
                        shrinkWrap: true,
                        data: data,
                        style: {
                          "body": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            color: c.textSecondary,
                            fontSize: FontSize(15),
                            lineHeight: const LineHeight(1.5),
                            fontFamily: t.body.fontFamily,
                          ),
                          "h1": Style(color: c.textPrimary, fontSize: FontSize(20)),
                          "h2": Style(color: c.textPrimary, fontSize: FontSize(18)),
                          "h3": Style(color: c.textPrimary, fontSize: FontSize(16)),
                          "strong": Style(color: c.textPrimary),
                          "a": Style(color: c.brandStrong),
                        },
                      ),
                    ),
                  ], offset: const Offset(0, 18)),
                ),
              ),
            ),
    );
  }
}
