import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype L – status screen: a single centered, calm message with the
/// maintenance illustration. No action: the app comes back on its own.
class MaintenanceModeScreen extends StatelessWidget {
  const MaintenanceModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: DsSpace.xxxl),
            child: DsResponsive(
              maxWidth: 480,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: DsFadeSlideIn.stagger(
                  [
                    Container(
                      padding: const EdgeInsets.all(DsSpace.xl),
                      decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                      child: Image.asset(
                        'assets/images/maintenance.png',
                        height: 180,
                        width: 180,
                      ),
                    ),
                    const DsGap(DsSpace.xxl),
                    Text(
                      "We'll be back soon!".tr,
                      textAlign: TextAlign.center,
                      style: t.display,
                    ),
                    const DsGap(DsSpace.md),
                    Text(
                      "Sorry for the inconvenience but we're performing some maintenance at the moment. We'll be back online shortly!".tr,
                      textAlign: TextAlign.center,
                      style: t.bodyLg.copyWith(color: c.textSecondary),
                    ),
                    const DsGap(DsSpace.xxl),
                    DsCard.tinted(
                      tone: DsTone.info,
                      child: Row(
                        children: [
                          const DsIconWell(icon: Icons.build_outlined, tone: DsTone.info, size: 40),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Text(
                              "Maintenance in progress".tr,
                              style: t.bodyStrong,
                            ),
                          ),
                          DsSpinner(size: 18, color: c.info),
                        ],
                      ),
                    ),
                  ],
                  offset: const Offset(0, 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
