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
    setUpSecureScreen()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Finance screens showing sensitive data (card details) call
  // spideli/secure_screen: Android sets FLAG_SECURE; here the app is hidden
  // behind a plain cover while it is in the app switcher.
  private var secureScreen = false
  private var privacyCover: UIView?

  private func setUpSecureScreen() {
    guard let registrar = self.registrar(forPlugin: "SpideliSecureScreen") else { return }
    let channel = FlutterMethodChannel(name: "spideli/secure_screen", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "enable":
        self?.secureScreen = true
        result(true)
      case "disable":
        self?.secureScreen = false
        self?.hidePrivacyCover()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    NotificationCenter.default.addObserver(self, selector: #selector(showPrivacyCover), name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(hidePrivacyCover), name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  @objc private func showPrivacyCover() {
    guard secureScreen, privacyCover == nil else { return }
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
    guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return }
    let cover = UIView(frame: window.bounds)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // The Finance navy (FinColors.navy).
    cover.backgroundColor = UIColor(red: 11 / 255, green: 42 / 255, blue: 74 / 255, alpha: 1)
    window.addSubview(cover)
    privacyCover = cover
  }

  @objc private func hidePrivacyCover() {
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }
}
