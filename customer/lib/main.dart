import 'package:customer/screen_ui/splash_screen/splash_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/localization_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/easy_loading_config.dart';
import 'package:customer/utils/notification_service.dart';
import 'package:customer/utils/preferences.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino_ui;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'controllers/global_setting_controller.dart';
import 'controllers/theme_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseApp firebaseApp = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Push: one top-level background handler, registered before runApp, and the
  // Android channel created before any push can arrive.
  FirebaseMessaging.onBackgroundMessage(firebaseMessageBackgroundHandle);
  await NotificationService.createChannels();

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

/// Localization delegates the app adds on top of the ones `MaterialApp`
/// installs by itself.
///
/// Packages built on the standalone `material_ui` / `cupertino_ui` copies of
/// the Material and Cupertino libraries (bottom_picker 5, pin_code_fields 10+,
/// ...) look their localizations up by **their own** `MaterialLocalizations` /
/// `CupertinoLocalizations` types, which a `package:flutter/material.dart`
/// `MaterialApp` never registers. Without these, `showModalBottomSheet` threw
/// "No MaterialLocalizations found" and the schedule-time picker never
/// appeared anywhere in the app.
const List<LocalizationsDelegate<Object>> appLocalizationsDelegates = [
  material_ui.DefaultMaterialLocalizations.delegate,
  cupertino_ui.DefaultCupertinoLocalizations.delegate,
];

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
        localizationsDelegates: appLocalizationsDelegates,
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
