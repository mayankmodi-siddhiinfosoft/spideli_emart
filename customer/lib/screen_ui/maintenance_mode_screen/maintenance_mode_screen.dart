import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class MaintenanceModeScreen extends StatelessWidget {
  const MaintenanceModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Keeps the screen rebuilding on theme change (unchanged behaviour).
    Provider.of<ThemeController>(context);
    final c = context.dsColors;
    final t = context.dsText;
    final warn = c.tone(DsTone.warning);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: context.dsLayout.gutter, vertical: DsSpace.xxxl),
            child: DsResponsive(
              maxWidth: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: DsFadeSlideIn.stagger([
                  Container(
                    padding: const EdgeInsets.all(DsSpace.xxl),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: warn.soft),
                    child: Image.asset('assets/images/maintenance.png', height: 160, width: 160),
                  ),
                  const DsGap(DsSpace.xxl),
                  DsBadge(label: "Scheduled maintenance".tr, tone: DsTone.warning, icon: Icons.build_rounded),
                  const DsGap(DsSpace.md),
                  Text("We'll be back soon!".tr, textAlign: TextAlign.center, style: t.display.withColor(c.textPrimary)),
                  const DsGap(DsSpace.md),
                  Text(
                    "Sorry for the inconvenience but we're performing some maintenance at the moment. We'll be back online shortly!".tr,
                    textAlign: TextAlign.center,
                    style: t.bodyLg.withColor(c.textSecondary),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
