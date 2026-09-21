import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/chat_screens/chat_video_container.dart';
import 'package:vendor/app/chat_screens/full_screen_image_viewer.dart';
import 'package:vendor/app/chat_screens/full_screen_video_viewer.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/chat_controller.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/firebase_pagination/firebase_pagination.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ChatController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              controller.receivedId.value == 'admin' ? 'Admin' : controller.receiverUser.value!.fullName(),
              textAlign: TextAlign.start,
              style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(10), // height of the bottom section
              child: Padding(
                padding: const EdgeInsets.only(left: 55, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "${controller.sectionType.value == 'adv' ? "AvdId" : "OrderId".tr} ${Constant.orderId(orderId: controller.orderId.value.toString())}",
                    style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey200 : AppThemeData.grey700),
                  ),
                ),
              ),
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
                    itemBuilder: (context, documentSnapshots, index) {
                      ConversationModel chatmodel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);
                      log("chatmodel :: ${chatmodel.id}");
                      return chatItemView(isDark, chatmodel.senderId == FireStoreUtils.getCurrentUid(), chatmodel);
                    },
                    onEmpty: Constant.showEmptyView(message: "No conversion found".tr, isDark: isDark),
                    query: FireStoreUtils.fireStore.collection(CollectionName.chat).doc(controller.orderId.value).collection("thread").orderBy('createdAt', descending: true),
                    isLive: true,
                    viewType: ViewType.list,
                  ),
                ),
              ),
              Container(
                color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              onCameraClick(context, controller);
                            },
                            child: SvgPicture.asset("assets/icons/ic_picture_one.svg"),
                          ),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: TextField(
                                textInputAction: TextInputAction.send,
                                keyboardType: TextInputType.text,
                                textCapitalization: TextCapitalization.sentences,
                                controller: controller.messageController.value,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.only(top: 3, left: 10),
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  hintText: 'Type message here....'.tr,
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
                          ),
                          InkWell(
                            onTap: () {
                              if (controller.messageController.value.text.isNotEmpty) {
                                controller.sendMessage(controller.messageController.value.text, null, '', 'text');
                                Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
                                controller.messageController.value.clear();
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 10),
                              decoration: BoxDecoration(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200, borderRadius: BorderRadius.circular(30)),
                              child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_send.svg")),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget chatItemView(bool isDark, bool isMe, ConversationModel data) {
    return Container(
      padding: EdgeInsets.only(left: isMe ? 80 : 10, right: isMe ? 10 : 80, top: 10, bottom: 10),
      child: isMe
          ? Align(
              alignment: Alignment.topRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  data.messageType == "text"
                      ? Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: Radius.circular(12)),
                            color: AppThemeData.primary300,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Text(
                            data.message.toString(),
                            style: const TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: AppThemeData.grey50),
                          ),
                        )
                      : data.messageType == "image"
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: Radius.circular(12)),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Get.to(FullScreenImageViewer(imageUrl: data.url!.url));
                                },
                                child: Hero(
                                  tag: data.url!.url,
                                  child: NetworkImageWidget(imageUrl: data.url!.url, height: 100, width: 100, fit: BoxFit.cover),
                                ),
                              ),
                            ],
                          ),
                        )
                      : FloatingActionButton(
                          mini: true,
                          heroTag: data.id,
                          backgroundColor: AppThemeData.primary300,
                          onPressed: () {
                            Get.to(FullScreenVideoViewer(heroTag: data.id.toString(), videoUrl: data.url!.url));
                          },
                          child: const Icon(Icons.play_arrow, color: Colors.white),
                        ),
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('MMM d, yyyy hh:mm aa').format(DateTime.fromMillisecondsSinceEpoch(data.createdAt!.millisecondsSinceEpoch)),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
          : Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  data.messageType == "text"
                      ? Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                            color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Text(
                            data.message.toString(),
                            maxLines: null,
                            style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                          ),
                        )
                      : data.messageType == "image"
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Get.to(FullScreenImageViewer(imageUrl: data.url!.url));
                                  },
                                  child: Hero(
                                    tag: data.url!.url,
                                    child: NetworkImageWidget(imageUrl: data.url!.url),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : FloatingActionButton(
                          mini: true,
                          heroTag: data.id,
                          backgroundColor: AppThemeData.primary300,
                          onPressed: () {
                            Get.to(FullScreenVideoViewer(heroTag: data.id.toString(), videoUrl: data.url!.url));
                          },
                          child: const Icon(Icons.play_arrow, color: Colors.white),
                        ),
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('MMM d, yyyy hh:mm aa').format(DateTime.fromMillisecondsSinceEpoch(data.createdAt!.millisecondsSinceEpoch)),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), context);
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
              ChatVideoContainer? videoContainer = await FireStoreUtils.uploadChatVideoToFireStorage(context, File(galleryVideo.path));
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
                Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), context);
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
