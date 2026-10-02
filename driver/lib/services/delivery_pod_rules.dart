import 'dart:math';

/// Proof of delivery by customer OTP — the pure rules of
/// `.claude/POD-OTP-CONTRACT.md`, with no Firebase in sight so they can be
/// unit tested. [DeliveryPodService] applies them inside Firestore
/// transactions; the Customer and Store apps implement the same numbers.
abstract final class DeliveryPodRules {
  /// `order_pod.status` / `pod.status` values.
  static const String statusPending = 'pending';
  static const String statusVerified = 'verified';
  static const String statusExpired = 'expired';

  static const int codeLength = 6;

  /// A code is valid for 10 minutes from generation.
  static const Duration validity = Duration(minutes: 10);

  /// Five wrong entries invalidate the code (status `expired`).
  static const int maxAttempts = 5;

  /// A new code can be requested 60 seconds after the last one.
  static const Duration resendCooldown = Duration(seconds: 60);

  /// At most five regenerations per order. `order_pod.regenerations` counts
  /// how many codes the order has had, so the first code is not a
  /// regeneration: an order can have 1 + 5 codes in all.
  static const int maxRegenerations = 5;

  /// A fresh 6-digit code from `Random.secure()` that differs from
  /// [previous] (the order's last code), zero-padded ("004213").
  static String generateCode({String? previous, Random? random}) {
    final Random rng = random ?? Random.secure();
    final int bound = pow(10, codeLength).toInt();
    String code;
    do {
      code = rng.nextInt(bound).toString().padLeft(codeLength, '0');
    } while (code == previous);
    return code;
  }

  /// When the code issued at [generatedAt] stops working.
  static DateTime expiryFor(DateTime generatedAt) => generatedAt.add(validity);

  /// True once [now] reached [expiresAt] (or when there is no expiry).
  static bool isExpired({required DateTime now, required DateTime? expiresAt}) => expiresAt == null || !now.isBefore(expiresAt);

  static int attemptsLeft(int attempts) => max(0, maxAttempts - attempts);

  /// A pending, unexpired code with attempts left — "Drop Delivery" again
  /// reuses it instead of creating a new one.
  static bool canReuse({required String? status, required DateTime now, required DateTime? expiresAt, required int attempts}) =>
      status == statusPending && !isExpired(now: now, expiresAt: expiresAt) && attempts < maxAttempts;

  /// Regenerations already used for an order that has had [regenerations] codes.
  static int regenerationsUsed(int regenerations) => max(0, regenerations - 1);

  static int regenerationsLeft(int regenerations) => max(0, maxRegenerations - regenerationsUsed(regenerations));

  /// Time left before a new code may be requested. The code issued at
  /// [lastGeneratedAt] starts the cooldown; no code yet means no wait.
  static Duration cooldownRemaining({required DateTime now, required DateTime? lastGeneratedAt}) {
    if (lastGeneratedAt == null) return Duration.zero;
    final Duration left = lastGeneratedAt.add(resendCooldown).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether a NEW code may be created now for an order that has had
  /// [regenerations] codes, the last one issued at [lastGeneratedAt].
  static PodNewCodeDecision newCodeDecision({required int regenerations, required DateTime now, required DateTime? lastGeneratedAt}) {
    if (regenerations <= 0) return const PodNewCodeDecision.allowed();
    if (regenerationsUsed(regenerations) >= maxRegenerations) return const PodNewCodeDecision.capReached();
    final Duration wait = cooldownRemaining(now: now, lastGeneratedAt: lastGeneratedAt);
    if (wait > Duration.zero) return PodNewCodeDecision.cooldown(wait);
    return const PodNewCodeDecision.allowed();
  }

  /// The verification rule of the contract: status `pending`, now <
  /// `expiresAt`, `attempts < 5`, entered == `code`. [code] null means the
  /// order has no code yet.
  static PodCheck check({
    required String? status,
    required String? code,
    required DateTime now,
    required DateTime? expiresAt,
    required int attempts,
    required String entered,
  }) {
    if (status == statusVerified) return const PodCheck(PodCheckResult.alreadyVerified);
    if (code == null || code.isEmpty || status == null) return const PodCheck(PodCheckResult.noCode);
    if (attempts >= maxAttempts) return const PodCheck(PodCheckResult.tooManyAttempts);
    if (status != statusPending || isExpired(now: now, expiresAt: expiresAt)) return const PodCheck(PodCheckResult.expired);
    if (entered.trim() == code) return const PodCheck(PodCheckResult.verified);
    final int after = attempts + 1;
    if (after >= maxAttempts) return const PodCheck(PodCheckResult.tooManyAttempts, attemptsAfter: maxAttempts, invalidates: true, countsAttempt: true);
    return PodCheck(PodCheckResult.wrong, attemptsAfter: after, attemptsLeft: attemptsLeft(after), countsAttempt: true);
  }

  /// The contract's driver-facing messages (untranslated keys).
  static String messageFor(PodCheck check) {
    switch (check.result) {
      case PodCheckResult.verified:
      case PodCheckResult.alreadyVerified:
        return 'Delivery verified.';
      case PodCheckResult.wrong:
        return 'Incorrect code. ${check.attemptsLeft} attempts left.';
      case PodCheckResult.expired:
        return expiredMessage;
      case PodCheckResult.tooManyAttempts:
        return tooManyAttemptsMessage;
      case PodCheckResult.noCode:
        return noCodeMessage;
    }
  }

  static const String expiredMessage = 'This code has expired. Generate a new one.';
  static const String tooManyAttemptsMessage = 'Too many incorrect attempts. Generate a new code.';
  static const String noCodeMessage = 'No code yet. Tap "Get a new code" to send one to the customer.';
  static const String offlineMessage = 'You are offline. Connect to the internet and try again.';
  static const String capReachedMessage = 'No new codes left for this order. Contact support.';
}

enum PodCheckResult { verified, alreadyVerified, wrong, expired, tooManyAttempts, noCode }

class PodCheck {
  final PodCheckResult result;

  /// The `attempts` value to write back after a wrong entry.
  final int? attemptsAfter;
  final int? attemptsLeft;

  /// True when this entry used up the last attempt (status → `expired`).
  final bool invalidates;

  /// True when this entry is a wrong entry against a live code.
  final bool countsAttempt;

  const PodCheck(this.result, {this.attemptsAfter, this.attemptsLeft, this.invalidates = false, this.countsAttempt = false});

  bool get isSuccess => result == PodCheckResult.verified || result == PodCheckResult.alreadyVerified;
}

enum PodNewCodeKind { allowed, cooldown, capReached }

class PodNewCodeDecision {
  final PodNewCodeKind kind;
  final Duration wait;

  const PodNewCodeDecision.allowed()
      : kind = PodNewCodeKind.allowed,
        wait = Duration.zero;
  const PodNewCodeDecision.capReached()
      : kind = PodNewCodeKind.capReached,
        wait = Duration.zero;
  const PodNewCodeDecision.cooldown(this.wait) : kind = PodNewCodeKind.cooldown;

  bool get allowed => kind == PodNewCodeKind.allowed;
}
