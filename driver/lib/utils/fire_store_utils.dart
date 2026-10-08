import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/chat_screens/chat_video_container.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/services/wallet_once.dart';
import 'package:driver/utils/chat_unread.dart';
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
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vehicle_type.dart';
import 'package:driver/models/vendor_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/models/withdraw_method_model.dart';
import 'package:driver/models/withdrawal_model.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/services/order_ringtone_service.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/utils/cancel_reason_list.dart';
import 'package:driver/utils/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import '../models/parcel_category.dart';
import '../models/rating_model.dart';

enum FirebaseEnv { defaultDb, staging }

/// Change this to switch between default / staging
const FirebaseEnv currentEnv = FirebaseEnv.defaultDb;

/// Writes only the given top-level fields of an existing document and leaves
/// every other field (e.g. panel-written `regionId`) untouched (contract lesson 2).
extension SetKnownFields on DocumentReference<Map<String, dynamic>> {
  Future<void> setKnownFields(Map<String, dynamic> data) {
    return set(data, SetOptions(mergeFields: data.keys.map((key) => FieldPath([key])).toList()));
  }
}

/// Outcome of [FireStoreUtils.updateExistingUserFields].
enum UserWrite { done, missing, failed }

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

  /// Adds [amount] (negative to debit) to one user's `wallet_amount` in a
  /// transaction. It used to read the user, add locally and write the whole
  /// document back ([updateUser]), so a credit made meanwhile by another app
  /// or the server was undone. [updateUser] never writes the wallet.
  static Future<bool?> updateUserWallet({required String amount, required String userId}) async {
    final num delta = num.tryParse(amount) ?? 0;
    try {
      final DocumentReference<Map<String, dynamic>> ref = fireStore.collection(CollectionName.users).doc(userId);
      final num? newTotal = await fireStore.runTransaction<num?>((transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await transaction.get(ref);
        if (!snap.exists) return null;
        final num total = (num.tryParse(snap.data()?['wallet_amount']?.toString() ?? '') ?? 0) + delta;
        transaction.update(ref, {'wallet_amount': total});
        return total;
      });
      // Keep the signed-in user's copy in step.
      if (newTotal != null && Constant.userModel?.id == userId) {
        Constant.userModel!.walletAmount = newTotal;
      }
      return newTotal != null;
    } catch (e, s) {
      log("updateUserWallet failed: $e", stackTrace: s);
      return false;
    }
  }

  /// Drops null values, and nested maps that end up empty, before a write.
  ///
  /// It used to remove the empty maps from inside `map.forEach`, which throws
  /// "Concurrent modification during iteration": a new company driver (empty
  /// `vehicleDetails`) could not be saved ("The driver account was created
  /// but its details could not be saved").
  static Map<String, dynamic> removeNulls(Map<String, dynamic> map) {
    map.removeWhere((key, value) => value == null);
    final List<String> emptied = [];
    map.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        removeNulls(value);
        if (value.isEmpty) emptied.add(key);
      }
    });
    for (final String key in emptied) {
      map.remove(key);
    }
    return map;
  }

  /// What [updateUser] writes. Never `wallet_amount`; for an existing
  /// account never `fcmToken`, `isActive` (the online switch), the admin's
  /// `isDocumentVerify`, the dispatch arrays or the position.
  @visibleForTesting
  static Map<String, dynamic> userSaveData(UserModel userModel, {bool isNew = false}) {
    final Map<String, dynamic> data = removeNulls(userModel.toJson()..remove('wallet_amount'));
    if (!isNew) data.remove('fcmToken');
    // Online / offline is the driver's own choice: only their online switch
    // (DashBoardController.setOnline and the cab / parcel / rental
    // equivalents) writes `isActive`. A profile, bank, vehicle or section
    // save wrote back the value its copy was loaded with, which put a driver
    // who had gone online since back offline.
    if (!isNew) data.remove('isActive');
    // Report Doc 37: `isDocumentVerify` is the administrator's verdict. A new
    // account starts at `false`; afterwards this app never writes it, so a
    // copy loaded before an approval (or a revocation) cannot overwrite it.
    if (!isNew) data.remove('isDocumentVerify');
    // Dispatch spec §4: `orderRequestData` (offers the Cloud Function added),
    // `inProgressOrderID` (accepted jobs) and the legacy ride request move
    // only by field-level arrayUnion / arrayRemove. A profile, bank,
    // vehicle, section or sign-in save wrote back the arrays its copy was
    // loaded with, dropping an offer or a job added meanwhile; the position
    // is written by the location stream alone.
    if (!isNew) {
      for (final String key in const ['orderRequestData', 'inProgressOrderID', 'ordercabRequestData', 'location', 'rotation']) {
        data.remove(key);
      }
    }
    return data;
  }

  /// Saves a user, never its `wallet_amount`: a balance moves only through
  /// [updateUserWallet] / `WalletOnce` (transactions). This in-memory copy,
  /// written back, undid a credit made by another app or the server between
  /// its read and this write.
  ///
  /// [isNew] (sign-up, a fleet owner creating a driver): the document starts
  /// with `wallet_amount: 0` if it has no balance yet ([_openWallet]).
  ///
  /// `fcmToken` is written only for a new document: afterwards it moves only
  /// through `NotificationService.saveToken` (a field-level write). A copy
  /// read a moment earlier, written back whole, put a stale token over the
  /// one the device had just saved, and pushes stopped reaching it.
  static Future<bool> updateUser(UserModel userModel, {bool isNew = false}) async {
    try {
      final docRef = fireStore.collection(CollectionName.users).doc(userModel.id);

      final Map<String, dynamic> data = userSaveData(userModel, isNew: isNew);

      await docRef.set(data, SetOptions(merge: true));
      if (isNew) await _openWallet(docRef);

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

  /// A new account's starting fields, in a transaction that only fills what
  /// is absent (an existing value is never reset): `wallet_amount: 0`, and,
  /// for a driver, the two dispatch arrays (`orderRequestData`,
  /// `inProgressOrderID`, dispatch spec §4) as empty lists.
  static Future<void> _openWallet(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await fireStore.runTransaction<void>((transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await transaction.get(ref);
        final Map<String, dynamic>? data = snap.data();
        if (!snap.exists || data == null) return;
        final Map<String, dynamic> missing = {
          if (data['wallet_amount'] == null) 'wallet_amount': 0,
          if (data['role'] == Constant.userRoleDriver && data['orderRequestData'] is! List) 'orderRequestData': <String>[],
          if (data['role'] == Constant.userRoleDriver && data['inProgressOrderID'] is! List) 'inProgressOrderID': <String>[],
        };
        if (missing.isNotEmpty) transaction.update(ref, missing);
      });
    } catch (e) {
      log("opening the wallet of ${ref.id} failed: $e");
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

  /// Returns active sections for driver registration: delivery sections (any
  /// multivendor / e-commerce section, spec 4.11), cab, parcel and rental.
  /// Excludes on-demand and any other non-driver section types.
  static Future<List<SectionModel>> getAllActiveSections() async {
    const driverFlags = ['delivery-service', 'ecommerce-service', 'cab-service', 'parcel_delivery', 'rental-service'];
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

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _notificationSettingsSub;

  /// `settings/notification_setting`, live. Registered on its own, before
  /// anything else in [getSettings]: it used to sit after the globalSettings
  /// read, so a throw there (e.g. a missing `app_driver_color`) left
  /// `senderId` / `serviceJson` empty and every push failed. Every field is
  /// read null-safely and always assigned, so clearing one in Firestore
  /// takes effect live (that is the server-push rollback).
  static void listenNotificationSettings() {
    _notificationSettingsSub ??= fireStore.collection(CollectionName.settings).doc("notification_setting").snapshots().listen(
      (event) {
        final Map<String, dynamic> data = event.data() ?? const <String, dynamic>{};
        Constant.senderId = (data["senderId"] ?? '').toString();
        Constant.jsonNotificationFileURL = (data["serviceJson"] ?? '').toString();
        Constant.serverPushUrl = (data["serverPushUrl"] ?? '').toString();
      },
      onError: (Object e) => log("notification_setting listener failed: $e"),
    );
  }

  /// `settings/document_verification_settings` into
  /// [Constant.isDriverVerification] / [Constant.isOwnerVerification].
  /// Tolerant: a missing document or field leaves the setting unknown (null);
  /// a failed read keeps what was loaded before. Awaited by sign-up and by a
  /// company creating a driver before the new account's flags are set
  /// ([DocumentVerification.initialFlags]): [getSettings] runs in the
  /// background and may not have finished by then.
  static Future<void> loadDocumentVerificationSettings() async {
    try {
      final value = await fireStore.collection(CollectionName.settings).doc("document_verification_settings").get();
      final dynamic driver = value.data()?['isDriverVerification'];
      final dynamic owner = value.data()?['isOwnerVerification'];
      Constant.isDriverVerification = driver is bool ? driver : null;
      Constant.isOwnerVerification = owner is bool ? owner : null;
    } catch (e) {
      log("document_verification_settings read failed: $e");
    }
  }

  static Future<void> getSettings() async {
    listenNotificationSettings();
    try {
      await fireStore.collection(CollectionName.settings).doc("globalSettings").get().then((value) async {
        Constant.orderRingtoneUrl = value.data()?['order_ringtone_url'] ?? '';
        Constant.isSelfDeliveryFeature = value.data()!['isSelfDelivery'] ?? false;
        Constant.defaultCountryCode = value.data()?['defaultCountryCode'] ?? '';

        Preferences.setString(Preferences.orderRingtone, Constant.orderRingtoneUrl);
        // The same sound for job / offer notifications in the background /
        // closed (Android channel `driver_jobs_rt_<key>`, iOS
        // `order_ringtone_<key>.caf`); kept in step with later changes and
        // re-checked on every return to the foreground.
        OrderRingtoneService.start();
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

      await loadDocumentVerificationSettings();

      await listenDriverNearBy();
    } catch (e) {
      log(e.toString());
    }
  }

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverNearBySub;

  /// `settings/DriverNearBy` (dispatch spec §6): read once (awaited — the
  /// dashboards pick their home screen by `singleOrderReceive`), then kept
  /// live, so a panel change (the offer window, a deposit) applies without
  /// a restart.
  static Future<void> listenDriverNearBy() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> value = await fireStore.collection(CollectionName.settings).doc("DriverNearBy").get();
      applyDriverNearBy(value.data() ?? const <String, dynamic>{});
    } catch (e) {
      log("DriverNearBy read failed: $e");
    }
    _driverNearBySub ??= fireStore.collection(CollectionName.settings).doc("DriverNearBy").snapshots().listen(
      (event) {
        if (event.exists) applyDriverNearBy(event.data() ?? const <String, dynamic>{});
      },
      onError: (Object e) => log("DriverNearBy listener failed: $e"),
    );
  }

  /// Each key read on its own and tolerantly (a number may be stored as a
  /// number or as text, a flag as a bool, text or 1 / 0), with the spec's
  /// defaults: one value of an unexpected type used to throw and abort every
  /// key after it — `singleOrderReceive` then stayed false, which also picks
  /// the delivery home screen.
  static void applyDriverNearBy(Map<String, dynamic> data) {
    void read(String key, void Function(dynamic value) apply) {
      try {
        apply(data[key]);
      } catch (e) {
        log("DriverNearBy.$key could not be read: $e");
      }
    }

    read('minimumDepositToRideAccept', (v) => Constant.minimumDepositToRideAccept = DispatchSettings.amount(v, '0'));
    read('ownerMinimumDepositToRideAccept', (v) => Constant.ownerMinimumDepositToRideAccept = DispatchSettings.amount(v, '0'));
    read('minimumAmountToWithdrawal', (v) => Constant.minimumAmountToWithdrawal = DispatchSettings.amount(v, '0'));
    read('driverLocationUpdate', (v) => Constant.driverLocationUpdate = DispatchSettings.amount(v, '50'));
    read('singleOrderReceive', (v) => Constant.singleOrderReceive = DispatchSettings.flag(v));
    read('driverOrderAcceptRejectDuration', (v) => Constant.driverOrderAcceptRejectDuration = DispatchSettings.acceptRejectSeconds(v));
    read('selectedMapType', (v) => Constant.selectedMapType = DispatchSettings.text(v, 'google'));
    read('mapType', (v) => Constant.mapType = DispatchSettings.text(v, 'inappmap'));
    read('auto_approve_driver', (v) => Constant.autoApproveDriver = v == null ? null : DispatchSettings.flag(v));
    read('enableOTPTripStart', (v) => Constant.enableOTPTripStart = DispatchSettings.flag(v, fallback: false));
    read('enableOTPTripStartForRental', (v) => Constant.enableOTPTripStartForRental = DispatchSettings.flag(v, fallback: true));
    read('parcelRadius', (v) => Constant.parcelRadius = DispatchSettings.amount(v, '50'));
    read('rentalRadius', (v) => Constant.rentalRadius = DispatchSettings.amount(v, '50'));
    log("Constant.singleOrderReceive :: ${Constant.singleOrderReceive}, offer window ${Constant.driverOrderAcceptRejectDuration}s");
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

  /// Live form of [getOnGoingParcelList] — same query, same parsing. A parcel
  /// assigned to this driver (by hand from a panel, possibly with no push)
  /// appears on the parcel home while it is open, not only on the next visit.
  static Stream<List<ParcelOrderModel>> listenOnGoingParcelList() {
    return fireStore
        .collection(CollectionName.parcelOrders)
        .where("driverId", isEqualTo: FireStoreUtils.getCurrentUid())
        .where("status", whereIn: [Constant.driverAccepted, Constant.orderInTransit, Constant.orderShipped])
        .snapshots()
        .map((snapshot) {
      final List<ParcelOrderModel> parcelOrderList = [];
      for (final document in snapshot.docs) {
        try {
          parcelOrderList.add(ParcelOrderModel.fromJson(document.data()));
        } catch (e) {
          debugPrint('FireStoreUtils.listenOnGoingParcelList parse error $e');
        }
      }
      return parcelOrderList;
    });
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

  // `getTaxList()` (tax by the reverse-geocoded country of
  // `Constant.selectedLocation`) is gone: nothing called it, and it read
  // `location!` and `placeMarks.first` unguarded (report 02#27 / 02#18).

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

  // No whole-model write of a `parcel_orders` record exists in this app
  // (decision D5): every parcel write is a field update
  // (DispatchOfferService, ParcelTrackingService), so the server-owned
  // receiver / SMS fields (`receiver*`, `sendReceiverSms`, `smsCharge`,
  // `smsSent`, `smsOptOut`) and `rejectedByDrivers` are never rolled back.

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

      await _payDriverOnce(orderModel, codTxn, driverAmount);
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

      await _payDriverOnce(orderModel, onlineTxn, driverAmount);
    }
  }

  /// The driver's row and balance move together, once per order: a retried
  /// completion (POD-OTP-CONTRACT, "a retry must not pay twice") is a no-op.
  static Future<void> _payDriverOnce(OrderModel orderModel, WalletTransactionModel txn, double driverAmount) async {
    final String? orderId = orderModel.id;
    if (orderId == null || orderId.isEmpty) {
      await FireStoreUtils.setWalletTransaction(txn);
      await FireStoreUtils.updateUserWallet(userId: orderModel.driverID!, amount: driverAmount.toString());
      return;
    }
    await WalletOnce.pay(rowId: WalletOnce.driverRowId(orderId), row: txn.toJson(), userId: orderModel.driverID, amount: driverAmount);
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

  /// The `dynamic_notification` template for [type], or null when the admin
  /// has not set one up. Notification text comes only from these templates:
  /// there is no wording in the app to fall back to.
  static Future<NotificationModel?> getNotificationContent(String type) async {
    final QuerySnapshot<Map<String, dynamic>> value =
        await fireStore.collection(CollectionName.dynamicNotification).where('type', isEqualTo: type).limit(1).get();
    if (value.docs.isEmpty) return null;
    return NotificationModel.fromJson(value.docs.first.data());
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

  static Future<List<DocumentModel>> getDocumentList(String type) => getDocumentListForTypes([type]);

  /// The document types the signed-in actor has to provide: its own ("owner"
  /// for a company, "driver" otherwise) plus the vehicle documents a cab or
  /// rental driver needs (client point 25). A type the admin never created
  /// returns nothing, so this is additive.
  static List<String> documentTypesForCurrentUser() {
    final UserModel? me = Constant.userModel;
    final List<String> types = [me?.isOwner == true ? "owner" : "driver"];
    final List<String> services = me?.serviceModules ?? const <String>[];
    if (services.contains('cab-service') || services.contains('rental-service')) {
      types.add("vehicle");
    }
    return types;
  }

  /// The enabled document types an actor has to provide. Several types at once
  /// (client point 25: a cab / rental driver also provides vehicle documents),
  /// read tolerantly — a type the admin never created simply returns nothing.
  static Future<List<DocumentModel>> getDocumentListForTypes(List<String> types) async {
    final List<String> wanted = types.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList();
    if (wanted.isEmpty) return [];
    final List<DocumentModel> documentList = [];
    final Set<String> seen = {};
    await fireStore
        .collection(CollectionName.documents)
        .where('type', whereIn: wanted)
        .where('enable', isEqualTo: true)
        .get()
        .then((value) {
      for (var element in value.docs) {
        DocumentModel documentModel = DocumentModel.fromJson(element.data());
        final String id = documentModel.id ?? element.id;
        if (!seen.add(id)) continue;
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

  /// Spec 3.6: an actor whose documents are not valid cannot go online.
  /// Account-level approval stays `users.isDocumentVerify` (checked by the
  /// callers exactly as before); this adds the per-document checks: a
  /// document that expired or was rejected blocks going online. Returns the
  /// message to show, or null when the driver may go online.
  static Future<String?> documentBlockReason() async {
    try {
      final driverDocs = await getDocumentOfDriver();
      // Only document types the admin currently requires (the same list the
      // verification screen shows). An old entry for a type that was since
      // disabled can't be re-uploaded, so it must not lock the driver offline.
      final required = await getDocumentListForTypes(documentTypesForCurrentUser());
      final Set<String> requiredIds = required.map((d) => d.id ?? '').where((id) => id.isNotEmpty).toSet();
      for (final doc in driverDocs?.documents ?? <Documents>[]) {
        if (!requiredIds.contains(doc.documentId)) continue;
        final status = doc.verificationStatus;
        if (status == 'expired') return "One of your documents has expired. Please upload a valid document to go online.";
        if (status == 'rejected') return "One of your documents was rejected. Please upload it again to go online.";
      }
    } catch (e) {
      log("documentBlockReason failed: $e");
    }
    return null;
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

  /// The holder `type` of `documents_verify/{uid}` — the panel's types are
  /// "driver" | "vendor" | "owner" | "provider" | "worker" (report §3 02#26).
  /// A delivery company is an owner: its record was filed as "driver".
  static String documentHolderType(UserModel? user) => user?.isOwner == true ? "owner" : "driver";

  /// Uploads one document against the id of an admin-defined type from the
  /// `documents` collection (report Doc 36 / 41) — [documents.documentId] is
  /// always a `documents/{id}`, never a hard-coded key.
  static Future<bool> uploadDriverDocument(Documents documents) async {
    bool isAdded = false;
    final String holderType = documentHolderType(Constant.userModel);
    if ((documents.documentId ?? '').trim().isEmpty) return false;
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
          driverDocumentModel.type = holderType;
          driverDocumentModel.documents = documentsList;
        } else {
          var index = newDriverDocumentModel.documents!.indexWhere((element) => element.documentId == documents.documentId);

          driverDocumentModel.id = getCurrentUid();
          driverDocumentModel.type = holderType;
          documentsList.removeAt(index);
          documentsList.insert(index, documents);
          driverDocumentModel.documents = documentsList;
          isAdded = false;
        }
      } else {
        documentsList.add(documents);
        driverDocumentModel.id = getCurrentUid();
        driverDocumentModel.type = holderType;
        driverDocumentModel.documents = documentsList;
      }
    });

    await fireStore.collection(CollectionName.documentsVerify).doc(getCurrentUid()).set(driverDocumentModel.toJson(), SetOptions(merge: true)).then((value) {
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
            id: orderModel.id == null ? Constant.getUuid() : WalletOnce.referralRowId(orderModel.id!),
            amount: double.parse(Constant.referralAmount.toString()),
            date: Timestamp.now(),
            paymentMethod: "Referral Amount",
            transactionUser: "user",
            userId: referralModel!.referralBy,
            isTopup: true,
            note: "You referral user has complete his this order #${orderModel.id}",
            paymentStatus: "success");

        // Once per order: a retried completion does not pay the referrer again.
        await WalletOnce.pay(
          rowId: transactionModel.id!,
          row: transactionModel.toJson(),
          userId: referralModel!.referralBy,
          amount: double.parse(Constant.referralAmount.toString()),
        );
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
                  .update({"wallet_amount": FieldValue.increment(double.parse(sectionModel!.referralAmount.toString()))});

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
                  .update({"wallet_amount": FieldValue.increment(double.parse(sectionModel!.referralAmount.toString()))});

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
                  .update({"wallet_amount": FieldValue.increment(double.parse(sectionModel!.referralAmount.toString()))});

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
    // merge: a save from the app must not delete fields it does not model
    // (regionId, priceProposal history written by the customer, ...).
    await fireStore.collection(CollectionName.rentalOrders).doc(orderModel.id).set(orderModel.toJson(), SetOptions(merge: true));
  }

  /// Known-fields update of a `rides` document.
  static Future<bool> updateRideFields(String rideId, Map<String, dynamic> data) async {
    try {
      await fireStore.collection(CollectionName.ridesBooking).doc(rideId).setKnownFields(data);
      return true;
    } catch (e) {
      log("updateRideFields failed: $e");
      return false;
    }
  }

  /// Known-fields update of a `vendor_orders` document.
  static Future<bool> updateVendorOrderFields(String orderId, Map<String, dynamic> data) async {
    try {
      await fireStore.collection(CollectionName.vendorOrders).doc(orderId).setKnownFields(data);
      return true;
    } catch (e) {
      log("updateVendorOrderFields failed: $e");
      return false;
    }
  }

  /// Known-fields update of a `rental_orders` document.
  static Future<bool> updateRentalFields(String orderId, Map<String, dynamic> data) async {
    try {
      await fireStore.collection(CollectionName.rentalOrders).doc(orderId).setKnownFields(data);
      return true;
    } catch (e) {
      log("updateRentalFields failed: $e");
      return false;
    }
  }

  /// Zone-bound dispatch (spec 9.1): declines a `vendor_orders` request that
  /// belongs to another region, exactly like the driver's own "Reject" but
  /// without a reason (D2: `Driver Rejected`, this driver in
  /// `rejectedByDrivers`, `driverId` / `driverID` null) so dispatch moves on,
  /// in the same transaction that first re-checks the live order, and removes
  /// it from the driver's pending requests.
  static final Set<String> _declinedVendorOrders = {};

  static Future<void> declineOutOfRegionVendorOrder(String orderId, String driverId) async {
    if (!_declinedVendorOrders.add(orderId)) return;
    log("Declining order $orderId: not in the driver's region");
    final OfferAnswer answer = await AssignedDeliveryOrders.rejectOffer(orderId, driverId);
    if (answer == OfferAnswer.failed) _declinedVendorOrders.remove(orderId);
  }

  /// The driver's position, and nothing else: `location` and `rotation`,
  /// field-level. The location listeners used to read the whole user document
  /// and write it all back on every update; any write that landed in between
  /// — the Store app adding an order to `inProgressOrderID`, dispatch adding
  /// an offer to `orderRequestData` / `ordercabRequestData`, the assignment
  /// watcher's `arrayUnion` — was rolled back by that stale copy.
  ///
  /// An `update`, never a merge `set`: a tick must not create a missing
  /// `users/{uid}`. After an account deletion (or an admin deleting the
  /// driver) a merge set re-created the document as a `{location, rotation}`
  /// stub, and that stub locked the phone number out of login and sign-up.
  /// The missing document fails with `not-found`, which is ignored.
  static Future<bool> updateUserLocation(String userId, {double? latitude, double? longitude, double? heading}) async {
    // Dispatch spec §4: `location` always holds numeric coordinates. A fix
    // without them is skipped rather than written as {latitude: null, ...}.
    if (latitude == null || longitude == null || !latitude.isFinite || !longitude.isFinite) return false;
    try {
      await fireStore.collection(CollectionName.users).doc(userId).update({
        'location': UserLocation(latitude: latitude, longitude: longitude).toJson(),
        if (heading != null && heading.isFinite) 'rotation': heading,
      });
      return true;
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') log("updateUserLocation failed: $e");
      return false;
    } catch (e) {
      log("updateUserLocation failed: $e");
      return false;
    }
  }

  /// Known-fields update of a `users` document.
  static Future<bool> updateUserFields(String userId, Map<String, dynamic> data) async {
    try {
      await fireStore.collection(CollectionName.users).doc(userId).setKnownFields(data);
      return true;
    } catch (e) {
      log("updateUserFields failed: $e");
      return false;
    }
  }

  /// Field-level write of an EXISTING `users/{uid}`, by `update`: unlike
  /// [updateUserFields] (a merge `set`) it never creates a missing document.
  /// For writes a still-signed-in driver can make after the account was
  /// deleted (the online/offline toggle): a merge set re-created the document
  /// as a stub with no role, and that stub locked the phone number out of
  /// login and sign-up. [UserWrite.missing] when the document is gone.
  static Future<UserWrite> updateExistingUserFields(String userId, Map<String, dynamic> data) async {
    try {
      await fireStore.collection(CollectionName.users).doc(userId).update(data);
      return UserWrite.done;
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return UserWrite.missing;
      log("updateExistingUserFields failed: $e");
      return UserWrite.failed;
    } catch (e) {
      log("updateExistingUserFields failed: $e");
      return UserWrite.failed;
    }
  }

  /// Built-in driver cancellation reasons (APP-CONTRACT), used when
  /// `settings/cancellationReasons.driver` is missing or empty.
  static const List<String> defaultDriverCancellationReasons = [
    "Customer not at pickup",
    "Customer asked to cancel",
    "Vehicle problem",
    "Unsafe pickup location",
    "Other",
  ];

  /// `settings/cancellationReasons`: the `driver` key, then `reasons`, then
  /// `list` (strings or `{code, label}` maps, as the web panels read it), else
  /// the built-in defaults. Always ends with exactly one "Other" (free text).
  /// See [parseCancelReasonList].
  static Future<List<CancelReasonOption>> getDriverCancellationReasons() async {
    Map<String, dynamic>? data;
    try {
      final doc = await fireStore.collection(CollectionName.settings).doc('cancellationReasons').get();
      data = doc.data();
    } catch (e) {
      log("getDriverCancellationReasons failed: $e");
    }
    return parseCancelReasonList(data, roleKeys: const ['driver'], defaults: defaultDriverCancellationReasons);
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

  static StreamSubscription<QuerySnapshot>? orderChatSeenSubscription;

  static void setSeenChatForOrder({required String orderId}) {
    // An empty id is not a document path: Firestore throws on `doc("")`.
    if (orderId.trim().isEmpty) return;
    // Opening a second conversation must not leave the previous listener
    // running on the old thread.
    orderChatSeenSubscription?.cancel();
    orderChatSeenSubscription = null;
    final String me = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (me.isEmpty) return;
    // The messages addressed to this driver: exactly what the inbox badge
    // counts (unreadOrderChatCount). Equality filters only - the old
    // `senderId != me` + `seen == false` needs a composite index (none is
    // deployed, so the listener failed) and, since the customer's store chat
    // shares this thread, would also mark the customer's messages to the
    // store seen.
    orderChatSeenSubscription = fireStore
        .collection(CollectionName.chat)
        .doc(orderId)
        .collection("thread")
        .where('receiverId', isEqualTo: me)
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
    _orderChatSeenOrderId = orderId;
  }

  static String? _orderChatSeenOrderId;

  /// Stops marking [orderId]'s messages seen once its conversation is closed.
  /// The listener used to run on after the chat screen was left, so every
  /// later message in that conversation was marked seen at once and never
  /// showed as unread in the inbox.
  static void stopSeenChatForOrder({required String orderId}) {
    if (_orderChatSeenOrderId != orderId) return;
    orderChatSeenSubscription?.cancel();
    orderChatSeenSubscription = null;
    _orderChatSeenOrderId = null;
  }

  /// Live unread count of one order conversation for the signed-in user
  /// (`.claude/CUSTOMER-NOTIFICATIONS.md` section 2): messages in
  /// `chat/{orderId}/thread` with `receiverId == me` and `seen == false`,
  /// at most [ChatUnread.queryLimit] documents (the badge shows `99+` above
  /// [ChatUnread.displayCap]). Equality filters only: no composite index.
  static Stream<int> unreadOrderChatCount(String orderId) {
    final String id = orderId.trim();
    final String me = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (id.isEmpty || me.isEmpty) return Stream<int>.value(0);
    return fireStore
        .collection(CollectionName.chat)
        .doc(id)
        .collection("thread")
        .where('receiverId', isEqualTo: me)
        .where('seen', isEqualTo: false)
        .limit(ChatUnread.queryLimit)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> s) => s.docs.where((d) => ChatUnread.isUnreadFor(d.data(), me)).length);
  }

  // ── Customer Notification Center (`.claude/CUSTOMER-NOTIFICATIONS.md` §1) ──

  static CollectionReference<Map<String, dynamic>> _customerNotifications(String customerId) =>
      fireStore.collection(CollectionName.users).doc(customerId).collection(CollectionName.userNotifications);

  /// A new, unique id for `users/{customerId}/notifications` (no write).
  static String newCustomerNotificationId(String customerId) => _customerNotifications(customerId).doc().id;

  /// Writes the customer's notification record `users/{customerId}/notifications/{id}`.
  static Future<void> setCustomerNotification(String customerId, String id, Map<String, dynamic> document) =>
      _customerNotifications(customerId).doc(id).set(document);
}
