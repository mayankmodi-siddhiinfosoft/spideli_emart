import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';

class API {
  static Map<String, String> get headers {
    return {
      HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      'apikey': Constant.apiSecureKey.toString(),
    };
  }

  //new
  static String generateTitleAndDescription = "${Constant.apiBaseUrl}/api/v1/generate-title-and-description";
  static String generateVariationData = "${Constant.apiBaseUrl}/api/v1/generate-variation-data";
  static String generateIngredients = "${Constant.apiBaseUrl}/api/v1/generate-ingredients";
  static String generateSpecification = "${Constant.apiBaseUrl}/api/v1/generate-specification";
  static String generateAddons = "${Constant.apiBaseUrl}/api/v1/generate-addons";
  static String generateImageData = "${Constant.apiBaseUrl}/api/v1/generate-image-data";

  static Future<dynamic> handleApiRequest({required Future<http.Response> Function() request, bool showLoader = true}) async {
    try {
      if (showLoader) {
        ShowToastDialog.showLoader("Please wait");
      }

      final response = await request().timeout(const Duration(seconds: 30));

      log("✅ API :: URL :: ${response.request?.url}");
      log("✅ API :: Response Status :: ${response.statusCode}");
      log("✅ API :: Response Body :: ${response.body}");

      final decodedResponse = jsonDecode(response.body);

      if (showLoader) ShowToastDialog.closeLoader();

      if (response.statusCode == 200) {
        return decodedResponse;
      } else if (response.statusCode == 401) {
        return null;
      } else {
        CustomDialog.showErrorDialog("Server Error", "Status Code: ${response.statusCode}");
        return null;
      }
    } on TimeoutException {
      log("⏰ Timeout Exception");
      CustomDialog.showErrorDialog("Server Timeout", "The server took too long to respond.");
    } on SocketException {
      log("🌐 No Internet / DNS Fail");
      CustomDialog.showErrorDialog("No Internet", "Please check your connection.");
    } on FormatException {
      log("📦 JSON Decode Error");
      ShowToastDialog.showToast("Invalid response format.");
    } catch (e) {
      log("🔥 Unexpected Error: $e");
      CustomDialog.showErrorDialog("Unexpected Error", "$e");
    } finally {
      if (showLoader) ShowToastDialog.closeLoader();
    }

    return null;
  }

  static Future<dynamic> handleMultipartRequest(
      {required String url, required Map<String, String> headers, required Map<String, String> fields, List<http.MultipartFile>? files, bool showLoader = true}) async {
    try {
      if (showLoader) {
        ShowToastDialog.showLoader("Please wait");
      }

      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(headers);
      request.fields.addAll(fields);

      if (files != null) {
        request.files.addAll(files);
      }

      var streamedResponse = await request.send();
      var responseBytes = await streamedResponse.stream.toBytes();
      var response = http.Response.bytes(
        responseBytes,
        streamedResponse.statusCode,
        headers: streamedResponse.headers,
        request: streamedResponse.request,
      );

      log("API :: URL :: ${response.request?.url}");
      log("API :: Response Status :: ${response.statusCode}");
      log("API :: Response Body :: ${response.body}");

      dynamic decodedResponse;
      try {
        decodedResponse = jsonDecode(response.body);
      } catch (e) {
        ShowToastDialog.showToast("Server error: ${response.body}");
        return null;
      }

      if (showLoader) {
        ShowToastDialog.closeLoader();
      }

      if (response.statusCode == 200) {
        return decodedResponse;
      } else {
        ShowToastDialog.showToast(decodedResponse['error'] ?? "Something went wrong: ${response.statusCode}");
        return null;
      }
    } on TimeoutException catch (e) {
      ShowToastDialog.showToast("Timeout: ${e.message}");
    } on SocketException catch (e) {
      ShowToastDialog.showToast("Connection Error: ${e.message}");
    } on Error catch (e) {
      ShowToastDialog.showToast("Error: $e");
    } catch (e) {
      ShowToastDialog.showToast("Unexpected Error: $e");
    } finally {
      if (showLoader) {
        ShowToastDialog.closeLoader();
      }
    }
    return null;
  }
}

class CustomDialog {
  static bool _isDialogVisible = false;

  static void showErrorDialog(String title, String message) {
    if (_isDialogVisible) return;

    _isDialogVisible = true;

    Get.defaultDialog(
      title: title,
      content: Text(message),
      textConfirm: "OK",
      barrierDismissible: false,
      onConfirm: () {
        _isDialogVisible = false;
        Get.back();
      },
      onWillPop: () async {
        _isDialogVisible = false;
        return true;
      },
    );
  }
}
