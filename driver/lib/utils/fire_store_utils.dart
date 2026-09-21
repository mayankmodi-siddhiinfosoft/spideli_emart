import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/app/chat_screens/chat_video_container.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/firebase_options.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/models/car_makes.dart';
import 'package:driver/models/car_model.dart';
import 'package:driver/models/conversation_model.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/models/email_template_model.dart';
import 'package:driver/models/inbox_model.dart';
import 'package:driver/models/mail_setting.dart';
import 'package:driver/models/notification_model.dart';
import 'package:driver/models/on_boarding_model.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/payment_model/cod_setting_model.dart';
import 'package:driver/models/payment_model/flutter_wave_model.dart';
import 'package:driver/models/payment_model/mercado_pago_model.dart';
import 'package:driver/models/payment_model/mid_trans.dart';
import 'package:driver/models/payment_model/orange_money.dart';
import 'package:driver/models/payment_model/pay_fast_model.dart';
import 'package:driver/models/payment_model/pay_stack_model.dart';
import 'package:driver/models/payment_model/paypal_model.dart';
import 'package:driver/models/payment_model/paytm_model.dart';
import 'package:driver/models/payment_model/razorpay_model.dart';
import 'package:driver/models/payment_model/stripe_model.dart';
import 'package:driver/models/payment_model/wallet_setting_model.dart';
import 'package:driver/models/payment_model/xendit.dart';
import 'package:driver/models/referral_model.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/models/tax_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/vendor_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/models/withdraw_method_model.dart';
import 'package:driver/models/withdrawal_model.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/utils/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import '../models/parcel_category.dart';
import '../models/rating_model.dart';

enum FirebaseEnv { defaultDb, staging }

/// Change this to switch between default / staging
const FirebaseEnv currentEnv = FirebaseEnv.defaultDb;

class FireStoreUtils {
  FireStoreUtils._privateConstructor();

  static final FireStoreUtils instance = FireStoreUtils._privateConstructor();

  static late FirebaseFirestore fireStore;

  /// Initialize Firestore with a FirebaseApp and optional databaseId
  void init(FirebaseApp app, {String? databaseId}) {
    fireStore = FirebaseFirestore.instanceFor(app: app, databaseId: databaseId);
  }

  static String getCurrentUid() {
    return FirebaseAuth.instance.currentUser!.uid;
  }

  static Future<bool> isLogin() async {
    bool isLogin = false;
    if (FirebaseAuth.instance.currentUser != null) {
      isLogin = await userExistOrNot(FirebaseAuth.instance.currentUser!.uid);
    } else {
      isLogin = false;
    }
    return isLogin;
  }

  static Future<bool> userExistOrNot(String uid) async {
    bool isExist = false;

    await fireStore.collection(CollectionName.users).doc(uid).get().then(
      (value) {
        if (value.exists) {
          isExist = true;
        } else {
          isExist = false;
        }
      },
    ).catchError((error) {
      log("Failed to check user exist: $error");
      isExist = false;
    });
    return isExist;
  }

  static Future<bool> isMaintenanceMode() async {
    bool isMaintenance = false;
    await fireStore.collection(CollectionName.settings).doc('maintenance_settings').get().then((value) async {
      isMaintenance = value.data()?['isMaintenanceModeForDriver'] == true;
      log("isMaintenance :: $isMaintenance");
    });
    return isMaintenance;
  }

  static Future<UserModel?> getUserProfile(String uuid) async {
    UserModel? userModel;
    await fireStore.collection(CollectionName.users).doc(uuid).get().then((value) {
      if (value.exists) {
        userModel = UserModel.fromJson(value.data()!);
      }
    }).catchError((error) {
      log("Failed to update user: $error");
      userModel = null;
    });
    return userModel;
  }

  static Future<bool?> updateUserWallet({required String amount, required String userId}) async {
    bool isAdded = false;
    await getUserProfile(userId).then((value) async {
      if (value != null) {
        UserModel userModel = value;
        userModel.walletAmount = double.parse(userModel.walletAmount.toString()) + double.parse(amount);
        await FireStoreUtils.updateUser(userModel).then((value) {
          isAdded = value;
        });
      }
    });
    return isAdded;
  }

  static Map<String, dynamic> removeNulls(Map<String, dynamic> map) {
    map.removeWhere((key, value) => value == null);

    map.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        removeNulls(value);
        if (value.isEmpty) {
          map.remove(key);
        }
      }
    });

    return map;
  }

  static Future<bool> updateUser(UserModel userModel) async {
    try {
      final docRef = fireStore.collection(CollectionName.users).doc(userModel.id);

      final Map<String, dynamic> data = removeNulls(userModel.toJson());

      await docRef.set(data, SetOptions(merge: true));

      // Clean up legacy / deprecated top-level fields via a separate update()
      // call. Sentinels (FieldValue.delete) can only appear at the top level
      // of an update, and must not appear inside nested maps written via set().
      final Map<String, dynamic> deletes = {
        'sectionId': FieldValue.delete(),
        'serviceType': FieldValue.delete(),
        'serviceDetails': FieldValue.delete(),
      };
      if (userModel.role == Constant.userRoleDriver) {
        deletes.addAll({
          'vehicleType': FieldValue.delete(),
          'vehicleId': FieldValue.delete(),
          'carName': FieldValue.delete(),
          'carNumber': FieldValue.delete(),
          'carMakes': FieldValue.delete(),
          'rideType': FieldValue.delete(),
        });
      }
      if (userModel.orderCabRequestData == null) {
        deletes['ordercabRequestData'] = FieldValue.delete();
      }
      await docRef.update(deletes);

      if (userModel.id == getCurrentUid()) {
        Constant.userModel = userModel;
      }

      return true;
    } catch (error, stack) {
      log("Failed to update user: $error");
      log(stack.toString());
      return false;
    }
  }

  static Future<List<OnBoardingModel>> getOnBoardingList() async {
    List<OnBoardingModel> onBoardingModel = [];
    await fireStore.collection(CollectionName.onBoarding).where("type", isEqualTo: "driver").get().then((value) {
      for (var element in value.docs) {
        OnBoardingModel documentModel = OnBoardingModel.fromJson(element.data());
        onBoardingModel.add(documentModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return onBoardingModel;
  }

  static Future<List<SectionModel>> getSections(String serviceType) async {
    List<SectionModel> sections = [];
    QuerySnapshot<Map<String, dynamic>> productsQuery = await fireStore.collection(CollectionName.sections).where("serviceTypeFlag", isEqualTo: serviceType).where("isActive", isEqualTo: true).get();

    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        sections.add(SectionModel.fromJson(document.data()));
      } catch (e) {
        print('**-FireStoreUtils.getSection Parse error $e');
      }
    });
    return sections;
  }

  /// Returns active sections for driver registration (delivery, cab, parcel, rental only).
  /// Excludes onDemand, ecommerce, and any other non-driver section types.
  static Future<List<SectionModel>> getAllActiveSections() async {
    const driverFlags = ['delivery-service', 'cab-service', 'parcel_delivery', 'rental-service'];
    List<SectionModel> sections = [];
    await fireStore.collection(CollectionName.sections).where("isActive", isEqualTo: true).get().then((query) {
      for (var doc in query.docs) {
        try {
          final section = SectionModel.fromJson(doc.data());
          if (driverFlags.contains(section.serviceTypeFlag)) {
            sections.add(section);
          }
        } catch (e) {
          print('**-FireStoreUtils.getAllActiveSections Parse error $e');
        }
      }
    });
    return sections;
  }

  static Future<bool?> setWalletTransaction(WalletTransactionModel walletTransactionModel) async {
    bool isAdded = false;
    await fireStore.collection(CollectionName.wallet).doc(walletTransactionModel.id).set(walletTransactionModel.toJson()).then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<void> getSettings() async {
    try {
      await fireStore.collection(CollectionName.settings).doc("globalSettings").get().then((value) async {
        Constant.orderRingtoneUrl = value.data()?['order_ringtone_url'] ?? '';
        Constant.isSelfDeliveryFeature = value.data()!['isSelfDelivery'] ?? false;
        Constant.defaultCountryCode = value.data()?['defaultCountryCode'] ?? '';

        Preferences.setString(Preferences.orderRingtone, Constant.orderRingtoneUrl);
        AppThemeData.primary300 = Color(int.parse(value.data()!['app_driver_color'].replaceFirst("#", "0xff")));
        if (Constant.orderRingtoneUrl.isNotEmpty) {
          await AudioPlayerService.initAudio();
        }
      });

      fireStore.collection(CollectionName.settings).doc("googleMapKey").snapshots().listen((event) {
        if (event.exists) {
          Constant.mapAPIKey = event.data()!["key"];
        }
      });

      fireStore.collection(CollectionName.settings).doc("notification_setting").snapshots().listen((event) {
        if (event.exists) {
          Constant.senderId = event.data()?["senderId"];
          Constant.jsonNotificationFileURL = event.data()?["serviceJson"];
        }
      });

      fireStore.collection(CollectionName.settings).doc("RestaurantNearBy").snapshots().listen((event) {
        if (event.exists) {
          Constant.distanceType = event.data()!["distanceType"];
        }
      });

      fireStore.collection(CollectionName.settings).doc("privacyPolicy").snapshots().listen((event) {
        if (event.exists) {
          Constant.privacyPolicy = event.data()!["privacy_policy"];
        }
      });

      fireStore.collection(CollectionName.settings).doc("termsAndConditions").snapshots().listen((event) {
        if (event.exists) {
          Constant.termsAndConditions = event.data()?["terms_and_condition"] ?? '';
        }
      });

      fireStore.collection(CollectionName.settings).doc("Version").snapshots().listen((event) {
        if (event.exists) {
          Constant.googlePlayLink = event.data()!["googlePlayLink"] ?? '';
          Constant.appStoreLink = event.data()!["appStoreLink"] ?? '';
          Constant.appVersion = event.data()!["app_version"] ?? '';
        }
      });

      // fireStore.collection(CollectionName.settings).doc('referral_amount').get().then((value) {
      //   Constant.referralAmount = value.data()!['referralAmount'];
      // });

      fireStore.collection(CollectionName.settings).doc("emailSetting").get().then((value) {
        if (value.exists) {
          Constant.mailSettings = MailSettings.fromJson(value.data()!);
        }
      });

      fireStore.collection(CollectionName.settings).doc('placeHolderImage').get().then((value) {
        Constant.placeHolderImage = value.data()!['image'];
      });

      await fireStore.collection(CollectionName.settings).doc("document_verification_settings").get().then((value) {
        Constant.isDriverVerification = value.data()!['isDriverVerification'];
        Constant.isOwnerVerification = value.data()!['isOwnerVerification'];
      });

      await fireStore.collection(CollectionName.settings).doc("DriverNearBy").get().then((value) {
        Constant.minimumDepositToRideAccept = value.data()!['minimumDepositToRideAccept'];
        Constant.ownerMinimumDepositToRideAccept = value.data()!['ownerMinimumDepositToRideAccept'];
        Constant.minimumAmountToWithdrawal = value.data()!['minimumAmountToWithdrawal'];
        Constant.driverLocationUpdate = value.data()!['driverLocationUpdate'];
        Constant.singleOrderReceive = value.data()!['singleOrderReceive'];
        Constant.selectedMapType = value.data()!["selectedMapType"];
        Constant.mapType = value.data()!["mapType"];
        Constant.autoApproveDriver = value.data()!["auto_approve_driver"];
        Constant.enableOTPTripStart = value.data()!["enableOTPTripStart"];
        Constant.enableOTPTripStartForRental = value.data()!["enableOTPTripStartForRental"];
        Constant.parcelRadius = value.data()!["parcelRadius"];
        Constant.rentalRadius = value.data()!["rentalRadius"];
        log("Constant.singleOrderReceive :: ${Constant.singleOrderReceive}");
      });
    } catch (e) {
      log(e.toString());
    }
  }

  static Future<List<ZoneModel>?> getZone() async {
    List<ZoneModel> airPortList = [];
    await fireStore.collection(CollectionName.zone).where('publish', isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        ZoneModel ariPortModel = ZoneModel.fromJson(element.data());
        airPortList.add(ariPortModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return airPortList;
  }

  static Future<List<CarMakes>> getCarMakes() async {
    List<CarMakes> airPortList = [];
    await fireStore.collection(CollectionName.carMake).where('isActive', isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        CarMakes ariPortModel = CarMakes.fromJson(element.data());
        airPortList.add(ariPortModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return airPortList;
  }

  static Future<List<ParcelOrderModel>> getOnGoingParcelList() async {
    List<ParcelOrderModel> parcelOrderList = [];
    QuerySnapshot<Map<String, dynamic>> currencyQuery = await fireStore
        .collection(CollectionName.parcelOrders)
        .where("driverId", isEqualTo: FireStoreUtils.getCurrentUid())
        .where("status", whereIn: [Constant.driverAccepted, Constant.orderInTransit, Constant.orderShipped]).get();
    await Future.forEach(currencyQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        parcelOrderList.add(ParcelOrderModel.fromJson(document.data()));
      } catch (e) {
        debugPrint('FireStoreUtils.get Currency Parse error $e');
      }
    });
    return parcelOrderList;
  }

  static Future<List<RentalOrderModel>> getRentalOnGoingParcelList() async {
    List<RentalOrderModel> parcelOrderList = [];
    QuerySnapshot<Map<String, dynamic>> currencyQuery = await fireStore
        .collection(CollectionName.rentalOrders)
        .where("driverId", isEqualTo: FireStoreUtils.getCurrentUid())
        .where("status", whereIn: [Constant.driverAccepted, Constant.orderInTransit, Constant.orderShipped]).get();
    await Future.forEach(currencyQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        parcelOrderList.add(RentalOrderModel.fromJson(document.data()));
      } catch (e) {
        debugPrint('FireStoreUtils.get Currency Parse error $e');
      }
    });
    return parcelOrderList;
  }

  static Future<List<UserModel>> getOwnerDriver() async {
    List<UserModel> userList = [];
    QuerySnapshot<Map<String, dynamic>> currencyQuery =
        await fireStore.collection(CollectionName.users).where("ownerId", isEqualTo: FireStoreUtils.getCurrentUid()).where("isOwner", isEqualTo: false).get();
    await Future.forEach(currencyQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        userList.add(UserModel.fromJson(document.data()));
      } catch (e) {
        debugPrint('FireStoreUtils.get Currency Parse error $e');
      }
    });
    return userList;
  }

  static Future<List<CarModel>> getCarModel(String name) async {
    List<CarModel> airPortList = [];
    await fireStore.collection(CollectionName.carModel).where("car_make_name", isEqualTo: name).where('isActive', isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        CarModel ariPortModel = CarModel.fromJson(element.data());
        airPortList.add(ariPortModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return airPortList;
  }

  static Future<List<VehicleType>> getCabVehicleType(String sectionId) async {
    List<VehicleType> airPortList = [];
    await fireStore.collection(CollectionName.vehicleType).where('sectionId', isEqualTo: sectionId).where("isActive", isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        VehicleType ariPortModel = VehicleType.fromJson(element.data());
        airPortList.add(ariPortModel);
      }
    });
    return airPortList;
  }

  static Future<List<VehicleType>> getRentalVehicleType(String sectionId) async {
    print("sectionId :: $sectionId");
    List<VehicleType> airPortList = [];
    await fireStore.collection(CollectionName.rentalVehicleType).where('sectionId', isEqualTo: sectionId).where('isActive', isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        VehicleType ariPortModel = VehicleType.fromJson(element.data());
        airPortList.add(ariPortModel);
      }
    });
    return airPortList;
  }

  static Future<List<WalletTransactionModel>?> getWalletTransaction() async {
    List<WalletTransactionModel> walletTransactionList = [];
    await fireStore.collection(CollectionName.wallet).where('user_id', isEqualTo: FireStoreUtils.getCurrentUid()).orderBy('date', descending: true).get().then((value) {
      for (var element in value.docs) {
        WalletTransactionModel walletTransactionModel = WalletTransactionModel.fromJson(element.data());
        walletTransactionList.add(walletTransactionModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return walletTransactionList;
  }

  static Future getPaymentSettingsData() async {
    await fireStore.collection(CollectionName.settings).doc("payFastSettings").get().then((value) async {
      if (value.exists) {
        PayFastModel payFastModel = PayFastModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.payFastSettings, jsonEncode(payFastModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("MercadoPago").get().then((value) async {
      if (value.exists) {
        MercadoPagoModel mercadoPagoModel = MercadoPagoModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.mercadoPago, jsonEncode(mercadoPagoModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("paypalSettings").get().then((value) async {
      if (value.exists) {
        PayPalModel payPalModel = PayPalModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.paypalSettings, jsonEncode(payPalModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("stripeSettings").get().then((value) async {
      if (value.exists) {
        StripeModel stripeModel = StripeModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.stripeSettings, jsonEncode(stripeModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("flutterWave").get().then((value) async {
      if (value.exists) {
        FlutterWaveModel flutterWaveModel = FlutterWaveModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.flutterWave, jsonEncode(flutterWaveModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("payStack").get().then((value) async {
      if (value.exists) {
        PayStackModel payStackModel = PayStackModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.payStack, jsonEncode(payStackModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("PaytmSettings").get().then((value) async {
      if (value.exists) {
        PaytmModel paytmModel = PaytmModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.paytmSettings, jsonEncode(paytmModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("walletSettings").get().then((value) async {
      if (value.exists) {
        WalletSettingModel walletSettingModel = WalletSettingModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.walletSettings, jsonEncode(walletSettingModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("razorpaySettings").get().then((value) async {
      if (value.exists) {
        RazorPayModel razorPayModel = RazorPayModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.razorpaySettings, jsonEncode(razorPayModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("CODSettings").get().then((value) async {
      if (value.exists) {
        CodSettingModel codSettingModel = CodSettingModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.codSettings, jsonEncode(codSettingModel.toJson()));
      }
    });

    await fireStore.collection(CollectionName.settings).doc("midtrans_settings").get().then((value) async {
      if (value.exists) {
        MidTrans midTrans = MidTrans.fromJson(value.data()!);
        await Preferences.setString(Preferences.midTransSettings, jsonEncode(midTrans.toJson()));
      }
    });

    await fireStore.collection(CollectionName.settings).doc("orange_money_settings").get().then((value) async {
      if (value.exists) {
        OrangeMoney orangeMoney = OrangeMoney.fromJson(value.data()!);
        await Preferences.setString(Preferences.orangeMoneySettings, jsonEncode(orangeMoney.toJson()));
      }
    });

    await fireStore.collection(CollectionName.settings).doc("xendit_settings").get().then((value) async {
      if (value.exists) {
        Xendit xendit = Xendit.fromJson(value.data()!);
        await Preferences.setString(Preferences.xenditSettings, jsonEncode(xendit.toJson()));
      }
    });
  }

  static Future<VendorModel?> getVendorById(String vendorId) async {
    VendorModel? vendorModel;
    try {
      await fireStore.collection(CollectionName.vendors).doc(vendorId).get().then((value) {
        if (value.exists) {
          vendorModel = VendorModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorModel;
  }

  static Future<OrderModel?> getOrderById(String orderId) async {
    OrderModel? orderModel;
    try {
      await fireStore.collection(CollectionName.vendorOrders).doc(orderId).get().then((value) {
        if (value.exists) {
          orderModel = OrderModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return orderModel;
  }

  static Future<SectionModel?> getSectionBySectionId(String sectionId) async {
    SectionModel? orderModel;
    try {
      await fireStore.collection(CollectionName.sections).doc(sectionId).get().then((value) {
        if (value.exists) {
          orderModel = SectionModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return orderModel;
  }

  static Future<DeliveryCharge?> getDeliveryCharge() async {
    DeliveryCharge? deliveryCharge;
    try {
      await fireStore.collection(CollectionName.settings).doc("DeliveryCharge").get().then((value) {
        if (value.exists) {
          deliveryCharge = DeliveryCharge.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return deliveryCharge;
  }

  static Future<List<TaxModel>?> getTaxList() async {
    List<TaxModel> taxList = [];
    List<Placemark> placeMarks = await placemarkFromCoordinates(Constant.selectedLocation.location!.latitude!, Constant.selectedLocation.location!.longitude!);
    await fireStore.collection(CollectionName.tax).where('country', isEqualTo: placeMarks.first.country).where('enable', isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        TaxModel taxModel = TaxModel.fromJson(element.data());
        taxList.add(taxModel);
      }
    }).catchError((error) {
      log(error.toString());
    });

    return taxList;
  }

  static Future<bool?> setOrder(OrderModel orderModel) async {
    bool isAdded = false;
    await fireStore.collection(CollectionName.vendorOrders).doc(orderModel.id).set(orderModel.toJson(), SetOptions(merge: true)).then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<bool?> setParcelOrder(ParcelOrderModel orderModel) async {
    bool isAdded = false;
    await fireStore.collection(CollectionName.parcelOrders).doc(orderModel.id).set(orderModel.toJson()).then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<bool> setCabOrder(CabOrderModel orderModel) async {
    log("setCabOrder :: ${orderModel.toJson()}");
    try {
      await fireStore.collection(CollectionName.ridesBooking).doc(orderModel.id).set(orderModel.toJson(), SetOptions(merge: true));
      return true;
    } catch (error) {
      log("Failed to update cab order: $error");
      return false;
    }
  }

  static Future<EmailTemplateModel?> getEmailTemplates(String type) async {
    EmailTemplateModel? emailTemplateModel;
    await fireStore.collection(CollectionName.emailTemplates).where('type', isEqualTo: type).get().then((value) {
      print("------>");
      if (value.docs.isNotEmpty) {
        print(value.docs.first.data());
        emailTemplateModel = EmailTemplateModel.fromJson(value.docs.first.data());
      }
    });
    return emailTemplateModel;
  }

  static Future<void> updateWallateAmount(OrderModel orderModel) async {
    double subTotal = 0.0;
    double specialDiscountAmount = 0.0;
    double couponAmount = 0.0;
    double productTaxAmount = 0.0;
    double orderTaxAmount = 0.0;
    double driverDeliveryTaxAmount = 0.0;
    double packagingTaxAmount = 0.0;
    double platformTaxAmount = 0.0;
    double platformFee = 0.0;
    double deliveryCharges = 0.0;
    double deliveryTips = 0.0;
    double packagingCharge = 0.0;

    /// ---------------- SUBTOTAL ----------------
    for (var element in orderModel.products!) {
      final double price = (double.parse(element.discountPrice.toString()) > 0) ? double.parse(element.discountPrice.toString()) : double.parse(element.price.toString());

      final double qty = double.parse(element.quantity.toString());
      final double extras = double.parse(element.extrasPrice.toString());

      subTotal += (price * qty) + (extras * qty);
    }

    /// ---------------- DISCOUNTS ----------------
    couponAmount = double.parse(orderModel.discount.toString());

    if (orderModel.specialDiscount != null && orderModel.specialDiscount!['special_discount'] != null) {
      specialDiscountAmount = double.parse(orderModel.specialDiscount!['special_discount'].toString());
    }

    final double totalDiscount = couponAmount + specialDiscountAmount;

    /// ---------------- DISCOUNT RATIO ----------------
    double discountRatio = 0.0;
    if (subTotal > 0 && totalDiscount > 0) {
      discountRatio = totalDiscount / subTotal;
    }

    /// ---------------- PRODUCT TAX (AFTER DISCOUNT) ----------------
    if (orderModel.taxScope == "product") {
      for (var element in orderModel.products!) {
        final double price = (double.parse(element.discountPrice.toString()) > 0) ? double.parse(element.discountPrice.toString()) : double.parse(element.price.toString());

        final double qty = double.parse(element.quantity.toString());
        final double extras = double.parse(element.extrasPrice.toString());

        final double itemAmount = (price * qty) + (extras * qty);

        final double discountedItemAmount = itemAmount - (itemAmount * discountRatio);

        for (var taxElement in element.taxSetting!) {
          if (taxElement.type == "fix") {
            productTaxAmount += Constant.calculateTax(
                  amount: discountedItemAmount.toString(),
                  taxModel: taxElement,
                ) *
                qty;
          } else {
            productTaxAmount += Constant.calculateTax(
              amount: discountedItemAmount.toString(),
              taxModel: taxElement,
            );
          }
        }
      }
    }

    /// ---------------- ORDER LEVEL TAX ----------------
    if (orderModel.taxScope == "order") {
      for (var taxElement in orderModel.taxSetting ?? []) {
        orderTaxAmount += Constant.calculateTax(
          amount: (subTotal - totalDiscount).toString(),
          taxModel: taxElement,
        );
      }
    }

    /// ---------------- OTHER CHARGES ----------------
    deliveryCharges = double.parse(orderModel.deliveryCharge.toString());

    deliveryTips = double.parse(orderModel.tipAmount.toString());

    packagingCharge = orderModel.packagingChargeEnable == true ? double.parse(orderModel.vendor!.packagingCharge.toString()) : 0.0;

    platformFee = double.parse(orderModel.platformFee ?? '0.0');

    /// ---------------- DELIVERY TAX ----------------
    if (orderModel.takeAway != true && orderModel.vendor?.isSelfDelivery != true) {
      for (var taxElement in orderModel.driverDeliveryTax ?? []) {
        driverDeliveryTaxAmount += Constant.calculateTax(
          amount: deliveryCharges.toString(),
          taxModel: taxElement,
        );
      }
    }

    /// ---------------- PACKAGING TAX ----------------
    if (packagingCharge > 0) {
      for (var taxElement in orderModel.packagingTax ?? []) {
        packagingTaxAmount += Constant.calculateTax(
          amount: packagingCharge.toString(),
          taxModel: taxElement,
        );
      }
    }

    /// ---------------- PLATFORM TAX ----------------
    if (platformFee > 0) {
      for (var taxElement in orderModel.platformTax ?? []) {
        platformTaxAmount += Constant.calculateTax(
          amount: platformFee.toString(),
          taxModel: taxElement,
        );
      }
    }

    double driverAmount = 0.0;
    final isCOD = orderModel.paymentMethod?.toLowerCase() == "cod";

    if (isCOD) {
      // Driver gives money back
      driverAmount = -((subTotal - totalDiscount) + productTaxAmount + orderTaxAmount + packagingTaxAmount + platformTaxAmount + packagingCharge + platformFee);

      WalletTransactionModel codTxn = WalletTransactionModel(
        id: Constant.getUuid(),
        amount: driverAmount,
        date: Timestamp.now(),
        paymentMethod: orderModel.paymentMethod!,
        transactionUser: "driver",
        userId: FireStoreUtils.getCurrentUid(),
        isTopup: false,
        note: "Product amount debited from order #${orderModel.id}",
        orderId: orderModel.id,
        paymentStatus: "success",
      );

      await FireStoreUtils.setWalletTransaction(codTxn);
    } else {
      driverAmount = deliveryCharges + deliveryTips + driverDeliveryTaxAmount;

      WalletTransactionModel onlineTxn = WalletTransactionModel(
        id: Constant.getUuid(),
        amount: driverAmount,
        date: Timestamp.now(),
        paymentMethod: orderModel.paymentMethod ?? "online",
        transactionUser: "driver",
        userId: FireStoreUtils.getCurrentUid(),
        isTopup: true,
        note: "Delivery charge credited for order #${orderModel.id}",
        orderId: orderModel.id,
        paymentStatus: "success",
      );

      await FireStoreUtils.setWalletTransaction(onlineTxn);
    }
    await FireStoreUtils.updateUserWallet(
      userId: orderModel.driverID!,
      amount: driverAmount.toString(),
    );
  }

  static Future<void> sendTopUpMail({required String amount, required String paymentMethod, required String tractionId}) async {
    EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.walletTopup);

    String newString = emailTemplateModel!.message.toString();
    newString = newString.replaceAll("{username}", Constant.userModel!.firstName.toString() + Constant.userModel!.lastName.toString());
    newString = newString.replaceAll("{date}", DateFormat('yyyy-MM-dd').format(Timestamp.now().toDate()));
    newString = newString.replaceAll("{amount}", Constant.amountShow(amount: amount));
    newString = newString.replaceAll("{paymentmethod}", paymentMethod.toString());
    newString = newString.replaceAll("{transactionid}", tractionId.toString());
    newString = newString.replaceAll("{newwalletbalance}.", Constant.amountShow(amount: Constant.userModel!.walletAmount.toString()));
    await Constant.sendMail(subject: emailTemplateModel.subject, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
  }

  static Future<List> getVendorCuisines(String id) async {
    List tagList = [];
    List prodTagList = [];
    QuerySnapshot<Map<String, dynamic>> productsQuery = await fireStore.collection(CollectionName.vendorProducts).where('vendorID', isEqualTo: id).get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      if (document.data().containsKey("categoryID") && document.data()['categoryID'].toString().isNotEmpty) {
        prodTagList.add(document.data()['categoryID']);
      }
    });
    QuerySnapshot<Map<String, dynamic>> catQuery = await fireStore.collection(CollectionName.vendorCategories).where('publish', isEqualTo: true).get();
    await Future.forEach(catQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      Map<String, dynamic> catDoc = document.data();
      if (catDoc.containsKey("id") && catDoc['id'].toString().isNotEmpty && catDoc.containsKey("title") && catDoc['title'].toString().isNotEmpty && prodTagList.contains(catDoc['id'])) {
        tagList.add(catDoc['title']);
      }
    });
    return tagList;
  }

  static Future<NotificationModel?> getNotificationContent(String type) async {
    NotificationModel? notificationModel;
    await fireStore.collection(CollectionName.dynamicNotification).where('type', isEqualTo: type).get().then((value) {
      print("------>");
      if (value.docs.isNotEmpty) {
        print(value.docs.first.data());

        notificationModel = NotificationModel.fromJson(value.docs.first.data());
      } else {
        notificationModel = NotificationModel(id: "", message: "Notification setup is pending", subject: "setup notification", type: "");
      }
    });
    return notificationModel;
  }

  static Future<bool?> deleteUser() async {
    bool? isDelete;
    try {
      await fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).delete();

      // delete user  from firebase auth
      await FirebaseAuth.instance.currentUser?.delete().then((value) {
        isDelete = true;
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return false;
    }
    return isDelete;
  }

  static Future<List<DocumentModel>> getDocumentList(String type) async {
    List<DocumentModel> documentList = [];
    await fireStore.collection(CollectionName.documents).where('type', isEqualTo: type).where('enable', isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        DocumentModel documentModel = DocumentModel.fromJson(element.data());
        documentList.add(documentModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return documentList;
  }

  static Future<DriverDocumentModel?> getDocumentOfDriver() async {
    DriverDocumentModel? driverDocumentModel;
    await fireStore.collection(CollectionName.documentsVerify).doc(getCurrentUid()).get().then((value) async {
      if (value.exists) {
        driverDocumentModel = DriverDocumentModel.fromJson(value.data()!);
      }
    });
    return driverDocumentModel;
  }

  static Future addDriverInbox(InboxModel inboxModel) async {
    return await fireStore.collection("chat_driver").doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addDriverChat(ConversationModel conversationModel) async {
    return await fireStore.collection("chat_driver").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addRestaurantChat(ConversationModel conversationModel) async {
    return await fireStore.collection("chat_restaurant").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future<Url> uploadChatImageToFireStorage(File image, BuildContext context) async {
    ShowToastDialog.showLoader("Please wait");
    var uniqueID = const Uuid().v4();
    Reference upload = FirebaseStorage.instance.ref().child('images/$uniqueID.png');
    UploadTask uploadTask = upload.putFile(image);
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();
    var metaData = await storageRef.getMetadata();
    ShowToastDialog.closeLoader();
    return Url(mime: metaData.contentType ?? 'image', url: downloadUrl.toString());
  }

  // static Future<ChatVideoContainer> uploadChatVideoToFireStorage(File video, BuildContext context) async {
  //   ShowToastDialog.showLoader("Please wait");
  //   var uniqueID = const Uuid().v4();
  //   Reference upload = FirebaseStorage.instance.ref().child('videos/$uniqueID.mp4');
  //   SettableMetadata metadata = SettableMetadata(contentType: 'video');
  //   UploadTask uploadTask = upload.putFile(video, metadata);
  //   var storageRef = (await uploadTask.whenComplete(() {})).ref;
  //   var downloadUrl = await storageRef.getDownloadURL();
  //   var metaData = await storageRef.getMetadata();
  //   final uint8list = await VideoThumbnail.thumbnailFile(video: downloadUrl, thumbnailPath: (await getTemporaryDirectory()).path, imageFormat: ImageFormat.PNG);
  //   final file = File(uint8list ?? '');
  //   String thumbnailDownloadUrl = await uploadVideoThumbnailToFireStorage(file);
  //   ShowToastDialog.closeLoader();
  //   return ChatVideoContainer(videoUrl: Url(url: downloadUrl.toString(), mime: metaData.contentType ?? 'video'), thumbnailUrl: thumbnailDownloadUrl);
  // }

  static Future<ChatVideoContainer?> uploadChatVideoToFireStorage(BuildContext context, File video) async {
    try {
      ShowToastDialog.showLoader("Uploading video...");
      final String uniqueID = const Uuid().v4();
      final Reference videoRef = FirebaseStorage.instance.ref('videos/$uniqueID.mp4');
      final UploadTask uploadTask = videoRef.putFile(
        video,
        SettableMetadata(contentType: 'video/mp4'),
      );
      await uploadTask;
      final String videoUrl = await videoRef.getDownloadURL();
      ShowToastDialog.showLoader("Generating thumbnail...");
      File thumbnail = await VideoCompress.getFileThumbnail(
        video.path,
        quality: 75, // 0 - 100
        position: -1, // Get the first frame
      );

      final String thumbnailID = const Uuid().v4();
      final Reference thumbnailRef = FirebaseStorage.instance.ref('thumbnails/$thumbnailID.jpg');
      final UploadTask thumbnailUploadTask = thumbnailRef.putData(
        thumbnail.readAsBytesSync(),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      await thumbnailUploadTask;
      final String thumbnailUrl = await thumbnailRef.getDownloadURL();
      var metaData = await thumbnailRef.getMetadata();
      ShowToastDialog.closeLoader();

      return ChatVideoContainer(videoUrl: Url(url: videoUrl.toString(), mime: metaData.contentType ?? 'video'), thumbnailUrl: thumbnailUrl);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error: ${e.toString()}");
      return null;
    }
  }

  static Future<String> uploadVideoThumbnailToFireStorage(File file) async {
    var uniqueID = const Uuid().v4();
    Reference upload = FirebaseStorage.instance.ref().child('thumbnails/$uniqueID.png');
    UploadTask uploadTask = upload.putFile(file);
    var downloadUrl = await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  static Future<bool> uploadDriverDocument(Documents documents) async {
    bool isAdded = false;
    DriverDocumentModel driverDocumentModel = DriverDocumentModel();
    List<Documents> documentsList = [];
    await fireStore.collection(CollectionName.documentsVerify).doc(getCurrentUid()).get().then((value) async {
      if (value.exists) {
        DriverDocumentModel newDriverDocumentModel = DriverDocumentModel.fromJson(value.data()!);
        documentsList = newDriverDocumentModel.documents!;
        var contain = newDriverDocumentModel.documents!.where((element) => element.documentId == documents.documentId);
        if (contain.isEmpty) {
          documentsList.add(documents);

          driverDocumentModel.id = getCurrentUid();
          driverDocumentModel.type = "driver";
          driverDocumentModel.documents = documentsList;
        } else {
          var index = newDriverDocumentModel.documents!.indexWhere((element) => element.documentId == documents.documentId);

          driverDocumentModel.id = getCurrentUid();
          driverDocumentModel.type = "driver";
          documentsList.removeAt(index);
          documentsList.insert(index, documents);
          driverDocumentModel.documents = documentsList;
          isAdded = false;
        }
      } else {
        documentsList.add(documents);
        driverDocumentModel.id = getCurrentUid();
        driverDocumentModel.type = "driver";
        driverDocumentModel.documents = documentsList;
      }
    });

    await fireStore.collection(CollectionName.documentsVerify).doc(getCurrentUid()).set(driverDocumentModel.toJson()).then((value) {
      isAdded = true;
    }).catchError((error) {
      isAdded = false;
      log(error.toString());
    });

    return isAdded;
  }

  static Future<WithdrawMethodModel?> getWithdrawMethod() async {
    WithdrawMethodModel? withdrawMethodModel;
    await fireStore.collection(CollectionName.withdrawMethod).where("userId", isEqualTo: getCurrentUid()).get().then((value) async {
      if (value.docs.isNotEmpty) {
        withdrawMethodModel = WithdrawMethodModel.fromJson(value.docs.first.data());
      }
    });
    return withdrawMethodModel;
  }

  static Future<WithdrawMethodModel?> setWithdrawMethod(WithdrawMethodModel withdrawMethodModel) async {
    if (withdrawMethodModel.id == null) {
      withdrawMethodModel.id = const Uuid().v4();
      withdrawMethodModel.userId = getCurrentUid();
    }
    await fireStore.collection(CollectionName.withdrawMethod).doc(withdrawMethodModel.id).set(withdrawMethodModel.toJson()).then((value) async {});
    return withdrawMethodModel;
  }

  static Future<List<WithdrawalModel>?> getWithdrawHistory() async {
    List<WithdrawalModel> walletTransactionList = [];
    await fireStore.collection(CollectionName.driverPayouts).where('driverID', isEqualTo: Constant.userModel!.id.toString()).orderBy('paidDate', descending: true).get().then((value) {
      for (var element in value.docs) {
        WithdrawalModel walletTransactionModel = WithdrawalModel.fromJson(element.data());
        walletTransactionList.add(walletTransactionModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return walletTransactionList;
  }

  static Future<void> sendPayoutMail({required String amount, required String payoutrequestid}) async {
    EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.payoutRequest);

    String body = emailTemplateModel!.subject.toString();
    body = body.replaceAll("{userid}", Constant.userModel!.id.toString());

    String newString = emailTemplateModel.message.toString();
    newString = newString.replaceAll("{username}", Constant.userModel!.fullName());
    newString = newString.replaceAll("{userid}", Constant.userModel!.id.toString());
    newString = newString.replaceAll("{amount}", Constant.amountShow(amount: amount));
    newString = newString.replaceAll("{payoutrequestid}", payoutrequestid.toString());
    newString = newString.replaceAll("{usercontactinfo}", "${Constant.userModel!.email}\n${Constant.userModel!.phoneNumber}");
    await Constant.sendMail(subject: body, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
  }

  static Future<bool> withdrawWalletAmount(WithdrawalModel userModel) async {
    bool isUpdate = false;
    await fireStore.collection(CollectionName.driverPayouts).doc(userModel.id).set(userModel.toJson()).whenComplete(() {
      isUpdate = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isUpdate = false;
    });
    return isUpdate;
  }

  static Future<bool> getFirestOrderOrNOt(OrderModel orderModel) async {
    bool isFirst = true;
    await fireStore.collection(CollectionName.vendorOrders).where('authorID', isEqualTo: orderModel.authorID).get().then((value) {
      if (value.size == 1) {
        isFirst = true;
      } else {
        isFirst = false;
      }
    });
    return isFirst;
  }

  static Future updateReferralAmount(OrderModel orderModel) async {
    ReferralModel? referralModel;
    await fireStore.collection(CollectionName.referral).doc(orderModel.authorID).get().then((value) {
      if (value.data() != null) {
        referralModel = ReferralModel.fromJson(value.data()!);
      } else {
        return;
      }
    });
    if (referralModel != null) {
      if (referralModel!.referralBy != null && referralModel!.referralBy!.isNotEmpty) {
        WalletTransactionModel transactionModel = WalletTransactionModel(
            id: Constant.getUuid(),
            amount: double.parse(Constant.referralAmount.toString()),
            date: Timestamp.now(),
            paymentMethod: "Referral Amount",
            transactionUser: "user",
            userId: referralModel!.referralBy,
            isTopup: true,
            note: "You referral user has complete his this order #${orderModel.id}",
            paymentStatus: "success");

        await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
          if (value == true) {
            await FireStoreUtils.updateUserWallet(amount: Constant.referralAmount.toString(), userId: referralModel!.referralBy.toString()).then((value) {});
          }
        });
      } else {
        return;
      }
    }
  }

  static Future<bool> getFirestOrderOrNOtCabService(CabOrderModel orderModel) async {
    bool isFirst = true;
    await fireStore.collection(CollectionName.ridesBooking).where('authorID', isEqualTo: orderModel.authorID).get().then((value) {
      if (value.size == 1) {
        isFirst = true;
      } else {
        isFirst = false;
      }
    });
    return isFirst;
  }

  static Future updateReferralAmountCabService(CabOrderModel orderModel) async {
    ReferralModel? referralModel;
    SectionModel? sectionModel;
    await getSectionBySectionId(orderModel.sectionId.toString()).then((value) {
      sectionModel = value;
    });
    await fireStore.collection(CollectionName.referral).doc(orderModel.authorID).get().then((value) {
      if (value.data() != null) {
        referralModel = ReferralModel.fromJson(value.data()!);
      } else {
        return;
      }
    });

    if (referralModel != null) {
      if (referralModel!.referralBy != null && referralModel!.referralBy!.isNotEmpty) {
        await fireStore.collection(CollectionName.users).doc(referralModel!.referralBy).get().then((value) async {
          DocumentSnapshot<Map<String, dynamic>> userDocument = value;
          if (userDocument.data() != null && userDocument.exists) {
            try {
              UserModel user = UserModel.fromJson(userDocument.data()!);
              await fireStore
                  .collection(CollectionName.users)
                  .doc(user.id)
                  .update({"wallet_amount": double.parse(user.walletAmount.toString()) + double.parse(sectionModel!.referralAmount.toString())});

              WalletTransactionModel transactionModel = WalletTransactionModel(
                  id: Constant.getUuid(),
                  amount: double.parse(sectionModel!.referralAmount.toString()),
                  date: Timestamp.now(),
                  paymentMethod: "Referral Amount",
                  transactionUser: "user",
                  userId: referralModel!.referralBy.toString(),
                  isTopup: true,
                  note: "Wallet Top-up",
                  paymentStatus: "success");

              await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
                if (value == true) {
                  await FireStoreUtils.updateUserWallet(amount: sectionModel!.referralAmount.toString(), userId: referralModel!.referralBy.toString()).then((value) {});
                }
              });
            } catch (e) {
              log(e.toString());
            }
          }
        });
      } else {
        return;
      }
    }
  }

  static Future<bool> getParcelFirstOrderOrNOt(ParcelOrderModel orderModel) async {
    bool isFirst = true;
    await fireStore.collection(CollectionName.parcelOrders).where('authorID', isEqualTo: orderModel.authorID).get().then((value) {
      if (value.size == 1) {
        isFirst = true;
      } else {
        isFirst = false;
      }
    });
    return isFirst;
  }

  static Future<bool> getRentalFirstOrderOrNOt(RentalOrderModel orderModel) async {
    bool isFirst = true;
    await fireStore.collection(CollectionName.rentalOrders).where('authorID', isEqualTo: orderModel.authorID).get().then((value) {
      if (value.size == 1) {
        isFirst = true;
      } else {
        isFirst = false;
      }
    });
    return isFirst;
  }

  static Future updateParcelReferralAmount(ParcelOrderModel orderModel) async {
    ReferralModel? referralModel;
    SectionModel? sectionModel;
    print(orderModel.authorID);
    await getSectionBySectionId(orderModel.sectionId.toString()).then((value) {
      sectionModel = value;
    });
    await fireStore.collection(CollectionName.referral).doc(orderModel.authorID).get().then((value) {
      if (value.data() != null) {
        referralModel = ReferralModel.fromJson(value.data()!);
      } else {
        return;
      }
    });

    if (referralModel != null) {
      if (referralModel!.referralBy != null && referralModel!.referralBy!.isNotEmpty) {
        await fireStore.collection(CollectionName.users).doc(referralModel!.referralBy).get().then((value) async {
          DocumentSnapshot<Map<String, dynamic>> userDocument = value;
          if (userDocument.data() != null && userDocument.exists) {
            try {
              UserModel user = UserModel.fromJson(userDocument.data()!);
              await fireStore
                  .collection(CollectionName.users)
                  .doc(user.id)
                  .update({"wallet_amount": double.parse(user.walletAmount.toString()) + double.parse(sectionModel!.referralAmount.toString())});

              WalletTransactionModel transactionModel = WalletTransactionModel(
                  id: Constant.getUuid(),
                  amount: double.parse(sectionModel!.referralAmount.toString()),
                  date: Timestamp.now(),
                  paymentMethod: "Referral Amount",
                  transactionUser: "user",
                  userId: referralModel!.referralBy.toString(),
                  isTopup: true,
                  note: "Wallet Top-up",
                  paymentStatus: "success");

              await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
                if (value == true) {
                  await FireStoreUtils.updateUserWallet(amount: sectionModel!.referralAmount.toString(), userId: referralModel!.referralBy.toString()).then((value) {});
                }
              });
            } catch (error) {
              log(error.toString());
            }
            print("data val");
          }
        });
      } else {
        return;
      }
    }
  }

  static Future updateRentalReferralAmount(RentalOrderModel orderModel) async {
    ReferralModel? referralModel;
    SectionModel? sectionModel;
    print(orderModel.authorID);
    await getSectionBySectionId(orderModel.sectionId.toString()).then((value) {
      sectionModel = value;
    });
    await fireStore.collection(CollectionName.referral).doc(orderModel.authorID).get().then((value) {
      if (value.data() != null) {
        referralModel = ReferralModel.fromJson(value.data()!);
      } else {
        return;
      }
    });

    if (referralModel != null) {
      if (referralModel!.referralBy != null && referralModel!.referralBy!.isNotEmpty) {
        await fireStore.collection(CollectionName.users).doc(referralModel!.referralBy).get().then((value) async {
          DocumentSnapshot<Map<String, dynamic>> userDocument = value;
          if (userDocument.data() != null && userDocument.exists) {
            try {
              UserModel user = UserModel.fromJson(userDocument.data()!);
              await fireStore
                  .collection(CollectionName.users)
                  .doc(user.id)
                  .update({"wallet_amount": double.parse(user.walletAmount.toString()) + double.parse(sectionModel!.referralAmount.toString())});

              WalletTransactionModel transactionModel = WalletTransactionModel(
                  id: Constant.getUuid(),
                  amount: double.parse(sectionModel!.referralAmount.toString()),
                  date: Timestamp.now(),
                  paymentMethod: "Referral Amount",
                  transactionUser: "user",
                  userId: referralModel!.referralBy.toString(),
                  isTopup: true,
                  note: "Wallet Top-up",
                  paymentStatus: "success");

              await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
                if (value == true) {
                  await FireStoreUtils.updateUserWallet(amount: sectionModel!.referralAmount.toString(), userId: referralModel!.referralBy.toString()).then((value) {});
                }
              });
            } catch (error) {
              log(error.toString());
            }
            print("data val");
          }
        });
      } else {
        return;
      }
    }
  }

  static Stream<List<ParcelOrderModel>> listenParcelOrders(String driverId) {
    return fireStore.collection(CollectionName.parcelOrders).where('driverId', isEqualTo: driverId).orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        log("===>");
        print(doc.data());
        return ParcelOrderModel.fromJson(doc.data());
      }).toList();
    });
  }

  static Future<List<ParcelCategory>> getParcelServiceCategory() async {
    List<ParcelCategory> parcelCategoryList = [];
    await fireStore.collection(CollectionName.parcelCategory).where('publish', isEqualTo: true).orderBy('set_order', descending: false).get().then((value) {
      for (var element in value.docs) {
        try {
          ParcelCategory category = ParcelCategory.fromJson(element.data());
          parcelCategoryList.add(category);
        } catch (e, stackTrace) {
          print('getParcelServiceCategory parse error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return parcelCategoryList;
  }

  static Future rentalOrderPlace(RentalOrderModel orderModel) async {
    await fireStore.collection(CollectionName.rentalOrders).doc(orderModel.id).set(orderModel.toJson());
  }

  static Future<RentalOrderModel?> getRentalOrderById(String orderId) async {
    RentalOrderModel? orderModel;
    await fireStore.collection(CollectionName.rentalOrders).doc(orderId).get().then((value) {
      if (value.exists) {
        orderModel = RentalOrderModel.fromJson(value.data()!);
      }
    });
    return orderModel;
  }

  static Stream<List<RentalOrderModel>> getRentalOrders(String driverId) {
    return fireStore.collection(CollectionName.rentalOrders).where('driverId', isEqualTo: driverId).orderBy('createdAt', descending: true).snapshots().map((
      query,
    ) {
      List<RentalOrderModel> ordersList = [];
      for (var element in query.docs) {
        ordersList.add(RentalOrderModel.fromJson(element.data()));
      }
      return ordersList;
    });
  }

  static Future<RatingModel?> getReviewsbyID(String orderId) async {
    RatingModel? ratingModel;

    await fireStore.collection(CollectionName.itemsReview).where('orderid', isEqualTo: orderId).get().then((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        ratingModel = RatingModel.fromJson(snapshot.docs.first.data());
      }
    }).catchError((error) {
      print('Error fetching review for provider: $error');
    });

    return ratingModel;
  }

  static Future<RatingModel?> updateReviewById(RatingModel ratingProduct) async {
    try {
      await fireStore.collection(CollectionName.itemsReview).doc(ratingProduct.id).set(ratingProduct.toJson());
      return ratingProduct;
    } catch (e, stackTrace) {
      print('Error updating review: $e');
      print(stackTrace);
      return null;
    }
  }

  static Stream<List<CabOrderModel>> getCabDriverOrders(String driverId) {
    return fireStore.collection(CollectionName.ridesBooking).where('driverId', isEqualTo: driverId).orderBy('createdAt', descending: true).snapshots().map((query) {
      List<CabOrderModel> ordersList = [];
      for (var element in query.docs) {
        ordersList.add(CabOrderModel.fromJson(element.data()));
      }
      return ordersList;
    });
  }

  static Future<dynamic> getOrderByIdFromAllCollections(String orderId) async {
    final List<String> collections = [
      CollectionName.parcelOrders,
      CollectionName.rentalOrders,
      CollectionName.ridesBooking,
      CollectionName.vendorOrders,
    ];

    for (String collection in collections) {
      try {
        final snapshot = await fireStore.collection(collection).where('id', isEqualTo: orderId).limit(1).get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          data['collection_name'] = collection;
          return data;
        }
      } catch (e) {
        log("Error fetching from $collection => $e");
      }
    }

    log("No order found with ID $orderId");
    return null;
  }

  static Future<List<CabOrderModel>> getCabDriverOrdersOnce(String driverId) async {
    Query query = fireStore.collection(CollectionName.ridesBooking).orderBy('createdAt', descending: true);
    if (driverId.isNotEmpty) {
      query = query.where('driverId', isEqualTo: driverId);
    }
    QuerySnapshot snapshot = await query.get();
    return snapshot.docs.map((doc) => CabOrderModel.fromJson(doc.data() as Map<String, dynamic>)).toList();
  }

  static Future<List<ParcelOrderModel>> getParcelDriverOrdersOnce(String driverId) async {
    Query query = fireStore.collection(CollectionName.parcelOrders).orderBy('createdAt', descending: true);
    if (driverId.isNotEmpty) {
      query = query.where('driverId', isEqualTo: driverId);
    }
    QuerySnapshot snapshot = await query.get();
    return snapshot.docs.map((doc) => ParcelOrderModel.fromJson(doc.data() as Map<String, dynamic>)).toList();
  }

  static Future<List<RentalOrderModel>> getRentalDriverOrdersOnce(String driverId) async {
    Query query = fireStore.collection(CollectionName.rentalOrders).orderBy('createdAt', descending: true);
    if (driverId.isNotEmpty) {
      query = query.where('driverId', isEqualTo: driverId);
    }
    QuerySnapshot snapshot = await query.get();
    return snapshot.docs.map((doc) => RentalOrderModel.fromJson(doc.data() as Map<String, dynamic>)).toList();
  }

  // ── Section-filtered order queries (for owner order list) ─────────────────

  static Future<List<CabOrderModel>> getCabOrdersBySection({
    required String sectionId,
    required List<String> driverIds,
  }) async {
    List<CabOrderModel> allOrders = [];
    for (final did in driverIds) {
      Query query = fireStore.collection(CollectionName.ridesBooking).where('driverId', isEqualTo: did).where('sectionId', isEqualTo: sectionId).orderBy('createdAt', descending: true);
      QuerySnapshot snapshot = await query.get();
      allOrders.addAll(
        snapshot.docs.map((doc) => CabOrderModel.fromJson(doc.data() as Map<String, dynamic>)),
      );
    }
    return allOrders;
  }

  static Future<List<ParcelOrderModel>> getParcelOrdersBySection({
    required String sectionId,
    required List<String> driverIds,
  }) async {
    List<ParcelOrderModel> allOrders = [];
    for (final did in driverIds) {
      Query query = fireStore.collection(CollectionName.parcelOrders).where('driverId', isEqualTo: did).where('sectionId', isEqualTo: sectionId).orderBy('createdAt', descending: true);
      QuerySnapshot snapshot = await query.get();
      allOrders.addAll(
        snapshot.docs.map((doc) => ParcelOrderModel.fromJson(doc.data() as Map<String, dynamic>)),
      );
    }
    return allOrders;
  }

  static Future<List<RentalOrderModel>> getRentalOrdersBySection({
    required String sectionId,
    required List<String> driverIds,
  }) async {
    List<RentalOrderModel> allOrders = [];
    for (final did in driverIds) {
      Query query = fireStore.collection(CollectionName.rentalOrders).where('driverId', isEqualTo: did).where('sectionId', isEqualTo: sectionId).orderBy('createdAt', descending: true);
      QuerySnapshot snapshot = await query.get();
      allOrders.addAll(
        snapshot.docs.map((doc) => RentalOrderModel.fromJson(doc.data() as Map<String, dynamic>)),
      );
    }
    return allOrders;
  }

  static Future<List<OrderModel>> getVendorOrdersBySection({
    required String sectionId,
    required List<String> driverIds,
  }) async {
    List<OrderModel> allOrders = [];
    for (final did in driverIds) {
      Query query = fireStore.collection(CollectionName.vendorOrders).where('driverID', isEqualTo: did).where('section_id', isEqualTo: sectionId).orderBy('createdAt', descending: true);
      QuerySnapshot snapshot = await query.get();
      allOrders.addAll(
        snapshot.docs.map((doc) => OrderModel.fromJson(doc.data() as Map<String, dynamic>)),
      );
    }
    return allOrders;
  }

  static Future<bool> deleteDriverId(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ No user is logged in.");
        return false;
      }

      final idToken = await user.getIdToken();
      final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
      final url = Uri.parse('https://us-central1-$projectId.cloudfunctions.net/deleteUser');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {'uid': uid}, // 👈 matches your Cloud Function structure
        }),
      );

      print("Response [${response.statusCode}]: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['result']?['success'] == true || decoded['success'] == true;
      } else {
        print("⚠️ Cloud Function failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error deleting driver: $e");
      return false;
    }
  }

  static Future<InboxModel> addInbox(InboxModel inboxModel) async {
    final collection = fireStore.collection(CollectionName.chat);
    final docId = (inboxModel.senderReceiverId?.contains('admin') == false) ? inboxModel.orderId : inboxModel.senderId;
    await collection.doc(docId).set(inboxModel.toJson());
    log("inboxModel :: 22 :: ${inboxModel.senderReceiverId?.contains('admin')} :: $docId ::  ${inboxModel.toJson()} ");
    return inboxModel;
  }

  static Future<ConversationModel> addChat(ConversationModel conversationModel) async {
    final chatCollection = fireStore.collection(CollectionName.chat);
    final docId = (conversationModel.receiverId?.contains('admin') == false) ? conversationModel.orderId : conversationModel.senderId;
    await chatCollection.doc(docId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson());
    log("conversationModel :: 22 :: $docId ::  ${conversationModel.toJson()} ");
    return conversationModel;
  }

  static late StreamSubscription<QuerySnapshot> adminChatSeenSubscription;

  static void setSeen() {
    final currentUserId = FireStoreUtils.getCurrentUid();

    adminChatSeenSubscription = fireStore
        .collection(CollectionName.chat)
        .doc(currentUserId)
        .collection("thread")
        .where('senderId', isEqualTo: Constant.adminType)
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen((querySnapshot) async {
      for (final doc in querySnapshot.docs) {
        try {
          await doc.reference.update({'seen': true});
        } catch (e) {
          log(e.toString());
        }
      }
    }, onError: (error) {
      log(error.toString());
    });
  }

  static void stopSeenListener() {
    adminChatSeenSubscription.cancel();
  }

  static late StreamSubscription<QuerySnapshot> orderChatSeenSubscription;

  static void setSeenChatForOrder({required String orderId}) {
    orderChatSeenSubscription = fireStore
        .collection(CollectionName.chat)
        .doc(orderId)
        .collection("thread")
        .where('senderId', isNotEqualTo: FireStoreUtils.getCurrentUid())
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen((querySnapshot) async {
      for (final doc in querySnapshot.docs) {
        try {
          await doc.reference.update({'seen': true});
        } catch (e) {
          log(e.toString());
        }
      }
    }, onError: (error) {
      log(error.toString());
    });
  }
}
