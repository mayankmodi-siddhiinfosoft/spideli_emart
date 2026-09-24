import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/refer_friend_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../themes/show_toast_dialog.dart';

/// Archetype **G — referral**: a full-bleed promo canvas with the reward as
/// the hero metric, the code on a glass card with copy, and share below.
class ReferFriendScreen extends StatelessWidget {
  const ReferFriendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ReferFriendController(),
      builder: (controller) {
        final loading = controller.isLoading.value;
        final referralCode = controller.referralModel.value.referralCode.toString();
        final reward = Constant.amountShow(amount: Constant.sectionConstantModel!.referralAmount, currency: RegionService.customerCurrency);
        return Scaffold(
          body: DsAsync(
            isLoading: loading,
            skeleton: const Center(child: DsBrandLoader()),
            builder: (_) => Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(image: DecorationImage(image: AssetImage("assets/images/refer_friend.png"), fit: BoxFit.fill)),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm),
                      child: DsBackButton(
                        color: Colors.white,
                        onPressed: () {
                          Get.back();
                        },
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.xxxl),
                        child: DsResponsive(
                          maxWidth: 520,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: DsFadeSlideIn.stagger([
                              Center(child: SvgPicture.asset("assets/images/referal_top.svg")),
                              const DsGap(DsSpace.md),
                              Text(
                                "Refer your friend and earn".tr,
                                textAlign: TextAlign.center,
                                style: DsTypography.title.copyWith(color: Colors.white.withValues(alpha: 0.92)),
                              ),
                              const DsGap(DsSpace.xs),
                              Text(
                                "$reward ${'Each🎉'.tr}",
                                textAlign: TextAlign.center,
                                style: DsTypography.metricLg.copyWith(color: Colors.white),
                              ),
                              const DsGap(DsSpace.xxxl),
                              Text(
                                "Invite Friends & Businesses".tr,
                                textAlign: TextAlign.center,
                                style: DsTypography.titleSm.copyWith(color: Colors.white),
                              ),
                              const DsGap(DsSpace.sm),
                              Text(
                                "${'Invite your friends to sign up with spideli using your code, and you’ll earn'.tr} $reward ${'after their Success the first order! 💸🍔'.tr}".tr,
                                textAlign: TextAlign.center,
                                style: DsTypography.body.copyWith(color: Colors.white.withValues(alpha: 0.88), fontSize: 15),
                              ),
                              const DsGap(DsSpace.huge),

                              /// Referral code
                              Center(
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 56),
                                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl, vertical: DsSpace.sm),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    borderRadius: DsRadius.brPill,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(referralCode, style: DsTypography.title.copyWith(color: Colors.white, letterSpacing: 2).tabular),
                                      const DsGap(DsSpace.md),
                                      DsIconButton(
                                        icon: Icons.copy_rounded,
                                        semanticLabel: "Copied".tr,
                                        color: Colors.white,
                                        size: 36,
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: controller.referralModel.value.referralCode.toString()));
                                          ShowToastDialog.showToast("Copied".tr);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const _WhiteDivider(),
                              Center(
                                child: DsButton.primary(
                                  label: "Share Code".tr,
                                  icon: Icons.ios_share_rounded,
                                  size: DsButtonSize.lg,
                                  onPressed: () async {
                                    await Share.share(
                                      "${"Hey there, thanks for choosing Foodie. Hope you love our product. If you do, share it with your friends using code".tr} ${controller.referralModel.value.referralCode.toString()} ${"and get".tr}${Constant.amountShow(amount: Constant.sectionConstantModel!.referralAmount.toString(), currency: RegionService.customerCurrency)} ${"when order completed".tr}",
                                    );
                                  },
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "or" divider drawn in white, for use over the promo artwork.
class _WhiteDivider extends StatelessWidget {
  const _WhiteDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.4)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.huge, vertical: DsSpace.xxl),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.xl),
            child: Text("or".tr, textAlign: TextAlign.center, style: DsTypography.labelSm.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          ),
          line,
        ],
      ),
    );
  }
}
