import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MaintenanceModeScreen extends StatelessWidget {
  const MaintenanceModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final tone = c.tone(DsTone.warning);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: DsResponsive(
          maxWidth: 520,
          padded: true,
          alignment: Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.xxxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: DsFadeSlideIn.stagger([
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(DsSpace.xxl),
                    decoration: BoxDecoration(color: tone.soft, shape: BoxShape.circle),
                    child: Image.asset('assets/images/maintenance.png', height: 200, width: 200),
                  ),
                ),
                const DsGap(DsSpace.xxl),
                Center(
                  child: DsBadge(label: 'Maintenance'.tr, tone: DsTone.warning, icon: Icons.build_circle_outlined),
                ),
                const DsGap(DsSpace.md),
                Text("We'll be back soon!".tr, textAlign: TextAlign.center, style: t.display),
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
    );
  }
}
