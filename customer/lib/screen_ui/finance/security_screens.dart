import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_security.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_rules.dart' show ltr;
import 'package:customer/utils/finance_security_rules.dart';
import 'package:customer/utils/mfa_challenge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// The SMS code sheet of two-step verification in the finance identity.
Future<bool?> _financeSheet(Widget child, String title) => finSheet<bool>(title: title, child: child);

String _day(DateTime d) => ltr(DateFormat('dd MMM yyyy').format(d));

// ------------------------------------------------------------- security

/// Finance > Profile > Security: two-step verification (Firebase Auth
/// multi-factor, an SMS code at each sign-in). Shows whether it is on, the
/// phone numbers that receive the codes, adds one (SMS code to confirm it)
/// and removes one (after confirming it is the user).
///
/// Needs Identity Platform with SMS multi-factor turned on for the Firebase
/// project; until then adding a number says "Two-step verification is not
/// available yet." Firebase also requires a verified email address and does
/// not offer a second factor to accounts that sign in with a phone number.
class FinanceSecurityScreen extends StatefulWidget {
  const FinanceSecurityScreen({super.key});

  @override
  State<FinanceSecurityScreen> createState() => _FinanceSecurityScreenState();
}

/// The signed-in account as the screen shows it.
class _Account {
  final User user;
  final MfaEligibility eligibility;
  final List<MultiFactorInfo> factors;

  const _Account(this.user, this.eligibility, this.factors);
}

class _FinanceSecurityScreenState extends State<FinanceSecurityScreen> {
  late Future<_Account?> _future = _load();

  /// An action is running: its button is disabled.
  bool _busy = false;

  /// Null when nobody is signed in.
  Future<_Account?> _load() async {
    final User? current = FirebaseAuth.instance.currentUser;
    if (current == null) return null;
    try {
      // The email may just have been verified (link opened in the mail app).
      await current.reload();
    } catch (_) {
      // Offline: the last known state.
    }
    final User user = FirebaseAuth.instance.currentUser ?? current;
    final List<MultiFactorInfo> factors = await user.multiFactor.getEnrolledFactors();
    final MfaEligibility eligibility = MfaEligibility.of(providerIds: user.providerData.map((p) => p.providerId), email: user.email, emailVerified: user.emailVerified);
    return _Account(user, eligibility, factors);
  }

  void _refresh() {
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Security".tr,
      body: FutureBuilder<_Account?>(
        future: _future,
        builder: (context, snap) {
          // A refresh keeps the last state on screen instead of a skeleton.
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return FinBody(children: [FinState.loading()]);
          if (snap.hasError && !snap.hasData) {
            return FinBody(children: [FinState.error("Could not load your security settings. Check your connection and try again.".tr, onRetry: _refresh)]);
          }
          final _Account? account = snap.data;
          if (account == null) return FinBody(children: [FinState.empty(Icons.lock_outline_rounded, "Sign in to manage the security of your account.".tr)]);
          return _content(context, account);
        },
      ),
    );
  }

  Widget _content(BuildContext context, _Account a) {
    final c = DsColors.of(context);
    final bool on = a.factors.isNotEmpty;
    return FinBody(children: [
      FinHeader(
        icon: on ? Icons.verified_user_outlined : Icons.shield_outlined,
        overline: "Sign-in security".tr,
        title: "Two-step verification".tr,
        subtitle: on
            ? "On: each sign-in also asks for a code sent by SMS to your phone.".tr
            : "Off: turn it on to be asked for a code sent by SMS each time you sign in, in addition to your password.".tr,
        status: on ? 'active' : 'off',
        statusLabel: on ? "On".tr : "Off".tr,
      ),
      if (a.eligibility == MfaEligibility.unsupportedSignIn)
        FinNotice(
          "You sign in with your phone number: each sign-in already asks for a code sent by SMS. Two-step verification is for accounts that sign in with an email address, Google, Apple or LinkedIn.".tr,
        ),
      if (a.eligibility == MfaEligibility.emailUnverified) ...[
        FinNotice(
          "Two-step verification needs a verified email address. Open the link we send to @email, then come back here.".trParams({'email': a.user.email ?? ''}),
          title: "Verify your email address".tr,
          tone: DsTone.warning,
          actionLabel: "Send verification email".tr,
          onAction: _sendVerification,
        ),
        const DsGap(DsSpace.sm),
        DsButton.ghost(label: "I have verified my email".tr, icon: Icons.refresh_rounded, expand: true, onPressed: _refresh),
      ],
      FinSection(
        title: "Phone numbers for codes".tr,
        divided: true,
        footnote: on ? "Keep a number you can always receive SMS on. If you lose access to it, contact support.".tr : null,
        children: on
            ? [for (final f in a.factors) _factorTile(context, f, a.factors.length)]
            : [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                  child: Text("No phone number yet.".tr, style: DsTypography.body.copyWith(color: c.textSecondary)),
                ),
              ],
      ),
      if (a.eligibility == MfaEligibility.ready) ...[
        const DsGap(DsSpace.lg),
        DsButton.primary(
          label: on ? "Add another phone number".tr : "Turn on two-step verification".tr,
          icon: on ? Icons.add_rounded : Icons.lock_outline_rounded,
          expand: true,
          loading: _busy,
          onPressed: _busy ? null : () => _enroll(first: !on),
        ),
      ],
      FinSection(
        title: "Good to know".tr,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
            child: Text(
              "The code is asked when you sign in and when you confirm a sensitive action. Spideli never asks for it by phone, SMS or email: never share it.".tr,
              style: DsTypography.bodySm.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _factorTile(BuildContext context, MultiFactorInfo f, int count) {
    final DateTime? added = MfaPhone.enrolledAt(f.enrollmentTimestamp);
    return FinListTile(
      icon: Icons.sms_outlined,
      iconTone: DsTone.success,
      title: ltr(_phoneOf(f)),
      subtitle: added == null ? null : '${"Added on".tr} ${_day(added)}',
      // The whole row removes it: one target, read as one by screen readers.
      trailing: Text("Remove".tr, style: DsTypography.label.copyWith(color: DsColors.of(context).dangerStrong)),
      onTap: _busy ? null : () => _remove(f, count),
    );
  }

  static String _phoneOf(MultiFactorInfo f) => f is PhoneMultiFactorInfo && f.phoneNumber.isNotEmpty ? f.phoneNumber : (f.displayName ?? "Phone".tr);

  Future<void> _sendVerification() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String message;
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      await user.sendEmailVerification();
      message = "Verification email sent. Open the link it contains, then come back here.";
    } on FirebaseAuthException catch (e) {
      message = MfaErrors.messageKey(e.code);
    } catch (_) {
      message = MfaErrors.fallback;
    }
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(message.tr);
  }

  // ── Add a phone number ────────────────────────────────────────────────

  Future<void> _enroll({required bool first}) async {
    final String? phone = await finSheet<String>(
      title: "Add a phone number".tr,
      child: _PhoneForm(initial: MfaPhone.fromProfile(Constant.userModel?.countryCode, Constant.userModel?.phoneNumber)),
    );
    if (phone == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _enrollPhone(phone, first: first, retried: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _refresh();
  }

  Future<void> _enrollPhone(String phone, {required bool first, required bool retried}) async {
    // Firebase adds a second factor only after a recent sign-in.
    if (!await FinanceReauth.confirm(force: retried)) return;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final MultiFactorSession session = await user.multiFactor.getSession();
      final bool done = await MfaChallenge.verifyBySms(
        session: session,
        phoneNumber: phone,
        title: "Confirm your phone number".tr,
        sheet: _financeSheet,
        complete: (credential) async {
          try {
            // The label keeps only the last digits (it is shown at sign-in).
            await user.multiFactor.enroll(PhoneMultiFactorGenerator.getAssertion(credential), displayName: MfaPhone.masked(phone));
            return null;
          } on FirebaseAuthException catch (e) {
            return MfaErrors.messageKey(e.code);
          }
        },
      );
      if (done) {
        ShowToastDialog.showToast((first ? "Two-step verification is on. Each sign-in will ask for a code sent by SMS." : "Phone number added.").tr);
      }
    } on FirebaseAuthException catch (e) {
      // The sign-in was not recent enough after all: confirm it is the user, once.
      if (MfaErrors.normalize(e.code) == 'requires-recent-login' && !retried) return _enrollPhone(phone, first: first, retried: true);
      ShowToastDialog.showToast(MfaErrors.messageKey(e.code).tr);
    } catch (_) {
      ShowToastDialog.showToast(MfaErrors.fallback.tr);
    }
  }

  // ── Remove a phone number ─────────────────────────────────────────────

  Future<void> _remove(MultiFactorInfo f, int count) async {
    final bool last = count <= 1;
    final bool ok = await finConfirm(
      title: (last ? "Turn off two-step verification?" : "Remove this phone number?").tr,
      message: (last ? "Signing in will no longer ask for a code sent by SMS: your account will be less protected." : "Codes will no longer be sent to this number.").tr,
      lines: [("Phone number".tr, ltr(_phoneOf(f)))],
      confirmLabel: (last ? "Turn off" : "Remove").tr,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _unenroll(f, last: last, retried: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _refresh();
  }

  Future<void> _unenroll(MultiFactorInfo f, {required bool last, required bool retried}) async {
    // Firebase removes a second factor only after a recent sign-in.
    if (!await FinanceReauth.confirm(force: retried)) return;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String message;
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      await user.multiFactor.unenroll(factorUid: f.uid);
      message = last ? "Two-step verification is off." : "Phone number removed.";
    } on FirebaseAuthException catch (e) {
      final String code = MfaErrors.normalize(e.code);
      if (code == 'requires-recent-login' && !retried) {
        ShowToastDialog.closeLoader();
        return _unenroll(f, last: last, retried: true);
      }
      // Firebase ends the sessions that used the removed factor: it is
      // removed, but this device has to sign in again.
      message = code == 'user-token-expired' ? "Phone number removed. Sign in again to continue." : MfaErrors.messageKey(e.code);
    } catch (_) {
      message = MfaErrors.fallback;
    }
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(message.tr);
  }
}

/// The number to add: international format, prefilled from the profile.
class _PhoneForm extends StatefulWidget {
  final String initial;

  const _PhoneForm({required this.initial});

  @override
  State<_PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends State<_PhoneForm> {
  late final TextEditingController _phone = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final String? phone = MfaPhone.normalize(_phone.text);
    if (phone == null) {
      setState(() => _error = "Enter a valid phone number with its country code.");
      return;
    }
    Navigator.of(context).pop(phone);
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("We send a code to this number now, then at each sign-in.".tr, style: DsTypography.body.copyWith(color: c.textSecondary)),
        const DsGap(DsSpace.md),
        DsTextField(
          label: "Phone number".tr,
          hint: "+237 6 12 34 56 78",
          helper: "With the country code, for example +237.".tr,
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          prefixIcon: Icons.smartphone_rounded,
          autofocus: true,
          autofillHints: const [AutofillHints.telephoneNumber],
          errorText: _error?.tr,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        DsButton.primary(label: "Send the code".tr, icon: Icons.send_rounded, expand: true, onPressed: _submit),
      ],
    );
  }
}

// -------------------------------------------------------- notifications

/// Finance > Profile > Notifications: what Spideli Finance sends by push,
/// SMS and email, per category, saved to `users/{uid}.financeNotificationPrefs`
/// (the user's own document, that field only). Security notices are always
/// sent and are not a choice.
class FinanceNotificationsScreen extends StatefulWidget {
  const FinanceNotificationsScreen({super.key});

  @override
  State<FinanceNotificationsScreen> createState() => _FinanceNotificationsScreenState();
}

class _FinanceNotificationsScreenState extends State<FinanceNotificationsScreen> {
  Stream<Map<String, dynamic>>? _profile;

  /// The choices being saved, shown until the save is done.
  Map<String, Map<String, bool>>? _saving;

  @override
  void initState() {
    super.initState();
    if (FinanceService.uid.isNotEmpty) _profile = FinanceService.myProfile();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _profile;
    return FinScaffold(
      title: "Notifications".tr,
      body: stream == null
          ? FinBody(children: [FinState.empty(Icons.notifications_off_outlined, "Sign in to choose your notifications.".tr)])
          : StreamBuilder<Map<String, dynamic>>(
              stream: stream,
              builder: (context, snap) {
                final Map<String, Map<String, bool>>? saving = _saving;
                if (saving == null && snap.hasError) {
                  return FinBody(children: [
                    FinState.error("Could not load your preferences. Check your connection and try again.".tr, onRetry: () {
                      FinanceService.retry();
                      setState(() {});
                    }),
                  ]);
                }
                if (saving == null && !snap.hasData) return FinBody(children: [FinState.loading()]);
                final prefs = saving ?? FinanceNotificationPrefs.resolve(snap.data?[FinanceNotificationPrefs.field]);
                return FinBody(children: [
                  DsInlineAlert(
                    tone: DsTone.info,
                    icon: Icons.lock_outline_rounded,
                    title: "Security notices are always sent".tr,
                    message: "New sign-ins, password and two-step verification changes: you always receive them, whatever you choose here.".tr,
                  ),
                  for (final channel in FinanceNotificationPrefs.channels)
                    FinSection(
                      title: _channelTitle(channel).tr,
                      footnote: _channelNote(channel).tr,
                      divided: true,
                      children: [for (final category in FinanceNotificationPrefs.categories) _toggle(context, prefs, channel, category)],
                    ),
                ]);
              },
            ),
    );
  }

  Widget _toggle(BuildContext context, Map<String, Map<String, bool>> prefs, String channel, String category) {
    final c = DsColors.of(context);
    final (String title, String about) = _category(channel, category);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: prefs[channel]?[category] ?? false,
      title: Text(title.tr, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
      subtitle: Text(about.tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
      onChanged: (on) => _save(prefs, channel, category, on),
    );
  }

  /// Saves the whole preferences (that field only) at once, so the admin's
  /// senders always read a complete map.
  Future<void> _save(Map<String, Map<String, bool>> current, String channel, String category, bool on) async {
    final next = FinanceNotificationPrefs.withChoice(current, channel, category, on);
    setState(() => _saving = next);
    try {
      await FirebaseFirestore.instance.collection(CollectionName.users).doc(FinanceService.uid).update({FinanceNotificationPrefs.field: next});
    } catch (_) {
      if (!mounted) return;
      ShowToastDialog.showToast("Could not save your choice. Check your connection and try again.".tr);
      // Back to what is saved (unless a newer choice is on its way).
      if (identical(_saving, next)) setState(() => _saving = null);
      return;
    }
    if (mounted && identical(_saving, next)) setState(() => _saving = null);
  }

  static String _channelTitle(String channel) => switch (channel) {
        FinanceNotificationPrefs.push => "Push notifications",
        FinanceNotificationPrefs.sms => "SMS",
        _ => "Email",
      };

  static String _channelNote(String channel) => switch (channel) {
        FinanceNotificationPrefs.push => "On this phone, when notifications are allowed for Spideli.",
        FinanceNotificationPrefs.sms => "Sent to the phone number of your profile.",
        _ => "Sent to the email address of your profile.",
      };

  /// A category's name and what it covers (translation keys); by email,
  /// payments are the receipts.
  static (String, String) _category(String channel, String category) => switch (category) {
        FinanceNotificationPrefs.payments => (
            "Payments and transfers",
            channel == FinanceNotificationPrefs.email ? "Receipts of your payments, transfers and bills" : "Money received and sent, bills, deposits and withdrawals",
          ),
        FinanceNotificationPrefs.groups => ("Savings and tontines", "Contributions due, payouts and invitations"),
        FinanceNotificationPrefs.loans => ("Loans", "Votes, funding and repayments due"),
        FinanceNotificationPrefs.investments => ("Investments", "Orders, redemptions and reports"),
        FinanceNotificationPrefs.insurance => ("Insurance", "Quotes, premiums due and claims"),
        _ => ("News and markets", "Market updates and Spideli Finance news"),
      };
}
