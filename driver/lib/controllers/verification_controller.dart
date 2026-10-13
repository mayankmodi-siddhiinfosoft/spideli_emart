import 'dart:async';
import 'dart:developer';

import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:driver/services/driver_document_status_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

/// The signed-in driver's own documents, live: `users/{uid}` and
/// `documents_verify/{uid}` are followed, so an owner's approval / rejection
/// (or the driver's own upload) shows at once, with the overall status
/// computed from the required documents ([DriverDocumentStatus.overall]).
class VerificationController extends GetxController {
  RxBool isLoading = true.obs;

  /// The documents could not be read: the screen offers a retry.
  RxBool loadFailed = false.obs;

  final Rxn<DriverDocumentsView> view = Rxn<DriverDocumentsView>();

  StreamSubscription<DriverDocumentsView>? _sub;

  List<DocumentModel> get documentList => view.value?.required ?? const [];

  List<Documents> get driverDocumentList => view.value?.docs ?? const [];

  DocumentOverallStatus get overall => view.value?.overall ?? DocumentOverallStatus.notSubmitted;

  @override
  void onInit() {
    getDocument();
    super.onInit();
  }

  /// (Re)starts following the driver's documents.
  Future<void> getDocument() async {
    await _sub?.cancel();
    loadFailed.value = false;
    if (view.value == null) isLoading.value = true;
    _sub = DriverDocumentStatusService.watch(FireStoreUtils.getCurrentUid()).listen(
      (v) {
        view.value = v;
        isLoading.value = false;
        loadFailed.value = false;
        update();
      },
      onError: (Object e) {
        log("Own documents not loaded: $e");
        isLoading.value = false;
        if (view.value == null) loadFailed.value = true;
        update();
      },
    );
  }

  /// The driver's entry for [documentModel] (an empty one when none).
  Documents entryFor(DocumentModel documentModel) => view.value?.entryFor(documentModel.id) ?? Documents();

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
