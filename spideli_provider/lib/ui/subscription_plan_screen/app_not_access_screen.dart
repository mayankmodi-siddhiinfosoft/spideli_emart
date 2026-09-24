import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

/// Access blocked (archetype O – status). A single centred danger-toned state:
/// halo illustration, one sentence, one upgrade action in a sticky bar.
class AppNotAccessScreen extends StatelessWidget {
  const AppNotAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    return DsScaffold(
      maxContentWidth: DsLayout.contentMax,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
          child: DsFadeSlideIn(
            child: DsEmptyState(
              tone: DsTone.danger,
              illustration: SvgPicture.asset("assets/icons/ic_payment_card.svg", width: 56, height: 56, colorFilter: ColorFilter.mode(c.dangerStrong, BlendMode.srcIn)),
              title: "Access denied".tr,
              message: "Your current plan doesn’t include this feature. Upgrade to get access now.".tr,
            ),
          ),
        ),
      ),
      bottomBar: DsStickyBar(
        child: DsButton.primary(
          label: "Upgrade Plan".tr,
          icon: Icons.workspace_premium_outlined,
          expand: true,
          onPressed: () async {
            Get.offAll(SubscriptionPlanScreen(), arguments: {"isShowAppBar": false});
          },
        ),
      ),
    );
  }
}
