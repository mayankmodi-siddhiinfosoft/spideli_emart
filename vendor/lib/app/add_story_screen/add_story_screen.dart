import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/add_story_controller.dart';
import 'package:vendor/models/story_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/video_widget.dart';
import 'package:video_player/video_player.dart';

class AddStoryScreen extends StatelessWidget {
  const AddStoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: AddStoryController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: IconThemeData(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, size: 20),
            title: Text(
              "Add Story".tr,
              style: TextStyle(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DottedBorder(
                          options: RoundedRectDottedBorderOptions(radius: const Radius.circular(12), dashPattern: const [6, 6, 6, 6], color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                          child: Container(
                            decoration: BoxDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, borderRadius: const BorderRadius.all(Radius.circular(12))),
                            child: SizedBox(
                              height: Responsive.height(20, context),
                              width: Responsive.width(90, context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset('assets/icons/ic_folder.svg'),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Choose a image for thumbnail".tr,
                                    style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.medium, fontSize: 16),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "JPEG, PNG, JPG, GIF format".tr,
                                    style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey200 : AppThemeData.grey700, fontFamily: AppThemeData.regular),
                                  ),
                                  const SizedBox(height: 10),
                                  RoundedButtonFill(
                                    title: "Brows Image".tr,
                                    color: isDark ? AppThemeData.secondary600 : AppThemeData.secondary50,
                                    width: 30,
                                    height: 5,
                                    textColor: AppThemeData.primary300,
                                    onPress: () async {
                                      onCameraClick(context, controller, false);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        controller.thumbnailFile.isEmpty
                            ? const SizedBox()
                            : Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                                      child: controller.thumbnailFile[0].runtimeType == XFile
                                          ? Image.file(File(controller.thumbnailFile[0].path), fit: BoxFit.cover, width: 80, height: 80)
                                          : NetworkImageWidget(imageUrl: controller.thumbnailFile[0], fit: BoxFit.cover, width: 80, height: 80),
                                    ),
                                    Positioned(
                                      right: 5,
                                      top: 5,
                                      child: InkWell(
                                        onTap: () {
                                          controller.thumbnailFile.clear();
                                        },
                                        child: const Icon(Icons.delete, color: AppThemeData.danger300),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 10),
                        DottedBorder(
                          options: RoundedRectDottedBorderOptions(radius: const Radius.circular(12), dashPattern: const [6, 6, 6, 6], color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                          child: Container(
                            decoration: BoxDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, borderRadius: const BorderRadius.all(Radius.circular(12))),
                            child: SizedBox(
                              height: Responsive.height(20, context),
                              width: Responsive.width(90, context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset('assets/icons/ic_folder.svg'),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Choose a story video".tr,
                                    style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.medium, fontSize: 16),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "${'mp4 format,  less then'.tr} ${double.parse(controller.videoDuration.toString()).toStringAsFixed(0)} ${'sec.'.tr}".tr,
                                    style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey200 : AppThemeData.grey700, fontFamily: AppThemeData.regular),
                                  ),
                                  const SizedBox(height: 10),
                                  RoundedButtonFill(
                                    title: "Brows Video".tr,
                                    color: isDark ? AppThemeData.secondary600 : AppThemeData.secondary50,
                                    width: 30,
                                    height: 5,
                                    textColor: AppThemeData.primary300,
                                    onPress: () async {
                                      onCameraClick(context, controller, true);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: SizedBox(
                            height: 200,
                            child: ListView.builder(
                              itemCount: controller.mediaFiles.length,
                              shrinkWrap: true,
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: Stack(
                                    children: [
                                      VideoWidget(url: controller.mediaFiles[index]),
                                      Positioned(
                                        right: 0,
                                        child: InkWell(
                                          onTap: () {
                                            controller.mediaFiles.removeAt(index);
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Icon(Icons.remove_circle, color: Colors.red),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: Container(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      ShowToastDialog.showLoader("Please wait".tr);
                      await FireStoreUtils.removeStory(Constant.userModel!.vendorID.toString()).then((value) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Story remove successfully".tr);
                        controller.getStory();
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset("assets/icons/ic_delete.svg", height: 14),
                        const SizedBox(width: 10),
                        Text(
                          "Delete Story".tr,
                          style: TextStyle(color: isDark ? AppThemeData.danger300 : AppThemeData.danger300, fontSize: 16, fontFamily: AppThemeData.medium),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  RoundedButtonFill(
                    title: "Save Story".tr,
                    height: 5.5,
                    color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                    textColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                    fontSizes: 16,
                    onPress: () async {
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
                ],
              ),
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
