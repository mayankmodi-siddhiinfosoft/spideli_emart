import Flutter
import UIKit
import GoogleMaps
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// `spideli/order_ringtone` (OrderRingtoneSounds below).
  private var orderRingtoneChannel: FlutterMethodChannel?

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
    if let registrar = self.registrar(forPlugin: "SpideliOrderRingtone") {
      orderRingtoneChannel = OrderRingtoneSounds.register(messenger: registrar.messenger())
    }
    // The FCM token cannot exist on iOS until APNs has given the device a
    // token. firebase_messaging asks too; asking twice is harmless.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// A remote push presented in the foreground keeps its banner; it loses
  /// only its sound when Dart says the in-app alert is already ringing the
  /// same order sound (no double sound). Everything else is unchanged.
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    guard userInfo["gcm.message_id"] != nil, let channel = orderRingtoneChannel else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
      return
    }
    super.userNotificationCenter(center, willPresent: notification) { options in
      OrderRingtoneSounds.present(options: options, userInfo: userInfo, channel: channel, completion: completionHandler)
    }
  }
}

// MARK: - Order ringtone (.claude/PUSH-CHANNELS.md, "Order ringtone")

/// The admin's order ringtone (`globalSettings.order_ringtone_url`, downloaded
/// by the Dart `OrderRingtoneService`) as a notification sound:
/// `Library/Sounds/order_ringtone_<key>.caf`, Linear PCM, under 30 s, the
/// file `aps.sound` names. iOS cannot play MP3 / M4A as a notification sound
/// and plays the default tone for a longer file, so the download is
/// converted here. Also asks Dart whether a push presented in the foreground
/// must lose its sound because the in-app alert already rings.
enum OrderRingtoneSounds {
  static let channelName = "spideli/order_ringtone"
  static let filePrefix = "order_ringtone_"
  static let maxSeconds = 29.5

  struct Failure: Error, CustomStringConvertible {
    let description: String
  }

  static func register(messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      let key = args["key"] as? String ?? ""
      let work: () throws -> Any?
      switch call.method {
      case "existing":
        work = { existing(key: key) }
      case "install":
        let path = args["path"] as? String ?? ""
        work = { try install(path: path, key: key) }
      case "prune":
        work = { prune(keepKey: key); return nil }
      case "clear":
        work = { clear(); return nil }
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.global(qos: .utility).async {
        do {
          let value = try work()
          DispatchQueue.main.async { result(value) }
        } catch {
          DispatchQueue.main.async { result(FlutterError(code: "order_ringtone", message: "\(error)", details: nil)) }
        }
      }
    }
    return channel
  }

  private static func isValidKey(_ key: String) -> Bool {
    return key.range(of: "^[0-9a-f]{8}$", options: .regularExpression) != nil
  }

  private static func soundsDirectory() throws -> URL {
    let library = try FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let sounds = library.appendingPathComponent("Sounds", isDirectory: true)
    try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
    return sounds
  }

  /// The sound name for [key] when it was converted before, else nil.
  static func existing(key: String) -> String? {
    guard isValidKey(key), let dir = try? soundsDirectory() else { return nil }
    let name = "\(filePrefix)\(key).caf"
    let path = dir.appendingPathComponent(name).path
    guard let size = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? NSNumber, size.intValue > 0 else { return nil }
    return name
  }

  /// Converts the download at [path]. Older ringtones stay until [prune].
  static func install(path: String, key: String) throws -> String {
    guard isValidKey(key) else { throw Failure(description: "bad ringtone key") }
    let fm = FileManager.default
    let dir = try soundsDirectory()
    let name = "\(filePrefix)\(key).caf"
    let dest = dir.appendingPathComponent(name)
    let incoming = dir.appendingPathComponent("incoming_\(key).caf")
    try? fm.removeItem(at: incoming)
    do {
      try convert(from: URL(fileURLWithPath: path), to: incoming)
    } catch {
      try? fm.removeItem(at: incoming)
      throw error
    }
    if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
    try fm.moveItem(at: incoming, to: dest)
    return name
  }

  /// Removes every ringtone except [keepKey]'s, once that one is in use.
  static func prune(keepKey: String) {
    guard isValidKey(keepKey), let dir = try? soundsDirectory() else { return }
    let keep = "\(filePrefix)\(keepKey).caf"
    for file in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where file.hasPrefix(filePrefix) && file != keep {
      try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
    }
  }

  static func clear() {
    guard let dir = try? soundsDirectory() else { return }
    for file in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where file.hasPrefix(filePrefix) || file.hasPrefix("incoming_") {
      try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
    }
  }

  /// Any format AVAudioFile reads (MP3, M4A/AAC, WAV, CAF, AIFF, ...) to
  /// 16-bit little-endian Linear PCM .caf, mono or stereo, cut at [maxSeconds].
  private static func convert(from source: URL, to destination: URL) throws {
    let input = try AVAudioFile(forReading: source)
    let format = input.processingFormat
    guard format.sampleRate > 0, format.channelCount >= 1, format.channelCount <= 2 else {
      throw Failure(description: "unsupported audio format")
    }
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: format.sampleRate,
      AVNumberOfChannelsKey: format.channelCount,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let limit = min(input.length, AVAudioFramePosition(maxSeconds * format.sampleRate))
    guard limit > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else {
      throw Failure(description: "empty audio")
    }
    var written: AVAudioFramePosition = 0
    do {
      // Released (and its header written) at the end of this scope.
      let output = try AVAudioFile(forWriting: destination, settings: settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
      while written < limit {
        let want = AVAudioFrameCount(min(AVAudioFramePosition(buffer.frameCapacity), limit - written))
        do {
          try input.read(into: buffer, frameCount: want)
        } catch {
          if written > 0 { break }
          throw error
        }
        if buffer.frameLength == 0 { break }
        try output.write(from: buffer)
        written += AVAudioFramePosition(buffer.frameLength)
      }
    }
    guard written > 0 else { throw Failure(description: "no audio decoded") }
  }

  /// A remote push about to be presented in the foreground: Dart answers
  /// whether to drop its sound (a new order while the in-app alert rings the
  /// same sound). The answer is awaited for at most 3 s; the push is
  /// presented exactly once either way.
  static func present(options: UNNotificationPresentationOptions,
                      userInfo: [AnyHashable: Any],
                      channel: FlutterMethodChannel,
                      completion: @escaping (UNNotificationPresentationOptions) -> Void) {
    guard options.contains(.sound) else {
      completion(options)
      return
    }
    var data: [String: String] = [:]
    for (key, value) in userInfo {
      if let k = key as? String, let v = value as? String { data[k] = v }
    }
    if let aps = userInfo["aps"] as? [String: Any], let sound = aps["sound"] as? String {
      data["__apsSound"] = sound
    }
    var done = false
    let finish: (Bool) -> Void = { silent in
      if done { return }
      done = true
      completion(silent ? options.subtracting(.sound) : options)
    }
    channel.invokeMethod("foregroundPushSilent", arguments: data) { result in
      DispatchQueue.main.async { finish((result as? Bool) == true) }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { finish(false) }
  }
}
