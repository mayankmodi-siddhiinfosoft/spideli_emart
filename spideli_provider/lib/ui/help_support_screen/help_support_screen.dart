import 'dart:io';

import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/help_support_controller.dart';
import 'package:spideliprovider/model/chat_video_container.dart';
import 'package:spideliprovider/model/conversation_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/preferences.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/chat_screen/full_screen_image_viewer.dart';
import 'package:spideliprovider/ui/chat_screen/full_screen_video_viewer.dart';
import 'package:spideliprovider/ui/dashboard/dashboard_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/firebase_pagination/src/firestore_pagination.dart';
import 'package:spideliprovider/widgets/firebase_pagination/src/models/view_type.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class HelpSupportScreen extends StatelessWidget {
  final bool? isNavigateViaNotification;
  HelpSupportScreen({super.key, this.isNavigateViaNotification});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    return WillPopScope(
      onWillPop: () async {
        if (isNavigateViaNotification == true) {
          await Preferences.setBoolean(Preferences.isClickOnNotification, false);
          Get.offAll(DashBoardScreen());
        } else {
          Get.back();
        }
        return false;
      },
      child: GetX(
        init: HelpSupportController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: c.background,
            // appBar: AppBar(
            //   backgroundColor: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey50,
            //   centerTitle: false,
            //   automaticallyImplyLeading: false,
            //   titleSpacing: 0,
            //   leading: InkWell(
            //     onTap: () async {
            //       if (isNavigateViaNotification == true) {
            //         await Preferences.setBoolean(Preferences.isClickOnNotification, false);
            //         Get.offAll(DashBoardScreen());
            //       } else {
            //         Get.back();
            //       }
            //     },
            //     child: Icon(Icons.chevron_left_outlined, color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900),
            //   ),
            //   title: Text(
            //     'Help & Support'.tr,
            //     style: TextStyle(color: themeChange.getTheme() ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.bold, fontSize: 18),
            //   ),
            //   elevation: 0,
            //   bottom: PreferredSize(
            //     preferredSize: const Size.fromHeight(4.0),
            //     child: Container(color: themeChange.getTheme() ? AppThemeData.grey700 : AppThemeData.grey200, height: 4.0),
            //   ),
            // ),

            body: Column(
              children: <Widget>[
                // Support desk banner – tells this thread apart from a
                // customer conversation at a glance.
                Padding(
                  padding: EdgeInsets.fromLTRB(context.dsLayout.gutter, DsSpace.lg, context.dsLayout.gutter, DsSpace.sm),
                  child: DsFadeSlideIn(
                    child: DsCard.tinted(
                      tone: DsTone.brand,
                      padding: const EdgeInsets.all(DsSpace.lg),
                      child: Row(
                        children: [
                          const DsIconWell(icon: Icons.support_agent_rounded, tone: DsTone.brand, size: 46, circle: true),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Help & Support'.tr, style: t.titleSm),
                                const DsGap(DsSpace.xxs),
                                Text('Chat with the spideli team about your account, bookings or payouts.'.tr, style: t.bodySm),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                    },
                    child: FirestorePagination(
                      controller: controller.scrollController.value,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: context.dsLayout.gutter, vertical: DsSpace.sm),
                      query: FireStoreUtils.firestore.collection('chat').doc(FireStoreUtils.getCurrentUid()).collection('thread').orderBy('createdAt', descending: true),
                      isLive: true,
                      shrinkWrap: true,
                      reverse: true,
                      onEmpty: DsEmptyState(icon: Icons.support_agent_rounded, title: "No conversion found".tr),
                      initialLoader: const DsSkeletonList(itemCount: 5, leading: false, trailing: false),
                      viewType: ViewType.list,
                      // to fetch real-time data
                      itemBuilder: (context, documentSnapshots, index) {
                        ConversationModel inboxModel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);
                        return chatItemView(isMe: inboxModel.senderId == FireStoreUtils.getCurrentUid(), data: inboxModel, context: context, controller: controller);
                      },
                    ),
                  ),
                ),
                DsStickyBar(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      DsIconButton(
                        icon: Icons.add_photo_alternate_outlined,
                        semanticLabel: 'Send Media'.tr,
                        variant: DsIconButtonVariant.tonal,
                        onPressed: () async {
                          _onCameraClick(controller: controller, context: context);
                        },
                      ),
                      const DsGap(DsSpace.sm),
                      Flexible(
                        child: TextField(
                          style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                          textInputAction: TextInputAction.send,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          controller: controller.messageController.value,
                          minLines: 1,
                          maxLines: 4,
                          cursorColor: c.brand,
                          decoration: DsInputDecoration.of(
                            context,
                            hint: 'Start typing with admin...'.tr,
                            contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: 12),
                          ),
                          onSubmitted: (value) async {
                            if (controller.messageController.value.text.isNotEmpty) {
                              controller.sendMessage(message: controller.messageController.value.text, url: null, videoThumbnail: '', messageType: 'text');
                              // Timer(const Duration(milliseconds: 500), () => _controller.jumpTo(_controller.position.maxScrollExtent));
                              controller.messageController.value.clear();
                            }
                          },
                        ),
                      ),
                      const DsGap(DsSpace.sm),
                      DsIconButton(
                        icon: Icons.send_rounded,
                        semanticLabel: 'Send'.tr,
                        variant: DsIconButtonVariant.brand,
                        onPressed: () async {
                          if (controller.messageController.value.text.isNotEmpty) {
                            controller.sendMessage(message: controller.messageController.value.text, url: null, videoThumbnail: '', messageType: 'text');
                            controller.messageController.value.clear();
                          } else {
                            ShowToastDialog.showToast("Please enter text".tr);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Support bubble. Mine carries my avatar and the delivery ticks; the
  /// admin's is labelled so the thread never reads as a customer chat.
  Widget chatItemView({required bool isMe, required ConversationModel data, required BuildContext context, required HelpSupportController controller}) {
    final c = context.dsColors;
    final t = context.dsText;
    final BorderRadius radius = isMe
        ? const BorderRadius.only(topLeft: Radius.circular(DsRadius.lg), topRight: Radius.circular(DsRadius.lg), bottomLeft: Radius.circular(DsRadius.lg), bottomRight: Radius.circular(DsRadius.xs))
        : const BorderRadius.only(topLeft: Radius.circular(DsRadius.lg), topRight: Radius.circular(DsRadius.lg), bottomRight: Radius.circular(DsRadius.lg), bottomLeft: Radius.circular(DsRadius.xs));

    Widget bubble() {
      if (data.messageType == "text") {
        return Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.7, // prevent overflow
          ),
          decoration: BoxDecoration(
            color: isMe ? c.brand : c.surface,
            borderRadius: radius,
            border: isMe ? null : Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
          child: Text(data.message.toString(), softWrap: true, maxLines: null, style: DsTypography.bodyLg.copyWith(color: isMe ? c.onBrand : c.textPrimary)),
        );
      }
      if (data.messageType == "image") {
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Get.to(FullScreenImageViewer(imageUrl: data.url!.url));
                  },
                  child: Hero(
                    tag: data.url!.url,
                    child: DsImage(url: data.url!.url, radius: 0, width: 200, height: 200),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
        child: DsPressable(
          onTap: () {
            Get.to(FullScreenVideoViewer(heroTag: data.id.toString(), videoUrl: data.url!.url));
          },
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Hero(
                  tag: data.url!.url,
                  child: DsImage(url: data.videoThumbnail ?? '', radius: 0, width: 200, height: 160, errorIcon: Icons.movie_outlined),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: c.scrim, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow, size: 30, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: isMe ? 60 : 0, right: isMe ? 0 : 60, top: DsSpace.sm, bottom: DsSpace.sm),
      child: Align(
        alignment: isMe ? Alignment.topRight : Alignment.topLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isMe)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: bubble()),
                  const DsGap(DsSpace.sm),
                  DsAvatar(imageUrl: controller.userModel.value.profilePictureURL.toString(), name: controller.userModel.value.firstName, size: 28),
                ],
              )
            else
              bubble(),
            const DsGap(DsSpace.xs),
            if (isMe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dateAndTimeFormatTimestamp(data.createdAt), style: t.caption),
                  const DsGap(DsSpace.xs),
                  data.seen == true ? Text("✓✓", style: t.caption.withColor(c.brandStrong)) : Text("✓", style: t.caption),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsBadge(label: "Admin", tone: DsTone.info, small: true, icon: Icons.verified_user_outlined),
                  const DsGap(DsSpace.sm),
                  Text(dateAndTimeFormatTimestamp(data.createdAt), style: t.caption),
                ],
              ),
          ],
        ),
      ),
    );
  }

  final ImagePicker _imagePicker = ImagePicker();

  void _onCameraClick({required HelpSupportController controller, required BuildContext context}) {
    Get.bottomSheet(
      DsSheet(
        title: 'Send Media'.tr,
        showClose: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsListTile(
              title: "Choose image from gallery".tr,
              leadingIcon: Icons.photo_library_outlined,
              showChevron: true,
              onTap: () async {
                Get.back();
                try {
                  XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path));
                    controller.sendMessage(message: '', url: url, videoThumbnail: '', messageType: 'image');
                  }
                } catch (e) {
                  ShowToastDialog.showToast("Storage permission is not enabled. Please allow it.");
                }
              },
            ),
            DsListTile(
              title: "Choose video from gallery".tr,
              leadingIcon: Icons.video_library_outlined,
              showChevron: true,
              onTap: () async {
                Navigator.pop(context);
                XFile? galleryVideo = await _imagePicker.pickVideo(source: ImageSource.gallery);
                if (galleryVideo != null) {
                  ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(context, File(galleryVideo.path));
                  if (videoContainer != null) {
                    controller.sendMessage(message: '', url: videoContainer.videoUrl, videoThumbnail: videoContainer.thumbnailUrl, messageType: 'video');
                  } else {
                    ShowToastDialog.showToast("Message sent failed");
                  }
                }
              },
            ),
            DsListTile(
              title: "Take a Photo".tr,
              leadingIcon: Icons.photo_camera_outlined,
              showChevron: true,
              onTap: () async {
                Navigator.pop(context);
                try {
                  XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path));
                    controller.sendMessage(message: '', url: url, videoThumbnail: '', messageType: 'image');
                  }
                } catch (e) {
                  ShowToastDialog.showToast("Camera access is not enabled. Please allow camera permission.");
                }
              },
            ),
            DsListTile(
              title: "Record video".tr,
              leadingIcon: Icons.videocam_outlined,
              showChevron: true,
              onTap: () async {
                Navigator.pop(context);
                XFile? recordedVideo = await _imagePicker.pickVideo(source: ImageSource.camera);
                if (recordedVideo != null) {
                  ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(context, File(recordedVideo.path));
                  if (videoContainer != null) {
                    controller.sendMessage(message: '', url: videoContainer.videoUrl, videoThumbnail: videoContainer.thumbnailUrl, messageType: 'video');
                  } else {
                    ShowToastDialog.showToast("Message sent failed");
                  }
                }
              },
            ),
            DsGap.md,
            DsButton.secondary(
              label: 'Cancel'.tr,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
