import 'package:customer/utils/auth_security_rules.dart';
import 'package:customer/utils/finance_security_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spideli Finance account security (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 3.12): notification preferences, the blacklist, two-step
/// verification helpers and the optional LinkedIn sign-in flags.
void main() {
  group('FinanceNotificationPrefs', () {
    test('defaults: every push, SMS for payments only, email receipts only', () {
      final p = FinanceNotificationPrefs.resolve(null);
      expect(p.keys, ['push', 'sms', 'email']);
      expect(p['push']!.values.every((v) => v), isTrue);
      expect(p['sms'], {'payments': true, 'groups': false, 'loans': false, 'investments': false, 'insurance': false, 'news': false});
      expect(p['email']!['payments'], isTrue);
      expect(p['email']!.entries.where((e) => e.value).map((e) => e.key), ['payments']);
    });

    test('a stored choice wins, every other value is the default', () {
      final p = FinanceNotificationPrefs.resolve({
        'push': {'news': false},
        'sms': {'loans': true},
      });
      expect(p['push']!['news'], isFalse);
      expect(p['push']!['payments'], isTrue);
      expect(p['sms']!['loans'], isTrue);
      expect(p['sms']!['payments'], isTrue);
      expect(p['email'], FinanceNotificationPrefs.defaults['email']);
    });

    test('non-bool values, unknown channels and categories are ignored', () {
      final p = FinanceNotificationPrefs.resolve({
        'push': {'payments': 'no', 'groups': 0, 'marketing': false},
        'whatsapp': {'payments': true},
        'email': 'off',
      });
      expect(p['push']!['payments'], isTrue);
      expect(p['push']!['groups'], isTrue);
      expect(p['push']!.containsKey('marketing'), isFalse);
      expect(p.containsKey('whatsapp'), isFalse);
      expect(p['email'], FinanceNotificationPrefs.defaults['email']);
    });

    test('withChoice returns a complete new map and leaves the input alone', () {
      final current = FinanceNotificationPrefs.resolve(null);
      final next = FinanceNotificationPrefs.withChoice(current, 'sms', 'groups', true);
      expect(next['sms']!['groups'], isTrue);
      expect(current['sms']!['groups'], isFalse, reason: 'input unchanged');
      for (final ch in FinanceNotificationPrefs.channels) {
        expect(next[ch]!.keys.toList(), FinanceNotificationPrefs.categories, reason: 'every category of $ch is written');
      }
      expect(FinanceNotificationPrefs.withChoice(current, 'fax', 'payments', false), current, reason: 'unknown channel');
      expect(FinanceNotificationPrefs.withChoice(current, 'push', 'security', false), current, reason: 'security is not a choice');
    });

    test('allows: from the user document; security notices always', () {
      final doc = {
        'financeNotificationPrefs': {
          'push': {'payments': false},
          'email': {'payments': false},
        },
      };
      expect(FinanceNotificationPrefs.allows(doc, 'push', 'payments'), isFalse);
      expect(FinanceNotificationPrefs.allows(doc, 'push', 'loans'), isTrue);
      expect(FinanceNotificationPrefs.allows(doc, 'sms', 'payments'), isTrue);
      expect(FinanceNotificationPrefs.allows(doc, 'email', 'security'), isTrue);
      expect(FinanceNotificationPrefs.allows(null, 'sms', 'news'), isFalse);
      expect(FinanceNotificationPrefs.allows(null, 'push', 'news'), isTrue);
    });
  });

  group('FinanceRestriction', () {
    Map<String, dynamic> user(Object? restriction) => {'firstName': 'Awa', 'financeRestriction': restriction};

    test('no restriction: nothing is blocked', () {
      expect(FinanceRestriction.of(null), isNull);
      expect(FinanceRestriction.of({'firstName': 'Awa'}), isNull);
      expect(FinanceRestriction.of(user(null)), isNull);
      expect(FinanceRestriction.of(user('restricted')), isNull, reason: 'not a map');
      expect(FinanceRestriction.of(user({'status': 'lifted', 'scopes': ['all']})), isNull);
      expect(FinanceRestriction.blocks(user({'status': 'lifted', 'scopes': ['all']}), 'loans'), isFalse);
    });

    test('scopes: only the listed services are blocked', () {
      final doc = user({'status': 'restricted', 'reason': 'Unpaid loan', 'scopes': ['loans']});
      expect(FinanceRestriction.blocks(doc, 'loans'), isTrue);
      expect(FinanceRestriction.blocks(doc, 'tontines'), isFalse);
      final r = FinanceRestriction.of(doc)!;
      expect(r.reason, 'Unpaid loan');
      expect(r.isTotal, isFalse);
      expect(r.scopes, ['loans']);
    });

    test("'all', or no scopes at all, blocks every service", () {
      for (final scopes in <Object?>[
        ['all'],
        ['loans', 'ALL'],
        [],
        null,
      ]) {
        final doc = user({'status': 'restricted', 'scopes': scopes});
        expect(FinanceRestriction.blocks(doc, 'loans'), isTrue, reason: '$scopes');
        expect(FinanceRestriction.blocks(doc, 'tontines'), isTrue, reason: '$scopes');
        expect(FinanceRestriction.blocks(doc, 'investments'), isTrue, reason: '$scopes');
        expect(FinanceRestriction.of(doc)!.isTotal, isTrue);
      }
    });

    test('status and scopes are read case-insensitively, duplicates once', () {
      final doc = user({'status': ' Restricted ', 'scopes': ['Tontines', 'tontines', ' ', 'loans']});
      final r = FinanceRestriction.of(doc)!;
      expect(r.scopes, ['tontines', 'loans']);
      expect(FinanceRestriction.blocks(doc, 'TONTINES'), isTrue);
    });

    test('since: DateTime, epoch millis, ISO text or a Timestamp through toDate', () {
      final day = DateTime(2026, 10, 1);
      expect(FinanceRestriction.of(user({'status': 'restricted', 'since': day}))!.since, day);
      expect(FinanceRestriction.of(user({'status': 'restricted', 'since': day.millisecondsSinceEpoch}))!.since, day);
      expect(FinanceRestriction.of(user({'status': 'restricted', 'since': '2026-10-01T00:00:00'}))!.since, day);
      expect(FinanceRestriction.of(user({'status': 'restricted', 'since': const _FakeTimestamp()}))!.since, isNull, reason: 'unknown type without toDate');
      expect(FinanceRestriction.of(user({'status': 'restricted', 'since': const _FakeTimestamp()}), toDate: (v) => v is _FakeTimestamp ? day : null)!.since, day);
    });
  });

  group('two-step verification', () {
    test('error codes in every spelling give a clear message', () {
      expect(MfaErrors.messageKey('operation-not-allowed'), MfaErrors.notAvailable);
      expect(MfaErrors.messageKey('ADMIN_RESTRICTED_OPERATION'), MfaErrors.notAvailable);
      expect(MfaErrors.messageKey('auth/operation-not-allowed'), MfaErrors.notAvailable);
      expect(MfaErrors.messageKey('requires-recent-login'), contains('confirm it is you'));
      expect(MfaErrors.messageKey('unverified-email'), contains('Verify your email'));
      expect(MfaErrors.messageKey('invalid-verification-code'), 'Invalid code.');
      expect(MfaErrors.messageKey('session-expired'), 'This code has expired. Send a new code.');
      expect(MfaErrors.messageKey('something-new'), MfaErrors.fallback);
    });

    test('phone numbers: E.164 only', () {
      expect(MfaPhone.normalize('+237 6 12-34.56 78'), '+237612345678');
      expect(MfaPhone.normalize('00237612345678'), '+237612345678');
      expect(MfaPhone.normalize('(+33) 6 12 34 56 78'), '+33612345678');
      expect(MfaPhone.normalize('612345678'), isNull, reason: 'no country code');
      expect(MfaPhone.normalize('+0123456789'), isNull);
      expect(MfaPhone.normalize('+12'), isNull);
      expect(MfaPhone.normalize(''), isNull);
    });

    test('the profile number becomes the default second factor', () {
      expect(MfaPhone.fromProfile('+237', '612345678'), '+237612345678');
      expect(MfaPhone.fromProfile('91', '9876543210'), '+919876543210');
      expect(MfaPhone.fromProfile('+91', '+91 98765 43210'), '+919876543210');
      expect(MfaPhone.fromProfile('+91', ''), '');
      expect(MfaPhone.fromProfile(null, null), '');
      expect(MfaPhone.fromProfile('', '612'), '');
    });

    test('masked label and enrolment date', () {
      expect(MfaPhone.masked('+237612345678'), '•••• 5678');
      expect(MfaPhone.masked('12'), '12');
      final at = DateTime.utc(2026, 10, 14, 9);
      expect(MfaPhone.enrolledAt(at.millisecondsSinceEpoch / 1000)!.toUtc(), at, reason: 'seconds');
      expect(MfaPhone.enrolledAt(at.millisecondsSinceEpoch)!.toUtc(), at, reason: 'milliseconds');
      expect(MfaPhone.enrolledAt(0), isNull);
    });

    test('who can turn it on', () {
      expect(MfaEligibility.of(providerIds: ['password'], email: 'a@b.cm', emailVerified: true), MfaEligibility.ready);
      expect(MfaEligibility.of(providerIds: ['password'], email: 'a@b.cm', emailVerified: false), MfaEligibility.emailUnverified);
      expect(MfaEligibility.of(providerIds: ['google.com'], email: 'a@b.cm', emailVerified: true), MfaEligibility.ready);
      expect(MfaEligibility.of(providerIds: ['oidc.linkedin'], email: 'a@b.cm', emailVerified: true), MfaEligibility.ready);
      expect(MfaEligibility.of(providerIds: ['phone'], email: null, emailVerified: false), MfaEligibility.unsupportedSignIn);
      expect(MfaEligibility.of(providerIds: ['phone', 'password'], email: 'a@b.cm', emailVerified: true), MfaEligibility.ready);
      expect(MfaEligibility.of(providerIds: ['apple.com'], email: '', emailVerified: true), MfaEligibility.unsupportedSignIn, reason: 'no email');
      expect(MfaEligibility.of(providerIds: const [], email: 'a@b.cm', emailVerified: true), MfaEligibility.unsupportedSignIn);
    });
  });

  group('LinkedIn sign-in', () {
    test('hidden unless settings/authProviders turns it on', () {
      expect(AuthProviderFlags.parse(null).linkedin, isFalse);
      expect(AuthProviderFlags.parse({}).linkedin, isFalse);
      expect(AuthProviderFlags.parse({'linkedin': 'true'}).linkedin, isFalse, reason: 'only a real true');
      final f = AuthProviderFlags.parse({'linkedin': true, 'linkedinProviderId': 'oidc.linkedin-prod', 'facebook': true});
      expect(f.linkedin, isTrue);
      expect(f.linkedinProviderId, 'oidc.linkedin-prod');
      expect(f.facebook, isTrue);
      expect(AuthProviderFlags.parse({'linkedin': true, 'linkedinProviderId': 'linkedin.com'}).linkedinProviderId, 'oidc.linkedin');
      expect(AuthProviderFlags.parse({'linkedin': true, 'linkedinProviderId': 'oidc.'}).linkedinProviderId, 'oidc.linkedin');
    });

    test('names from the claims, else the display name', () {
      expect(SocialAuthRules.splitName(given: 'Awa', family: 'Ndiaye', display: 'X Y'), ('Awa', 'Ndiaye'));
      expect(SocialAuthRules.splitName(display: 'Jean  Paul Mbarga'), ('Jean', 'Paul Mbarga'));
      expect(SocialAuthRules.splitName(display: 'Awa'), ('Awa', ''));
      expect(SocialAuthRules.splitName(), ('', ''));
    });

    test('a closed LinkedIn page says nothing; a missing provider says so', () {
      expect(SocialAuthRules.linkedInErrorKey('web-context-canceled'), isNull);
      expect(SocialAuthRules.linkedInErrorKey('WEB_CONTEXT_CANCELLED'), isNull);
      expect(SocialAuthRules.linkedInErrorKey('operation-not-allowed'), 'LinkedIn sign-in is not available yet.');
      expect(SocialAuthRules.linkedInErrorKey('account-exists-with-different-credential'), contains('already exists'));
      expect(SocialAuthRules.linkedInErrorKey('weird'), 'Something went wrong. Please try again.');
    });
  });
}

/// Stands for a Firestore Timestamp (not constructed in a pure test).
class _FakeTimestamp {
  const _FakeTimestamp();
}
