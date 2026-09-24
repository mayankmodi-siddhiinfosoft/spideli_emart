import 'dart:async';
import 'dart:io';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/chat_controller.dart';
import 'package:customer/models/conversation_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/widgets/chat_widgets.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../service/fire_store_utils.dart';
import '../../../widget/firebase_pagination/src/firestore_pagination.dart';
import '../../../widget/firebase_pagination/src/models/view_type.dart';
import 'chat_video_container.dart';
import 'full_screen_image_viewer.dart';
import 'full_screen_video_viewer.dart';

/// Archetype **J — chat**: avatar + order id in the bar, alternating bubbles
/// and a pill composer in a sticky bar.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ChatController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final name = controller.receivedName.value;
        final profileUrl = controller.receivedProfileUrl.value;
        final orderLabel = "${"Order".tr} ${Constant.orderId(orderId: controller.orderId.value.toString())}";
        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: DsAppBar(
            titleWidget: Row(
              children: [
                DsAvatar(imageUrl: profileUrl, name: name, size: 40),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                      Text(orderLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.tabular),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomBar: ChatComposer(
            controller: controller.messageController.value,
            hint: 'Type message here....'.tr,
            attachIcon: SvgPicture.asset("assets/icons/ic_picture_one.svg", width: 22, height: 22, colorFilter: ColorFilter.mode(c.brandStrong, BlendMode.srcIn)),
            sendIcon: SvgPicture.asset("assets/icons/ic_send.svg", width: 20, height: 20, colorFilter: ColorFilter.mode(c.onBrand, BlendMode.srcIn)),
            onAttach: () {
              onCameraClick(context, controller);
            },
            onSend: () {
              if (controller.messageController.value.text.isNotEmpty) {
                controller.sendMessage(controller.messageController.value.text, null, '', 'text', controller);
                Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
                controller.messageController.value.clear();
              }
            },
            onSubmitted: (value) async {
              if (controller.messageController.value.text.isNotEmpty) {
                controller.sendMessage(controller.messageController.value.text, null, '', 'text', controller);
                Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
                controller.messageController.value.clear();
              }
            },
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
                ConversationModel inboxModel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);
                return chatItemView(context, inboxModel.senderId == FireStoreUtils.getCurrentUid(), inboxModel);
              },
              onEmpty: Constant.showEmptyView(message: "No Conversion found".tr),
              // orderBy is compulsory to enable pagination
              query: FireStoreUtils.fireStore.collection(CollectionName.chat).doc(controller.orderId.value).collection("thread").orderBy('createdAt', descending: true),
              isLive: true,
              viewType: ViewType.list,
            ),
          ),
        );
      },
    );
  }

  Widget chatItemView(BuildContext context, bool isMe, ConversationModel data) {
    final timeLabel = DateFormat('MMM d, yyyy hh:mm aa').format(DateTime.fromMillisecondsSinceEpoch(data.createdAt!.millisecondsSinceEpoch));
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
        child: Hero(tag: data.url!.url, child: NetworkImageWidget(imageUrl: data.url!.url, height: 160, width: 220, fit: BoxFit.cover)),
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
        child: NetworkImageWidget(imageUrl: data.videoThumbnail ?? '', height: 140, width: 180, fit: BoxFit.cover),
      );
    }
    return ChatMessageRow(isMe: isMe, bubble: bubble, timeLabel: timeLabel);
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
                Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), context);
                controller.sendMessage(controller.messageController.value.text, url, '', 'image', controller);
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
              ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(context, File(galleryVideo.path));
              if (videoContainer != null) {
                controller.sendMessage(controller.messageController.value.text, videoContainer.videoUrl, videoContainer.thumbnailUrl, 'video', controller);
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
                controller.sendMessage(controller.messageController.value.text, url, '', 'image', controller);
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
