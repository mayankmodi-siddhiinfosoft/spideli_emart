import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';

/// Maintenance status page: a warm, centered illustration with a status pill
/// and the message. No actions (the app is intentionally unavailable).
class MaintenanceModeScreen extends StatelessWidget {
  const MaintenanceModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final tone = c.tone(DsTone.warning);
    return Scaffold(
      backgroundColor: c.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.background, tone.soft]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl, vertical: DsSpace.xxxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: DsFadeSlideIn.stagger([
                    Container(
                      width: 240,
                      height: 240,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [tone.soft, tone.soft.withValues(alpha: 0)], stops: const [0.62, 1]),
                      ),
                      child: Image.asset('assets/images/maintenance.png', height: 200, width: 200),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.lg),
                      child: DsStatusChip(label: "Maintenance".tr, tone: DsTone.warning, pulse: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.lg),
                      child: Semantics(header: true, child: Text("We'll be back soon!".tr, textAlign: TextAlign.center, style: t.display)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.md),
                      child: Text(
                        "Sorry for the inconvenience but we're performing some maintenance at the moment. We'll be back online shortly!".tr,
                        textAlign: TextAlign.center,
                        style: t.bodyLg.copyWith(color: c.textSecondary),
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
