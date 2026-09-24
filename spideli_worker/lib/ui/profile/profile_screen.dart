import 'dart:io';

import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/profile_controller.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/chat_screen/inbox_screen.dart';
import 'package:spideliworker/ui/help_support_screen/help_support_screen.dart';
import 'package:spideliworker/ui/language_screen.dart';
import 'package:spideliworker/ui/login/login_screen.dart';
import 'package:spideliworker/ui/privacyPolicy/privacy_policy.dart';
import 'package:spideliworker/ui/termsAndCondition/terms_and_codition.dart';
import 'package:spideliworker/ui/theme_change_screen/theme_change_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Profile (archetype E): an identity card with the avatar, name, e-mail and
/// an availability switch, then grouped [DsTileGroup] settings rows with the
/// destructive "Logout" row on its own. Two columns on tablets.
class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<ProfileController>(
        init: ProfileController(),
        builder: (controller) {
          // Read synchronously so this GetX tracks the availability switch.
          final bool online = controller.online.value;
          final l = context.dsLayout;

          final Widget account = DsTileGroup(
            title: 'Account'.tr,
            children: [
              DsListTile(
                title: "Inbox".tr,
                leadingIcon: Icons.forum_outlined,
                showChevron: true,
                onTap: () {
                  Get.to(const InboxScreen());
                },
              ),
              DsListTile(
                title: "Help & Support".tr,
                leadingIcon: Icons.support_agent_outlined,
                showChevron: true,
                onTap: () {
                  Get.to(HelpSupportScreen(isNavigateViaNotification: false));
                },
              ),
            ],
          );

          final Widget preferences = DsTileGroup(
            title: 'Preferences'.tr,
            children: [
              DsListTile(
                title: "App Theme".tr,
                leadingIcon: Icons.dark_mode_outlined,
                showChevron: true,
                onTap: () {
                  Get.to(const ThemeChangeScreen());
                },
              ),
              DsListTile(
                title: "App Language".tr,
                leadingIcon: Icons.translate_rounded,
                showChevron: true,
                onTap: () {
                  Get.to(const LanguageScreen());
                },
              ),
            ],
          );

          final Widget legal = DsTileGroup(
            title: 'Legal'.tr,
            children: [
              DsListTile(
                title: "Terms & Condition".tr,
                leadingIcon: Icons.gavel_rounded,
                showChevron: true,
                onTap: () {
                  Get.to(const TermsAndCondition());
                },
              ),
              DsListTile(
                title: "Privacy policy".tr,
                leadingIcon: Icons.privacy_tip_outlined,
                showChevron: true,
                onTap: () {
                  Get.to(const PrivacyPolicy());
                },
              ),
            ],
          );

          final Widget session = DsTileGroup(
            children: [
              DsListTile(
                title: "Logout".tr,
                leadingIcon: Icons.logout_rounded,
                destructive: true,
                onTap: () async {
                  MyAppState.currentUser = null;
                  await FirebaseAuth.instance.signOut();
                  Get.offAll(const LoginScreen());
                },
              ),
            ],
          );

          return DsScaffold(
            title: "Profile".tr,
            showBack: false,
            maxContentWidth: DsLayout.wideMax,
            actions: [
              DsIconButton(
                icon: Icons.info_outline,
                semanticLabel: 'My Provider'.tr,
                onPressed: () {
                  viewProviderInfo(controller, themeChange, context);
                },
              ),
            ],
            body: ListView(
              padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
              children: DsFadeSlideIn.stagger([
                _identityCard(context, controller, online),
                const DsGap(DsSpace.xl),
                if (l.isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: [account, const DsGap(DsSpace.lg), preferences])),
                      const DsGap(DsSpace.xxl),
                      Expanded(child: Column(children: [legal, const DsGap(DsSpace.lg), session])),
                    ],
                  )
                else ...[
                  account,
                  const DsGap(DsSpace.lg),
                  preferences,
                  const DsGap(DsSpace.lg),
                  legal,
                  const DsGap(DsSpace.lg),
                  session,
                ],
              ]),
            ),
          );
        });
  }

  /// Avatar + name + e-mail + the "Available Status" switch.
  Widget _identityCard(BuildContext context, ProfileController controller, bool online) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      padding: const EdgeInsets.all(DsSpace.xl),
      child: Column(
        children: [
          Stack(
            alignment: AlignmentDirectional.bottomEnd,
            children: [
              DsAvatar(
                imageUrl: MyAppState.currentUser!.profilePictureURL.toString(),
                name: MyAppState.currentUser!.fullName(),
                size: 104,
                ring: true,
                statusTone: online ? DsTone.success : DsTone.neutral,
              ),
              DsIconButton(
                icon: Icons.camera_alt,
                semanticLabel: 'Add Profile Picture'.tr,
                variant: DsIconButtonVariant.brand,
                size: 40,
                onPressed: () => _onCameraClick(context, controller),
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          Text(MyAppState.currentUser!.fullName(), textAlign: TextAlign.center, style: t.title),
          const DsGap(DsSpace.xxs),
          Text(MyAppState.currentUser!.email.toString(), textAlign: TextAlign.center, style: t.bodySecondary),
          const DsGap(DsSpace.lg),
          Divider(height: 1, color: c.divider),
          const DsGap(DsSpace.md),
          Row(
            children: [
              DsIconWell(
                icon: online ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                tone: online ? DsTone.success : DsTone.neutral,
                size: 40,
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available Status'.tr, style: t.titleSm),
                    MyAppState.currentUser?.online == true
                        ? Text('You are online'.tr, style: t.bodySm.withColor(c.successStrong))
                        : Text('You are offline'.tr, style: t.bodySm.withColor(c.dangerStrong)),
                  ],
                ),
              ),
              Semantics(
                label: 'Available Status'.tr,
                toggled: online,
                child: CupertinoSwitch(
                  activeTrackColor: c.brand,
                  value: online,
                  onChanged: (value) async {
                    // Spec 3.6: unverified workers cannot go online.
                    if (value && Get.isRegistered<VerificationController>() && !Get.find<VerificationController>().canReceiveJobs) {
                      ShowToastDialog.showToast("Your documents must be approved before you can go online.".tr);
                      return;
                    }
                    controller.online.value = value;
                    MyAppState.currentUser!.online = controller.online.value;
                    await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
                    controller.update();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void viewProviderInfo(ProfileController controller, themeChange, context) {
    final BuildContext ctx = context;
    final c = ctx.dsColors;
    final t = ctx.dsText;
    Get.bottomSheet(
      DsSheet(
        title: 'My Provider'.tr,
        showClose: true,
        child: DsObserve(
          builder: (_) => DsCard.outlined(
            child: Column(
              children: [
                Row(
                  children: [
                    DsAvatar(
                      imageUrl: controller.provider.value.profilePictureURL != "" ? controller.provider.value.profilePictureURL.toString() : placeholderImage,
                      name: controller.provider.value.fullName().toString(),
                      size: 60,
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(controller.provider.value.fullName().toString(), style: t.titleSm),
                          const DsGap(DsSpace.xs),
                          RatingBar.builder(
                            initialRating: double.parse(controller.provider.value.reviewsCount != 0
                                ? (controller.provider.value.reviewsSum / controller.provider.value.reviewsCount).toStringAsFixed(1)
                                : 0.toString()),
                            direction: Axis.horizontal,
                            itemSize: 20,
                            ignoreGestures: true,
                            itemPadding: const EdgeInsets.only(right: DsSpace.xs),
                            itemBuilder: (context, _) => Icon(
                              Icons.star,
                              color: c.warning,
                            ),
                            onRatingUpdate: (double rate) {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.md),
                Divider(height: 1, color: c.divider),
                DsListTile(
                  title: controller.provider.value.email.toString(),
                  leadingIcon: Icons.email_outlined,
                ),
                DsListTile(
                  title: controller.provider.value.phoneNumber.toString(),
                  leadingIcon: Icons.phone_in_talk_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  void showDeleteAccountAlertDialog(BuildContext context) {
    // set up the button
    Widget okButton = TextButton(
      child: Text("Ok".tr),
      onPressed: () async {
        ShowToastDialog.showLoader("Please wait".tr);
        await FireStoreUtils.deleteUser();
        MyAppState.currentUser = null;
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Account delete".tr);
        Get.offAll(const LoginScreen());
      },
    );
    Widget cancel = TextButton(
      child: Text("Cancel".tr),
      onPressed: () {
        Get.back();
      },
    );

    Get.defaultDialog(
        title: "Account delete".tr,
        content: Text("Are you sure want to delete Account.".tr),
        actions: [
          okButton,
          cancel,
        ],
        radius: 10.0);
  }

  final ImagePicker imagePicker = ImagePicker();

  void _onCameraClick(context, controller) {
    final action = CupertinoActionSheet(
      message: const Text(
        'Add Profile Picture',
        style: TextStyle(fontSize: 15.0),
      ),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () async {
            Get.back();
            showProgress(context, 'removingPicture'.tr, false);
            MyAppState.currentUser!.profilePictureURL = '';
            await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
            hideProgress();
            controller.update();
          },
          child: Text('Remove picture'.tr),
        ),
        CupertinoActionSheetAction(
          child: Text('Choose Image From Gallery'.tr),
          onPressed: () async {
            Get.back();
            XFile? image = await imagePicker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              await _imagePicked(File(image.path), controller, context);
            }
            controller.update();
          },
        ),
        CupertinoActionSheetAction(
          child: Text('Take a picture'.tr),
          onPressed: () async {
            Get.back();
            XFile? image = await imagePicker.pickImage(source: ImageSource.camera);
            if (image != null) {
              await _imagePicked(File(image.path), controller, context);
            }
            controller.update();
          },
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel'.tr),
        onPressed: () {
          Get.back();
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  Future<void> _imagePicked(File image, controller, context) async {
    showProgress(context, 'Uploading image...'.tr, false);
    MyAppState.currentUser!.profilePictureURL = await FireStoreUtils.uploadUserImageToFireStorage(image, MyAppState.currentUser!.id.toString());
    await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
    hideProgress();
    controller.update();
  }
}
