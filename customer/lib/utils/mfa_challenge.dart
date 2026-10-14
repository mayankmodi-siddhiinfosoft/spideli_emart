import 'dart:async';

import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'auth_security_rules.dart';

export 'auth_security_rules.dart';

/// Presents the code form in a bottom sheet titled [title]; completes with
/// true once verified, null / false when closed. The sign-in screens use the
/// app's sheet ([DsBottomSheet]); Spideli Finance passes its own (finSheet)
/// for its navy identity.
typedef MfaSheet = Future<bool?> Function(Widget child, String title);

/// Two-step verification (Firebase Auth multi-factor, SMS second factor).
///
/// Sign-in: an account with a second factor makes every Firebase sign-in /
/// re-authentication throw [FirebaseAuthMultiFactorException]
/// (`multi-factor-auth-required`); [signIn] catches it, sends the code to the
/// enrolled phone, asks it and completes the sign-in. Accounts without a
/// second factor sign in exactly as before (nothing is caught for them).
///
/// Needs Identity Platform (Firebase Authentication with Identity Platform)
/// with SMS multi-factor turned on for the project; until then enrolling
/// fails with `operation-not-allowed` / `admin-restricted-operation` and no
/// account can have a second factor.
abstract final class MfaChallenge {
  /// Runs [signIn] (signInWith… / reauthenticateWith…). When the account has
  /// two-step verification, asks the SMS code and completes it: the
  /// [UserCredential] of the completed sign-in, or null when the user closed
  /// the code sheet (nobody is signed in then). Every other error is thrown
  /// unchanged, so the caller's own handling stays what it was.
  static Future<UserCredential?> signIn(Future<UserCredential> Function() signIn, {MfaSheet? sheet}) async {
    try {
      return await signIn();
    } on FirebaseAuthMultiFactorException catch (e) {
      return resolve(e, sheet: sheet);
    }
  }

  /// Completes a sign-in that needs the second factor: sends the code to the
  /// enrolled phone (the first phone factor of the account), asks it, then
  /// `resolver.resolveSignIn`. Null when the user closed the sheet. Throws a
  /// [FirebaseAuthException] when the code cannot be sent, or with code
  /// `unsupported-second-factor` when the account has no phone factor (a
  /// factor this app does not offer, e.g. an authenticator app).
  ///
  /// A loader shown by the caller is closed while the sheet is open and shown
  /// again afterwards, so the caller's own closeLoader() still matches.
  static Future<UserCredential?> resolve(FirebaseAuthMultiFactorException e, {MfaSheet? sheet}) async {
    final MultiFactorResolver resolver = e.resolver;
    final PhoneMultiFactorInfo? hint = resolver.hints.whereType<PhoneMultiFactorInfo>().firstOrNull;
    if (hint == null) throw FirebaseAuthException(code: 'unsupported-second-factor', message: 'No phone second factor.');
    final bool hadLoader = EasyLoading.isShow;
    UserCredential? result;
    await verifyBySms(
      session: resolver.session,
      factor: hint,
      title: "Two-step verification".tr,
      sheet: sheet,
      complete: (credential) async {
        try {
          result = await resolver.resolveSignIn(PhoneMultiFactorGenerator.getAssertion(credential));
          return null;
        } on FirebaseAuthException catch (err) {
          return MfaErrors.messageKey(err.code);
        }
      },
    );
    // Also when the sheet was closed while the code was being checked: the
    // sign-in went through, the caller must not treat it as cancelled.
    if (result != null && hadLoader) ShowToastDialog.showLoader("Please wait...".tr);
    return result;
  }

  /// Sends an SMS code (to [phoneNumber] when enrolling a new number, to
  /// [factor] when signing in) in the multi-factor [session], asks it in a
  /// sheet and hands the credential to [complete], which returns null when
  /// done or a message key shown in the sheet (wrong code: the user types it
  /// again). True when completed, false when the user closed the sheet.
  /// Throws a [FirebaseAuthException] when the first code cannot be sent.
  static Future<bool> verifyBySms({
    required MultiFactorSession session,
    String? phoneNumber,
    PhoneMultiFactorInfo? factor,
    required Future<String?> Function(PhoneAuthCredential credential) complete,
    String? title,
    MfaSheet? sheet,
  }) async {
    final sms = _SmsSession(session: session, phoneNumber: phoneNumber, factor: factor);
    ShowToastDialog.showLoader("Sending the code...".tr);
    try {
      await sms.send();
    } catch (_) {
      sms.dispose();
      rethrow;
    } finally {
      ShowToastDialog.closeLoader();
    }
    try {
      final MfaSheet open = sheet ?? _appSheet;
      final bool? ok = await open(_CodeForm(sms: sms, phone: phoneNumber ?? factor?.phoneNumber ?? '', complete: complete), title ?? "Two-step verification".tr);
      return ok == true;
    } finally {
      sms.dispose();
    }
  }

  static Future<bool?> _appSheet(Widget child, String title) => DsBottomSheet.show<bool>(title: title, child: child);
}

/// One SMS verification of a multi-factor session: the verification id of
/// the last code sent and, on Android, the credential read from the SMS.
class _SmsSession {
  final MultiFactorSession session;
  final String? phoneNumber;
  final PhoneMultiFactorInfo? factor;

  String? verificationId;
  int? _resendToken;

  /// The sheet is closed: a late callback (Android reading the SMS) is ignored.
  bool _closed = false;

  /// Android verified the code itself (read the SMS): the form completes with it.
  final ValueNotifier<PhoneAuthCredential?> auto = ValueNotifier(null);

  _SmsSession({required this.session, this.phoneNumber, this.factor});

  /// Sends a code (again with the resend token); completes once it is sent
  /// or Android verified the number, throws when it could not be sent.
  Future<void> send() {
    final done = Completer<void>();
    void ok() {
      if (!done.isCompleted) done.complete();
    }

    void failed(Object e) {
      if (!done.isCompleted) done.completeError(e);
    }

    FirebaseAuth.instance
        .verifyPhoneNumber(
          phoneNumber: factor == null ? phoneNumber : null,
          multiFactorInfo: factor,
          multiFactorSession: session,
          forceResendingToken: _resendToken,
          verificationCompleted: (credential) {
            if (_closed) return;
            auto.value = credential;
            ok();
          },
          verificationFailed: failed,
          codeSent: (id, token) {
            verificationId = id;
            _resendToken = token;
            ok();
          },
          codeAutoRetrievalTimeout: (_) {},
        )
        .catchError(failed);
    // Never a loader for ever (no callback at all, e.g. a reCAPTCHA closed on iOS).
    return done.future.timeout(const Duration(seconds: 90), onTimeout: () => throw FirebaseAuthException(code: 'code-not-sent'));
  }

  void dispose() {
    _closed = true;
    auto.dispose();
  }
}

/// The code sheet: the 6-digit code, Verify, Send a new code.
class _CodeForm extends StatefulWidget {
  final _SmsSession sms;
  final String phone;
  final Future<String?> Function(PhoneAuthCredential credential) complete;

  const _CodeForm({required this.sms, required this.phone, required this.complete});

  @override
  State<_CodeForm> createState() => _CodeFormState();
}

class _CodeFormState extends State<_CodeForm> {
  final TextEditingController _code = TextEditingController();
  String? _error;
  String? _info;
  bool _busy = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    widget.sms.auto.addListener(_onAuto);
    // Already verified before the sheet opened (Android instant verification).
    if (widget.sms.auto.value != null) WidgetsBinding.instance.addPostFrameCallback((_) => _onAuto());
  }

  @override
  void dispose() {
    widget.sms.auto.removeListener(_onAuto);
    _code.dispose();
    super.dispose();
  }

  void _onAuto() {
    final PhoneAuthCredential? credential = widget.sms.auto.value;
    if (credential == null || _busy || !mounted) return;
    if ((credential.smsCode ?? '').isNotEmpty) _code.text = credential.smsCode!;
    _submit(credential);
  }

  Future<void> _verify() async {
    final String code = _code.text.trim();
    final String? id = widget.sms.verificationId;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = "Enter the 6-digit code sent by SMS.");
      return;
    }
    if (id == null) return;
    await _submit(PhoneAuthProvider.credential(verificationId: id, smsCode: code));
  }

  Future<void> _submit(PhoneAuthCredential credential) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    String? error;
    try {
      error = await widget.complete(credential);
    } catch (_) {
      error = MfaErrors.fallback;
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    String? error;
    try {
      await widget.sms.send();
    } on FirebaseAuthException catch (e) {
      error = MfaErrors.messageKey(e.code);
    } catch (_) {
      error = MfaErrors.fallback;
    }
    if (!mounted) return;
    setState(() {
      _resending = false;
      _error = error;
      _info = error == null ? "A new code was sent." : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("${"Enter the code sent by SMS to".tr} ${widget.phone}", style: DsTypography.body.copyWith(color: c.textPrimary)),
        const DsGap(DsSpace.md),
        DsTextField(
          label: "Code".tr,
          controller: _code,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofocus: true,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          errorText: _error?.tr,
          helper: _info?.tr,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) {
            if (!_busy) _verify();
          },
        ),
        DsButton.primary(label: "Verify".tr, expand: true, loading: _busy, onPressed: _busy ? null : _verify),
        const DsGap(DsSpace.xs),
        DsButton.ghost(label: "Send a new code".tr, expand: true, loading: _resending, onPressed: _busy || _resending ? null : _resend),
      ],
    );
  }
}
