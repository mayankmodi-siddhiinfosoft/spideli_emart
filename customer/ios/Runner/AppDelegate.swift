import Flutter
import UIKit
import UserNotifications
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyBhZufLHi10nF6KpZtqXlmJ84QMStjBmRo")
    // Before the plugins register: FlutterAppDelegate forwards notification
    // presentation and taps to every plugin, so firebase_messaging (remote
    // pushes) and flutter_local_notifications (local ones) both get them.
    // firebase_messaging keeps this delegate instead of replacing it.
    // registerForRemoteNotifications is not called here: firebase_messaging
    // calls it once Firebase is configured (earlier, the APNs token could
    // reach Firebase Messaging before Firebase.initializeApp).
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
