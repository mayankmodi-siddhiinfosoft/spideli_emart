import 'dart:async';
import 'dart:io';

import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/chat_controller.dart';
import 'package:spideliprovider/model/chat_video_container.dart';
import 'package:spideliprovider/model/conversation_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/chat_screen/full_screen_image_viewer.dart';
import 'package:spideliprovider/ui/chat_screen/full_screen_video_viewer.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/firebase_pagination/firebase_pagination.dart';
import 'package:spideliprovider/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    return GetX(
      init: ChatController(),
      builder: (controller) {
        // Header values are read here so the GetX observer tracks them.
        final String title = controller.receivedId.value == 'admin' ? 'Admin' : controller.receiverUser.value!.fullName();
        final String reference = "${controller.sectionType.value == 'adv' ? "AvdId" : "OrderId".tr} ${orderId(orderId: controller.orderId.value.toString())}";
        return Scaffold(
          backgroundColor: c.background,
          appBar: DsAppBar(
            backgroundColor: c.surface,
            titleWidget: Row(
              children: [
                DsAvatar(imageUrl: controller.receiverUser.value?.profilePictureURL, name: title, size: 38),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                      Text(reference, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                  },
                  child: FirestorePagination(
                    reverse: true,
                    controller: controller.scrollController.value,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: context.dsLayout.gutter, vertical: DsSpace.md),
                    itemBuilder: (context, documentSnapshots, index) {
                      ConversationModel chatmodel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);

                      return chatItemView(context, chatmodel.senderId == FireStoreUtils.getCurrentUid(), chatmodel);
                    },
                    onEmpty: DsEmptyState(icon: Icons.chat_bubble_outline_rounded, title: "No conversion found".tr),
                    initialLoader: const DsSkeletonList(itemCount: 5, leading: false, trailing: false),
                    query: FireStoreUtils.firestore.collection('chat').doc(controller.orderId.value).collection("thread").orderBy('createdAt', descending: true),
                    isLive: true,
                    viewType: ViewType.list,
                  ),
                ),
              ),
              // Composer: pill input flanked by the attach and send actions.
              DsStickyBar(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                        style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                        decoration: DsInputDecoration.of(
                          context,
                          hint: 'Type message here....'.tr,
                          contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: 12),
                        ),
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
            ],
          ),
        );
      },
    );
  }

  /// One message bubble: brand fill for mine, bordered surface for theirs,
  /// with a single squared corner on the sender's side.
  Widget chatItemView(BuildContext context, bool isMe, ConversationModel data) {
    final c = context.dsColors;
    final t = context.dsText;
    final BorderRadius mineRadius = const BorderRadius.only(
      topLeft: Radius.circular(DsRadius.lg),
      topRight: Radius.circular(DsRadius.lg),
      bottomLeft: Radius.circular(DsRadius.lg),
      bottomRight: Radius.circular(DsRadius.xs),
    );
    final BorderRadius theirsRadius = const BorderRadius.only(
      topLeft: Radius.circular(DsRadius.lg),
      topRight: Radius.circular(DsRadius.lg),
      bottomRight: Radius.circular(DsRadius.lg),
      bottomLeft: Radius.circular(DsRadius.xs),
    );
    final BorderRadius radius = isMe ? mineRadius : theirsRadius;

    Widget body() {
      if (data.messageType == "text") {
        return Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: isMe ? c.brand : c.surface,
            border: isMe ? null : Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
          child: Text(data.message.toString(), maxLines: null, style: DsTypography.bodyLg.copyWith(color: isMe ? c.onBrand : c.textPrimary)),
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
                    child: NetworkImageWidget(imageUrl: data.url!.url, height: isMe ? 140 : null, width: isMe ? 140 : null, fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return FloatingActionButton(
        mini: true,
        heroTag: data.id,
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        onPressed: () {
          Get.to(FullScreenVideoViewer(heroTag: data.id.toString(), videoUrl: data.url!.url));
        },
        child: const Icon(Icons.play_arrow),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: isMe ? 60 : 0, right: isMe ? 0 : 60, top: DsSpace.xs, bottom: DsSpace.xs),
      child: Align(
        alignment: isMe ? Alignment.topRight : Alignment.topLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            body(),
            const DsGap(DsSpace.xs),
            Text(DateFormat('MMM d, yyyy hh:mm aa').format(DateTime.fromMillisecondsSinceEpoch(data.createdAt!.millisecondsSinceEpoch)), style: t.caption),
          ],
        ),
      ),
    );
  }

  void onCameraClick(BuildContext context, ChatController controller) {
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
            ),
            DsListTile(
              title: "Choose video from gallery".tr,
              leadingIcon: Icons.video_library_outlined,
              showChevron: true,
              onTap: () async {
                Get.back();
                XFile? galleryVideo = await controller.imagePicker.pickVideo(source: ImageSource.gallery);
                if (galleryVideo != null) {
                  ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(context, File(galleryVideo.path));
                  if (videoContainer != null) {
                    controller.sendMessage(controller.messageController.value.text, videoContainer.videoUrl, videoContainer.thumbnailUrl, 'video');
                    Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
                  }
                }
              },
            ),
            DsListTile(
              title: "Take a picture".tr,
              leadingIcon: Icons.photo_camera_outlined,
              showChevron: true,
              onTap: () async {
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
            ),
            // DsListTile(
            //   title: "Record video".tr,
            //   onTap: () async {
            //     Get.back();
            //     XFile? recordedVideo = await controller.imagePicker.pickVideo(source: ImageSource.camera);
            //     if (recordedVideo != null) {
            //       ChatVideoContainer videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(File(recordedVideo.path), context);
            //       controller.sendMessage('', videoContainer.videoUrl, videoContainer.thumbnailUrl, 'video');
            //     }
            //   },
            // ),
            DsGap.md,
            DsButton.secondary(
              label: 'Cancel'.tr,
              expand: true,
              onPressed: () {
                Get.back();
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
