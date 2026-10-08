import 'dart:async';

/// What the driver's online switch may do with a request ([OnlineStatusRules.switchRequest]).
enum OnlineSwitchStep {
  /// Write the new value now.
  write,

  /// Refused: the account is still waiting for document verification.
  verificationPending,

  /// Going online: check the uploaded documents (expired / rejected) first.
  checkDocuments,
}

/// Where a request to show a driver's dashboard leads ([OnlineStatusRules.dashboardRoute]).
enum DashboardRoute {
  /// No dashboard is running: open it (the first open after sign-in / start).
  open,

  /// The same dashboards are already running: go back to them, never
  /// rebuilding them (their listeners and location stream stay alive).
  reuse,

  /// Different dashboards (another service set), or a rebuild was asked
  /// for: the running ones are closed completely before the new ones open.
  rebuild,
}

/// The driver's online status, `users/{uid}.isActive`: one value for every
/// service the driver works in (delivery, cab, parcel, rental). Only the
/// driver's own switch changes it; nothing else in the app writes it after
/// the account was created.
abstract final class OnlineStatusRules {
  /// Whether a stored `isActive` means online. Read as tolerantly as
  /// `UserModel.fromJson` (a bool, a number, "true" / "1"); anything else,
  /// including a missing field, is offline: the dispatch Cloud Functions
  /// offer work only on `isActive == true`.
  static bool isOnline(dynamic stored) {
    if (stored is bool) return stored;
    if (stored is num) return stored != 0;
    if (stored is String) {
      final String text = stored.trim().toLowerCase();
      return text == 'true' || text == '1';
    }
    return false;
  }

  /// The status to show before the live `users/{uid}` record has arrived:
  /// the value of the session copy (read from the server at sign-in / app
  /// start) when it is this driver's, otherwise unknown (null). A dashboard
  /// used to start from an empty model and show "Offline" until the first
  /// snapshot, which on some phones never came (see [dashboardRoute]).
  static bool? initial({required String uid, String? copyId, dynamic copyIsActive}) {
    if (uid.isEmpty || copyId != uid) return null;
    return isOnline(copyIsActive);
  }

  /// The next step for a tap on the online switch. Going OFFLINE is never
  /// refused: the document checks are about receiving new work, and a driver
  /// whose verification was withdrawn while online used to be stuck online.
  static OnlineSwitchStep switchRequest({required bool goingOnline, required bool checksDocuments, required bool verificationPending}) {
    if (!goingOnline || !checksDocuments) return OnlineSwitchStep.write;
    if (verificationPending) return OnlineSwitchStep.verificationPending;
    return OnlineSwitchStep.checkDocuments;
  }

  /// The dashboards a driver gets: a company account its own, everyone
  /// else one per service module (each once, in order; none = delivery).
  static String dashboardLayout({required bool isOwner, required List<String> modules}) {
    if (isOwner) return 'owner';
    final List<String> unique = <String>[];
    for (final String module in modules) {
      if (module.isNotEmpty && !unique.contains(module)) unique.add(module);
    }
    return unique.isEmpty ? 'delivery-service' : unique.join('|');
  }

  /// How to show the dashboards of [wanted] layout. Navigating with
  /// `Get.offAll` onto a dashboard that is already running made the new
  /// screens adopt the running controllers, which the old screens then
  /// deleted on their way out: the users listener and the location stream
  /// stopped, and the online switch showed "Offline" until the app was
  /// restarted.
  static DashboardRoute dashboardRoute({required bool running, required String? openLayout, required String wanted, bool rebuild = false}) {
    if (!running) return DashboardRoute.open;
    if (rebuild || openLayout != wanted) return DashboardRoute.rebuild;
    return DashboardRoute.reuse;
  }
}

/// One call at a time for a platform request that keeps a single pending
/// result. The `location` plugin answers `enableBackgroundMode` and
/// `requestPermission` through ONE stored result on Android: when the four
/// service dashboards asked at the same time, each call replaced the
/// previous one's result and only the last ever completed. The others
/// waited for good, and their dashboard, which awaited it before listening
/// to `users/{uid}`, kept showing the driver "Offline".
class SingleFlight<T> {
  Future<T>? _pending;

  bool get isRunning => _pending != null;

  /// The call in progress, or [task] started now. Every caller gets the
  /// same result (or error).
  Future<T> run(Future<T> Function() task) {
    final Future<T>? running = _pending;
    if (running != null) return running;
    final Future<T> started = Future<T>.sync(task);
    _pending = started;
    void clear() {
      if (identical(_pending, started)) _pending = null;
    }

    started.then((T value) => clear(), onError: (Object error) => clear());
    return started;
  }
}

/// [future], or [fallback] when it has not completed within [limit] (or
/// failed). Never throws.
Future<T> boundedOrDefault<T>(Future<T> future, Duration limit, T fallback) async {
  try {
    return await future.timeout(limit);
  } on TimeoutException {
    return fallback;
  } catch (_) {
    return fallback;
  }
}
