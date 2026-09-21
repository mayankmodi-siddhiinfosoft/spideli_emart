import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/section_model.dart';
import 'package:vendor/models/admin_commission_model.dart';
import 'package:vendor/models/advertisement_model.dart';
import 'package:vendor/models/coupon_model.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/models/language_model.dart';
import 'package:vendor/models/mail_setting.dart';
import 'package:vendor/models/permission_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/zone_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/utils/preferences.dart';
import 'package:vendor/widget/permission_dialog.dart';
import 'package:video_player/video_player.dart';

class Constant {
  static String userRoleDriver = 'driver';
  static String userRoleCustomer = 'customer';
  static String userRoleVendor = 'vendor';
  static String userRoleEmployee = 'employee';

  static UserModel? userModel;
  static EmployeeRoleModel? employeeRoleModel;

  static const globalUrl = "https://spideli.com/admin";
  static const commissionSubscriptionID = "J0RwvxCWhZzQQD7Kc2Ll";

  static bool isZoneAvailable = false;
  static ZoneModel? selectedZone;

  static String mapAPIKey = "AIzaSyBhZufLHi10nF6KpZtqXlmJ84QMStjBmRo";
  static String placeHolderImage = "";
  static String defaultCountryCode = "";

  static String senderId = '';
  static String jsonNotificationFileURL = '';

  static String distanceType = "km";

  static bool? isEmployeeManagement = true;

  static String placeholderImage = "";
  static String googlePlayLink = "";
  static String appStoreLink = "";
  static String appVersion = "";
  static String storeUrl = "";
  static String termsAndConditions = "";
  static String digitalProductFileSize = "10";
  static String privacyPolicy = "";
  static String supportURL = "";
  static String minimumAmountToDeposit = "0.0";
  static String? referralAmount = "0.0";
  static String? selectedMapType = "google";
  static bool? storyEnable = true;

  static bool? autoApproveVendor = true;
  static bool? autoApproveStore = true;
  static bool isSubscriptionModelApplied = false; //Check SubscriptionModel is Active or Not in the Admin Panel.

  static bool isStoreVerification = false;
  static bool specialDiscountOfferEnable = false;

  static String scheduleOrder = "schedule_order";
  static String dineInPlaced = "dinein_placed";
  static String dineInCanceled = "dinein_canceled";
  static String dineInAccepted = "dinein_accepted";

  // static String driverAccepted = "driver_accepted";
  static String restaurantRejected = "restaurant_rejected";
  static String restaurantCancelled = "restaurant_cancelled";
  static String driverCompleted = "driver_completed";
  static String driverCancelled = "driver_cancelled";
  static String restaurantAccepted = "restaurant_accepted";
  static String takeawayCompleted = "takeaway_completed";
  static String newDeliveryOrder = "new_delivery_order";

  static const String orderPlaced = "Order Placed";
  static const String orderAccepted = "Order Accepted";
  static const String orderCancelled = "Order Cancelled";
  static const String orderRejected = "Order Rejected";
  static const String driverPending = "Driver Pending";
  static const String driverAccepted = "Driver Accepted";
  static const String driverRejected = "Driver Rejected";
  static const String orderShipped = "Order Shipped";
  static const String orderInTransit = "In Transit";
  static const String orderCompleted = "Order Completed";

  static String walletTopup = "wallet_topup";
  static String newVendorSignup = "new_vendor_signup";
  static String payoutRequestStatus = "payout_request_status";
  static String payoutRequest = "payout_request";
  static String newOrderPlaced = "new_order_placed";

  static String adsPending = 'pending';
  static String adsUpdated = 'updated';
  static String adsApproved = 'approved';
  static String adsRunning = 'running';
  static String adsPaused = 'paused';
  static String adsCancel = 'canceled';
  static String adsExpire = 'expired';

  static SectionModel? selectedSection;
  static CurrencyModel? currencyModel;
  static AdminCommission? vendorAdminCommission;
  static bool isEnableAdsFeature = false;
  static bool isSelfDeliveryFeature = false;

  static String orderRingtoneUrl = '';
  static bool singleOrderReceive = false;

  static String scheduleOrderTime = '0';
  static String scheduleOrderTimeType = 'minute'; // hour and day

  static String adminEmail = '';

  static String? apiBaseUrl = "";
  static String? apiSecureKey = "";
  static bool? openAIStatus = false;

  static String? taxScope = "";
  static List<TaxModel>? taxProductList = [];

  static String? adminType = "admin";

  static Color statusColor({required String? status}) {
    if (status == orderPlaced) {
      return AppThemeData.primary300;
    } else if (status == orderAccepted || status == orderCompleted) {
      return AppThemeData.success400;
    } else if (status == orderRejected) {
      return AppThemeData.danger300;
    } else {
      return AppThemeData.warning300;
    }
  }

  static Color adsStatusColor({required String? status}) {
    if (status == adsPending || status == adsUpdated) {
      return AppThemeData.warning300;
    } else if (status == adsApproved || status == adsRunning) {
      return AppThemeData.success400;
    } else if (status == adsExpire || status == adsCancel) {
      return AppThemeData.danger300;
    } else {
      return AppThemeData.danger300;
    }
  }

  static String getFileName(String url) {
    RegExp regExp = RegExp(r'.+(\/|%2F)(.+)\?.+');
    //This Regex won't work if you remove ?alt...token
    var matches = regExp.allMatches(url);

    var match = matches.elementAt(0);
    return Uri.decodeFull(match.group(2)!);
  }

  static String orderId({String orderId = ''}) {
    return "#${(orderId).substring(orderId.length - 10)}";
  }

  static String amountShow({required String? amount}) {
    if (currencyModel?.symbolAtRight == true) {
      return "${double.parse(amount == null ? '0.0' : amount.toString()).toStringAsFixed(currencyModel!.decimalDigits ?? 0)} ${currencyModel!.symbol.toString()}";
    } else {
      return "${currencyModel!.symbol.toString()} ${double.parse(amount == null ? '0.0' : amount.toString()).toStringAsFixed(currencyModel!.decimalDigits ?? 0)}";
    }
  }

  static double calculateTax({String? amount, TaxModel? taxModel}) {
    double taxAmount = 0.0;
    if (taxModel != null && taxModel.enable == true) {
      if (taxModel.type == "fix") {
        taxAmount = double.parse(taxModel.tax.toString());
      } else {
        taxAmount = (double.parse(amount.toString()) * double.parse(taxModel.tax!.toString())) / 100;
      }
    }
    return taxAmount;
  }

  static double calculateDiscount({String? amount, CouponModel? offerModel}) {
    double taxAmount = 0.0;
    if (offerModel != null) {
      if (offerModel.discountType == "Percentage" || offerModel.discountType == "percentage") {
        taxAmount = (double.parse(amount.toString()) * double.parse(offerModel.discount.toString())) / 100;
      } else {
        taxAmount = double.parse(offerModel.discount.toString());
      }
    }
    return taxAmount;
  }

  static String calculateReview({required String? reviewCount, required String? reviewSum}) {
    if (0 == double.parse(reviewSum.toString()) && 0 == double.parse(reviewSum.toString())) {
      return "0";
    }
    return (double.parse(reviewSum.toString()) / double.parse(reviewCount.toString())).toStringAsFixed(1);
  }

  static const userPlaceHolder = 'assets/images/user_placeholder.png';

  static String getUuid() {
    return const Uuid().v4();
  }

  static Widget loader() {
    return Center(child: CircularProgressIndicator(color: AppThemeData.primary300));
  }

  static Widget showEmptyView({required String message, required bool isDark}) {
    return Center(
      child: Text(
        message,
        style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
      ),
    );
  }

  static String getReferralCode() {
    var rng = math.Random();
    return (rng.nextInt(900000) + 100000).toString();
  }

  static String maskingString(String documentId, int maskingDigit) {
    String maskedDigits = documentId;
    for (int i = 0; i < documentId.length - maskingDigit; i++) {
      maskedDigits = maskedDigits.replaceFirst(documentId[i], "*");
    }
    return maskedDigits;
  }

  String? validateRequired(String? value, String type) {
    if (value!.isEmpty) {
      return '$type required';
    }
    return null;
  }

  String? validateEmail(String? value) {
    String pattern = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = RegExp(pattern);
    if (value == null || value.isEmpty) {
      return "Email is Required";
    } else if (!regExp.hasMatch(value)) {
      return "Invalid Email";
    } else {
      return null;
    }
  }

  static String getDistance({required String lat1, required String lng1, required String lat2, required String lng2}) {
    double distance;
    double distanceInMeters = Geolocator.distanceBetween(double.parse(lat1), double.parse(lng1), double.parse(lat2), double.parse(lng2));
    if (distanceType == "miles") {
      distance = distanceInMeters / 1609;
    } else {
      distance = distanceInMeters / 1000;
    }
    return distance.toStringAsFixed(2);
  }

  bool hasValidUrl(String value) {
    String pattern = r'(http|https)://[\w-]+(\.[\w-]+)+([\w.,@?^=%&amp;:/~+#-]*[\w@?^=%&amp;/~+#-])?';
    RegExp regExp = RegExp(pattern);
    if (value.isEmpty) {
      return false;
    } else if (!regExp.hasMatch(value)) {
      return false;
    }
    return true;
  }

  static Future<String> uploadUserImageToFireStorage(File image, String filePath, String fileName) async {
    Reference upload = FirebaseStorage.instance.ref().child('$filePath/$fileName');
    UploadTask uploadTask = upload.putFile(image);
    var downloadUrl = await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  Future<void> launchURL(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  static Future<TimeOfDay?> selectTime(context) async {
    FocusScope.of(context).requestFocus(FocusNode()); //remove focus
    TimeOfDay? newTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (newTime != null) {
      return newTime;
    }
    return null;
  }

  static Future<DateTime?> selectDate(context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppThemeData.primary300, // header background color
              onPrimary: AppThemeData.grey900, // header text color
              onSurface: AppThemeData.grey900, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppThemeData.grey900, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
      initialDate: DateTime.now(),
      //get today's date
      firstDate: DateTime(2000),
      //DateTime.now() - not to allow to choose before today.
      lastDate: DateTime(2101),
    );
    return pickedDate;
  }

  static String timestampToDate(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('MMM dd,yyyy').format(dateTime);
  }

  static String timestampToDateTime(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('MMM dd,yyyy hh:mm aa').format(dateTime);
  }

  static String timestampToTime(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('hh:mm aa').format(dateTime);
  }

  static String timestampToDateChat(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  static LanguageModel getLanguage() {
    final String user = Preferences.getString(Preferences.languageCodeKey);
    Map<String, dynamic> userMap = jsonDecode(user);
    return LanguageModel.fromJson(userMap);
  }

  static Future<void> checkPermission({required BuildContext context, required Function() onTap}) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      ShowToastDialog.showToast("You have to allow location permission to use your location".tr);
    } else if (permission == LocationPermission.deniedForever) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const PermissionDialog();
        },
      );
    } else {
      onTap();
    }
  }

  static bool isPointInPolygon(LatLng point, List<GeoPoint> polygon) {
    int crossings = 0;
    for (int i = 0; i < polygon.length; i++) {
      int next = (i + 1) % polygon.length;
      if (polygon[i].latitude <= point.latitude && polygon[next].latitude > point.latitude || polygon[i].latitude > point.latitude && polygon[next].latitude <= point.latitude) {
        double edgeLong = polygon[next].longitude - polygon[i].longitude;
        double edgeLat = polygon[next].latitude - polygon[i].latitude;
        double interpol = (point.latitude - polygon[i].latitude) / edgeLat;
        if (point.longitude < polygon[i].longitude + interpol * edgeLong) {
          crossings++;
        }
      }
    }
    return (crossings % 2 != 0);
  }

  static MailSettings? mailSettings;

  static final smtpServer = SmtpServer(
    mailSettings!.host.toString(),
    username: mailSettings!.userName.toString(),
    password: mailSettings!.password.toString(),
    port: 465,
    ignoreBadCertificate: false,
    ssl: true,
    allowInsecure: true,
  );

  static Future<void> sendMail({String? subject, String? body, bool? isAdmin = false, List<dynamic>? recipients}) async {
    // Create our message.
    if (isAdmin == true) {
      recipients!.add(mailSettings!.userName.toString());
    }
    final message = Message()
      ..from = Address(mailSettings!.userName.toString(), mailSettings!.fromName.toString())
      ..recipients = recipients!
      ..subject = subject
      ..text = body
      ..html = body;

    try {
      final sendReport = await send(message, smtpServer);
      print('Message sent: $sendReport');
    } on MailerException catch (e) {
      print(e);
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }

  static Color statusText({required String? status}) {
    if (status == orderPlaced) {
      return AppThemeData.grey50;
    } else if (status == orderAccepted || status == orderCompleted) {
      return AppThemeData.grey50;
    } else if (status == orderRejected) {
      return AppThemeData.grey50;
    } else {
      return AppThemeData.grey900;
    }
  }

  Timestamp? addDayInTimestamp({required String? days, required Timestamp date}) {
    if (days?.isNotEmpty == true && days != '0') {
      Timestamp now = date;
      DateTime dateTime = now.toDate();
      DateTime newDateTime = dateTime.add(Duration(days: int.parse(days!)));
      Timestamp newTimestamp = Timestamp.fromDate(newDateTime);
      return newTimestamp;
    } else {
      return null;
    }
  }

  Future<bool> isImageAspectRatioByType({required String imagePath, required AspectRatioType type}) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final aspectRatio = image.width / image.height;
    print("aspectRatio - 2.0).abs() :: ${((aspectRatio - 2.0).abs())}");
    // Allow a small margin for rounding differences
    return type == AspectRatioType.square ? (aspectRatio - 1.0).abs() < 0.01 : (aspectRatio - 2.0).abs() < 0.05;
  }

  Future<bool> isVideoLandscape({required String videoPath}) async {
    final controller = VideoPlayerController.file(File(videoPath));
    try {
      await controller.initialize();
      var size = controller.value.size;
      return (size.width > (size.height * 1.7));
    } catch (e) {
      print("Error loading video: $e");
      return false;
    } finally {
      await controller.dispose();
    }
  }

  static String getAdsStatus(AdvertisementModel adsModel) {
    if ((adsModel.status == Constant.adsPending || adsModel.status == Constant.adsUpdated) && adsModel.isPaused != true && adsModel.endDate!.toDate().isAfter(DateTime.now())) {
      return Constant.adsPending;
    } else if ((adsModel.status == Constant.adsApproved) &&
        adsModel.isPaused != true &&
        adsModel.paymentStatus == true &&
        adsModel.endDate!.toDate().isAfter(DateTime.now()) &&
        adsModel.startDate!.toDate().isBefore(DateTime.now())) {
      return Constant.adsRunning;
    } else if ((adsModel.status == Constant.adsApproved) &&
        adsModel.isPaused != true &&
        (adsModel.paymentStatus == false || (adsModel.paymentStatus == true && adsModel.startDate!.toDate().isAfter(DateTime.now()))) &&
        !adsModel.endDate!.toDate().isBefore(DateTime.now())) {
      return Constant.adsApproved;
    } else if (adsModel.status == Constant.adsCancel) {
      return Constant.adsCancel;
    } else if (adsModel.isPaused == true) {
      return Constant.adsPaused;
    } else if (adsModel.endDate!.toDate().isBefore(DateTime.now())) {
      return Constant.adsExpire;
    } else {
      return '';
    }
  }

  static DateTime checkScheduleTime({required DateTime scheduleDate}) {
    final int parsedTime = int.tryParse(scheduleOrderTime) ?? 0;

    Duration duration;
    switch (scheduleOrderTimeType) {
      case 'minute':
        duration = Duration(minutes: parsedTime);
        break;
      case 'hour':
        duration = Duration(hours: parsedTime);
        break;
      case 'day':
        duration = Duration(days: parsedTime);
        break;
      default:
        duration = Duration(minutes: 1);
    }
    return scheduleDate.subtract(duration);
  }

  static String getTaxDisplayText(List<TaxModel>? taxes) {
    if (taxes == null || taxes.isEmpty) return '';

    return taxes
        .map((tax) {
          if (tax.type == "fix") {
            return "${tax.title} (${Constant.amountShow(amount: tax.tax)})";
          } else {
            return "${tax.title} (${tax.tax}%)";
          }
        })
        .join(', ');
  }

  static bool getEmployeeRolePermission({required String module}) {
    if (Constant.userModel?.role != Constant.userRoleEmployee || Constant.isEmployeeManagement == false) {
      return true;
    }

    final permission = Constant.employeeRoleModel?.permissions?.firstWhere((p) => p.title == module, orElse: () => PermissionModel(title: ''));

    if (permission == null || permission.title == null || permission.title == '') {
      return false;
    }

    if (permission.isActive == true) {
      return true;
    } else {
      return false;
    }
  }

  static String dateAndTimeFormatTimestamp(Timestamp? timestamp) {
    var format = DateFormat('dd MMM yyyy hh:mm aa'); // <- use skeleton here
    return format.format(timestamp!.toDate());
  }
}

extension StringExtension on String {
  String capitalizeString() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

enum AspectRatioType {
  square, // 1:1
  wide, // 2:1
}
