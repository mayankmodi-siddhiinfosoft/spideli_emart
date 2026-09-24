import 'package:customer/constant/collection_name.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_html/flutter_html.dart';

/// Archetype **H — legal document**: a readable long-form page. The rich text
/// sits on a single card capped at reading width, with a shimmer paragraph
/// skeleton while the document loads.
class TermsAndConditionScreen extends StatefulWidget {
  final String? type;

  const TermsAndConditionScreen({super.key, this.type});

  @override
  State<TermsAndConditionScreen> createState() => _TermsAndConditionScreenState();
}

class _TermsAndConditionScreenState extends State<TermsAndConditionScreen> {
  String _content = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    try {
      if (widget.type == "privacy") {
        final doc = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("privacyPolicy").get();
        if (doc.exists && doc.data() != null) {
          _content = doc.data()?["privacy_policy"] ?? "";
        }
      } else {
        final doc = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc("termsAndConditions").get();
        if (doc.exists && doc.data() != null) {
          _content = doc.data()?["terms_and_condition"] ?? "";
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final isPrivacy = widget.type == "privacy";
    final title = isPrivacy ? "Privacy Policy".tr : "Terms & Conditions".tr;
    return DsScaffold(
      maxContentWidth: DsLayout.contentMax,
      appBar: DsAppBar(
        title: title,
        onBack: () {
          Get.back();
        },
      ),
      body: DsAsync(
        isLoading: _isLoading,
        skeleton: const _DocumentSkeleton(),
        isEmpty: _content.trim().isEmpty,
        empty: DsEmptyState(icon: Icons.description_outlined, title: title, message: "Nothing to show here yet.".tr),
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
          child: DsFadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DsIconWell(icon: isPrivacy ? Icons.privacy_tip_outlined : Icons.gavel_rounded, tone: DsTone.brand, size: 44),
                    const DsGap(DsSpace.md),
                    Expanded(child: Text(title, style: t.headline)),
                  ],
                ),
                const DsGap(DsSpace.lg),
                DsCard(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                  child: Html(
                    shrinkWrap: true,
                    data: _content,
                    style: {
                      "body": Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        color: c.textSecondary,
                        fontFamily: DsTypography.family,
                        fontSize: FontSize(15),
                        lineHeight: LineHeight.number(1.6),
                      ),
                      "h1": Style(color: c.textPrimary, fontFamily: DsTypography.family, fontSize: FontSize(20), fontWeight: FontWeight.w700),
                      "h2": Style(color: c.textPrimary, fontFamily: DsTypography.family, fontSize: FontSize(18), fontWeight: FontWeight.w700),
                      "h3": Style(color: c.textPrimary, fontFamily: DsTypography.family, fontSize: FontSize(16), fontWeight: FontWeight.w600),
                      "strong": Style(color: c.textPrimary),
                      "b": Style(color: c.textPrimary),
                      "a": Style(color: c.brandStrong),
                      "li": Style(color: c.textSecondary),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentSkeleton extends StatelessWidget {
  const _DocumentSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DsSpace.lg),
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSkeleton.line(width: 180, height: 20),
            const DsGap(DsSpace.xl),
            for (var block = 0; block < 4; block++) ...[
              DsSkeleton.line(width: 140, height: 14),
              const DsGap(DsSpace.md),
              SizedBox(width: double.infinity, child: DsSkeleton.line()),
              const DsGap(DsSpace.sm),
              SizedBox(width: double.infinity, child: DsSkeleton.line()),
              const DsGap(DsSpace.sm),
              DsSkeleton.line(width: 220),
              const DsGap(DsSpace.xxl),
            ],
          ],
        ),
      ),
    );
  }
}
