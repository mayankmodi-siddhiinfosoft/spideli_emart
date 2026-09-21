import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import 'package:vendor/app/chat_screens/chat_video_container.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/firebase_options.dart';
import 'package:vendor/models/attributes_model.dart';
import 'package:vendor/models/section_model.dart';
import 'package:vendor/models/advertisement_model.dart';
import 'package:vendor/models/brands_model.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/models/coupon_model.dart';
import 'package:vendor/models/dine_in_booking_model.dart';
import 'package:vendor/models/document_model.dart';
import 'package:vendor/models/driver_document_model.dart';
import 'package:vendor/models/email_template_model.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/models/inbox_model.dart';
import 'package:vendor/models/mail_setting.dart';
import 'package:vendor/models/notification_model.dart';
import 'package:vendor/models/on_boarding_model.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/payment_model/cod_setting_model.dart';
import 'package:vendor/models/payment_model/flutter_wave_model.dart';
import 'package:vendor/models/payment_model/mercado_pago_model.dart';
import 'package:vendor/models/payment_model/mid_trans.dart';
import 'package:vendor/models/payment_model/orange_money.dart';
import 'package:vendor/models/payment_model/pay_fast_model.dart';
import 'package:vendor/models/payment_model/pay_stack_model.dart';
import 'package:vendor/models/payment_model/paypal_model.dart';
import 'package:vendor/models/payment_model/paytm_model.dart';
import 'package:vendor/models/payment_model/razorpay_model.dart';
import 'package:vendor/models/payment_model/stripe_model.dart';
import 'package:vendor/models/payment_model/wallet_setting_model.dart';
import 'package:vendor/models/payment_model/xendit.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/models/rating_model.dart';
import 'package:vendor/models/referral_model.dart';
import 'package:vendor/models/review_attribute_model.dart';
import 'package:vendor/models/story_model.dart';
import 'package:vendor/models/subscription_history.dart';
import 'package:vendor/models/subscription_plan_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_category_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/models/wallet_transaction_model.dart';
import 'package:vendor/models/withdraw_method_model.dart';
import 'package:vendor/models/withdrawal_model.dart';
import 'package:vendor/models/zone_model.dart';
import 'package:vendor/service/audio_player_service.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/utils/preferences.dart';
import 'package:video_compress/video_compress.dart';

enum FirebaseEnv { defaultDb, staging }

/// Change this to switch between default / staging
const FirebaseEnv currentEnv = FirebaseEnv.defaultDb;

class FireStoreUtils {
  FireStoreUtils._privateConstructor();

  static final FireStoreUtils instance = FireStoreUtils._privateConstructor();

  static late FirebaseFirestore fireStore;

  static String getCurrentUid() {
    return FirebaseAuth.instance.currentUser!.uid;
  }

  void init(FirebaseApp app, {String? databaseId}) {
    fireStore = FirebaseFirestore.instanceFor(app: app, databaseId: databaseId);
  }

  static Future<bool> isLogin() async {
    bool isLogin = false;
    if (FirebaseAuth.instance.currentUser?.uid != null) {
      isLogin = await userExistOrNot(FirebaseAuth.instance.currentUser!.uid);
    } else {
      isLogin = false;
    }
    return isLogin;
  }

  static Future<bool> userExistOrNot(String uid) async {
    bool isExist = false;

    await fireStore
        .collection(CollectionName.users)
        .doc(uid)
        .get()
        .then((value) {
          if (value.exists) {
            isExist = true;
          } else {
            isExist = false;
          }
        })
        .catchError((error) {
          log("Failed to check user exist: $error");
          isExist = false;
        });
    return isExist;
  }

  static Future<UserModel?> getUserProfile(String uuid) async {
    UserModel? userModel;
    await fireStore.collection(CollectionName.users).doc(uuid).get().then((value) {
      if (value.exists) {
        userModel = UserModel.fromJson(value.data()!);
        Constant.userModel = userModel;
      }
    });
    return userModel;
  }

  static Future<UserModel?> getUserById(String uuid) async {
    UserModel? userModel;
    log("uuid :: $uuid");
    await fireStore.collection(CollectionName.users).doc(uuid).get().then((value) {
      if (value.exists) {
        userModel = UserModel.fromJson(value.data()!);
      }
    });
    return userModel;
  }

  static Future<bool?> updateUserWallet({required String amount, required String userId}) async {
    bool isAdded = false;
    await getUserProfile(userId).then((value) async {
      if (value != null) {
        UserModel userModel = value;
        userModel.walletAmount = ((userModel.walletAmount ?? 0.0) + double.parse(amount));
        await FireStoreUtils.updateUser(userModel).then((value) {
          isAdded = value;
        });
      }
    });
    return isAdded;
  }

  static Future<bool> updateUser(UserModel userModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.users)
        .doc(userModel.id)
        .set(userModel.toJson())
        .whenComplete(() async {
          Constant.userModel = userModel;
          if (userModel.employeePermissionId != null) {
            Constant.employeeRoleModel = await FireStoreUtils.getEmployeeRoleById(userModel.employeePermissionId!);
          }
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future<bool> updateDriverUser(UserModel userModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.users)
        .doc(userModel.id)
        .set(userModel.toJson())
        .whenComplete(() {
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future<bool> withdrawWalletAmount(WithdrawalModel userModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.payouts)
        .doc(userModel.id)
        .set(userModel.toJson())
        .whenComplete(() {
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future<bool> isMaintenanceMode() async {
    bool isMaintenance = false;
    await fireStore.collection(CollectionName.settings).doc('maintenance_settings').get().then((value) async {
      isMaintenance = value.data()?['isMaintenanceModeForVendor'] == true;
      log("isMaintenance :: $isMaintenance");
    });
    return isMaintenance;
  }

  static Future<List<OnBoardingModel>> getOnBoardingList() async {
    List<OnBoardingModel> onBoardingModel = [];
    await fireStore
        .collection(CollectionName.onBoarding)
        .where("type", isEqualTo: "store")
        .get()
        .then((value) {
          for (var element in value.docs) {
            OnBoardingModel documentModel = OnBoardingModel.fromJson(element.data());
            onBoardingModel.add(documentModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return onBoardingModel;
  }

  static Future<bool?> setWalletTransaction(WalletTransactionModel walletTransactionModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.wallet)
        .doc(walletTransactionModel.id)
        .set(walletTransactionModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<void> getSettings() async {
    try {
      await fireStore.collection(CollectionName.settings).doc("globalSettings").get().then((value) async {
        Constant.orderRingtoneUrl = value.data()?['order_ringtone_url'] ?? '';
        Constant.defaultCountryCode = value.data()?['defaultCountryCode'] ?? '';
        Preferences.setString(Preferences.orderRingtone, Constant.orderRingtoneUrl);
        AppThemeData.primary300 = Color(int.parse(value.data()!['app_store_color'].replaceFirst("#", "0xff")));
        Constant.isEnableAdsFeature = value.data()?['isEnableAdsFeature'] ?? false;
        Constant.isSelfDeliveryFeature = value.data()?['isSelfDelivery'] ?? false;

        Constant.apiSecureKey = value.data()?['apiSecureKey'] ?? "";
        Constant.apiBaseUrl = value.data()?['apiBaseUrl'] ?? "";

        Constant.taxScope = value.data()?['taxScope'] ?? "";

        if (Constant.orderRingtoneUrl.isNotEmpty) {
          await AudioPlayerService.initAudio();
        }
      });

      fireStore.collection(CollectionName.settings).doc("DriverNearBy").get().then((event) {
        if (event.exists) {
          Constant.selectedMapType = event.data()!["selectedMapType"];
          Constant.singleOrderReceive = event.data()!['singleOrderReceive'];
          Constant.distanceType = event.data()!["distanceType"];
        }
      });

      fireStore.collection(CollectionName.settings).doc("scheduleOrderNotification").get().then((time) {
        if (time.exists) {
          Constant.scheduleOrderTime = time.data()!["notifyTime"];
          Constant.scheduleOrderTimeType = time.data()!["timeUnit"];
        }
      });

      await fireStore.collection(CollectionName.settings).doc('vendor').get().then((value) {
        Constant.autoApproveVendor = value.data()!['auto_approve_vendor'];
        Constant.autoApproveStore = value.data()!['auto_approve_store'];
        Constant.isSubscriptionModelApplied = value.data()!['subscription_model'];
        Constant.isEmployeeManagement = value.data()!['isEmployeeManagement'];
      });

      fireStore.collection(CollectionName.settings).doc("googleMapKey").snapshots().listen((event) {
        if (event.exists) {
          Constant.mapAPIKey = event.data()!["key"];
        }
      });

      fireStore.collection(CollectionName.settings).doc('story').get().then((value) {
        Constant.storyEnable = value.data()!['isEnabled'];
      });

      fireStore.collection(CollectionName.settings).doc('placeHolderImage').get().then((value) {
        Constant.placeholderImage = value.data()!['image'];
      });

      fireStore.collection(CollectionName.settings).doc("Version").snapshots().listen((event) {
        if (event.exists) {
          Constant.googlePlayLink = event.data()!["googlePlayLink"] ?? '';
          Constant.appStoreLink = event.data()!["appStoreLink"] ?? '';
          Constant.appVersion = event.data()!["app_version"] ?? '';
          Constant.storeUrl = event.data()!["storeUrl"] ?? '';
        }
      });

      fireStore.collection(CollectionName.settings).doc("specialDiscountOffer").get().then((dineinresult) {
        if (dineinresult.exists) {
          Constant.specialDiscountOfferEnable = dineinresult.data()!["isEnable"];
        }
      });

      fireStore.collection(CollectionName.settings).doc("emailSetting").get().then((value) {
        if (value.exists) {
          Constant.mailSettings = MailSettings.fromJson(value.data()!);
        }
      });

      fireStore.collection(CollectionName.settings).doc("ContactUs").get().then((time) {
        if (time.exists) {
          Constant.adminEmail = time.data()!["Email"];
        }
      });

      fireStore.collection(CollectionName.settings).doc("notification_setting").snapshots().listen((event) {
        if (event.exists) {
          Constant.senderId = event.data()?["senderId"];
          Constant.jsonNotificationFileURL = event.data()?["serviceJson"];
        }
      });

      await fireStore.collection(CollectionName.settings).doc("document_verification_settings").get().then((value) {
        Constant.isStoreVerification = value.data()!['isStoreVerification'];
      });

      fireStore.collection(CollectionName.settings).doc("privacyPolicy").get().then((event) {
        if (event.exists) {
          Constant.privacyPolicy = event.data()!["privacy_policy"];
        }
      });

      fireStore.collection(CollectionName.settings).doc("openai_settings").get().then((event) {
        if (event.exists) {
          Constant.openAIStatus = event.data()!["status"];
        }
      });

      fireStore.collection(CollectionName.settings).doc("termsAndConditions").get().then((event) {
        if (event.exists) {
          Constant.termsAndConditions = event.data()!["terms_and_condition"];
        }
      });

      fireStore.collection(CollectionName.settings).doc("digitalProduct").get().then((event) {
        if (event.exists) {
          Constant.digitalProductFileSize = event.data()!["fileSize"] ?? "10";
        }
      });
    } catch (e) {
      log(e.toString());
    }
  }

  static Future<bool?> checkReferralCodeValidOrNot(String referralCode) async {
    bool? isExit;
    try {
      await fireStore.collection(CollectionName.referral).where("referralCode", isEqualTo: referralCode).get().then((value) {
        if (value.size > 0) {
          isExit = true;
        } else {
          isExit = false;
        }
      });
    } catch (e, s) {
      print('FireStoreUtils.firebaseCreateNewUser $e $s');
      return false;
    }
    return isExit;
  }

  static Future<ReferralModel?> getReferralUserByCode(String referralCode) async {
    ReferralModel? referralModel;
    try {
      await fireStore.collection(CollectionName.referral).where("referralCode", isEqualTo: referralCode).get().then((value) {
        if (value.docs.isNotEmpty) {
          referralModel = ReferralModel.fromJson(value.docs.first.data());
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return referralModel;
  }

  static Future<List<TaxModel>?> getTaxList(double lat, double lng, String sectionId) async {
    List<TaxModel> taxList = [];
    List<Placemark> placeMarks = await placemarkFromCoordinates(lat, lng);

    await fireStore
        .collection(CollectionName.tax)
        .where('country', isEqualTo: placeMarks.first.country)
        .where('sectionId', isEqualTo: sectionId)
        .where('enable', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            TaxModel taxModel = TaxModel.fromJson(element.data());
            taxList.add(taxModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });

    return taxList;
  }

  static Future<OrderModel?> getOrderByOrderId(String orderId) async {
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

  static Future<String?> referralAdd(ReferralModel ratingModel) async {
    try {
      await fireStore.collection(CollectionName.referral).doc(ratingModel.id).set(ratingModel.toJson());
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return null;
  }

  static Future<List<ZoneModel>?> getZone(String sectionId) async {
    List<ZoneModel> airPortList = [];
    await fireStore
        .collection(CollectionName.zone)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            ZoneModel ariPortModel = ZoneModel.fromJson(element.data());
            airPortList.add(ariPortModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return airPortList;
  }

  static Future<List<OrderModel>?> getAllOrder() async {
    List<OrderModel> orderList = [];
    try {
      await fireStore
          .collection(CollectionName.vendorOrders)
          .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            for (var element in value.docs) {
              OrderModel orderModel = OrderModel.fromJson(element.data());
              orderList.add(orderModel);
            }
          })
          .catchError((error) {
            log(error.toString());
          });
    } catch (e) {
      log(e.toString());
    }
    return orderList;
  }

  static Future<bool> deleteCashbackRedeem(OrderModel orderModel) async {
    bool isUpdate = false;
    try {
      final querySnapshot = await fireStore.collection(CollectionName.cashbackRedeem).where('orderId', isEqualTo: orderModel.id).where('cashbackId', isEqualTo: orderModel.cashback?.id).get();
      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          await fireStore.collection(CollectionName.cashbackRedeem).doc(doc.id).delete();
        }
        isUpdate = true;
      } else {
        isUpdate = false;
      }
    } catch (e) {
      isUpdate = false;
      rethrow;
    }
    return isUpdate;
  }

  static Future<bool> updateOrder(OrderModel orderModel) async {
    bool isUpdate = false;

    await fireStore
        .collection(CollectionName.vendorOrders)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future restaurantVendorWalletSet(OrderModel orderModel) async {
    double subTotal = 0.0;
    double specialDiscountAmount = 0.0;
    double couponAmount = 0.0;
    double productTaxAmount = 0.0;
    double orderTaxAmount = 0.0;
    double packagingTaxAmount = 0.0;
    double totalTaxAmount = 0.0;
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
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement) * qty;
          } else {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement);
          }
        }
      }
    }

    /// ---------------- ORDER LEVEL TAX ----------------
    if (orderModel.taxScope == "order") {
      for (var taxElement in orderModel.taxSetting ?? []) {
        orderTaxAmount += Constant.calculateTax(amount: (subTotal - totalDiscount).toString(), taxModel: taxElement);
      }
    }

    packagingCharge = orderModel.packagingChargeEnable == true ? double.parse(orderModel.vendor!.packagingCharge.toString()) : 0.0;

    /// ---------------- PACKAGING TAX ----------------
    if (packagingCharge > 0) {
      for (var taxElement in orderModel.packagingTax ?? []) {
        packagingTaxAmount += Constant.calculateTax(amount: packagingCharge.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- TOTAL TAX ----------------
    totalTaxAmount = productTaxAmount + orderTaxAmount + packagingTaxAmount;

    double basePrice;
    final adminCommission = double.tryParse(orderModel.adminCommission ?? '0') ?? 0.0;

    if (Constant.selectedSection?.adminCommision?.isEnabled == true) {
      basePrice = (subTotal / (1 + (adminCommission / 100))) - couponAmount - specialDiscountAmount + double.parse(orderModel.vendor?.packagingCharge ?? '0.0');
    } else {
      basePrice = subTotal - couponAmount - specialDiscountAmount + double.parse(orderModel.vendor?.packagingCharge ?? '0.0');
    }

    subTotal = subTotal + packagingCharge;

    WalletTransactionModel historyModel = WalletTransactionModel(
      amount: basePrice,
      id: const Uuid().v4(),
      orderId: orderModel.id,
      userId: orderModel.vendor?.author,
      date: Timestamp.now(),
      isTopup: true,
      note: "Order Amount credited",
      paymentMethod: "Wallet",
      paymentStatus: "success",
      transactionUser: "vendor",
    );

    log("historyModel :: ${historyModel.toJson()}");
    await fireStore.collection(CollectionName.wallet).doc(historyModel.id).set(historyModel.toJson());

    WalletTransactionModel taxModel = WalletTransactionModel(
      amount: totalTaxAmount,
      id: const Uuid().v4(),
      orderId: orderModel.id,
      userId: orderModel.vendor?.author,
      date: Timestamp.now(),
      isTopup: true,
      note: "Order Tax credited",
      paymentMethod: "tax",
      paymentStatus: "success",
      transactionUser: "vendor",
    );
    log("taxModel historyModel :: ${taxModel.toJson()}");

    await fireStore.collection(CollectionName.wallet).doc(taxModel.id).set(taxModel.toJson());

    await updateUserWallet(amount: (basePrice + totalTaxAmount).toString(), userId: orderModel.vendor!.author.toString());
  }

  static Future<RatingModel?> getOrderReviewsByID(String orderId, String productID) async {
    RatingModel? ratingModel;

    await fireStore
        .collection(CollectionName.foodsReview)
        .where('orderid', isEqualTo: orderId)
        .where('productId', isEqualTo: productID)
        .get()
        .then((value) {
          print("======>");
          print(value.docs.length);
          if (value.docs.isNotEmpty) {
            ratingModel = RatingModel.fromJson(value.docs.first.data());
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return ratingModel;
  }

  static Future<List<ProductModel>?> getProduct() async {
    List<ProductModel> productList = [];
    await fireStore
        .collection(CollectionName.vendorProducts)
        .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
        .orderBy('createdAt', descending: false)
        .get()
        .then((value) {
          for (var element in value.docs) {
            ProductModel productModel = ProductModel.fromJson(element.data());
            productList.add(productModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return productList;
  }

  static Future<List<AdvertisementModel>?> getAdvertisement() async {
    List<AdvertisementModel> advertisementList = [];
    await fireStore
        .collection(CollectionName.advertisements)
        .where('vendorId', isEqualTo: Constant.userModel!.vendorID)
        .orderBy('createdAt', descending: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            AdvertisementModel advertisementModel = AdvertisementModel.fromJson(element.data());
            advertisementList.add(advertisementModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return advertisementList;
  }

  static Future<AdvertisementModel> getAdvertisementById({required String advertisementId}) async {
    AdvertisementModel advertisementdata = AdvertisementModel();
    await fireStore
        .collection(CollectionName.advertisements)
        .doc(advertisementId)
        .get()
        .then((value) {
          AdvertisementModel advertisementModel = AdvertisementModel.fromJson(value.data() as Map<String, dynamic>);
          advertisementdata = advertisementModel;
        })
        .catchError((error) {
          log(error.toString());
        });
    return advertisementdata;
  }

  static Future<bool> updateProduct(ProductModel productModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.vendorProducts)
        .doc(productModel.id)
        .set(productModel.toJson())
        .whenComplete(() {
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future<bool> deleteProduct(ProductModel productModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.vendorProducts)
        .doc(productModel.id)
        .delete()
        .whenComplete(() {
          isUpdate = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isUpdate = false;
        });
    return isUpdate;
  }

  static Future<List<WalletTransactionModel>?> getWalletTransaction() async {
    List<WalletTransactionModel> walletTransactionList = [];
    await fireStore
        .collection(CollectionName.wallet)
        .where('user_id', isEqualTo: FireStoreUtils.getCurrentUid())
        .orderBy('date', descending: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            WalletTransactionModel walletTransactionModel = WalletTransactionModel.fromJson(element.data());
            walletTransactionList.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return walletTransactionList;
  }

  static Future<List<SectionModel>> getSection() async {
    List<SectionModel> walletTransactionList = [];
    await fireStore
        .collection(CollectionName.sections)
        .where('isActive', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            SectionModel sectionModel = SectionModel.fromJson(element.data());
            walletTransactionList.add(sectionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return walletTransactionList;
  }

  static Future<List<WalletTransactionModel>?> getFilterWalletTransaction(Timestamp startTime, Timestamp endTime) async {
    List<WalletTransactionModel> walletTransactionList = [];
    await fireStore
        .collection(CollectionName.wallet)
        .where('user_id', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('date', isGreaterThanOrEqualTo: startTime)
        .where('date', isLessThanOrEqualTo: endTime)
        .orderBy('date', descending: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            WalletTransactionModel walletTransactionModel = WalletTransactionModel.fromJson(element.data());
            walletTransactionList.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return walletTransactionList;
  }

  static Future<List<WithdrawalModel>?> getWithdrawHistory() async {
    List<WithdrawalModel> walletTransactionList = [];
    await fireStore
        .collection(CollectionName.payouts)
        .where('vendorID', isEqualTo: Constant.userModel!.vendorID.toString())
        .orderBy('paidDate', descending: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            WithdrawalModel walletTransactionModel = WithdrawalModel.fromJson(element.data());
            walletTransactionList.add(walletTransactionModel);
          }
        })
        .catchError((error) {
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
      if (vendorId.isNotEmpty) {
        await fireStore.collection(CollectionName.vendors).doc(vendorId).get().then((value) {
          if (value.exists) {
            vendorModel = VendorModel.fromJson(value.data()!);
          }
        });
      }
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorModel;
  }

  static Future<SectionModel?> getSectionById(String sectionId) async {
    SectionModel? sectionModel;
    try {
      await fireStore.collection(CollectionName.sections).doc(sectionId).get().then((value) {
        if (value.exists) {
          sectionModel = SectionModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return sectionModel;
  }

  static Future<List<VendorCategoryModel>> getVendorCategoryById(String sectionId) async {
    List<VendorCategoryModel> attributeList = [];
    await fireStore.collection(CollectionName.vendorCategories).where('section_id', isEqualTo: sectionId).where('publish', isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        VendorCategoryModel favouriteModel = VendorCategoryModel.fromJson(element.data());
        attributeList.add(favouriteModel);
      }
    });
    return attributeList;
  }

  static Future<ProductModel?> getProductById(String productId) async {
    ProductModel? vendorCategoryModel;
    try {
      await fireStore.collection(CollectionName.vendorProducts).doc(productId).get().then((value) {
        if (value.exists) {
          vendorCategoryModel = ProductModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorCategoryModel;
  }

  static Future<VendorCategoryModel?> getVendorCategoryByCategoryId(String categoryId) async {
    VendorCategoryModel? vendorCategoryModel;
    try {
      await fireStore.collection(CollectionName.vendorCategories).doc(categoryId).get().then((value) {
        if (value.exists) {
          vendorCategoryModel = VendorCategoryModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorCategoryModel;
  }

  static Future<ReviewAttributeModel?> getVendorReviewAttribute(String attributeId) async {
    ReviewAttributeModel? vendorCategoryModel;
    try {
      await fireStore.collection(CollectionName.reviewAttributes).doc(attributeId).get().then((value) {
        if (value.exists) {
          vendorCategoryModel = ReviewAttributeModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return vendorCategoryModel;
  }

  static Future<List<AttributesModel>?> getAttributes() async {
    List<AttributesModel> attributeList = [];
    await fireStore.collection(CollectionName.vendorAttributes).get().then((value) {
      for (var element in value.docs) {
        AttributesModel favouriteModel = AttributesModel.fromJson(element.data());
        attributeList.add(favouriteModel);
      }
    });
    return attributeList;
  }

  static Future<List<BrandsModel>> getBrands() async {
    List<BrandsModel> attributeList = [];
    await fireStore.collection(CollectionName.brands).get().then((value) {
      for (var element in value.docs) {
        BrandsModel favouriteModel = BrandsModel.fromJson(element.data());
        attributeList.add(favouriteModel);
      }
    });
    return attributeList;
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

  static Future<List<DineInBookingModel>> getDineInBooking(bool isUpcoming) async {
    List<DineInBookingModel> list = [];

    if (isUpcoming) {
      await fireStore
          .collection(CollectionName.bookedTable)
          .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date', descending: true)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            for (var element in value.docs) {
              DineInBookingModel taxModel = DineInBookingModel.fromJson(element.data());
              list.add(taxModel);
            }
          })
          .catchError((error) {
            log(error.toString());
          });
    } else {
      await fireStore
          .collection(CollectionName.bookedTable)
          .where('vendorID', isEqualTo: Constant.userModel!.vendorID)
          .where('date', isLessThan: Timestamp.now())
          .orderBy('date', descending: true)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            for (var element in value.docs) {
              DineInBookingModel taxModel = DineInBookingModel.fromJson(element.data());
              list.add(taxModel);
            }
          })
          .catchError((error) {
            log(error.toString());
          });
    }

    return list;
  }

  static Future<List<CouponModel>> getAllVendorCoupons(String vendorId) async {
    List<CouponModel> coupon = [];

    await fireStore
        .collection(CollectionName.coupons)
        .where("vendorID", isEqualTo: vendorId)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .where("isPublic", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel taxModel = CouponModel.fromJson(element.data());
            coupon.add(taxModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return coupon;
  }

  static Future<bool?> setOrder(OrderModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.vendorOrders)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<bool?> setCoupon(CouponModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.coupons)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<bool?> deleteCoupon(CouponModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.coupons)
        .doc(orderModel.id)
        .delete()
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<List<CouponModel>> getOffer(String vendorId) async {
    List<CouponModel> list = [];
    await fireStore.collection(CollectionName.coupons).where("vendorID", isEqualTo: vendorId).orderBy("createdAt", descending: true).get().then((value) {
      for (var element in value.docs) {
        CouponModel taxModel = CouponModel.fromJson(element.data());
        list.add(taxModel);
      }
    });
    return list;
  }

  static Future<List<DocumentModel>> getDocumentList() async {
    List<DocumentModel> documentList = [];
    await fireStore
        .collection(CollectionName.documents)
        .where('type', isEqualTo: "vendor")
        .where('enable', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            DocumentModel documentModel = DocumentModel.fromJson(element.data());
            documentList.add(documentModel);
          }
        })
        .catchError((error) {
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

  static Future addRestaurantInbox(InboxModel inboxModel) async {
    return await fireStore.collection("chat_store").doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addAdminInbox(InboxModel inboxModel) async {
    return await fireStore.collection(CollectionName.chatAdmin).doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addRestaurantChat(ConversationModel conversationModel) async {
    return await fireStore.collection("chat_store").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addAdminChat(ConversationModel conversationModel) async {
    return await fireStore.collection(CollectionName.chatAdmin).doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
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
          driverDocumentModel.type = "restaurant";
          driverDocumentModel.documents = documentsList;
        } else {
          var index = newDriverDocumentModel.documents!.indexWhere((element) => element.documentId == documents.documentId);

          driverDocumentModel.id = getCurrentUid();
          driverDocumentModel.type = "restaurant";
          documentsList.removeAt(index);
          documentsList.insert(index, documents);
          driverDocumentModel.documents = documentsList;
          isAdded = false;
        }
      } else {
        documentsList.add(documents);
        driverDocumentModel.id = getCurrentUid();
        driverDocumentModel.type = "restaurant";
        driverDocumentModel.documents = documentsList;
      }
    });

    await fireStore
        .collection(CollectionName.documentsVerify)
        .doc(getCurrentUid())
        .set(driverDocumentModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          isAdded = false;
          log(error.toString());
        });

    return isAdded;
  }

  static Future<DeliveryCharge?> getDelivery() async {
    DeliveryCharge? driverDocumentModel;
    await fireStore.collection(CollectionName.settings).doc("DeliveryCharge").get().then((value) async {
      if (value.exists) {
        driverDocumentModel = DeliveryCharge.fromJson(value.data()!);
      }
    });
    return driverDocumentModel;
  }

  static Future<VendorModel> firebaseCreateNewVendor(VendorModel vendor) async {
    DocumentReference documentReference = fireStore.collection(CollectionName.vendors).doc();
    vendor.id = documentReference.id;
    await documentReference.set(vendor.toJson());
    Constant.userModel!.vendorID = documentReference.id;
    vendor.fcmToken = Constant.userModel!.fcmToken;
    Constant.vendorAdminCommission = vendor.adminCommission;
    await FireStoreUtils.updateUser(Constant.userModel!);
    return vendor;
  }

  static Future<VendorModel?> updateVendor(VendorModel vendor) async {
    return await fireStore.collection(CollectionName.vendors).doc(vendor.id).set(vendor.toJson()).then((document) {
      Constant.vendorAdminCommission = vendor.adminCommission;
      return vendor;
    });
  }

  static Future<bool?> deleteUser() async {
    try {
      if (Constant.userModel?.vendorID != null && Constant.userModel?.vendorID?.isNotEmpty == true) {
        await fireStore.collection(CollectionName.coupons).where('vendorID', isEqualTo: Constant.userModel!.vendorID).get().then((value) async {
          for (var doc in value.docs) {
            await fireStore.collection(CollectionName.coupons).doc(doc.reference.id).delete();
          }
        });
        await fireStore.collection(CollectionName.foodsReview).where('VendorId', isEqualTo: Constant.userModel!.vendorID).get().then((value) async {
          for (var doc in value.docs) {
            await fireStore.collection(CollectionName.foodsReview).doc(doc.reference.id).delete();
          }
        });

        await fireStore.collection(CollectionName.vendorProducts).where('vendorID', isEqualTo: Constant.userModel?.vendorID).get().then((value) async {
          for (var doc in value.docs) {
            await fireStore.collection(CollectionName.favoriteItem).where('product_id', isEqualTo: doc.reference.id).get().then((value0) async {
              for (var element0 in value0.docs) {
                await fireStore.collection(CollectionName.favoriteItem).doc(element0.reference.path).delete();
              }
            });
            await fireStore.collection(CollectionName.vendorProducts).doc(doc.reference.id).delete();
          }
        });

        await fireStore.collection(CollectionName.vendors).doc(Constant.userModel?.vendorID).delete();
      }

      await fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).delete();

      // delete user  from firebase auth
      await deleteAuthUser(FireStoreUtils.getCurrentUid());
      return true;
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return false;
    }
  }

  static Future<bool> deleteAuthUser(String uid) async {
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
        headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
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

  static Future<ChatVideoContainer?> uploadChatVideoToFireStorage(BuildContext context, File video) async {
    try {
      ShowToastDialog.showLoader("Uploading video...");
      final String uniqueID = const Uuid().v4();
      final Reference videoRef = FirebaseStorage.instance.ref('videos/$uniqueID.mp4');
      final UploadTask uploadTask = videoRef.putFile(video, SettableMetadata(contentType: 'video/mp4'));
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
      final UploadTask thumbnailUploadTask = thumbnailRef.putData(thumbnail.readAsBytesSync(), SettableMetadata(contentType: 'image/jpeg'));
      await thumbnailUploadTask;
      final String thumbnailUrl = await thumbnailRef.getDownloadURL();
      var metaData = await thumbnailRef.getMetadata();
      ShowToastDialog.closeLoader();

      return ChatVideoContainer(
        videoUrl: Url(url: videoUrl.toString(), mime: metaData.contentType ?? 'video'),
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error: ${e.toString()}");
      return null;
    }
  }

  static Future<String> uploadImageOfStory(File image, BuildContext context, String extansion) async {
    final data = await image.readAsBytes();
    final mime = lookupMimeType('', headerBytes: data);

    Reference upload = FirebaseStorage.instance.ref().child('Story/images/${image.path.split('/').last}');
    UploadTask uploadTask = upload.putFile(image, SettableMetadata(contentType: mime));
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();
    return downloadUrl.toString();
  }

  // static Future<File> _compressVideo(File file) async {
  //   MediaInfo? info = await VideoCompress.compressVideo(file.path, quality: VideoQuality.DefaultQuality, deleteOrigin: false, includeAudio: true, frameRate: 24);
  //   if (info != null) {
  //     File compressedVideo = File(info.path!);
  //     return compressedVideo;
  //   } else {
  //     return file;
  //   }
  // }

  // static Future<String?> uploadVideoStory(File video, BuildContext context) async {
  //   var uniqueID = const Uuid().v4();
  //   Reference upload = FirebaseStorage.instance.ref().child('Story/$uniqueID.mp4');
  //   File compressedVideo = await _compressVideo(video);
  //   SettableMetadata metadata = SettableMetadata(contentType: 'video');
  //   UploadTask uploadTask = upload.putFile(compressedVideo, metadata);
  //   var storageRef = (await uploadTask.whenComplete(() {})).ref;
  //   var downloadUrl = await storageRef.getDownloadURL();
  //   ShowToastDialog.closeLoader();
  //   return downloadUrl.toString();
  // }

  static Future<File> _compressVideo(File file) async {
    MediaInfo? info = await VideoCompress.compressVideo(file.path, quality: VideoQuality.MediumQuality, deleteOrigin: false, includeAudio: true, frameRate: 24);
    return info != null ? File(info.path!) : file;
  }

  static Future<String?> uploadVideoStory(File video, BuildContext context) async {
    try {
      var uniqueID = const Uuid().v4();
      Reference upload = FirebaseStorage.instance.ref().child('Story/$uniqueID.mp4');

      File compressedVideo = await _compressVideo(video);
      SettableMetadata metadata = SettableMetadata(contentType: 'video/mp4');

      UploadTask uploadTask = upload.putFile(compressedVideo, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint("Upload progress: ${(progress * 100).toStringAsFixed(2)}%");
      });

      await uploadTask;
      var downloadUrl = await upload.getDownloadURL();

      // optional: delete temp compressed file
      if (compressedVideo.path != video.path) {
        await compressedVideo.delete();
      }

      return downloadUrl.toString();
    } catch (e) {
      debugPrint("Video upload failed: $e");
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

  static Future<StoryModel?> getStory(String vendorId) async {
    DocumentSnapshot<Map<String, dynamic>> userDocument = await fireStore.collection(CollectionName.story).doc(vendorId).get();
    if (userDocument.data() != null && userDocument.exists) {
      return StoryModel.fromJson(userDocument.data()!);
    } else {
      return null;
    }
  }

  static Future<void> addOrUpdateStory(StoryModel storyModel) async {
    try {
      Future.microtask(() async {
        await fireStore.collection(CollectionName.story).doc(storyModel.vendorID).set(storyModel.toJson());
      });
    } catch (e) {
      debugPrint("Error adding/updating story: $e");
    }
  }

  // static Future addOrUpdateStory(StoryModel storyModel) async {
  //   await fireStore.collection(CollectionName.story).doc(storyModel.vendorID).set(storyModel.toJson());
  // }

  static Future removeStory(String vendorId) async {
    await fireStore.collection(CollectionName.story).doc(vendorId).delete();
  }

  static Future<WithdrawMethodModel?> getWithdrawMethod() async {
    WithdrawMethodModel? withdrawMethodModel;
    String? uuid = Constant.userModel?.role != 'employee' ? Constant.userModel?.id : '';
    if (Constant.userModel?.role == 'employee') {
      VendorModel? vendor = await getVendorById(Constant.userModel!.vendorID!);
      uuid = vendor?.author;
      log("GetWithdrawMethod :: ${vendor?.id} :: $uuid :: ${Constant.userModel!.vendorID} :: ${Constant.userModel?.role}");
    }

    await fireStore.collection(CollectionName.withdrawMethod).where("userId", isEqualTo: uuid).get().then((value) async {
      if (value.docs.isNotEmpty) {
        withdrawMethodModel = WithdrawMethodModel.fromJson(value.docs.first.data());
      }
    });
    return withdrawMethodModel;
  }

  static Future<WithdrawMethodModel?> setWithdrawMethod(WithdrawMethodModel withdrawMethodModel) async {
    String? uuid = Constant.userModel?.role != 'employee' ? Constant.userModel?.id : '';
    if (Constant.userModel?.role == 'employee') {
      VendorModel? user = await getVendorById(Constant.userModel!.vendorID!);
      uuid = user?.author;
    }
    if (withdrawMethodModel.id == null) {
      withdrawMethodModel.id = const Uuid().v4();
      withdrawMethodModel.userId = uuid;
    }
    await fireStore.collection(CollectionName.withdrawMethod).doc(withdrawMethodModel.id).set(withdrawMethodModel.toJson()).then((value) async {});
    return withdrawMethodModel;
  }

  static Future<EmailTemplateModel?> getEmailTemplates(String type) async {
    EmailTemplateModel? emailTemplateModel;
    await fireStore.collection(CollectionName.emailTemplates).where('type', isEqualTo: type).get().then((value) {
      if (value.docs.isNotEmpty) {
        emailTemplateModel = EmailTemplateModel.fromJson(value.docs.first.data());
      }
    });
    return emailTemplateModel;
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

  static Future<bool?> setBookedOrder(DineInBookingModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.bookedTable)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<bool?> setProduct(ProductModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.vendorProducts)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<String> uploadUserImageToFireStorage(File image, String userID) async {
    Reference upload = FirebaseStorage.instance.ref().child('images/$userID.png');
    UploadTask uploadTask = upload.putFile(image);
    var downloadUrl = await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  static Future<List<SubscriptionPlanModel>> getAllSubscriptionPlans(String sectionId) async {
    List<SubscriptionPlanModel> subscriptionPlanModels = [];
    await fireStore.collection(CollectionName.subscriptionPlans).where("isCommissionPlan", isEqualTo: false).where("sectionId", isEqualTo: sectionId).where('isEnable', isEqualTo: true).get().then((
      value,
    ) async {
      if (value.docs.isNotEmpty) {
        for (var element in value.docs) {
          SubscriptionPlanModel subscriptionPlanModel = SubscriptionPlanModel.fromJson(element.data());
          subscriptionPlanModels.add(subscriptionPlanModel);
        }
      }
    });
    return subscriptionPlanModels;
  }

  static Future<List<SubscriptionPlanModel>> getSubscriptionCommissionPlanById(String sectionId) async {
    List<SubscriptionPlanModel> subscriptionPlanModels = [];
    await fireStore.collection(CollectionName.subscriptionPlans).where("isCommissionPlan", isEqualTo: true).where("sectionId", isEqualTo: sectionId).where('isEnable', isEqualTo: true).get().then((
      value,
    ) async {
      if (value.docs.isNotEmpty) {
        for (var element in value.docs) {
          print(element.data());
          SubscriptionPlanModel subscriptionPlanModel = SubscriptionPlanModel.fromJson(element.data());
          subscriptionPlanModels.add(subscriptionPlanModel);
        }
      }
    });
    return subscriptionPlanModels;
  }

  static Future<bool?> setSubscriptionTransaction(SubscriptionHistoryModel subscriptionPlan) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.subscriptionHistory)
        .doc(subscriptionPlan.id)
        .set(subscriptionPlan.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<List<SubscriptionHistoryModel>> getSubscriptionHistory() async {
    List<SubscriptionHistoryModel> subscriptionHistoryList = [];
    await fireStore.collection(CollectionName.subscriptionHistory).where('user_id', isEqualTo: getCurrentUid()).orderBy('createdAt', descending: true).get().then((value) async {
      if (value.docs.isNotEmpty) {
        for (var element in value.docs) {
          SubscriptionHistoryModel subscriptionHistoryModel = SubscriptionHistoryModel.fromJson(element.data());
          subscriptionHistoryList.add(subscriptionHistoryModel);
        }
      }
    });
    return subscriptionHistoryList;
  }

  static Future<AdvertisementModel> firebaseCreateAdvertisement(AdvertisementModel model) async {
    await fireStore.collection(CollectionName.advertisements).doc(model.id).set(model.toJson());
    return model;
  }

  static Future<AdvertisementModel> removeAdvertisement(AdvertisementModel model) async {
    await fireStore.collection(CollectionName.advertisements).doc(model.id).delete();
    return model;
  }

  static Future<AdvertisementModel> pauseAndResumeAdvertisement(AdvertisementModel model) async {
    await fireStore.collection(CollectionName.advertisements).doc(model.id).update(model.toJson());
    return model;
  }

  static Future<List<RatingModel>> getOrderReviewsByVenderId({required String venderId}) async {
    List<RatingModel> ratingModelList = [];
    await fireStore
        .collection(CollectionName.foodsReview)
        .where('VendorId', isEqualTo: venderId)
        .get()
        .then((value) {
          print("======>");
          print(value.docs.length);
          if (value.docs.isNotEmpty) {
            for (int i = 0; i < value.docs.length; i++) {
              ratingModelList.add(RatingModel.fromJson(value.docs[i].data()));
            }
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return ratingModelList;
  }

  static Future<List<UserModel>> getAvalibleDrivers() async {
    List<UserModel> driverList = [];
    try {
      log("getAvalibleDrivers :: 22");
      await fireStore
          .collection(CollectionName.users)
          .where('vendorID', isEqualTo: Constant.userModel?.vendorID)
          .where('role', isEqualTo: Constant.userRoleDriver)
          .where('active', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            if (value.docs.isNotEmpty) {
              for (int i = 0; i < value.docs.length; i++) {
                driverList.add(UserModel.fromJson(value.docs[i].data()));
              }
            }
          });
    } catch (e) {
      log("Error fetching drivers: ${e.toString()}");
    }

    return driverList;
  }

  static Future<List<UserModel>> getAllDrivers() async {
    List<UserModel> driverList = [];
    try {
      await fireStore
          .collection(CollectionName.users)
          .where('vendorID', isEqualTo: Constant.userModel?.vendorID)
          .where('role', isEqualTo: Constant.userRoleDriver)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            if (value.docs.isNotEmpty) {
              for (int i = 0; i < value.docs.length; i++) {
                driverList.add(UserModel.fromJson(value.docs[i].data()));
              }
            }
          });
    } catch (e) {
      log("Error fetching drivers: ${e.toString()}");
    }
    return driverList;
  }

  static Future<List<ProductModel>?> getAdminProduct(String sectionId) async {
    List<ProductModel> productList = [];
    await fireStore.collection(CollectionName.adminProducts).where('publish', isEqualTo: true).where('sectionId', isEqualTo: sectionId).orderBy('createdAt', descending: true).get().then((value) {
      for (var element in value.docs) {
        ProductModel productModel = ProductModel.fromJson(element.data());
        productList.add(productModel);
      }
    });
    return productList;
  }

  static Future<bool?> setEmployeeRole(EmployeeRoleModel employeeRoleModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.vendorEmployeeRoles)
        .doc(employeeRoleModel.id)
        .set(employeeRoleModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<List<EmployeeRoleModel>> getAllEmployeeRoles({bool isActive = false}) async {
    try {
      var query = fireStore.collection(CollectionName.vendorEmployeeRoles).where('vendorId', isEqualTo: Constant.userModel?.vendorID);
      if (isActive) {
        query = query.where('isEnable', isEqualTo: true);
      }
      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) {
        return EmployeeRoleModel.fromJson(doc.data());
      }).toList();
    } catch (error) {
      log("Failed to get employee roles: $error");
      return [];
    }
  }

  static Future<EmployeeRoleModel?> getEmployeeRoleById(String id) async {
    try {
      final docSnapshot = await fireStore.collection(CollectionName.vendorEmployeeRoles).doc(id).get();
      log("docSnapshot.data() :: ${docSnapshot.data()}");
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return EmployeeRoleModel.fromJson(docSnapshot.data()!);
      }
      return null; // Not found
    } catch (error) {
      log("Failed to get employee role by ID: $error");
      return null;
    }
  }

  static Future<bool> deleteEmployeeRole(String id) async {
    bool isDeleted = false;
    await fireStore
        .collection(CollectionName.vendorEmployeeRoles)
        .doc(id)
        .delete()
        .then((value) {
          isDeleted = true;
        })
        .catchError((error) {
          log("Failed to delete employee role: $error");
          isDeleted = false;
        });
    return isDeleted;
  }

  static Future<List<UserModel>> getAllEmployee() async {
    List<UserModel> employeeList = [];
    try {
      await fireStore
          .collection(CollectionName.users)
          .where('vendorID', isEqualTo: Constant.userModel?.vendorID)
          .where('role', isEqualTo: Constant.userRoleEmployee)
          .orderBy('createdAt', descending: true)
          .get()
          .then((value) {
            log("value.docs.isNotEmpty :: ${value.docs.length}");
            if (value.docs.isNotEmpty) {
              for (int i = 0; i < value.docs.length; i++) {
                employeeList.add(UserModel.fromJson(value.docs[i].data()));
              }
            }
          });
    } catch (e) {
      log("Error fetching drivers: ${e.toString()}");
    }
    return employeeList;
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
        .listen(
          (querySnapshot) async {
            for (final doc in querySnapshot.docs) {
              try {
                await doc.reference.update({'seen': true});
              } catch (e) {
                log(e.toString());
              }
            }
          },
          onError: (error) {
            log(error.toString());
          },
        );
  }

  static Future<InboxModel> addInbox(InboxModel inboxModel) async {
    final collection = fireStore.collection(CollectionName.chat);
    final docId = (inboxModel.senderReceiverId?.contains('admin') == false)
        ? inboxModel.orderId
        : (inboxModel.orderId != null)
        ? inboxModel.orderId
        : inboxModel.senderId;
    await collection.doc(docId).set(inboxModel.toJson());
    return inboxModel;
  }

  static Future<ConversationModel> addChat(ConversationModel conversationModel) async {
    final chatCollection = fireStore.collection(CollectionName.chat);
    final docId = (conversationModel.receiverId?.contains('admin') == false)
        ? conversationModel.orderId
        : (conversationModel.orderId != null)
        ? conversationModel.orderId
        : conversationModel.senderId;
    await chatCollection.doc(docId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson());
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
        .listen(
          (querySnapshot) async {
            for (final doc in querySnapshot.docs) {
              try {
                await doc.reference.update({'seen': true});
              } catch (e) {
                log(e.toString());
              }
            }
          },
          onError: (error) {
            log(error.toString());
          },
        );
  }

  static void stopSeenListener() {
    adminChatSeenSubscription.cancel();
  }
}
