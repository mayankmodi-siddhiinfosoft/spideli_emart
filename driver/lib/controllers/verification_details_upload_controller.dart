import 'dart:io';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class DetailsUploadController extends GetxController {
  Rx<DocumentModel> documentModel = DocumentModel().obs;

  Rx<DateTime?> selectedDate = DateTime.now().obs;

  RxString frontImage = "".obs;
  RxString backImage = "".obs;

  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      documentModel.value = argumentData['documentModel'];
    }
    getDocument();
    update();
  }

  Rx<Documents> documents = Documents().obs;

  Future<void> getDocument() async {
    await FireStoreUtils.getDocumentOfDriver().then((value) {
      isLoading.value = false;
      if (value != null) {
        var contain = value.documents!.where((element) => element.documentId == documentModel.value.id);
        if (contain.isNotEmpty) {
          documents.value = value.documents!.firstWhere((itemToCheck) => itemToCheck.documentId == documentModel.value.id);
          frontImage.value = documents.value.frontImage!;
          backImage.value = documents.value.backImage!;
        }
      }
    });
  }

  final ImagePicker _imagePicker = ImagePicker();

  Future pickFile({required ImageSource source, required String type}) async {
    try {
      XFile? image = await _imagePicker.pickImage(source: source);
      if (image == null) return;
      Get.back();

      if (type == "front") {
        frontImage.value = image.path;
      } else {
        backImage.value = image.path;
      }
    } on PlatformException {
      ShowToastDialog.showToast(
          source == ImageSource.camera ? "Camera permission denied. Please allow access to take a photo." : "Gallery permission denied. Please allow access to select an image.");
    } catch (e) {
      ShowToastDialog.showToast("Something went wrong. Please try again.");
      print("Pick file error: $e");
    }
  }

  Future<void> uploadDocument() async {
    String frontImageFileName = File(frontImage.value).path.split('/').last;
    String backImageFileName = File(backImage.value).path.split('/').last;

    if (frontImage.value.isNotEmpty && Constant().hasValidUrl(frontImage.value) == false) {
      frontImage.value = await Constant.uploadUserImageToFireStorage(File(frontImage.value), "driverDocument/${FireStoreUtils.getCurrentUid()}", frontImageFileName);
    }

    if (backImage.value.isNotEmpty && Constant().hasValidUrl(backImage.value) == false) {
      backImage.value = await Constant.uploadUserImageToFireStorage(File(backImage.value), "driverDocument/${FireStoreUtils.getCurrentUid()}", backImageFileName);
    }
    documents.value.frontImage = frontImage.value;
    documents.value.backImage = backImage.value;
    documents.value.documentId = documentModel.value.id;
    documents.value.status = "uploaded";

    await FireStoreUtils.uploadDriverDocument(documents.value).then((value) {
      if (value) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Document upload successfully".tr);

        Get.back(result: true);
      }
    });
  }
}
