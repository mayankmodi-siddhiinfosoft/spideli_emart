import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/app/subscription_plan_screen/subscription_plan_screen.dart';

/// Shown when the store's plan does not include this app: a centered
/// "locked" status with one clear action (upgrade).
class AppNotAccessScreen extends StatelessWidget {
  const AppNotAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final tone = c.tone(DsTone.warning);
    return Scaffold(
      backgroundColor: c.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [tone.soft, c.background]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl, vertical: DsSpace.xxxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: DsFadeSlideIn.stagger([
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          padding: const EdgeInsets.all(DsSpace.xxxl),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.surface,
                            boxShadow: DsShadows.md(context),
                            border: Border.all(color: tone.main.withValues(alpha: 0.25), width: 1.5),
                          ),
                          child: SvgPicture.asset("assets/icons/ic_payment_card.svg"),
                        ),
                        PositionedDirectional(
                          end: 0,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(DsSpace.sm),
                            decoration: BoxDecoration(color: tone.main, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 3)),
                            child: Icon(Icons.lock_rounded, size: 18, color: tone.onMain),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.xxl),
                      child: Semantics(header: true, child: Text("Access denied".tr, textAlign: TextAlign.center, style: t.display)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.md),
                      child: Text(
                        "Your current subscription plan doesn't include access to this app. Upgrade to get access now".tr,
                        textAlign: TextAlign.center,
                        style: t.bodyLg.copyWith(color: c.textSecondary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.xxxl),
                      child: DsButton.primary(
                        label: "Upgrade Plan".tr,
                        icon: Icons.workspace_premium_outlined,
                        size: DsButtonSize.lg,
                        expand: true,
                        onPressed: () async {
                          Get.to(const SubscriptionPlanScreen());
                        },
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
