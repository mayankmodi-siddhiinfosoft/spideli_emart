import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/app/add_restaurant_screen/widgets/form_media_widgets.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/add_story_controller.dart';
import 'package:vendor/models/story_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/video_widget.dart';
import 'package:video_player/video_player.dart';

class AddStoryScreen extends StatelessWidget {
  const AddStoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AddStoryController(),
      builder: (controller) {
        final c = context.dsColors;

        final thumbnailStep = _StepCard(
          step: 1,
          done: controller.thumbnailFile.isNotEmpty,
          icon: Icons.image_outlined,
          title: "Choose a image for thumbnail".tr,
          caption: "JPEG, PNG, JPG, GIF format".tr,
          action: DsButton.tonal(
            label: "Brows Image".tr,
            icon: Icons.add_photo_alternate_outlined,
            size: DsButtonSize.sm,
            onPressed: () async {
              onCameraClick(context, controller, false);
            },
          ),
          child: controller.thumbnailFile.isEmpty
              ? null
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FormMediaThumb(
                    size: 96,
                    onRemove: () {
                      controller.thumbnailFile.clear();
                    },
                    child: controller.thumbnailFile[0].runtimeType == XFile
                        ? Image.file(File(controller.thumbnailFile[0].path), fit: BoxFit.cover, width: 96, height: 96)
                        : NetworkImageWidget(imageUrl: controller.thumbnailFile[0], fit: BoxFit.cover, width: 96, height: 96),
                  ),
                ),
        );

        final videoStep = _StepCard(
          step: 2,
          done: controller.mediaFiles.isNotEmpty,
          icon: Icons.movie_creation_outlined,
          title: "Choose a story video".tr,
          caption: "${'mp4 format,  less then'.tr} ${double.parse(controller.videoDuration.toString()).toStringAsFixed(0)} ${'sec.'.tr}".tr,
          action: DsButton.tonal(
            label: "Brows Video".tr,
            icon: Icons.video_call_outlined,
            size: DsButtonSize.sm,
            onPressed: () async {
              onCameraClick(context, controller, true);
            },
          ),
          child: controller.mediaFiles.isEmpty
              ? null
              : SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: controller.mediaFiles.length,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                        child: DsFadeSlideIn(
                          index: index,
                          offset: const Offset(12, 0),
                          child: ClipRRect(
                            borderRadius: DsRadius.brMd,
                            child: Stack(
                              children: [
                                VideoWidget(url: controller.mediaFiles[index]),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: DsIconButton(
                                    icon: Icons.close_rounded,
                                    semanticLabel: "Remove".tr,
                                    size: 30,
                                    variant: DsIconButtonVariant.filled,
                                    color: c.dangerStrong,
                                    onPressed: () {
                                      controller.mediaFiles.removeAt(index);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        );

        final preview = _StoryPreview(controller: controller);

        return DsScaffold(
          title: "Add Story".tr,
          maxContentWidth: null,
          body: controller.isLoading.value
              ? const DsResponsive(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(DsSpace.lg),
                    child: Column(children: [DsSkeletonCard(height: 300), DsGap(DsSpace.lg), DsSkeletonCard(height: 120), DsGap(DsSpace.md), DsSkeletonCard(height: 120)]),
                  ),
                )
              : SingleChildScrollView(
                  child: DsResponsive(
                    maxWidth: DsLayout.wideMax,
                    padded: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xxl),
                      child: DsResponsiveBuilder(
                        builder: (context, l) => l.isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DsFadeSlideIn(child: preview),
                                  const DsGap(DsSpace.xxl),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: DsFadeSlideIn.stagger([thumbnailStep, const DsGap(DsSpace.md), videoStep]),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: DsFadeSlideIn.stagger([Center(child: preview), const DsGap(DsSpace.xl), thumbnailStep, const DsGap(DsSpace.md), videoStep]),
                              ),
                      ),
                    ),
                  ),
                ),
          bottomBar: DsStickyBar(
            child: Row(
              children: [
                Expanded(
                  child: DsButton.dangerTonal(
                    label: "Delete Story".tr,
                    icon: Icons.delete_outline_rounded,
                    expand: true,
                    onPressed: () async {
                      ShowToastDialog.showLoader("Please wait".tr);
                      await FireStoreUtils.removeStory(Constant.userModel!.vendorID.toString()).then((value) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Story remove successfully".tr);
                        controller.getStory();
                      });
                    },
                  ),
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: DsButton.primary(
                    label: "Save Story".tr,
                    icon: Icons.cloud_upload_outlined,
                    expand: true,
                    onPressed: () async {
                      if (controller.thumbnailFile.isEmpty) {
                        ShowToastDialog.showToast("Please select thumbnail.".tr);
                        return;
                      }
                      if (controller.mediaFiles.isEmpty) {
                        ShowToastDialog.showToast("Please Select video".tr);
                        return;
                      }

                      try {
                        String? thumbnailUrl;
                        if (controller.thumbnailFile[0] is XFile) {
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showLoader("Uploading image...".tr);
                          thumbnailUrl = await FireStoreUtils.uploadImageOfStory(File(controller.thumbnailFile[0].path), context, getFileExtension(controller.thumbnailFile[0]!.path)!);
                        } else {
                          thumbnailUrl = controller.thumbnailFile[0];
                        }
                        List<String> mediaFilesURLs = controller.mediaFiles.whereType<String>().toList().cast<String>();
                        List<File> videosToUpload = controller.mediaFiles.whereType<File>().toList().cast<File>();
                        if (videosToUpload.isNotEmpty) {
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showLoader("Uploading video...".tr);
                          final uploadedUrls = await Future.wait(videosToUpload.map((video) => FireStoreUtils.uploadVideoStory(video, context)));
                          mediaFilesURLs.addAll(uploadedUrls.whereType<String>());
                        }
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showLoader("Please wait...".tr);
                        StoryModel storyModel = StoryModel(
                          vendorID: Constant.userModel!.vendorID,
                          videoThumbnail: thumbnailUrl,
                          videoUrl: mediaFilesURLs,
                          createdAt: Timestamp.now(),
                          sectionID: Constant.userModel!.sectionId,
                        );

                        await FireStoreUtils.addOrUpdateStory(storyModel);
                        await controller.getStory();
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Story uploaded successfully".tr);
                        Get.back();
                      } catch (e) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Failed to upload story".tr);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void onCameraClick(BuildContext context, AddStoryController controller, bool multipleSelect) {
    final action = CupertinoActionSheet(
      message: Text('Send Video'.tr, style: TextStyle(fontSize: 15.0)),
      actions: <Widget>[
        Visibility(
          visible: multipleSelect,
          child: CupertinoActionSheetAction(
            isDefaultAction: false,
            onPressed: () async {
              Navigator.pop(context);
              XFile? galleryVideo = await controller.imagePicker.pickVideo(source: ImageSource.gallery);
              if (galleryVideo != null) {
                VideoPlayerController controllers = VideoPlayerController.file(File(galleryVideo.path)); //Your file here

                String rounded = prettyDuration(double.parse(controllers.value.duration.inSeconds.toString()));

                if (double.parse(rounded).round() <= controller.videoDuration.value) {
                  controller.mediaFiles.add(File(galleryVideo.path));
                } else {
                  ShowToastDialog.showToast("${'Please select'.tr} ${controller.videoDuration.value.toString()} ${'second below video.'.tr}");
                }
              }
            },
            child: Text('Choose video from gallery'.tr),
          ),
        ),
        Visibility(
          visible: !multipleSelect,
          child: CupertinoActionSheetAction(
            isDefaultAction: false,
            onPressed: () async {
              Navigator.pop(context);
              XFile? galleryVideo = await controller.imagePicker.pickImage(source: ImageSource.gallery);
              if (galleryVideo != null) {
                controller.thumbnailFile.clear();
                controller.thumbnailFile.add(galleryVideo);
              }
            },
            child: Text('Choose thimbling image / GIF'.tr),
          ),
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

  String prettyDuration(double duration) {
    var seconds = duration / 1000.round();
    return '$seconds';
  }

  String? getFileExtension(String fileName) {
    try {
      return ".${fileName.split('.').last}";
    } catch (e) {
      return null;
    }
  }
}

/// Phone-shaped 9:16 preview of the story being composed.
class _StoryPreview extends StatelessWidget {
  final AddStoryController controller;
  const _StoryPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final hasThumb = controller.thumbnailFile.isNotEmpty;
    final videos = controller.mediaFiles.length;
    return Semantics(
      label: "Add Story".tr,
      container: true,
      child: Container(
        width: 200,
        height: 356,
        decoration: BoxDecoration(borderRadius: DsRadius.brXxl, color: c.surfaceInverse, boxShadow: DsShadows.lg(context)),
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DsRadius.xxl - 6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: DsMotion.of(context, DsMotion.slow),
                child: hasThumb
                    ? (controller.thumbnailFile[0].runtimeType == XFile
                          ? Image.file(File(controller.thumbnailFile[0].path), key: ValueKey(controller.thumbnailFile[0].path), fit: BoxFit.cover)
                          : NetworkImageWidget(key: ValueKey(controller.thumbnailFile[0]), imageUrl: controller.thumbnailFile[0], fit: BoxFit.cover))
                    : DecoratedBox(key: const ValueKey('empty'), decoration: BoxDecoration(gradient: DsGradients.brand(context))),
              ),
              const DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim)),
              // Story progress segments
              Positioned(
                left: DsSpace.md,
                right: DsSpace.md,
                top: DsSpace.md,
                child: Row(
                  children: [
                    for (int i = 0; i < (videos == 0 ? 1 : videos); i++) ...[
                      if (i > 0) const DsGap(3),
                      Expanded(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: videos == 0 ? 0 : (i == 0 ? 1 : 0.35)),
                          duration: DsMotion.of(context, DsMotion.slower),
                          curve: DsMotion.emphasized,
                          builder: (context, v, _) => ClipRRect(
                            borderRadius: DsRadius.brPill,
                            child: LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: Colors.white.withValues(alpha: 0.35), color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22), border: Border.all(color: Colors.white.withValues(alpha: 0.6))),
                  child: Icon(videos > 0 ? Icons.play_arrow_rounded : Icons.add_rounded, color: Colors.white, size: 32),
                ),
              ),
              Positioned(
                left: DsSpace.md,
                right: DsSpace.md,
                bottom: DsSpace.md,
                child: Row(
                  children: [
                    Icon(Icons.videocam_outlined, color: Colors.white, size: 16),
                    const DsGap(DsSpace.xs),
                    Text('$videos', style: t.label.withColor(Colors.white)),
                    const Spacer(),
                    Icon(hasThumb ? Icons.image_rounded : Icons.image_not_supported_outlined, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numbered upload step with a done state.
class _StepCard extends StatelessWidget {
  final int step;
  final bool done;
  final IconData icon;
  final String title;
  final String caption;
  final Widget action;
  final Widget? child;

  const _StepCard({required this.step, required this.done, required this.icon, required this.title, required this.caption, required this.action, this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      borderColor: done ? c.success.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: DsMotion.of(context, DsMotion.base),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: done
                    ? DsIconWell(key: const ValueKey('done'), icon: Icons.check_rounded, tone: DsTone.success, size: 44, circle: true)
                    : DsIconWell(
                        key: const ValueKey('todo'),
                        tone: DsTone.brand,
                        size: 44,
                        circle: true,
                        child: Text('$step', style: t.titleSm.withColor(c.brandStrong)),
                      ),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: c.textMuted),
                        const DsGap(DsSpace.xs),
                        Expanded(child: Text(title, style: t.label)),
                      ],
                    ),
                    const DsGap(2),
                    Text(caption, style: t.caption),
                    const DsGap(DsSpace.sm),
                    Align(alignment: AlignmentDirectional.centerStart, child: action),
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[const DsGap(DsSpace.md), child!],
        ],
      ),
    );
  }
}
