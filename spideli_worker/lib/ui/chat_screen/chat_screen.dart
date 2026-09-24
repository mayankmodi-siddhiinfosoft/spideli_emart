import 'dart:async';
import 'dart:io';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/chat_controller.dart';
import 'package:spideliworker/model/chat_video_container.dart';
import 'package:spideliworker/model/conversation_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/chat_screen/full_screen_image_viewer.dart';
import 'package:spideliworker/ui/chat_screen/full_screen_video_viewer.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Chat (archetype H): the app bar carries the customer's avatar and the
/// booking reference, messages are asymmetric bubbles (brand for mine,
/// surface + hairline for theirs) and the composer is a pill field with a
/// filled send button inside a [DsStickyBar].
/// Pill variant of the DS input decoration, for chat composers.
InputDecoration _pill(BuildContext context, String hint) {
  final c = DsColors.of(context);
  OutlineInputBorder b(Color color, [double w = 1]) => OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide(color: color, width: w));
  return DsInputDecoration.of(context, hint: hint, contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: 12)).copyWith(
    border: b(c.surfaceAlt),
    enabledBorder: b(c.isDark ? c.border : c.surfaceAlt),
    focusedBorder: b(c.brand, 1.6),
    errorBorder: b(c.danger),
    focusedErrorBorder: b(c.danger, 1.6),
  );
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX(
      init: ChatController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        // Read synchronously so this GetX tracks the conversation.
        final String title = controller.receivedId.value == 'admin' ? 'Admin' : controller.receiverUser.value!.fullName();
        final String reference = "${controller.sectionType.value == 'adv' ? "AvdId" : "OrderId".tr} ${orderId(orderId: controller.orderId.value.toString())}";
        final String? avatarUrl = controller.receiverUser.value?.profilePictureURL;

        return Scaffold(
          backgroundColor: c.background,
          appBar: DsAppBar(
            titleWidget: Row(
              children: [
                DsAvatar(imageUrl: avatarUrl, name: title, size: 38),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                      Text(reference, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.tabular),
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
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
              itemBuilder: (context, documentSnapshots, index) {
                ConversationModel chatmodel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);

                return chatItemView(context, chatmodel.senderId == FireStoreUtils.getCurrentUid(), chatmodel);
              },
              onEmpty: DsEmptyState(icon: Icons.forum_outlined, title: "No conversion found".tr),
              query: FireStoreUtils.firestore.collection('chat').doc(controller.orderId.value).collection("thread").orderBy('createdAt', descending: true),
              isLive: true,
              viewType: ViewType.list,
              initialLoader: const DsSkeletonList(itemCount: 5, leading: false, trailing: false),
            ),
          ),
          bottomNavigationBar: DsStickyBar(
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
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: TextField(
                      textInputAction: TextInputAction.send,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.sentences,
                      controller: controller.messageController.value,
                      minLines: 1,
                      maxLines: 4,
                      style: t.body,
                      decoration: _pill(context, 'Type message here....'.tr),
                      onSubmitted: (value) async {
                        if (controller.messageController.value.text.isNotEmpty) {
                          controller.sendMessage(controller.messageController.value.text, null, '', 'text');
                          Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
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
      },
    );
  }

  Widget chatItemView(BuildContext context, bool isMe, ConversationModel data) {
    final c = context.dsColors;
    final t = context.dsText;
    final BorderRadius bubble = isMe
        ? const BorderRadius.only(topLeft: Radius.circular(DsRadius.lg), topRight: Radius.circular(DsRadius.lg), bottomLeft: Radius.circular(DsRadius.lg))
        : const BorderRadius.only(topLeft: Radius.circular(DsRadius.lg), topRight: Radius.circular(DsRadius.lg), bottomRight: Radius.circular(DsRadius.lg));

    Widget content() {
      if (data.messageType == "text") {
        return Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
          decoration: BoxDecoration(
            borderRadius: bubble,
            color: isMe ? c.brand : c.surface,
            border: isMe ? null : Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
          child: Text(
            data.message.toString(),
            maxLines: null,
            style: t.bodyLg.withColor(isMe ? c.onBrand : c.textPrimary),
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
                child: DsImage(url: data.url!.url, height: isMe ? 140 : null, width: isMe ? 140 : null, radius: 0),
              ),
            ),
          ),
        );
      }
      return Semantics(
        button: true,
        label: 'Play'.tr,
        child: InkWell(
          borderRadius: bubble,
          onTap: () {
            Get.to(FullScreenVideoViewer(heroTag: data.id.toString(), videoUrl: data.url!.url));
          },
          child: Container(
            width: 140,
            height: 100,
            decoration: BoxDecoration(borderRadius: bubble, color: c.surfaceAlt, border: Border.all(color: c.border)),
            alignment: Alignment.center,
            child: DsIconWell(icon: Icons.play_arrow_rounded, tone: DsTone.brand, size: 48, circle: true),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(left: isMe ? 80 : 4, right: isMe ? 4 : 80, top: DsSpace.sm, bottom: DsSpace.sm),
      child: Align(
        alignment: isMe ? Alignment.topRight : Alignment.topLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            content(),
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
      message: Text('Send Media'.tr, style: const TextStyle(fontSize: 15.0)),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDefaultAction: false,
          onPressed: () async {
            Get.back();
            try {
              XFile? image = await controller.imagePicker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path));
                controller.sendMessage(controller.messageController.value.text, url, '', 'image');
                Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
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
              ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(File(galleryVideo.path));
              if (videoContainer != null) {
                controller.sendMessage(controller.messageController.value.text, videoContainer.videoUrl, videoContainer.thumbnailUrl, 'video');
                Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
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
                Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path));
                controller.sendMessage(controller.messageController.value.text, url, '', 'image');
                Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
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
        child: Text('Cancel'.tr),
        onPressed: () {
          Get.back();
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }
}
