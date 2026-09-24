import 'package:spideliworker/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Status screen (archetype I): the maintenance illustration in a warning
/// halo, a clear headline and the explanation, centred and width-capped.
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
            padding: EdgeInsets.all(context.dsLayout.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: DsFadeSlideIn.stagger([
                  Container(
                    padding: const EdgeInsets.all(DsSpace.xxl),
                    decoration: BoxDecoration(color: c.warningSoft, shape: BoxShape.circle),
                    child: Image.asset(
                      'assets/images/maintenance.png',
                      height: 180,
                      width: 180,
                    ),
                  ),
                  const DsGap(DsSpace.xxl),
                  DsBadge(label: 'Maintenance'.tr, tone: DsTone.warning, icon: Icons.construction_rounded),
                  const DsGap(DsSpace.md),
                  Semantics(
                    header: true,
                    child: Text(
                      "We'll be back soon!".tr,
                      textAlign: TextAlign.center,
                      style: t.headline,
                    ),
                  ),
                  const DsGap(DsSpace.sm),
                  Text(
                    "Sorry for the inconvenience but we're performing some maintenance at the moment. We'll be back online shortly!".tr,
                    textAlign: TextAlign.center,
                    style: t.bodySecondary,
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
