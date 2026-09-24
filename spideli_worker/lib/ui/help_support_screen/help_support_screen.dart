import 'dart:io';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/help_support_controller.dart';
import 'package:spideliworker/model/chat_video_container.dart';
import 'package:spideliworker/model/conversation_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/preferences.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/chat_screen/full_screen_image_viewer.dart';
import 'package:spideliworker/ui/chat_screen/full_screen_video_viewer.dart';
import 'package:spideliworker/ui/dashboard/dashboard_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Help & Support (archetype O): a direct line to the administrator. The page
/// opens with a "Contact us" banner, then the conversation as asymmetric
/// bubbles with delivery ticks, and the composer (attach + send) sits in a
/// [DsStickyBar].
class HelpSupportScreen extends StatelessWidget {
  final bool? isNavigateViaNotification;
  HelpSupportScreen({super.key, this.isNavigateViaNotification});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    // ignore: deprecated_member_use
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
          final c = context.dsColors;
          final t = context.dsText;
          // Read synchronously so this GetX tracks the worker's avatar.
          final String myAvatar = controller.userModel.value.profilePictureURL.toString();

          return DsScaffold(
            title: "Help & Support",
            onBack: () {
              Get.back();
            },
            maxContentWidth: DsLayout.contentMax,
            body: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xs),
                  child: DsFadeSlideIn(
                    child: DsCard.tinted(
                      tone: DsTone.info,
                      padding: const EdgeInsets.all(DsSpace.md),
                      child: Row(
                        children: [
                          DsIconWell(icon: Icons.support_agent_outlined, tone: DsTone.info, size: 40, circle: true),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Text('Start typing with admin...'.tr, style: t.bodySm),
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
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                      query: FireStoreUtils.firestore.collection('chat').doc(FireStoreUtils.getCurrentUid()).collection('thread').orderBy('createdAt', descending: true),
                      isLive: true,
                      shrinkWrap: true,
                      reverse: true,
                      onEmpty: DsEmptyState(icon: Icons.forum_outlined, title: "No conversion found".tr),
                      viewType: ViewType.list,
                      initialLoader: const DsSkeletonList(itemCount: 5, leading: false, trailing: false),
                      // to fetch real-time data
                      itemBuilder: (context, documentSnapshots, index) {
                        ConversationModel inboxModel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);
                        return chatItemView(isMe: inboxModel.senderId == FireStoreUtils.getCurrentUid(), data: inboxModel, context: context, myAvatar: myAvatar);
                      },
                    ),
                  ),
                ),
              ],
            ),
            bottomBar: DsStickyBar(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DsIconButton(
                    icon: Icons.camera_alt,
                    semanticLabel: 'Send Media'.tr,
                    variant: DsIconButtonVariant.tonal,
                    onPressed: () async {
                      _onCameraClick(controller: controller, context: context);
                    },
                  ),
                  const DsGap(DsSpace.sm),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        style: t.body,
                        textInputAction: TextInputAction.send,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        controller: controller.messageController.value,
                        minLines: 1,
                        maxLines: 4,
                        decoration: DsInputDecoration.of(
                          context,
                          hint: 'Start typing with admin...'.tr,
                          contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: 12),
                        ).copyWith(
                          border: OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide(color: c.surfaceAlt)),
                          enabledBorder: OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide(color: c.isDark ? c.border : c.surfaceAlt)),
                          focusedBorder: OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide(color: c.brand, width: 1.6)),
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
          );
        },
      ),
    );
  }

  Widget chatItemView({required bool isMe, required ConversationModel data, required BuildContext context, required String myAvatar}) {
    final c = context.dsColors;
    final t = context.dsText;
    final BorderRadius bubble = isMe
        ? const BorderRadius.only(topLeft: Radius.circular(DsRadius.lg), topRight: Radius.circular(DsRadius.lg), bottomLeft: Radius.circular(DsRadius.lg))
        : const BorderRadius.only(topLeft: Radius.circular(DsRadius.lg), topRight: Radius.circular(DsRadius.lg), bottomRight: Radius.circular(DsRadius.lg));

    Widget content() {
      if (data.messageType == "text") {
        return Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75, // prevent overflow
          ),
          decoration: BoxDecoration(
            color: isMe ? c.brand : c.surface,
            borderRadius: bubble,
            border: isMe ? null : Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
          child: Text(
            data.message.toString(),
            softWrap: true,
            maxLines: null,
            style: t.body.withColor(isMe ? c.onBrand : c.textPrimary),
          ),
        );
      }
      if (data.messageType == "image") {
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
          child: ClipRRect(
            borderRadius: bubble,
            child: GestureDetector(
              onTap: () {
                Get.to(FullScreenImageViewer(imageUrl: data.url!.url));
              },
              child: Hero(
                tag: data.url!.url,
                child: DsImage(url: data.url!.url, radius: 0),
              ),
            ),
          ),
        );
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
        child: Semantics(
          button: true,
          label: 'Play'.tr,
          child: InkWell(
            borderRadius: bubble,
            onTap: () {
              Get.to(FullScreenVideoViewer(heroTag: data.id.toString(), videoUrl: data.url!.url));
            },
            child: ClipRRect(
              borderRadius: bubble,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: data.url!.url,
                    child: DsImage(url: data.videoThumbnail ?? '', height: 140, width: 200, radius: 0),
                  ),
                  DsIconWell(icon: Icons.play_arrow_rounded, tone: DsTone.brand, size: 48, circle: true),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(left: isMe ? 72 : 4, right: isMe ? 4 : 72, top: DsSpace.sm, bottom: DsSpace.sm),
      child: Align(
        alignment: isMe ? Alignment.topRight : Alignment.topLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isMe)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(child: content()),
                  const DsGap(DsSpace.sm),
                  DsAvatar(imageUrl: myAvatar, size: 28),
                ],
              )
            else
              content(),
            const DsGap(DsSpace.xs),
            Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) Text("Admin", style: t.labelSm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dateAndTimeFormatTimestamp(data.createdAt), style: t.caption),
                    if (isMe) ...[
                      const DsGap(DsSpace.xs),
                      data.seen == true
                          ? Icon(Icons.done_all_rounded, size: 14, color: c.brandStrong)
                          : Icon(Icons.done_rounded, size: 14, color: c.textMuted),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  final ImagePicker _imagePicker = ImagePicker();

  void _onCameraClick({required HelpSupportController controller, required BuildContext context}) {
    final action = CupertinoActionSheet(
      message: Text(
        'Send Media'.tr,
        style: DsTypography.labelSm.copyWith(color: DsColors.of(context).textSecondary),
      ),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDefaultAction: false,
          onPressed: () async {
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
          child: Text("Choose image from gallery".tr),
        ),
        CupertinoActionSheetAction(
          isDefaultAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? galleryVideo = await _imagePicker.pickVideo(source: ImageSource.gallery);
            if (galleryVideo != null) {
              ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(File(galleryVideo.path));
              if (videoContainer != null) {
                controller.sendMessage(message: '', url: videoContainer.videoUrl, videoThumbnail: videoContainer.thumbnailUrl, messageType: 'video');
              } else {
                ShowToastDialog.showToast("Message sent failed");
              }
            }
          },
          child: Text("Choose video from gallery".tr),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () async {
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
          child: Text("Take a Photo".tr),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? recordedVideo = await _imagePicker.pickVideo(source: ImageSource.camera);
            if (recordedVideo != null) {
              ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(File(recordedVideo.path));
              if (videoContainer != null) {
                controller.sendMessage(message: '', url: videoContainer.videoUrl, videoThumbnail: videoContainer.thumbnailUrl, messageType: 'video');
              } else {
                ShowToastDialog.showToast("Message sent failed");
              }
            }
          },
          child: Text("Record video".tr),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel'.tr),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }
}
