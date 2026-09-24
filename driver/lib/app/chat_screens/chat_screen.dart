import 'dart:async';
import 'dart:io';
import 'package:driver/app/chat_screens/chat_video_container.dart';
import 'package:driver/app/chat_screens/full_screen_image_viewer.dart';
import 'package:driver/app/chat_screens/full_screen_video_viewer.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/chat_controller.dart';
import 'package:driver/models/conversation_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:driver/widget/firebase_pagination/src/models/view_type.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Order chat (archetype I): customer identity in the app bar, asymmetric
/// bubbles and a sticky composer.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: ChatController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;
          return DsScaffold(
            backgroundColor: c.background,
            appBar: DsAppBar(
              titleWidget: Row(
                children: [
                  DsAvatar(
                    imageUrl: controller.receivedProfileUrl.value,
                    name: controller.receivedName.value,
                    size: 40,
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          controller.receivedName.value,
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSm.w600,
                        ),
                        Text(
                          "${"Order".tr} ${Constant.orderId(orderId: controller.orderId.value.toString())}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.tabular,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: FirestorePagination(
                reverse: true,
                controller: controller.scrollController.value,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, documentSnapshots, index) {
                  ConversationModel chatmodel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);

                  return chatItemView(context, chatmodel.senderId == FireStoreUtils.getCurrentUid(), chatmodel);
                },
                onEmpty: DsEmptyState(
                  icon: Icons.forum_outlined,
                  compact: true,
                  title: "No Conversion found".tr,
                ),
                query: FireStoreUtils.fireStore.collection(CollectionName.chat).doc(controller.orderId.value).collection("thread").orderBy('createdAt', descending: true),
                isLive: true,
                viewType: ViewType.list,
              ),
            ),
            bottomBar: DsStickyBar(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DsIconButton(
                    icon: Icons.add_photo_alternate_outlined,
                    semanticLabel: 'Send Media'.tr,
                    variant: DsIconButtonVariant.tonal,
                    onPressed: () {
                      onCameraClick(context, controller);
                    },
                  ),
                  const DsGap(DsSpace.sm),
                  Flexible(
                    child: TextField(
                      textInputAction: TextInputAction.send,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.sentences,
                      controller: controller.messageController.value,
                      minLines: 1,
                      maxLines: 4,
                      cursorColor: c.brand,
                      style: t.body,
                      decoration: DsInputDecoration.of(context, hint: 'Type message here....'.tr),
                      onSubmitted: (value) async {
                        if (controller.messageController.value.text.isNotEmpty) {
                          controller.sendMessage(controller.messageController.value.text, null, '', 'text');
                          Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
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
                    onPressed: () {
                      if (controller.messageController.value.text.isNotEmpty) {
                        controller.sendMessage(controller.messageController.value.text, null, '', 'text');
                        Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
                        controller.messageController.value.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }

  Widget chatItemView(BuildContext context, bool isMe, ConversationModel data) {
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

    Widget bubble() {
      if (data.messageType == "text") {
        return Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: isMe ? c.brand : c.surface,
            border: isMe ? null : Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
          child: Text(
            data.message.toString(),
            style: t.body.withColor(isMe ? c.onBrand : c.textPrimary),
          ),
        );
      }
      if (data.messageType == "image") {
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
          child: ClipRRect(
            borderRadius: radius,
            child: GestureDetector(
              onTap: () {
                Get.to(FullScreenImageViewer(imageUrl: data.url!.url));
              },
              child: Hero(
                tag: data.url!.url,
                child: DsImage(
                  url: data.url!.url,
                  width: 180,
                  height: 180,
                  radius: 0,
                ),
              ),
            ),
          ),
        );
      }
      return DsPressable(
        onTap: () {
          Get.to(FullScreenVideoViewer(heroTag: data.id.toString(), videoUrl: data.url!.url));
        },
        child: Container(
          width: 120,
          height: 88,
          decoration: BoxDecoration(borderRadius: radius, color: c.surfaceAlt, border: Border.all(color: c.border)),
          alignment: Alignment.center,
          child: DsIconWell(icon: Icons.play_arrow_rounded, tone: DsTone.brand, size: 44, circle: true),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: isMe ? 80 : DsSpace.lg, right: isMe ? DsSpace.lg : 80, top: DsSpace.sm, bottom: DsSpace.sm),
      child: Align(
        alignment: isMe ? Alignment.topRight : Alignment.topLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            bubble(),
            const DsGap(DsSpace.xs),
            Text(
              DateFormat('MMM d, yyyy hh:mm aa').format(DateTime.fromMillisecondsSinceEpoch(data.createdAt!.millisecondsSinceEpoch)),
              style: t.caption,
            ),
          ],
        ),
      ),
    );
  }

  void onCameraClick(BuildContext context, ChatController controller) {
    final action = CupertinoActionSheet(
      message: Text(
        'Send Media'.tr,
        style: const TextStyle(fontSize: 15.0),
      ),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDefaultAction: false,
          onPressed: () async {
            Get.back();
            try {
              XFile? image = await controller.imagePicker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), context);
                controller.sendMessage(controller.messageController.value.text, url, '', 'image');
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
            Get.back();
            XFile? galleryVideo = await controller.imagePicker.pickVideo(source: ImageSource.gallery);
            if (galleryVideo != null) {
              ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(context, File(galleryVideo.path));
              if (videoContainer != null) {
                controller.sendMessage(controller.messageController.value.text, videoContainer.videoUrl, videoContainer.thumbnailUrl, 'video');
              }
            }
          },
          child: Text("Choose video from gallery".tr),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () async {
            Get.back();
            try {
              XFile? image = await controller.imagePicker.pickImage(source: ImageSource.camera);
              if (image != null) {
                Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), context);
                controller.sendMessage(controller.messageController.value.text, url, '', 'image');
              }
            } catch (e) {
              ShowToastDialog.showToast("Camera access is not enabled. Please allow camera permission.");
            }
          },
          child: Text("Take a picture".tr),
        ),
        // CupertinoActionSheetAction(
        //   isDestructiveAction: false,
        //   onPressed: () async {
        //     Get.back();
        //     XFile? recordedVideo = await controller.imagePicker.pickVideo(source: ImageSource.camera);
        //     if (recordedVideo != null) {
        //       ChatVideoContainer videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(File(recordedVideo.path), context);
        //       controller.sendMessage('', videoContainer.videoUrl, videoContainer.thumbnailUrl, 'video');
        //     }
        //   },
        //   child: Text("Record video".tr),
        // )
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text(
          'Cancel'.tr,
        ),
        onPressed: () {
          Get.back();
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }
}
