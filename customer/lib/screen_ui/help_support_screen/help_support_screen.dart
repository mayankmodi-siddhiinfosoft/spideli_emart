import 'dart:io';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/help_support_controller.dart';
import 'package:customer/models/conversation_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/chat_video_container.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/full_screen_image_viewer.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/full_screen_video_viewer.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/widgets/chat_widgets.dart';
import 'package:customer/screen_ui/multi_vendor_service/dash_board_screens/dash_board_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/utils/preferences.dart';
import 'package:customer/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:customer/widget/firebase_pagination/src/models/view_type.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Archetype **J — chat**: a support thread with the admin. Bubbles carry the
/// customer's avatar and delivery ticks; the composer sits in a sticky bar.
class HelpSupportScreen extends StatelessWidget {
  final bool? isNavigateViaNotification;
  HelpSupportScreen({super.key, this.isNavigateViaNotification});

  @override
  Widget build(BuildContext context) {
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
          final t = context.dsText;
          final avatarUrl = controller.userModel.value.profilePictureURL.toString();
          return DsScaffold(
            maxContentWidth: DsLayout.contentMax,
            appBar: DsAppBar(
              onBack: () async {
                if (isNavigateViaNotification == true) {
                  await Preferences.setBoolean(Preferences.isClickOnNotification, false);
                  Get.offAll(DashBoardScreen());
                } else {
                  Get.back();
                }
              },
              titleWidget: Row(
                children: [
                  DsIconWell(icon: Icons.support_agent_rounded, tone: DsTone.brand, size: 40, circle: true),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Help & Support'.tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                        Text("Admin".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomBar: ChatComposer(
              controller: controller.messageController.value,
              hint: 'Start typing with admin...'.tr,
              attachIcon: const Icon(Icons.camera_alt_outlined, size: 22),
              onAttach: () async {
                _onCameraClick(controller: controller, context: context);
              },
              onSend: () async {
                if (controller.messageController.value.text.isNotEmpty) {
                  controller.sendMessage(message: controller.messageController.value.text, url: null, videoThumbnail: '', messageType: 'text');
                  controller.messageController.value.clear();
                } else {
                  ShowToastDialog.showToast("Please enter text".tr);
                }
              },
              onSubmitted: (value) async {
                if (controller.messageController.value.text.isNotEmpty) {
                  controller.sendMessage(message: controller.messageController.value.text, url: null, videoThumbnail: '', messageType: 'text');
                  // Timer(const Duration(milliseconds: 500), () => _controller.jumpTo(_controller.position.maxScrollExtent));
                  controller.messageController.value.clear();
                }
              },
            ),
            body: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: FirestorePagination(
                controller: controller.scrollController.value,
                physics: const BouncingScrollPhysics(),
                query: FireStoreUtils.fireStore.collection(CollectionName.chat).doc(FireStoreUtils.getCurrentUid()).collection('thread').orderBy('createdAt', descending: true),
                isLive: true,
                shrinkWrap: true,
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                onEmpty: DsEmptyState(
                  icon: Icons.support_agent_rounded,
                  title: "No conversion found".tr,
                  message: "Send us a message and our team will get back to you.".tr,
                ),
                viewType: ViewType.list,
                initialLoader: const DsSkeletonList(itemCount: 4, trailing: false),
                // to fetch real-time data
                itemBuilder: (context, documentSnapshots, index) {
                  ConversationModel inboxModel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);
                  return chatItemView(
                    isMe: inboxModel.senderId == FireStoreUtils.getCurrentUid(),
                    data: inboxModel,
                    context: context,
                    controller: controller,
                    avatarUrl: avatarUrl,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget chatItemView({
    required bool isMe,
    required ConversationModel data,
    required BuildContext context,
    required HelpSupportController controller,
    required String avatarUrl,
  }) {
    late final Widget bubble;
    if (data.messageType == "text") {
      bubble = ChatTextBubble(isMe: isMe, text: data.message.toString());
    } else if (data.messageType == "image") {
      bubble = ChatMediaBubble(
        isMe: isMe,
        semanticLabel: 'Image'.tr,
        onTap: () {
          Get.to(FullScreenImageViewer(imageUrl: data.url!.url));
        },
        child: Hero(tag: data.url!.url, child: NetworkImageWidget(imageUrl: data.url!.url, height: 160, width: 200, fit: BoxFit.cover)),
      );
    } else {
      bubble = ChatMediaBubble(
        isMe: isMe,
        isVideo: true,
        maxWidth: 180,
        semanticLabel: 'Video'.tr,
        onTap: () {
          Get.to(FullScreenVideoViewer(heroTag: data.id.toString(), videoUrl: data.url!.url));
        },
        child: Hero(tag: data.url!.url, child: NetworkImageWidget(imageUrl: data.videoThumbnail ?? '', height: 140, width: 180, fit: BoxFit.cover)),
      );
    }

    return ChatMessageRow(
      isMe: isMe,
      bubble: bubble,
      senderLabel: isMe ? null : "Admin",
      timeLabel: Constant.dateAndTimeFormatTimestamp(data.createdAt),
      seen: isMe ? (data.seen == true) : null,
      avatar: isMe ? DsAvatar(imageUrl: avatarUrl, size: 28) : null,
    );
  }

  final ImagePicker _imagePicker = ImagePicker();

  void _onCameraClick({required HelpSupportController controller, required BuildContext context}) {
    final action = CupertinoActionSheet(
      message: Text('Send Media'.tr, style: DsTypography.label.copyWith(color: DsColors.of(context).textSecondary)),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDefaultAction: false,
          onPressed: () async {
            Get.back();
            try {
              XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), context);
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
              ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(context, File(galleryVideo.path));
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
                Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), context);
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
              ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(context, File(recordedVideo.path));
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
