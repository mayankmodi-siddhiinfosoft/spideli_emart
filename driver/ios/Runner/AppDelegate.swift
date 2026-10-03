import Flutter
import UIKit
import GoogleMaps
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyBhZufLHi10nF6KpZtqXlmJ84QMStjBmRo")
    GeneratedPluginRegistrant.register(with: self)
    // FlutterAppDelegate forwards notification-center callbacks to every
    // plugin (firebase_messaging AND flutter_local_notifications). Without
    // this, firebase_messaging made itself the only delegate, so a local
    // notification (job queue, assignment) was never handed to
    // flutter_local_notifications: its taps did nothing.
    UNUserNotificationCenter.current().delegate = self
    // Ask APNs for this device's token at every launch (firebase_messaging
    // needs it before getToken() can return an FCM token on iOS).
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
