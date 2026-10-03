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
    // Before the plugins register: firebase_messaging keeps this delegate and
    // forwards to it, and FlutterAppDelegate hands willPresent / didReceive on
    // to flutter_local_notifications. Without it a local notification shown
    // in the foreground never appears on iOS and its tap is lost.
    UNUserNotificationCenter.current().delegate = self
    GeneratedPluginRegistrant.register(with: self)
    // The FCM token cannot exist on iOS until APNs has given the device a
    // token. firebase_messaging asks too; asking twice is harmless.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
