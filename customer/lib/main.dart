import 'package:customer/screen_ui/splash_screen/splash_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/localization_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/easy_loading_config.dart';
import 'package:customer/utils/preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'controllers/global_setting_controller.dart';
import 'controllers/theme_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseApp firebaseApp = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (currentEnv == FirebaseEnv.defaultDb) {
    FireStoreUtils.instance.init(firebaseApp);
  } else {
    FireStoreUtils.instance.init(firebaseApp, databaseId: 'staging'); // pass databaseId if named DB
  }

  await Preferences.initPref();

  Get.put(ThemeController());
  await configEasyLoading();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final themeController = Get.find<ThemeController>();

  @override
  Widget build(BuildContext context) {
    Get.put(ThemeController());
    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return DsBrandTheme(child: SafeArea(bottom: true, top: false, child: EasyLoading.init()(context, child)));
        },
        translations: LocalizationService(),
        locale: LocalizationService.locale,
        fallbackLocale: LocalizationService.locale,
        themeMode: themeController.themeMode,
        // Design-system themes (lib/themes/ds). The brand color is read from
        // AppThemeData.primary300 (app color, then the active service
        // section's color) and refreshed by DsBrandTheme on navigation.
        theme: DsTheme.light(),
        darkTheme: DsTheme.dark(),
        // App-wide page transition (shared-axis on Android, native swipe on iOS).
        customTransition: DsPageTransition(),
        transitionDuration: DsMotion.page,
        navigatorObservers: [DsBrandTheme.observer],
        home: GetBuilder<GlobalSettingController>(
          init: GlobalSettingController(),
          builder: (context) {
            return const SplashScreen();
          },
        ),
      ),
    );
  }
}
