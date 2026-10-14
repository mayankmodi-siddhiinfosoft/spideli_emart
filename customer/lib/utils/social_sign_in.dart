import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/auth_screens/widgets/auth_shell.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/mfa_challenge.dart';
import 'package:customer/utils/push_token_sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// LinkedIn sign-in for the login and sign-up screens: the same flow as
/// Google (a new account completes its profile on the sign-up screen, which
/// creates `users/{uid}`; an existing customer goes to the app).
abstract final class SocialSignIn {
  static AuthProviderFlags? _flags;

  /// The last flags read in this session, if any (no flash on a rebuild).
  static AuthProviderFlags? get cachedFlags => _flags;

  /// `settings/authProviders`; [AuthProviderFlags.none] when it cannot be
  /// read (offline, not configured, Firebase not ready). A failed read is
  /// tried again next time.
  static Future<AuthProviderFlags> flags() async {
    final AuthProviderFlags? cached = _flags;
    if (cached != null) return cached;
    try {
      final snap = await FirebaseFirestore.instance.collection(CollectionName.settings).doc('authProviders').get();
      return _flags = AuthProviderFlags.parse(snap.data());
    } catch (_) {
      return AuthProviderFlags.none;
    }
  }

  /// Signs in with the LinkedIn OIDC provider [providerId] (second step
  /// included when the account has two-step verification) behind the
  /// loader. Null when cancelled or refused (the message is shown here).
  static Future<UserCredential?> signInWithLinkedIn(String providerId) async {
    final OAuthProvider provider = OAuthProvider(providerId)
      ..addScope('openid')
      ..addScope('profile')
      ..addScope('email');
    ShowToastDialog.showLoader("please wait...".tr);
    String? message;
    UserCredential? credential;
    try {
      credential = await MfaChallenge.signIn(() => FirebaseAuth.instance.signInWithProvider(provider));
    } on FirebaseAuthException catch (e) {
      debugPrint("LinkedIn sign-in failed: ${e.code}");
      message = SocialAuthRules.linkedInErrorKey(e.code);
    } catch (e) {
      debugPrint("LinkedIn sign-in failed: ${e.runtimeType}");
      message = 'Something went wrong. Please try again.';
    }
    // Before the toast: EasyLoading has one overlay.
    ShowToastDialog.closeLoader();
    if (message != null) ShowToastDialog.showToast(message.tr);
    return credential;
  }

  /// A first sign-in, or an account without a customer profile yet.
  static Future<bool> isNewCustomer(UserCredential credential) async =>
      credential.additionalUserInfo?.isNewUser == true || !await FireStoreUtils.userExistOrNot(credential.user!.uid);

  /// The profile the sign-up screen completes, from the provider's claims
  /// (given / family name, email) like the Google flow.
  static UserModel newProfile(UserCredential credential, String provider) {
    final User user = credential.user!;
    final Map<String, dynamic> claims = credential.additionalUserInfo?.profile ?? const {};
    final (String first, String last) = SocialAuthRules.splitName(
      given: claims['given_name']?.toString(),
      family: claims['family_name']?.toString(),
      display: user.displayName ?? claims['name']?.toString(),
    );
    final UserModel userModel = UserModel();
    userModel.id = user.uid;
    userModel.email = user.email ?? claims['email']?.toString();
    userModel.firstName = first;
    userModel.lastName = last;
    userModel.provider = provider;
    return userModel;
  }

  /// An existing customer after a social sign-in: the same checks and
  /// destinations as the Google flow of LoginController.
  static Future<void> openExistingCustomer(String uid) async {
    final UserModel? userModel = await FireStoreUtils.getUserProfile(uid);
    if (userModel != null && userModel.role == Constant.userRoleCustomer) {
      if (userModel.active == true) {
        await FireStoreUtils.updateUser(userModel);
        // This device's token, field-level (never '' over a good one).
        unawaited(PushTokenSync.syncForCurrentUser());

        if (userModel.shippingAddress != null && userModel.shippingAddress!.isNotEmpty) {
          final defaultAddress = userModel.shippingAddress!.firstWhere((e) => e.isDefault == true, orElse: () => userModel.shippingAddress!.first);
          Constant.selectedLocation = defaultAddress;
          Get.offAll(() => const ServiceListScreen());
        } else {
          Get.offAll(() => const LocationPermissionScreen());
        }
      } else {
        await FirebaseAuth.instance.signOut();
        ShowToastDialog.showToast("This user is disabled. Please contact admin.".tr);
        Get.offAll(() => const LoginScreen());
      }
    } else {
      await FirebaseAuth.instance.signOut();
      ShowToastDialog.showToast("This user does not exist in the customer app.".tr);
      Get.offAll(() => const LoginScreen());
    }
  }
}

/// "Continue with LinkedIn", shown only when `settings/authProviders` turns
/// LinkedIn on (nothing at all otherwise). [onPressed] gets the provider id.
class LinkedInSignInButton extends StatefulWidget {
  final void Function(String providerId) onPressed;
  final EdgeInsetsGeometry padding;

  const LinkedInSignInButton({super.key, required this.onPressed, this.padding = const EdgeInsets.only(top: DsSpace.md)});

  @override
  State<LinkedInSignInButton> createState() => _LinkedInSignInButtonState();
}

class _LinkedInSignInButtonState extends State<LinkedInSignInButton> {
  AuthProviderFlags _flags = SocialSignIn.cachedFlags ?? AuthProviderFlags.none;

  @override
  void initState() {
    super.initState();
    SocialSignIn.flags().then((flags) {
      if (mounted) setState(() => _flags = flags);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_flags.linkedin) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: AuthAltButton(
        label: "Continue with LinkedIn".tr,
        icon: const _LinkedInMark(),
        onPressed: () => widget.onPressed(_flags.linkedinProviderId),
      ),
    );
  }
}

/// The LinkedIn "in" mark, drawn (no image asset needed).
class _LinkedInMark extends StatelessWidget {
  const _LinkedInMark();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFF0A66C2), borderRadius: BorderRadius.circular(4)),
          child: const Text('in', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, height: 1)),
        ),
      );
}
