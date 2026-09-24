import 'package:spideliprovider/controller/splash_controller.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      init: SplashController(),
      builder: (controller) {
        return Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: DsGradients.brand(context)),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DsFadeSlideIn(
                      offset: const Offset(0, 8),
                      child: Container(
                        padding: const EdgeInsets.all(DsSpace.xxl),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: DsRadius.brXxl,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: Image.asset("assets/images/app_logo.png", width: 200),
                      ),
                    ),
                    const DsGap(DsSpace.huge),
                    const DsBrandLoader(size: 44, color: Colors.white),
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
