import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Location-permission-denied dialog. Visuals follow the design system;
/// the actions (close / open app settings) are unchanged.
class PermissionDialog extends StatelessWidget {
  const PermissionDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to the theme provider so the dialog rebuilds on theme changes.
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: DsRadius.brXl, side: c.isDark ? BorderSide(color: c.border) : BorderSide.none),
      backgroundColor: c.surfaceRaised,
      insetPadding: const EdgeInsets.all(DsSpace.xxl),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DsSpace.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const DsIconWell(icon: Icons.add_location_alt_rounded, tone: DsTone.warning, size: 72, circle: true),
            const SizedBox(height: DsSpace.xl),
            Text(
              'You denied location permission forever. Please allow location permission from your app settings.'.tr,
              textAlign: TextAlign.center,
              style: t.bodyLg.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DsSpace.xxl),
            Row(children: [
              Expanded(
                child: DsButton.secondary(
                  label: 'close'.tr,
                  expand: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: DsSpace.md),
              Expanded(
                child: DsButton.primary(
                  label: 'settings'.tr,
                  icon: Icons.settings_outlined,
                  expand: true,
                  onPressed: () async {
                    await Geolocator.openAppSettings();
                    Get.back();
                  },
                ),
              )
            ]),
          ]),
        ),
      ),
    );
  }
}
