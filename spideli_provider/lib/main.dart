import 'dart:developer';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/global_setting_conroller.dart';
import 'package:spideliprovider/firebase_options.dart';
import 'package:spideliprovider/model/mail_setting.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/localization_service.dart';
import 'package:spideliprovider/services/notification_service.dart';
import 'package:spideliprovider/services/preferences.dart';
import 'package:spideliprovider/services/send_notification.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/themes/easy_loading_config.dart';
import 'package:spideliprovider/ui/splash_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
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
  // The one background handler (top-level, entry-point; it starts Firebase in
  // its own isolate). Registered before runApp, as firebase_messaging requires.
  FirebaseMessaging.onBackgroundMessage(firebaseMessageBackgroundHandle);
  // Diagnostics only: compiled in only with --dart-define=PUSH_DEBUG=true
  // (end-to-end push tests on an emulator); release builds never log it.
  if (const bool.fromEnvironment('PUSH_DEBUG')) {
    FirebaseMessaging.instance.onTokenRefresh.listen((t) => debugPrint('PUSH_DEBUG token=$t'));
    FirebaseMessaging.instance.getToken().then((t) => debugPrint('PUSH_DEBUG token=$t'), onError: (Object e) => debugPrint('PUSH_DEBUG token error: $e'));
  }
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  // The Android channel must exist before the first push arrives, or Android
  // posts it on a silent fallback channel. No permission is needed for this.
  await NotificationService.createAndroidChannels();

  // The notification permission is NOT requested here: awaiting it before
  // runApp left the first screen blank behind the system dialog. It is asked
  // once, after the first frame, by NotificationService.initInfo (see
  // MyAppState.initState).
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
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
      // The single notification-permission request of this launch.
      await notificationService.initInfo();
      // Store the FCM token on the user document at launch and on every
      // refresh, so this app can actually be reached by chat and order pushes.
      await NotificationService.syncTokenToUserDoc();
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
    // First and on its own: a missing field in any of the documents below threw
    // and skipped the rest, which left the push settings empty and every push
    // this app sends failing silently.
    await SendNotification.loadNotificationSettings();
    try {
      await FireStoreUtils.firestore.collection(Setting).doc('vendor').get().then((value) {
        isSubscriptionModelApplied = value.data()!['subscription_model'];
      });

      /// Wait for Firebase to initialize and set `_initialized` state to true
      await FireStoreUtils.firestore.collection(Setting).doc("ContactUs").get().then((value) {
        adminEmail = value.data()!['Email'].toString();
      });
      await FireStoreUtils.firestore.collection(Setting).doc("Version").get().then((value) {
        appVersion = value.data()!['app_version'].toString();
        providerUrl = value.data()!['providerUrl'].toString();
      });
      await FireStoreUtils.firestore.collection(Setting).doc("googleMapKey").get().then((value) {
        GOOGLE_API_KEY = value.data()!['key'].toString();
      });

      await FireStoreUtils.firestore.collection(Setting).doc("globalSettings").get().then((value) {
        AppColors.colorPrimary = Color(int.parse(value.data()!['provider_app_color'].toString().replaceFirst("#", "0xff")));
        // Re-theme Material widgets with the runtime brand color.
        DsBrandTheme.refresh();
      });

      await FireStoreUtils.firestore.collection(Setting).doc("DriverNearBy").get().then((value) {
        selectedMapType = value.data()!['selectedMapType'].toString();
      });

      await FireStoreUtils.firestore.collection(Setting).doc("emailSetting").get().then((value) {
        if (value.exists) {
          mailSettings = MailSettings.fromJson(value.data()!);
        }
      });
    } catch (e) {
      log("$e==========ERROR");
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
          final isDark = themeChangeProvider.darkTheme == 0
              ? true
              : themeChangeProvider.darkTheme == 1
                  ? false
                  : themeChangeProvider.getSystemThem();
          return GetMaterialApp(
              navigatorKey: navigatorKey,
              title: 'spideli Provider',
              debugShowCheckedModeBanner: false,
              // Design-system theme (lib/themes/ds). Brightness follows
              // DarkThemeProvider; the brand color is read from
              // AppColors.colorPrimary and refreshed by DsBrandTheme below.
              theme: DsTheme.build(isDark),
              // App-wide page transition (shared-axis on Android, native swipe on iOS).
              customTransition: DsPageTransition(),
              transitionDuration: DsMotion.page,
              navigatorObservers: [DsBrandTheme.observer],
              locale: LocalizationService.locale,
              fallbackLocale: LocalizationService.locale,
              translations: LocalizationService(),
              builder: (context, child) {
                configEasyLoading(isDark);
                return DsBrandTheme(child: EasyLoading.init()(context, child));
              },
              home: GetBuilder<GlobalSettingController>(
                  init: GlobalSettingController(),
                  builder: (context) {
                    return const SplashScreen();
                  }));
        },
      ),
    );
  }
}
