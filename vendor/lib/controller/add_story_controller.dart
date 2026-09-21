import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/story_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class AddStoryController extends GetxController {
  RxBool isLoading = true.obs;

  Rx<StoryModel> storyModel = StoryModel().obs;
  final ImagePicker imagePicker = ImagePicker();

  RxList<dynamic> mediaFiles = <dynamic>[].obs;
  RxList<dynamic> thumbnailFile = <dynamic>[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getStory();
    super.onInit();
  }

  RxDouble videoDuration = 0.0.obs;

  Future<void> getStory() async {
    isLoading.value = true;

    // Clear existing data
    thumbnailFile.clear();
    mediaFiles.clear();

    // Fetch story
    final value = await FireStoreUtils.getStory(Constant.userModel!.vendorID.toString());
    if (value != null) {
      storyModel.value = value;

      if (value.videoThumbnail != null) {
        thumbnailFile.add(value.videoThumbnail);
      }

      if (value.videoUrl.isNotEmpty) {
        mediaFiles.addAll(value.videoUrl);
      }
    }

    // Fetch video duration from settings
    final settingsSnapshot = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc('story').get();
    if (settingsSnapshot.exists) {
      videoDuration.value = double.parse(settingsSnapshot.data()!['videoDuration'].toString());
    }

    isLoading.value = false;
  }


}
