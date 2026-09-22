import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:vendor/app/splash_screen.dart';
import 'package:vendor/controller/global_setting_controller.dart';
import 'package:vendor/firebase_options.dart';
import 'package:vendor/service/audio_player_service.dart';
import 'package:vendor/service/localization_service.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/easy_loading_config.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseApp firebaseApp = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (currentEnv == FirebaseEnv.defaultDb) {
    FireStoreUtils.instance.init(firebaseApp);
  } else {
    FireStoreUtils.instance.init(firebaseApp, databaseId: 'staging'); // pass databaseId if named DB
  }
  await FirebaseAppCheck.instance.activate(webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'), androidProvider: AndroidProvider.playIntegrity, appleProvider: AppleProvider.appAttest);
  await Preferences.initPref();
  Get.put(ThemeController());
  await configEasyLoading();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final themeController = Get.find<ThemeController>();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.paused) {
      AudioPlayerService.initAudio();
    }
  }

  @override
  Widget build(BuildContext context) {
    Get.put(ThemeController());
    return Obx(
      () => GetMaterialApp(
        title: 'spideli Store'.tr,
        debugShowCheckedModeBanner: false,
        themeMode: themeController.themeMode,
        // Design-system themes (lib/themes/ds). Brand color is read from
        // AppThemeData.primary300 and refreshed by DsBrandTheme below.
        theme: DsTheme.light(),
        darkTheme: DsTheme.dark(),
        // App-wide page transition (shared-axis on Android, native swipe on iOS).
        customTransition: DsPageTransition(),
        transitionDuration: DsMotion.page,
        navigatorObservers: [DsBrandTheme.observer],
        localizationsDelegates: const [CountryLocalizations.delegate],
        locale: LocalizationService.locale,
        fallbackLocale: LocalizationService.locale,
        translations: LocalizationService(),
        builder: (context, child) {
          return DsBrandTheme(child: SafeArea(bottom: true, top: false, child: EasyLoading.init()(context, child)));
        },
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
