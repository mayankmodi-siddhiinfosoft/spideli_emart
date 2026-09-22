import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/app/chat_screens/chat_video_container.dart';
import 'package:vendor/app/chat_screens/full_screen_image_viewer.dart';
import 'package:vendor/app/chat_screens/full_screen_video_viewer.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/chat_controller.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/firebase_pagination/firebase_pagination.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ChatController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final isAdmin = controller.receivedId.value == 'admin';
        final title = controller.receivedId.value == 'admin' ? 'Admin' : controller.receiverUser.value!.fullName();
        return Scaffold(
          backgroundColor: c.background,
          appBar: DsAppBar(
            backgroundColor: c.surface,
            titleWidget: Row(
              children: [
                DsAvatar(
                  imageUrl: isAdmin ? null : controller.receiverUser.value?.profilePictureURL,
                  name: isAdmin ? null : title,
                  size: 40,
                  fallbackIcon: isAdmin ? Icons.support_agent_rounded : Icons.person_rounded,
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm.withColor(c.textPrimary)),
                      Text(
                        "${controller.sectionType.value == 'adv' ? "AvdId" : "OrderId".tr} ${Constant.orderId(orderId: controller.orderId.value.toString())}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption,
                      ),
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
                  child: DsResponsive(
                    maxWidth: DsLayout.contentMax,
                    child: FirestorePagination(
                      reverse: true,
                      controller: controller.scrollController.value,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                      itemBuilder: (context, documentSnapshots, index) {
                        ConversationModel chatmodel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);
                        log("chatmodel :: ${chatmodel.id}");
                        // Neighbours: list is reversed, so index + 1 is the message shown above.
                        final ConversationModel? older = index + 1 < documentSnapshots.length
                            ? ConversationModel.fromJson(documentSnapshots[index + 1].data() as Map<String, dynamic>)
                            : null;
                        final ConversationModel? newer = index - 1 >= 0 ? ConversationModel.fromJson(documentSnapshots[index - 1].data() as Map<String, dynamic>) : null;
                        return chatItemView(
                          context,
                          chatmodel.senderId == FireStoreUtils.getCurrentUid(),
                          chatmodel,
                          groupedWithOlder: _isGrouped(chatmodel, older),
                          groupedWithNewer: _isGrouped(chatmodel, newer),
                          showDateHeader: older == null || !_sameDay(older.createdAt?.toDate(), chatmodel.createdAt?.toDate()),
                        );
                      },
                      onEmpty: DsEmptyState(
                        icon: Icons.forum_outlined,
                        title: "No conversion found".tr,
                        compact: true,
                      ),
                      initialLoader: const _ChatSkeleton(),
                      bottomLoader: const Padding(
                        padding: EdgeInsets.all(DsSpace.lg),
                        child: Center(child: DsSpinner()),
                      ),
                      query: FireStoreUtils.fireStore.collection(CollectionName.chat).doc(controller.orderId.value).collection("thread").orderBy('createdAt', descending: true),
                      isLive: true,
                      viewType: ViewType.list,
                    ),
                  ),
                ),
              ),
              _Composer(controller: controller, onAttach: () => onCameraClick(context, controller)),
            ],
          ),
        );
      },
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _isGrouped(ConversationModel a, ConversationModel? b) {
    if (b == null || a.senderId != b.senderId) return false;
    final da = a.createdAt?.toDate();
    final db = b.createdAt?.toDate();
    if (da == null || db == null || !_sameDay(da, db)) return false;
    return da.difference(db).inMinutes.abs() < 5;
  }

  Widget chatItemView(
    BuildContext context,
    bool isMe,
    ConversationModel data, {
    bool groupedWithOlder = false,
    bool groupedWithNewer = false,
    bool showDateHeader = false,
  }) {
    final c = context.dsColors;
    final t = context.dsText;
    const big = Radius.circular(DsRadius.lg);
    const small = Radius.circular(DsRadius.xs);
    final radius = isMe
        ? BorderRadius.only(topLeft: big, bottomLeft: big, topRight: groupedWithOlder ? small : big, bottomRight: small)
        : BorderRadius.only(topRight: big, bottomRight: big, topLeft: groupedWithOlder ? small : big, bottomLeft: small);
    final created = DateTime.fromMillisecondsSinceEpoch(data.createdAt!.millisecondsSinceEpoch);

    Widget bubble;
    if (data.messageType == "text") {
      bubble = Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: isMe ? c.brand : c.surface,
          border: isMe ? null : Border.all(color: c.border),
          boxShadow: isMe ? null : DsShadows.xs(context),
        ),
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md - 2),
        child: Text(
          data.message.toString(),
          maxLines: null,
          style: t.bodyLg.withColor(isMe ? c.onBrand : c.textPrimary),
        ),
      );
    } else if (data.messageType == "image") {
      bubble = ClipRRect(
        borderRadius: radius,
        child: GestureDetector(
          onTap: () {
            Get.to(FullScreenImageViewer(imageUrl: data.url!.url));
          },
          child: Semantics(
            button: true,
            label: 'Image'.tr,
            child: Hero(
              tag: data.url!.url,
              child: NetworkImageWidget(imageUrl: data.url!.url, height: 200, width: 200, fit: BoxFit.cover),
            ),
          ),
        ),
      );
    } else {
      Widget play = Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle, boxShadow: DsShadows.md(context)),
        child: Icon(Icons.play_arrow_rounded, color: c.onBrand, size: 30),
      );
      if (data.id != null) play = Hero(tag: data.id!, child: play);
      final hasThumb = (data.videoThumbnail ?? '').isNotEmpty;
      bubble = Semantics(
        button: true,
        label: 'Play video'.tr,
        child: DsPressable(
          onTap: () {
            Get.to(FullScreenVideoViewer(heroTag: data.id.toString(), videoUrl: data.url!.url));
          },
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              width: 200,
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasThumb
                      ? NetworkImageWidget(imageUrl: data.videoThumbnail!, height: 140, width: 200, fit: BoxFit.cover)
                      : DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.deep(context))),
                  const DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim)),
                  Center(child: play),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final column = Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        bubble,
        if (!groupedWithNewer)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.xs, left: DsSpace.xs, right: DsSpace.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('hh:mm aa').format(created), style: t.caption),
                if (isMe && data.seen == true) ...[
                  const DsGap(DsSpace.xs),
                  Icon(Icons.done_all_rounded, size: 14, color: c.brand),
                ],
              ],
            ),
          ),
      ],
    );

    return DsFadeSlideIn(
      offset: Offset(isMe ? 16 : -16, 8),
      child: Column(
        children: [
          if (showDateHeader) _DateHeader(date: created),
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 56 : 0,
              right: isMe ? 0 : 56,
              top: groupedWithOlder ? DsSpace.xxs : DsSpace.md,
            ),
            child: Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: column),
          ),
        ],
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

/// Sticky message composer: attach button, pill text field and send button.
class _Composer extends StatelessWidget {
  final ChatController controller;
  final VoidCallback onAttach;
  const _Composer({required this.controller, required this.onAttach});

  void _send() {
    if (controller.messageController.value.text.isNotEmpty) {
      controller.sendMessage(controller.messageController.value.text, null, '', 'text');
      Timer(const Duration(milliseconds: 500), () => controller.scrollController.value.jumpTo(controller.scrollController.value.position.minScrollExtent));
      controller.messageController.value.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final pill = OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide(color: c.isDark ? c.border : c.surfaceAlt));
    return DsStickyBar(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DsIconButton(
            icon: Icons.add_photo_alternate_outlined,
            semanticLabel: 'Send Media'.tr,
            variant: DsIconButtonVariant.tonal,
            size: 44,
            onPressed: onAttach,
          ),
          const DsGap(DsSpace.sm),
          Expanded(
            child: TextField(
              textInputAction: TextInputAction.send,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              controller: controller.messageController.value,
              cursorColor: c.brand,
              style: t.bodyStrong.withColor(c.textPrimary),
              decoration: DsInputDecoration.of(
                context,
                hint: 'Type message here....'.tr,
                contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: DsSpace.md),
              ).copyWith(
                border: pill,
                enabledBorder: pill,
                focusedBorder: OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide(color: c.brand, width: 1.6)),
              ),
              onSubmitted: (value) async {
                _send();
              },
            ),
          ),
          const DsGap(DsSpace.sm),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.messageController.value,
            builder: (context, value, _) {
              final hasText = value.text.isNotEmpty;
              return AnimatedSwitcher(
                duration: DsMotion.of(context, DsMotion.fast),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: DsIconButton(
                  key: ValueKey(hasText),
                  icon: Icons.send_rounded,
                  semanticLabel: 'Send'.tr,
                  size: 44,
                  variant: hasText ? DsIconButtonVariant.filled : DsIconButtonVariant.tonal,
                  onPressed: _send,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? 'Today'.tr
        : diff == 1
        ? 'Yesterday'.tr
        : DateFormat('MMM d, yyyy').format(date);
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.lg, bottom: DsSpace.xs),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brPill),
          child: Text(label, style: t.labelSm.withColor(c.textSecondary)),
        ),
      ),
    );
  }
}

class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton();

  @override
  Widget build(BuildContext context) {
    const widths = [180.0, 120.0, 220.0, 150.0, 200.0, 110.0];
    return DsShimmer(
      child: ListView.builder(
        reverse: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DsSpace.lg),
        itemCount: widths.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(top: DsSpace.md),
          child: Align(
            alignment: i.isEven ? Alignment.centerRight : Alignment.centerLeft,
            child: DsSkeleton.box(width: widths[i], height: 44, radius: DsRadius.lg),
          ),
        ),
      ),
    );
  }
}
