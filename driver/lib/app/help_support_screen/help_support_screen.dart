import 'dart:io';
import 'package:driver/app/chat_screens/chat_video_container.dart';
import 'package:driver/app/chat_screens/full_screen_image_viewer.dart';
import 'package:driver/app/chat_screens/full_screen_video_viewer.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/help_support_controller.dart';
import 'package:driver/models/conversation_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:driver/widget/firebase_pagination/src/models/view_type.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Help & support chat with the admin (archetype I): admin bubbles on the left
/// with their author label, the driver's own on the right with delivery ticks,
/// and a sticky composer.
class HelpSupportScreen extends StatelessWidget {
  HelpSupportScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: HelpSupportController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;
          return DsScaffold(
            backgroundColor: c.background,
            // appBar: AppBar(
            //   backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
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
            //     child: Icon(
            //       Icons.chevron_left_outlined,
            //       color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
            //     ),
            //   ),
            //   title: Text(
            //     'Help & Support'.tr,
            //     style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.bold, fontSize: 18),
            //   ),
            //   elevation: 0,
            //   bottom: PreferredSize(
            //     preferredSize: const Size.fromHeight(4.0),
            //     child: Container(
            //       color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
            //       height: 4.0,
            //     ),
            //   ),
            // ),
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
                onEmpty: DsEmptyState(
                  icon: Icons.support_agent_rounded,
                  compact: true,
                  title: "No conversion found".tr,
                ),
                viewType: ViewType.list,
                // to fetch real-time data
                itemBuilder: (context, documentSnapshots, index) {
                  ConversationModel inboxModel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);
                  return chatItemView(isMe: inboxModel.senderId == FireStoreUtils.getCurrentUid(), data: inboxModel, context: context, controller: controller);
                },
              ),
            ),
            bottomBar: DsStickyBar(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DsIconButton(
                    icon: Icons.camera_alt_outlined,
                    semanticLabel: 'Send Media'.tr,
                    variant: DsIconButtonVariant.tonal,
                    onPressed: () async {
                      _onCameraClick(controller: controller, context: context);
                    },
                  ),
                  const DsGap(DsSpace.sm),
                  Flexible(
                    child: TextField(
                      style: t.body,
                      cursorColor: c.brand,
                      textInputAction: TextInputAction.send,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.sentences,
                      controller: controller.messageController.value,
                      minLines: 1,
                      maxLines: 4,
                      decoration: DsInputDecoration.of(context, hint: 'Start typing with admin...'.tr),
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
                    variant: DsIconButtonVariant.filled,
                    size: 52,
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
        });
  }

  Widget chatItemView({required bool isMe, required ConversationModel data, required BuildContext context, required HelpSupportController controller}) {
    final c = context.dsColors;
    final t = context.dsText;
    final BorderRadius radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(DsRadius.lg),
            topRight: Radius.circular(DsRadius.lg),
            bottomLeft: Radius.circular(DsRadius.lg),
            bottomRight: Radius.circular(DsRadius.xs),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(DsRadius.lg),
            topRight: Radius.circular(DsRadius.lg),
            bottomRight: Radius.circular(DsRadius.lg),
            bottomLeft: Radius.circular(DsRadius.xs),
          );

    Widget media() {
      if (data.messageType == "image") {
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
          child: ClipRRect(
            borderRadius: radius,
            child: GestureDetector(
              onTap: () {
                Get.to(FullScreenImageViewer(
                  imageUrl: data.url!.url,
                ));
              },
              child: Hero(
                tag: data.url!.url,
                child: DsImage(url: data.url!.url, width: 180, height: 180, radius: 0),
              ),
            ),
          ),
        );
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
        child: DsPressable(
          onTap: () {
            Get.to(FullScreenVideoViewer(
              heroTag: data.id.toString(),
              videoUrl: data.url!.url,
            ));
          },
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(alignment: Alignment.center, children: [
              Hero(
                tag: data.url!.url,
                child: DsImage(url: data.videoThumbnail ?? '', width: 180, height: 180, radius: 0),
              ),
              DsIconWell(icon: Icons.play_arrow_rounded, tone: DsTone.brand, size: 48, circle: true),
            ]),
          ),
        ),
      );
    }

    Widget bubble() {
      if (data.messageType == "text") {
        return Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75, // prevent overflow
          ),
          decoration: BoxDecoration(
            color: isMe ? c.brand : c.surface,
            borderRadius: radius,
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
      return media();
    }

    return Padding(
      padding: EdgeInsets.only(left: isMe ? 80 : DsSpace.md, right: isMe ? DsSpace.md : 80, top: DsSpace.sm, bottom: DsSpace.sm),
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
                  Flexible(child: bubble()),
                  const DsGap(DsSpace.xs),
                  DsAvatar(
                    imageUrl: controller.userModel.value.profilePictureURL.toString(),
                    name: controller.userModel.value.fullName(),
                    size: 28,
                  ),
                ],
              )
            else
              bubble(),
            const DsGap(DsSpace.xs),
            if (isMe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Constant.dateAndTimeFormatTimestamp(data.createdAt), style: t.caption),
                  const DsGap(DsSpace.xs),
                  data.seen == true
                      ? Icon(Icons.done_all_rounded, size: 14, color: c.brandStrong)
                      : Icon(Icons.done_rounded, size: 14, color: c.textMuted),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Admin", style: t.labelSm.withColor(c.textPrimary)),
                  Text(Constant.dateAndTimeFormatTimestamp(data.createdAt), style: t.caption),
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
      message: Text('Send Media'.tr, style: context.dsText.labelSm),
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
        )
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text(
          'Cancel'.tr,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }
}
