import 'dart:developer';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/controller/global_setting_conroller.dart';
import 'package:spideliworker/firebase_options.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/localization_service.dart';
import 'package:spideliworker/services/notification_service.dart';
import 'package:spideliworker/services/preferences.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/themes/easy_loading_config.dart';
import 'package:spideliworker/ui/splash_screen/splash_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Preferences.initPref();
  FirebaseApp firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (currentEnv == FirebaseEnv.defaultDb) {
    FireStoreUtils.instance.init(firebaseApp);
  } else {
    FireStoreUtils.instance.init(firebaseApp, databaseId: 'staging'); // pass databaseId if named DB
  }

  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
  );
  initializeDateFormatting();
  // The one background handler: top-level, `vm:entry-point` (release builds
  // tree-shook the old unannotated one), and it initializes Firebase itself.
  FirebaseMessaging.onBackgroundMessage(firebaseMessageBackgroundHandle);
  // Diagnostics only: compiled in only with --dart-define=PUSH_DEBUG=true
  // (end-to-end push tests on an emulator); release builds never log it.
  if (const bool.fromEnvironment('PUSH_DEBUG')) {
    FirebaseMessaging.instance.onTokenRefresh.listen((t) => debugPrint('PUSH_DEBUG token=$t'));
    FirebaseMessaging.instance.getToken().then((t) => debugPrint('PUSH_DEBUG token=$t'), onError: (Object e) => debugPrint('PUSH_DEBUG token error: $e'));
  }
  // Before runApp, so a push that arrives right after the first launch
  // already has its Android channel (and iOS shows pushes in the foreground).
  await NotificationService.prepareBeforeRunApp();

  // The notification permission is NOT requested here: awaiting it before
  // runApp left the first screen blank behind the system dialog. It is asked
  // once, after the first frame, by NotificationService.initInfo (see
  // MyAppState.initState).
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static User? currentUser;
  DarkThemeProvider themeChangeProvider = DarkThemeProvider();
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  NotificationService notificationService = NotificationService();

  Future<void> notificationInit() async {
    try {
      // The single notification-permission request of this launch, and the
      // FCM token on the worker's document (at launch and on every refresh).
      // In parallel: the token does not need the permission, and on iOS it
      // must not wait for the user to answer the dialog.
      await Future.wait<void>([
        notificationService.initInfo(),
        NotificationService.syncTokenToUserDoc(),
      ]);
    } catch (e) {
      log("Notification init failed: $e");
    }
  }

  @override
  void initState() {
    // After the first frame, so the system permission dialog never sits on
    // top of a blank, not-yet-drawn first screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => notificationInit());
    initializeFlutterFire();
    getCurrentAppTheme();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  void initializeFlutterFire() async {
    // First and on its own: a failure in the reads below must not leave the
    // push settings unloaded (every push would then fail).
    try {
      await FireStoreUtils.firestore.collection(Setting).doc("notification_setting").get().then((value) {
        // Never log this document: `serviceJson` is a tokenised download URL
        // of a service-account key file.
        final Map<String, dynamic> data = value.data() ?? {};
        senderId = (data['senderId'] ?? '').toString();
        jsonNotificationFileURL = (data['serviceJson'] ?? '').toString();
        // Always assigned, so clearing the field switches back to the legacy
        // path (SERVER-PUSH-CONTRACT.md 1).
        serverPushUrl = (data['serverPushUrl'] ?? '').toString().trim();
      });
    } catch (e) {
      log("notification settings not loaded: $e");
    }
    try {
      /// Wait for Firebase to initialize and set `_initialized` state to true

      await FireStoreUtils.firestore.collection(Setting).doc("Version").get().then((value) {
        appVersion = value.data()!['app_version'].toString();
      });
      await FireStoreUtils.firestore.collection(Setting).doc("googleMapKey").get().then((value) {
        GOOGLE_API_KEY = value.data()!['key'].toString();
      });

      await FireStoreUtils.firestore.collection(Setting).doc("globalSettings").get().then((value) {
        AppColors.colorPrimary = Color(int.parse(value.data()!['worker_app_color'].toString().replaceFirst("#", "0xff")));
        // Re-theme Material widgets with the brand color that just loaded.
        DsBrandTheme.refresh();
      });
    } catch (e) {
      setState(() {
        log("$e==========ERROR");
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    getCurrentAppTheme();
  }

  void getCurrentAppTheme() async {
    themeChangeProvider.darkTheme = await themeChangeProvider.darkThemePreference.getTheme();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        return themeChangeProvider;
      },
      child: Consumer<DarkThemeProvider>(
        builder: (context, value, child) {
          final bool isDarkTheme = themeChangeProvider.darkTheme == 0
              ? true
              : themeChangeProvider.darkTheme == 1
                  ? false
                  : themeChangeProvider.getSystemThem();
          applyEasyLoadingStyle(isDarkTheme);
          return GetMaterialApp(
            navigatorKey: navigatorKey,
            title: 'spideli Worker',
            debugShowCheckedModeBanner: false,
            // Design-system theme (lib/themes/ds). Brightness follows
            // DarkThemeProvider exactly as before; the brand color is read
            // from AppColors.colorPrimary and refreshed by DsBrandTheme.
            theme: DsTheme.build(isDarkTheme),
            // App-wide page transition (shared-axis on Android, native
            // swipe-back on iOS).
            customTransition: DsPageTransition(),
            transitionDuration: DsMotion.page,
            navigatorObservers: [DsBrandTheme.observer],
            locale: LocalizationService.locale,
            fallbackLocale: LocalizationService.locale,
            translations: LocalizationService(),
            builder: (context, child) => DsBrandTheme(child: EasyLoading.init()(context, child)),
            home: GetBuilder<GlobalSettingController>(
              init: GlobalSettingController(),
              builder: (context) {
                return const SplashScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
