/// Sign-in security, the pure rules (no Flutter, no Firebase; unit tested
/// in test/finance_security_test.dart): the messages and phone numbers of
/// two-step verification (lib/utils/mfa_challenge.dart, which re-exports
/// this file) and the optional social sign-in methods
/// (lib/utils/social_sign_in.dart). Every message is a translation key:
/// call `.tr` where it is shown.
library;

/// The messages of two-step verification (translation keys, `.tr` where
/// shown); Firebase's own text is never shown.
abstract final class MfaErrors {
  static const String notAvailable = 'Two-step verification is not available yet.';
  static const String fallback = 'Could not complete two-step verification. Please try again.';

  /// Codes arrive as 'operation-not-allowed', 'OPERATION_NOT_ALLOWED' or
  /// 'auth/operation-not-allowed' depending on the platform.
  static String normalize(String code) {
    String c = code.trim().toLowerCase().replaceAll('_', '-');
    if (c.startsWith('auth/')) c = c.substring(5);
    return c;
  }

  static String messageKey(String code) => switch (normalize(code)) {
        // Identity Platform's SMS multi-factor is not turned on for the project.
        'operation-not-allowed' || 'admin-restricted-operation' => notAvailable,
        'requires-recent-login' => 'For your security, confirm it is you, then try again.',
        'unverified-email' => 'Verify your email address before turning on two-step verification.',
        'unsupported-first-factor' => 'Two-step verification is for accounts that sign in with an email address, Google, Apple or LinkedIn.',
        'unsupported-second-factor' => 'This account uses a second step this app does not offer. Please contact support.',
        'invalid-verification-code' => 'Invalid code.',
        'missing-verification-code' => 'Enter the 6-digit code sent by SMS.',
        'session-expired' || 'code-expired' || 'invalid-verification-id' || 'missing-verification-id' => 'This code has expired. Send a new code.',
        'invalid-phone-number' || 'missing-phone-number' => 'Enter a valid phone number with its country code.',
        'second-factor-already-in-use' => 'This phone number already receives your codes.',
        'maximum-second-factor-count-exceeded' => 'You cannot add more phone numbers.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'quota-exceeded' => 'Too many codes were sent. Please try again later.',
        'code-not-sent' => 'The code could not be sent. Please try again.',
        'network-request-failed' || 'unavailable' => 'No internet connection. Please check your connection and try again.',
        'user-token-expired' || 'user-disabled' || 'user-not-found' => 'Sign in again to continue.',
        _ => fallback,
      };
}

/// Phone numbers of the second factor: E.164 (`+` country code and number).
abstract final class MfaPhone {
  static final RegExp _e164 = RegExp(r'^\+[1-9]\d{6,14}$');

  /// [raw] as E.164 ("+237 6 12-34.56 78" or "00237612345678" ->
  /// "+237612345678"), or null when it is not an international number.
  static String? normalize(String raw) {
    String s = raw.trim().replaceAll(RegExp(r'[\s\-.()]'), '');
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    return _e164.hasMatch(s) ? s : null;
  }

  /// The number of the user's profile (`countryCode` "+237" or "237",
  /// `phoneNumber`) as E.164, or '' when it does not make one.
  static String fromProfile(String? countryCode, String? number) {
    final String n = (number ?? '').trim();
    if (n.isEmpty) return '';
    if (n.startsWith('+') || n.startsWith('00')) return normalize(n) ?? '';
    String cc = (countryCode ?? '').trim();
    if (cc.isNotEmpty && !cc.startsWith('+')) cc = '+$cc';
    return normalize('$cc$n') ?? '';
  }

  /// "•••• 5678": a phone number without most of its digits (the label
  /// saved with the factor, never the whole number).
  static String masked(String phone) {
    final String digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length < 4 ? phone : '•••• ${digits.substring(digits.length - 4)}';
  }

  /// When a factor was enrolled: Firebase gives seconds since the epoch
  /// (milliseconds on some platforms); null when unknown.
  static DateTime? enrolledAt(num timestamp) {
    if (timestamp <= 0) return null;
    final int ms = timestamp > 1e11 ? timestamp.round() : (timestamp * 1000).round();
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}

/// Whether the signed-in account can turn on two-step verification.
enum MfaEligibility {
  ready,

  /// Signs in with a phone number only (or has no email): Firebase does not
  /// offer a second factor to such accounts.
  unsupportedSignIn,

  /// Firebase requires a verified email address before a second factor.
  emailUnverified;

  /// From the account's sign-in methods ([providerIds]: 'password',
  /// 'google.com', 'apple.com', 'oidc.linkedin', 'phone'…), its email and
  /// whether that email is verified.
  static MfaEligibility of({required Iterable<String> providerIds, required String? email, required bool emailVerified}) {
    final bool emailSignIn = providerIds.any((p) => p.isNotEmpty && p != 'phone' && p != 'anonymous' && p != 'firebase');
    if (!emailSignIn || (email ?? '').trim().isEmpty) return MfaEligibility.unsupportedSignIn;
    if (!emailVerified) return MfaEligibility.emailUnverified;
    return MfaEligibility.ready;
  }
}

/// The sign-in methods the admin turned on beyond email, phone, Google and
/// Apple: `settings/authProviders` `{linkedin: true, linkedinProviderId:
/// "oidc.linkedin", facebook: false}`. Everything is off when the document
/// is missing or unreadable, so nothing changes on the sign-in screens until
/// the provider is configured in Firebase (Identity Platform).
class AuthProviderFlags {
  /// LinkedIn through an OpenID Connect provider of Firebase Authentication
  /// with Identity Platform.
  final bool linkedin;

  /// The OIDC provider id created in Firebase ("oidc." + its name).
  final String linkedinProviderId;

  /// Read for the admin panel; the app has no Facebook button (it needs the
  /// Facebook SDK, a package this app does not include).
  final bool facebook;

  const AuthProviderFlags({this.linkedin = false, this.linkedinProviderId = defaultLinkedinProviderId, this.facebook = false});

  static const String defaultLinkedinProviderId = 'oidc.linkedin';
  static const AuthProviderFlags none = AuthProviderFlags();

  /// Only a real `true` turns a provider on; a provider id that is not an
  /// OIDC id ("oidc.…") falls back to the default one.
  factory AuthProviderFlags.parse(Map<String, dynamic>? data) {
    if (data == null) return none;
    final String id = '${data['linkedinProviderId'] ?? ''}'.trim();
    return AuthProviderFlags(
      linkedin: data['linkedin'] == true,
      linkedinProviderId: id.startsWith('oidc.') && id.length > 5 ? id : defaultLinkedinProviderId,
      facebook: data['facebook'] == true,
    );
  }
}

/// Social sign-in (LinkedIn) helpers.
abstract final class SocialAuthRules {
  /// The message for a failed LinkedIn sign-in (a translation key), or null
  /// when the user closed the LinkedIn page (nothing to say).
  static String? linkedInErrorKey(String code) => switch (MfaErrors.normalize(code)) {
        'web-context-canceled' || 'web-context-cancelled' || 'canceled' || 'cancelled' || 'user-cancelled' || 'popup-closed-by-user' => null,
        // The OIDC provider is not (or no longer) set up in Firebase.
        'operation-not-allowed' || 'invalid-provider-id' || 'unsupported-platform' || 'admin-restricted-operation' => 'LinkedIn sign-in is not available yet.',
        'account-exists-with-different-credential' => 'An account already exists with this email. Sign in with the method you used before.',
        'user-disabled' => 'This user is disabled. Please contact admin.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' || 'unavailable' => 'No internet connection. Please check your connection and try again.',
        _ => 'Something went wrong. Please try again.',
      };

  /// First and last name: the provider's given / family names, else the
  /// display name split at its first space.
  static (String, String) splitName({String? given, String? family, String? display}) {
    final String g = (given ?? '').trim();
    final String f = (family ?? '').trim();
    if (g.isNotEmpty || f.isNotEmpty) return (g, f);
    final List<String> parts = (display ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return ('', '');
    return (parts.first, parts.skip(1).join(' '));
  }
}
