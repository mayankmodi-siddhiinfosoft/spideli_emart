import UIKit
import Flutter
import GoogleMaps
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
   GMSServices.provideAPIKey("AIzaSyBhZufLHi10nF6KpZtqXlmJ84QMStjBmRo")
    // flutter_local_notifications: foreground presentation and taps of local
    // notifications arrive through this delegate. FlutterAppDelegate forwards
    // every UNUserNotificationCenter call to the plugins, so firebase_messaging
    // keeps receiving its own (it does not replace a delegate that forwards).
    UNUserNotificationCenter.current().delegate = self
    GeneratedPluginRegistrant.register(with: self)
    // registerForRemoteNotifications is not called here: firebase_messaging
    // calls it as soon as Dart has configured Firebase (main.dart), and keeps
    // an APNs token that arrives earlier until then. Dart then waits for that
    // token before asking FCM for its own (NotificationService.getToken).
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
