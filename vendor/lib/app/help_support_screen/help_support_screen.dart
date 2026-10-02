import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/app/chat_screens/chat_video_container.dart';
import 'package:vendor/app/chat_screens/full_screen_image_viewer.dart';
import 'package:vendor/app/chat_screens/full_screen_video_viewer.dart';
import 'package:vendor/app/chat_screens/widgets/chat_widgets.dart';
import 'package:vendor/app/dash_board_screens/dash_board_screen.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/help_support_controller.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/preferences.dart';
import 'package:vendor/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:vendor/widget/firebase_pagination/src/models/view_type.dart';

class HelpSupportScreen extends StatelessWidget {
  final bool? isNavigateViaNotification;
  HelpSupportScreen({super.key, this.isNavigateViaNotification});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
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
          return Scaffold(
            backgroundColor: c.background,
            // The composer is in the body (ChatThreadLayout), which the
            // Scaffold lays out above the keyboard, so it rides up with it.
            resizeToAvoidBottomInset: true,
            appBar: DsAppBar(
              leading: DsBackButton(
                onPressed: () async {
                  if (isNavigateViaNotification == true) {
                    await Preferences.setBoolean(Preferences.isClickOnNotification, false);
                    Get.offAll(DashBoardScreen());
                  } else {
                    Get.back();
                  }
                },
              ),
              titleWidget: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const DsIconWell(icon: Icons.support_agent_rounded, size: 40, circle: true),
                      PositionedDirectional(
                        end: 0,
                        bottom: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: c.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.background, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Help & Support'.tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm.withColor(c.textPrimary)),
                        Text("Admin", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                      ],
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: c.divider, height: 1),
              ),
            ),
            body: ChatThreadLayout(
              maxContentWidth: DsLayout.contentMax,
              scrollController: controller.scrollController.value,
              textController: controller.messageController.value,
              messages: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: FirestorePagination(
                  controller: controller.scrollController.value,
                  physics: const BouncingScrollPhysics(),
                  query: FireStoreUtils.fireStore
                      .collection(CollectionName.chat)
                      .doc(FireStoreUtils.getCurrentUid())
                      .collection('thread')
                      .orderBy('createdAt', descending: true),
                  isLive: true,
                  shrinkWrap: true,
                  reverse: true,
                  onEmpty: DsEmptyState(icon: Icons.forum_outlined, title: "No conversion found".tr, compact: true),
                  viewType: ViewType.list,
                  // to fetch real-time data
                  itemBuilder: (context, documentSnapshots, index) {
                    ConversationModel inboxModel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);
                    return chatItemView(isMe: inboxModel.senderId == FireStoreUtils.getCurrentUid(), data: inboxModel, context: context, controller: controller);
                  },
                ),
              ),
              composer: HelpSupportComposer(
                controller: controller.messageController.value,
                onAttach: () async {
                  _onCameraClick(isDark: isDark, controller: controller, context: context);
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
            ),
          );
        },
      ),
    );
  }

  Widget chatItemView({required bool isMe, required ConversationModel data, required BuildContext context, required HelpSupportController controller}) {
    final c = context.dsColors;
    final t = context.dsText;
    const r = Radius.circular(DsRadius.lg);
    const sharp = Radius.circular(DsSpace.xs);
    final bubbleRadius = BorderRadius.only(topLeft: r, topRight: r, bottomLeft: isMe ? r : sharp, bottomRight: isMe ? sharp : r);
    final maxBubble = MediaQuery.of(context).size.width.clamp(0.0, DsLayout.contentMax) * 0.75;

    Widget media() {
      final placeholder = DsShimmer(child: DsSkeleton.box(width: 200, height: 160, radius: 0));
      final String mediaUrl = data.url?.url ?? '';
      // Tagged per message, not per URL: the same file sent twice would
      // otherwise put two heroes with one tag on this screen.
      final Object mediaTag = 'support-media-${data.id ?? identityHashCode(data)}';
      if (data.messageType == "image") {
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
          child: ClipRRect(
            borderRadius: bubbleRadius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    FullScreenImageViewer.open(mediaUrl, heroTag: mediaTag);
                  },
                  child: Hero(
                    tag: mediaTag,
                    child: CachedNetworkImage(imageUrl: mediaUrl, placeholder: (context, url) => placeholder, errorWidget: (context, url, error) => const Icon(Icons.error)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
        child: InkWell(
          onTap: () {
            if (FullScreenVideoViewer.canPlay(mediaUrl)) {
              Get.to(FullScreenVideoViewer(heroTag: data.id.toString(), videoUrl: mediaUrl, mediaHeroTag: mediaTag));
            }
          },
          child: ClipRRect(
            borderRadius: bubbleRadius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Hero(
                  tag: mediaTag,
                  child: CachedNetworkImage(
                    imageUrl: data.videoThumbnail ?? '',
                    placeholder: (context, url) => placeholder,
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(DsSpace.sm),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bubble = data.messageType == "text"
        ? Container(
            constraints: BoxConstraints(maxWidth: maxBubble),
            decoration: BoxDecoration(
              color: isMe ? c.brand : c.surface,
              borderRadius: bubbleRadius,
              border: isMe ? null : Border.all(color: c.border),
              boxShadow: DsShadows.xs(context),
            ),
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
            child: Text(data.message.toString(), softWrap: true, maxLines: null, style: t.body.withColor(isMe ? c.onBrand : c.textPrimary)),
          )
        : media();

    return DsFadeSlideIn(
      offset: Offset(isMe ? 16 : -16, 0),
      duration: DsMotion.base,
      child: Padding(
        padding: EdgeInsets.only(left: isMe ? 64 : DsSpace.md, right: isMe ? DsSpace.md : 64, top: DsSpace.sm, bottom: DsSpace.sm),
        child: Align(
          alignment: isMe ? Alignment.topRight : Alignment.topLeft,
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe) ...[const DsIconWell(icon: Icons.support_agent_rounded, size: 28, circle: true), const DsGap(DsSpace.sm)],
                  Flexible(child: bubble),
                  if (isMe) ...[
                    const DsGap(DsSpace.sm),
                    DsAvatar(imageUrl: controller.userModel.value.profilePictureURL.toString(), name: controller.userModel.value.fullName(), size: 28),
                  ],
                ],
              ),
              const DsGap(DsSpace.xs),
              Padding(
                padding: EdgeInsets.only(left: isMe ? 0 : 36, right: isMe ? 36 : 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe) ...[Text("Admin", style: t.labelSm.withColor(c.textSecondary)), const DsGap(DsSpace.sm)],
                    Text(Constant.dateAndTimeFormatTimestamp(data.createdAt), style: t.caption),
                    if (isMe) ...[const DsGap(DsSpace.xs), data.seen == true ? Text("✓✓", style: t.caption.withColor(c.brandStrong)) : Text("✓", style: t.caption)],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final ImagePicker _imagePicker = ImagePicker();

  void _onCameraClick({required bool isDark, required HelpSupportController controller, required BuildContext context}) {
    final action = CupertinoActionSheet(
      message: Text(
        'Send Media'.tr,
        style: TextStyle(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, fontFamily: AppThemeData.semiBold, fontSize: 12),
      ),
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
