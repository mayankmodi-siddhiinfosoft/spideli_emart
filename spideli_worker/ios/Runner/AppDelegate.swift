import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The app delegate is the notification-center delegate and forwards
    // "will present" / "did receive" to every plugin (firebase_messaging and
    // flutter_local_notifications), so a push shows in the foreground and a
    // tapped notification reaches Dart.
    UNUserNotificationCenter.current().delegate = self
    // Ask APNs for this device's token at launch: FCM has no token for an
    // iPhone until APNs has given one. Needs no permission and shows nothing.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
