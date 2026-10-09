import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/firebase_options.dart';
import 'package:customer/models/brands_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/models/rental_package_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/zone_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import '../constant/constant.dart';
import '../models/attributes_model.dart';
import '../models/cab_order_model.dart';
import '../models/cashback_redeem_model.dart';
import '../models/category_model.dart';
import '../models/coupon_model.dart';
import '../models/currency_model.dart';
import '../models/favorite_ondemand_service_model.dart';
import '../models/gift_cards_model.dart';
import '../models/advertisement_model.dart';
import '../models/banner_model.dart';
import '../models/cashback_model.dart';
import '../models/conversation_model.dart';
import '../models/dine_in_booking_model.dart';
import '../models/email_template_model.dart';
import '../models/favourite_item_model.dart';
import '../models/favourite_model.dart';
import '../models/gift_cards_order_model.dart';
import '../models/inbox_model.dart';
import '../models/mail_setting.dart';
import '../models/notification_model.dart';
import '../models/on_boarding_model.dart';
import '../models/onprovider_order_model.dart';
import '../models/order_model.dart';
import '../models/parcel_category.dart';
import '../models/parcel_order_model.dart';
import '../models/parcel_weight_model.dart';
import '../models/payment_model/cod_setting_model.dart';
import '../models/payment_model/flutter_wave_model.dart';
import '../models/payment_model/mercado_pago_model.dart';
import '../models/payment_model/mid_trans.dart';
import '../models/payment_model/orange_money.dart';
import '../models/payment_model/pay_fast_model.dart';
import '../models/payment_model/pay_stack_model.dart';
import '../models/payment_model/paypal_model.dart';
import '../models/payment_model/paytm_model.dart';
import '../models/payment_model/razorpay_model.dart';
import '../models/payment_model/stripe_model.dart';
import '../models/payment_model/wallet_setting_model.dart';
import '../models/payment_model/xendit.dart';
import '../models/popular_destination.dart';
import '../models/product_model.dart';
import '../models/provider_serivce_model.dart';
import '../models/rating_model.dart';
import '../models/referral_model.dart';
import '../models/rental_vehicle_type.dart';
import '../models/review_attribute_model.dart';
import '../models/section_model.dart';
import '../models/story_model.dart';
import '../models/tax_model.dart';
import '../models/vehicle_type.dart';
import '../models/vendor_category_model.dart';
import '../models/vendor_model.dart';
import '../models/wallet_transaction_model.dart';
import '../models/worker_model.dart';
import '../screen_ui/multi_vendor_service/chat_screens/chat_video_container.dart';
import '../themes/app_them_data.dart';
import '../themes/show_toast_dialog.dart';
import '../utils/address_format.dart';
import '../utils/tax_country.dart';
import '../utils/product_delivery_charge.dart';
import '../utils/preferences.dart';
import '../utils/push_token.dart';
import '../utils/region_service.dart';
import '../utils/review_totals.dart';
import '../widget/geoflutterfire/src/geoflutterfire.dart';
import '../widget/geoflutterfire/src/models/point.dart';
import 'package:http/http.dart' as http;

/// Writes only the keys present in [data] and leaves every other field of the
/// document alone (contract lesson 2): a full `set(model.toJson())` on an
/// existing document deletes fields the app does not model, such as the admin
/// panel's `regionId` / `regionIds`. Creates the document when it is missing.
extension SetKnownFields on DocumentReference<Map<String, dynamic>> {
  Future<void> setKnownFields(Map<String, dynamic> data) {
    return set(data, SetOptions(mergeFields: data.keys.map((key) => FieldPath([key])).toList()));
  }
}

enum FirebaseEnv { defaultDb, staging }

/// Change this to switch between default / staging
const FirebaseEnv currentEnv = FirebaseEnv.defaultDb;

class FireStoreUtils {
  FireStoreUtils._privateConstructor();

  static final FireStoreUtils instance = FireStoreUtils._privateConstructor();

  static late FirebaseFirestore fireStore;
  static bool _initialized = false;

  /// Initialize Firestore with a FirebaseApp and optional databaseId
  void init(FirebaseApp app, {String? databaseId}) {
    fireStore = FirebaseFirestore.instanceFor(app: app, databaseId: databaseId);
    _initialized = true;
  }

  /// [init] with the default Firebase app and [currentEnv], unless done
  /// already. For the push background handler, which runs in its own isolate
  /// where `main()` never ran (Firebase must be initialised first).
  static void ensureInitialized() {
    if (_initialized) return;
    if (currentEnv == FirebaseEnv.defaultDb) {
      instance.init(Firebase.app());
    } else {
      instance.init(Firebase.app(), databaseId: 'staging');
    }
  }

  static String getCurrentUid() {
    return auth.FirebaseAuth.instance.currentUser!.uid;
  }

  static Future<bool> isLogin() async {
    bool isLogin = false;
    if (auth.FirebaseAuth.instance.currentUser != null) {
      isLogin = await userExistOrNot(auth.FirebaseAuth.instance.currentUser!.uid);
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
    // `doc('')` throws ArgumentError rather than returning a missing document,
    // and this is called with ids straight out of chat/order payloads.
    if (uuid.trim().isEmpty) return null;
    await fireStore
        .collection(CollectionName.users)
        .doc(uuid)
        .get()
        .then((value) {
          if (value.exists) {
            userModel = UserModel.fromJson(value.data()!);
          }
        })
        .catchError((error) {
          log("Failed to update user: $error");
          userModel = null;
        });
    return userModel;
  }

  static Future<UserModel?> getUserForChat(String uuid) async {
    UserModel? userModel;
    if (uuid.trim().isEmpty) return null;

    await fireStore
        .collection(CollectionName.providersWorkers)
        .doc(uuid)
        .get()
        .then((value) {
          if (value.exists) {
            userModel = UserModel.fromJson(value.data()!);
          }
        })
        .catchError((error) {
          log("Failed to update user: $error");
          userModel = null;
        });
    // The other side of a chat is only a provider/worker for on-demand
    // threads; a store, a driver or a customer lives in `users`. Without this
    // the lookup returned null for them, which is why the chat push fallback
    // had no token to send to (bug #3). providers_workers is still tried
    // first, so an on-demand thread resolves exactly as before.
    if (userModel == null) return getUserProfile(uuid);
    return userModel;
  }

  /// What a user save writes. Never `wallet_amount`: balances move only via
  /// [updateUserWallet], so a stale copy of a user can't undo a credit (e.g. a
  /// refund the store just made). When the document belongs to SOMEONE ELSE
  /// (a customer rating a driver or provider), their account status,
  /// verification, subscription and earnings fields are left alone too.
  ///
  /// Never `fcmToken` on an existing document either: the token is written
  /// field-level by PushTokenSync only. A whole-user save carried whatever
  /// token its copy was loaded with, so a login on an iPhone (where the token
  /// was still '') wiped the good one, and a review or a profile edit put a
  /// stale token back over a refreshed one. [includeFcmToken] is for a new
  /// document (sign-up).
  ///
  /// Someone else's live state is never written either: a driver's job
  /// arrays (`inProgressOrderID`, `orderRequestData`, `ordercabRequestData` -
  /// owned by the dispatch Cloud Functions and the driver's accept / reject)
  /// and their position (`location`, `rotation`, `g`), which a copy read
  /// before the write would roll back.
  static Map<String, dynamic> _userWriteData(UserModel userModel, {bool includeFcmToken = false}) {
    final data = userModel.toJson()..remove('wallet_amount');
    if (!includeFcmToken) data.remove('fcmToken');
    final String? me = auth.FirebaseAuth.instance.currentUser?.uid;
    if (me != null && userModel.id != me) {
      for (final key in const [
        'active', 'isActive', 'role', 'isDocumentVerify', 'isAutoVerify', 'isOwner', 'ownerId',
        'subscriptionPlanId', 'subscriptionExpiryDate', 'subscription_plan', 'adminCommission',
        'salary', 'userBankDetails', 'vendorID', 'zoneId', 'sectionIds',
        'inProgressOrderID', 'orderRequestData', 'ordercabRequestData', 'location', 'rotation', 'g',
      ]) {
        data.remove(key);
      }
    }
    return data;
  }

  static Future<bool> updateUser(UserModel userModel) async {
    bool isUpdate = false;
    bool isNew = false;
    // Sign-up creates the user through here: give a NEW document an explicit
    // wallet_amount of 0 (updateUser never writes the balance otherwise).
    try {
      final ref = fireStore.collection(CollectionName.users).doc(userModel.id);
      if (!(await ref.get()).exists) {
        isNew = true;
        await ref.set({'wallet_amount': 0}, SetOptions(merge: true));
      }
    } catch (e) {
      log("updateUser: wallet_amount init skipped: $e");
    }
    final String? me = auth.FirebaseAuth.instance.currentUser?.uid;
    final bool isMine = me != null && userModel.id == me;
    // The signed-in customer's copy (Constant.userModel, embedded in new
    // orders as `author`) carries this device's current token, not the one
    // it was loaded with.
    if (isMine) userModel.fcmToken = PushToken.preferDevice(userModel.fcmToken);
    await fireStore
        .collection(CollectionName.users)
        .doc(userModel.id)
        .setKnownFields(_userWriteData(userModel, includeFcmToken: isNew && isMine))
        .whenComplete(() {
          // Reviews also update drivers/providers through here: only the
          // signed-in customer's own document refreshes the session copy.
          if (auth.FirebaseAuth.instance.currentUser == null || userModel.id == auth.FirebaseAuth.instance.currentUser!.uid) Constant.userModel = userModel;
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
      isMaintenance = value.data()?['isMaintenanceModeForCustomer'] == true;
      log("isMaintenance :: $isMaintenance");
    });
    return isMaintenance;
  }

  static Future<List<OnBoardingModel>> getOnBoardingList() async {
    List<OnBoardingModel> onBoardingModel = [];
    await fireStore
        .collection(CollectionName.onBoarding)
        .where("type", isEqualTo: "customer")
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

  static Future<List<ZoneModel>?> getZone() async {
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

  static Future<String?> referralAdd(ReferralModel ratingModel) async {
    try {
      await fireStore.collection(CollectionName.referral).doc(ratingModel.id).set(ratingModel.toJson());
    } catch (e, s) {
      print('FireStoreUtils.referralAdd $e $s');
      return "Couldn't review".tr;
    }
    return null;
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
      print('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return referralModel;
  }

  static Future<List<SectionModel>> getSections() async {
    List<SectionModel> sections = [];
    // Sorted here, not with orderBy("order"): the panel stores `order` as text
    // ("2", "10"), which Firestore sorts as text ("10" before "2"), and
    // orderBy leaves out every section that has no `order` at all.
    QuerySnapshot<Map<String, dynamic>> productsQuery = await fireStore.collection(CollectionName.sections).where("isActive", isEqualTo: true).get();

    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        sections.add(SectionModel.fromJson(document.data()));
      } catch (e) {
        print('**-FireStoreUtils.getSection Parse error $e');
      }
    });
    sections.sort(SectionModel.compareByOrder);
    return sections;
  }

  static Future<List<dynamic>> getSectionBannerList() async {
    List<dynamic> sections = [];
    await fireStore.collection(CollectionName.settings).doc("AppHomeBanners").get().then((value) {
      if (value.exists) {
        sections = value.data()!['banners'] ?? [];
      }
    });
    return sections;
  }

  static Future<CurrencyModel?> getCurrency() async {
    CurrencyModel? currency;
    await fireStore.collection(CollectionName.currency).where("isActive", isEqualTo: true).get().then((value) {
      if (value.docs.isNotEmpty) {
        currency = CurrencyModel.fromJson(value.docs.first.data());
      }
    });
    return currency;
  }

  static Future<List<AdvertisementModel>> getAllAdvertisement() async {
    List<AdvertisementModel> advertisementList = [];
    await fireStore
        .collection(CollectionName.advertisements)
        .where('status', isEqualTo: 'approved')
        .where('paymentStatus', isEqualTo: true)
        .where('startDate', isLessThanOrEqualTo: DateTime.now())
        .where('endDate', isGreaterThan: DateTime.now())
        .orderBy('priority', descending: false)
        .get()
        .then((value) {
          for (var element in value.docs) {
            AdvertisementModel advertisementModel = AdvertisementModel.fromJson(element.data());
            if (advertisementModel.isPaused == null || advertisementModel.isPaused == false) {
              advertisementList.add(advertisementModel);
            }
          }
        });
    return advertisementList;
  }

  static Future<List<FavouriteModel>> getFavouriteRestaurant() async {
    List<FavouriteModel> favouriteList = [];
    await fireStore.collection(CollectionName.favoriteVendor).where('user_id', isEqualTo: getCurrentUid()).where("section_id", isEqualTo: Constant.sectionConstantModel!.id).get().then((value) {
      for (var element in value.docs) {
        FavouriteModel favouriteModel = FavouriteModel.fromJson(element.data());
        favouriteList.add(favouriteModel);
      }
    });
    log("CollectionName.favoriteRestaurant :: ${favouriteList.length}");
    return favouriteList;
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

  static Future<List<CashbackModel>> getCashbackList() async {
    List<CashbackModel> cashbackList = [];
    try {
      await fireStore
          .collection(CollectionName.cashback)
          .where('isEnabled', isEqualTo: true)
          .where('startDate', isLessThanOrEqualTo: Timestamp.now())
          .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
          .get()
          .then((event) {
            if (event.docs.isNotEmpty) {
              for (var element in event.docs) {
                CashbackModel cashbackModel = CashbackModel.fromJson(element.data());
                if (cashbackModel.customerIds == null || cashbackModel.customerIds?.contains(FireStoreUtils.getCurrentUid()) == true) {
                  cashbackList.add(cashbackModel);
                }
              }
            }
          });
    } catch (error, stackTrace) {
      log('Error fetching redeemed cashback data: $error', stackTrace: stackTrace);
    }

    return cashbackList;
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

  static Future addRestaurantInbox(InboxModel inboxModel) async {
    return await fireStore.collection("chat_store").doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addRestaurantChat(ConversationModel conversationModel) async {
    return await fireStore.collection("chat_store").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addWorkerInbox(InboxModel inboxModel) async {
    return await fireStore.collection("chat_worker").doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addWorkerChat(ConversationModel conversationModel) async {
    return await fireStore.collection("chat_worker").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addProviderInbox(InboxModel inboxModel) async {
    return await fireStore.collection("chat_provider").doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addProviderChat(ConversationModel conversationModel) async {
    return await fireStore.collection("chat_provider").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future<List<TaxModel>?> getTaxList(String? sectionId) async {
    List<TaxModel> taxList = [];
    // The chosen location may carry no coordinates at all (an address typed by
    // hand), and the reverse geocode may come back empty: reading through
    // either threw here and the cart lost its taxes with it.
    final UserLocation? centre = Constant.selectedLocation.location;
    List<Placemark> placeMarks = [];
    try {
      placeMarks = await Geocoding().placemarkFromCoordinates(centre?.latitude ?? 0.0, centre?.longitude ?? 0.0);
    } catch (e) {
      log("getTaxList: reverse geocoding failed: $e");
    }
    if (placeMarks.isEmpty) return taxList;
    // Doc 61: the geocoder names the country in the DEVICE language
    // ("Cameroun"), the admin saves the English name ("Cameroon"). Ask for
    // both (plus English aliases) and keep each tax once, by doc id.
    final List<String> countries = TaxCountry.queryNames(detectedName: placeMarks.first.country, isoCode: placeMarks.first.isoCountryCode);
    if (countries.isEmpty) return taxList;
    final Map<String, TaxModel> byId = {};
    await fireStore
        .collection(CollectionName.tax)
        .where('sectionId', isEqualTo: sectionId)
        .where('country', whereIn: countries)
        .where('enable', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            byId.putIfAbsent(element.id, () => TaxModel.fromJson(element.data()));
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    taxList.addAll(byId.values);
    return taxList;
  }

  static Future<List<DineInBookingModel>> getDineInBooking(bool isUpcoming) async {
    List<DineInBookingModel> list = [];

    if (isUpcoming) {
      await fireStore
          .collection(CollectionName.bookedTable)
          .where('authorID', isEqualTo: getCurrentUid())
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
          .where('authorID', isEqualTo: getCurrentUid())
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

  static Future<List<VendorCategoryModel>> getHomeVendorCategory() async {
    List<VendorCategoryModel> list = [];
    await fireStore
        .collection(CollectionName.vendorCategories)
        .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
        .where("show_in_homepage", isEqualTo: true)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            VendorCategoryModel walletTransactionModel = VendorCategoryModel.fromJson(element.data());
            list.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return list;
  }

  static Future<List<ProductModel>> getProductListByBrandId(String brandId) async {
    List<ProductModel> list = [];
    await fireStore
        .collection(CollectionName.vendorProducts)
        .where('brandID', isEqualTo: brandId)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            ProductModel walletTransactionModel = ProductModel.fromJson(element.data());
            // Wholesale-only products are not shown to a customer without an
            // approved business account (WEB spec §19).
            if (walletTransactionModel.hiddenForCustomer) continue;
            list.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return list;
  }

  static Future<List<BannerModel>> getHomeBottomBanner() async {
    List<BannerModel> bannerList = [];
    await fireStore
        .collection(CollectionName.bannerItems)
        .where("is_publish", isEqualTo: true)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where("position", isEqualTo: "middle")
        .orderBy("set_order", descending: false)
        .get()
        .then((value) {
          for (var element in value.docs) {
            BannerModel bannerHome = BannerModel.fromJson(element.data());
            bannerList.add(bannerHome);
          }
        });
    return bannerList;
  }

  static Future<List<BrandsModel>> getBrandList() async {
    List<BrandsModel> brandList = [];
    await fireStore.collection(CollectionName.brands).where("is_publish", isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        BrandsModel bannerHome = BrandsModel.fromJson(element.data());
        brandList.add(bannerHome);
      }
    });
    return brandList;
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

  static Future<List<FavouriteItemModel>> getFavouriteItem() async {
    List<FavouriteItemModel> favouriteList = [];
    await fireStore.collection(CollectionName.favoriteItem).where('user_id', isEqualTo: getCurrentUid()).where("section_id", isEqualTo: Constant.sectionConstantModel!.id).get().then((value) {
      for (var element in value.docs) {
        FavouriteItemModel favouriteModel = FavouriteItemModel.fromJson(element.data());
        favouriteList.add(favouriteModel);
      }
    });
    return favouriteList;
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

  /// `sections/{sectionId}.is_delivery_charge_customization`, read now (Doc
  /// 60): true / false, or null when the section could not be read (callers
  /// then keep what they knew).
  static Future<bool?> getSectionDeliveryChargeCustomization(String? sectionId) async {
    if (sectionId == null || sectionId.isEmpty) return false;
    try {
      final snap = await fireStore.collection(CollectionName.sections).doc(sectionId).get();
      if (!snap.exists) return false;
      return ProductDeliveryCharge.isEnabled(snap.data()?['is_delivery_charge_customization']);
    } catch (e, s) {
      log('FireStoreUtils.getSectionDeliveryChargeCustomization $e $s');
      return null;
    }
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

  static Future<List<GiftCardsModel>> getGiftCard() async {
    List<GiftCardsModel> giftCardModelList = [];
    QuerySnapshot<Map<String, dynamic>> currencyQuery = await fireStore.collection(CollectionName.giftCards).where("isEnable", isEqualTo: true).get();
    await Future.forEach(currencyQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        log(document.data().toString());
        giftCardModelList.add(GiftCardsModel.fromJson(document.data()));
      } catch (e) {
        debugPrint('FireStoreUtils.get Currency Parse error $e');
      }
    });
    return giftCardModelList;
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

  /// `globalSettings.order_ringtone_url` as it is NOW (re-read at send time,
  /// bounded), for a new-order push to a store: the admin may have changed it
  /// since start-up. Falls back to the copy loaded at start-up.
  static Future<String> currentOrderRingtoneUrl() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await fireStore.collection(CollectionName.settings).doc("globalSettings").get().timeout(const Duration(seconds: 4));
      if (snap.exists) Constant.orderRingtoneUrl = (snap.data()?['order_ringtone_url'] ?? '').toString();
    } catch (e) {
      log("order_ringtone_url re-read failed, using the start-up value: $e");
    }
    return Constant.orderRingtoneUrl;
  }

  static Future<void> getSettings() async {
    try {
      final restaurantSnap = await fireStore.collection(CollectionName.settings).doc('vendor').get();

      if (restaurantSnap.exists && restaurantSnap.data() != null) {
        Constant.isSubscriptionModelApplied = restaurantSnap.data()?['subscription_model'] ?? false;
      } else {
        Constant.isSubscriptionModelApplied = false;
      }

      fireStore.collection(CollectionName.settings).doc("DriverNearBy").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.distanceType = event.data()?["distanceType"] ?? "km";
          Constant.isEnableOTPTripStart = event.data()?["enableOTPTripStart"] ?? false;
          Constant.isEnableOTPTripStartForRental = event.data()?["enableOTPTripStartForRental"] ?? false;
        }
      });

      final globalSettingsSnap = await fireStore.collection(CollectionName.settings).doc("globalSettings").get();

      if (globalSettingsSnap.exists && globalSettingsSnap.data() != null) {
        Constant.isEnableAdsFeature = globalSettingsSnap.data()?['isEnableAdsFeature'] ?? false;
        Constant.isSelfDeliveryFeature = globalSettingsSnap.data()?['isSelfDelivery'] ?? false;
        Constant.defaultCountryCode = globalSettingsSnap.data()?['defaultCountryCode'] ?? '';
        Constant.orderRingtoneUrl = (globalSettingsSnap.data()?['order_ringtone_url'] ?? '').toString();
        Constant.taxScope = globalSettingsSnap.data()?['taxScope'] ?? "";
        String? colorStr = globalSettingsSnap.data()?['app_customer_color'];
        if (colorStr != null && colorStr.isNotEmpty) {
          AppThemeData.primary300 = Color(int.parse(colorStr.replaceFirst("#", "0xff")));
        }
      }

      fireStore.collection(CollectionName.settings).doc("googleMapKey").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.mapAPIKey = event.data()?["key"] ?? "";
        }
      });
      fireStore.collection(CollectionName.settings).doc("placeHolderImage").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.placeHolderImage = event.data()?["image"] ?? "";
        }
      });

      fireStore.collection(CollectionName.settings).doc("notification_setting").snapshots().listen((event) {
        if (event.exists) {
          // Both fields are non-nullable Strings and these values are
          // `dynamic`: a notification_setting document missing either one threw
          // a TypeError inside this listener, so NEITHER was applied and every
          // push the app tried to send afterwards went to project "" with no
          // access token — one reason chat notifications never arrived (#3).
          // A field that is absent now leaves the last known value alone.
          final String? senderId = event.data()?["senderId"]?.toString();
          final String? serviceJson = event.data()?["serviceJson"]?.toString();
          if (senderId != null && senderId.isNotEmpty) Constant.senderId = senderId;
          if (serviceJson != null && serviceJson.isNotEmpty) Constant.jsonNotificationFileURL = serviceJson;
          // The server-push switch (SERVER-PUSH-CONTRACT): always assigned, so
          // clearing the field moves a running app back to the legacy path.
          Constant.serverPushUrl = (event.data()?["serverPushUrl"] ?? '').toString().trim();
        }
      });

      final cashbackSnap = await fireStore.collection(CollectionName.settings).doc("cashbackOffer").get();

      if (cashbackSnap.exists && cashbackSnap.data() != null) {
        Constant.isCashbackActive = cashbackSnap.data()?["isEnable"] ?? false;
      } else {
        Constant.isCashbackActive = false;
      }

      final driverNearBySnap = await fireStore.collection(CollectionName.settings).doc("DriverNearBy").get();

      if (driverNearBySnap.exists && driverNearBySnap.data() != null) {
        Constant.selectedMapType = driverNearBySnap.data()?["selectedMapType"] ?? "";
        Constant.mapType = driverNearBySnap.data()?["mapType"] ?? "";
      }

      fireStore.collection(CollectionName.settings).doc("privacyPolicy").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.privacyPolicy = event.data()?["privacy_policy"] ?? "";
        }
      });

      fireStore.collection(CollectionName.settings).doc("termsAndConditions").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.termsAndConditions = event.data()?["termsAndConditions"] ?? "";
        }
      });

      fireStore.collection(CollectionName.settings).doc("walletSettings").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.walletSetting = event.data()?["isEnabled"] ?? false;
        }
      });

      fireStore.collection(CollectionName.settings).doc("Version").snapshots().listen((event) {
        if (event.exists && event.data() != null) {
          Constant.googlePlayLink = event.data()?["googlePlayLink"] ?? '';
          Constant.appStoreLink = event.data()?["appStoreLink"] ?? '';
          Constant.appVersion = event.data()?["app_version"] ?? '';
          Constant.websiteUrl = event.data()?["websiteUrl"] ?? '';
        }
      });

      final storySnap = await fireStore.collection(CollectionName.settings).doc('story').get();

      if (storySnap.exists && storySnap.data() != null) {
        Constant.storyEnable = storySnap.data()?['isEnabled'] ?? false;
      } else {
        Constant.storyEnable = false;
      }

      final emailSnap = await fireStore.collection(CollectionName.settings).doc("emailSetting").get();

      if (emailSnap.exists && emailSnap.data() != null) {
        Constant.mailSettings = MailSettings.fromJson(emailSnap.data()!);
      }

      final specialDiscountSnap = await fireStore.collection(CollectionName.settings).doc("specialDiscountOffer").get();

      if (specialDiscountSnap.exists && specialDiscountSnap.data() != null) {
        Constant.specialDiscountOffer = specialDiscountSnap.data()?["isEnable"] ?? false;
      } else {
        Constant.specialDiscountOffer = false;
      }
    } catch (e) {
      log("getSettings() Error: $e");
    }
  }

  static Future<List<GiftCardsOrderModel>> getGiftHistory() async {
    List<GiftCardsOrderModel> giftCardsOrderList = [];
    await fireStore.collection(CollectionName.giftPurchases).where("userid", isEqualTo: FireStoreUtils.getCurrentUid()).get().then((value) {
      for (var element in value.docs) {
        GiftCardsOrderModel giftCardsOrderModel = GiftCardsOrderModel.fromJson(element.data());
        giftCardsOrderList.add(giftCardsOrderModel);
      }
    });
    return giftCardsOrderList;
  }

  static Future<List<OrderModel>> getAllOrder() async {
    List<OrderModel> list = [];

    print("Current UID: ${getCurrentUid()}");
    print("Section ID: ${Constant.sectionConstantModel?.id}");

    try {
      final snapshot =
          await fireStore
              .collection(CollectionName.vendorOrders)
              .where("authorID", isEqualTo: getCurrentUid())
              .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
              .orderBy("createdAt", descending: true)
              .get();

      print("Snapshot size: ${snapshot.docs.length}");

      for (var element in snapshot.docs) {
        OrderModel order = OrderModel.fromJson(element.data());
        print("Order fetched: ${order.id}"); // or other fields
        list.add(order);
      }

      print("Total Orders added to list: ${list.length}");
    } catch (e) {
      print("Error fetching orders: $e");
    }

    return list;
  }

  static Future<RatingModel?> getOrderReviewsByID(String orderId, String productID) async {
    RatingModel? ratingModel;

    await fireStore
        .collection(CollectionName.itemsReview)
        .where('orderid', isEqualTo: orderId)
        .where('productId', isEqualTo: productID)
        .get()
        .then((value) {
          if (value.docs.isNotEmpty) {
            ratingModel = RatingModel.fromJson(value.docs.first.data());
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return ratingModel;
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

  // static Future<bool?> setRatingModel(RatingModel ratingModel) async {
  //   bool isAdded = false;
  //   await fireStore
  //       .collection(CollectionName.itemsReview)
  //       .doc(ratingModel.id)
  //       .set(ratingModel.toJson())
  //       .then((value) {
  //         isAdded = true;
  //       })
  //       .catchError((error) {
  //         log("Failed to update user: $error");
  //         isAdded = false;
  //       });
  //   return isAdded;
  // }

  /// Adds a customer's rating to a store's review totals: only `reviewsCount`
  /// and `reviewsSum`, as increments. It used to write back the whole
  /// [VendorModel] loaded when the rating screen opened, which restored a
  /// stale `fcmToken`, `reststatus`, `workingHours` or
  /// `subscriptionTotalOrders` changed meanwhile by the store app.
  static Future<bool> addVendorReviewTotals(String? vendorId, {required num countDelta, required num sumDelta}) {
    return _addReviewTotals(CollectionName.vendors, vendorId, countDelta: countDelta, sumDelta: sumDelta);
  }

  /// Adds a customer's rating to a driver's review totals
  /// (`users/{driverId}.reviewsCount` / `reviewsSum`): those two fields only,
  /// re-read and written in one transaction ([UserReviewTotals.applied]).
  /// The cab, parcel and rental reviews used to write back the driver's whole
  /// document as read when the review was submitted, which put back stale
  /// `orderRequestData` / `inProgressOrderID` arrays (an offer or an accepted
  /// job the dispatch or the driver added meanwhile disappeared) and an old
  /// `location`. Not `FieldValue.increment`: user totals are stored as
  /// strings, which an increment would replace by the bare delta.
  static Future<bool> addDriverReviewTotals(String? driverId, {required num countDelta, required num sumDelta}) async {
    final String docId = (driverId ?? '').trim();
    if (docId.isEmpty) return false;
    if (countDelta == 0 && sumDelta == 0) return true;
    final ref = fireStore.collection(CollectionName.users).doc(docId);
    try {
      return await fireStore.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        tx.update(ref, UserReviewTotals.applied(snap.data(), countDelta: countDelta, sumDelta: sumDelta));
        return true;
      });
    } catch (e) {
      log('Failed to update the review totals of users/$docId: $e');
      return false;
    }
  }

  static Future<bool> _addReviewTotals(String collection, String? id, {required num countDelta, required num sumDelta}) async {
    final String docId = (id ?? '').trim();
    if (docId.isEmpty) return false;
    if (countDelta == 0 && sumDelta == 0) return true;
    try {
      await fireStore.collection(collection).doc(docId).update({
        'reviewsCount': FieldValue.increment(countDelta),
        'reviewsSum': FieldValue.increment(sumDelta),
      });
      return true;
    } catch (e) {
      log('Failed to update the review totals of $collection/$docId: $e');
      return false;
    }
  }

  static Future<bool?> setProduct(ProductModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.vendorProducts)
        .doc(orderModel.id)
        .setKnownFields(orderModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  static Future<ReferralModel?> getReferralUserBy() async {
    ReferralModel? referralModel;
    try {
      await fireStore.collection(CollectionName.referral).doc(getCurrentUid()).get().then((value) {
        referralModel = ReferralModel.fromJson(value.data()!);
      });
    } catch (e, s) {
      print('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return referralModel;
  }

  /// Published products of a store. With [filterByOrderType] (default) only
  /// the products the current Delivery / TakeAway order type allows, by the
  /// product's effective `fulfilment` (the Store app's rule: explicit
  /// `fulfilment`, else legacy `takeawayOption`: true = TakeAway only).
  static Future<List<ProductModel>> getProductByVendorId(String vendorId, {bool filterByOrderType = true}) async {
    String selectedFoodType = Preferences.getString(Preferences.foodDeliveryType, defaultValue: "Delivery");
    List<ProductModel> list = [];
    log("GetProductByVendorId :: $selectedFoodType");
    await fireStore
        .collection(CollectionName.vendorProducts)
        .where("vendorID", isEqualTo: vendorId)
        .where('publish', isEqualTo: true)
        .orderBy("createdAt", descending: false)
        .get()
        .then((value) {
          for (var element in value.docs) {
            ProductModel productModel = ProductModel.fromJson(element.data());
            // Wholesale-only products are not shown to a customer without an
            // approved business account (WEB spec §19) - the store page and
            // search both read this list.
            if (productModel.hiddenForCustomer) continue;
            if (!filterByOrderType || productModel.allowsFoodType(selectedFoodType)) list.add(productModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });

    return list;
  }

  /// settings/DeliveryCharge for [regionId] (the store's region):
  /// `regions[regionId]` when present, else the global figures (spec 18.6).
  static Future<DeliveryCharge?> getDeliveryCharge({String? regionId}) async {
    DeliveryCharge? deliveryCharge;
    try {
      await fireStore.collection(CollectionName.settings).doc("DeliveryCharge").get().then((value) {
        if (value.exists) {
          deliveryCharge = RegionService.deliveryChargeFrom(value.data(), regionId);
        }
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return deliveryCharge;
  }

  static Future<List<CouponModel>> getAllVendorPublicCoupons(String vendorId) async {
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
    print("coupon :::::::::::::::::${coupon.length}");
    return coupon;
  }

  static Future<List<CouponModel>> getAllVendorCoupons(String vendorId) async {
    List<CouponModel> coupon = [];

    await fireStore
        .collection(CollectionName.coupons)
        .where("vendorID", isEqualTo: vendorId)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
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
    print("coupon :::::::::::::::::${coupon.length}");
    return coupon;
  }

  static Future<List<CashbackModel>> getAllCashbak() async {
    List<CashbackModel> cashbackList = [];
    await fireStore
        .collection(CollectionName.cashback)
        .get()
        .then((value) {
          cashbackList =
              value.docs.map((doc) {
                return CashbackModel.fromJson(doc.data());
              }).toList();
        })
        .catchError((error) {
          log(error.toString());
        });

    return cashbackList;
  }

  static Future<List<CashbackRedeemModel>> getRedeemedCashbacks(String cashbackId) async {
    List<CashbackRedeemModel> redeemedDocs = [];

    try {
      await fireStore.collection(CollectionName.cashbackRedeem).where('userId', isEqualTo: FireStoreUtils.getCurrentUid()).where('cashbackId', isEqualTo: cashbackId).get().then((value) {
        redeemedDocs =
            value.docs.map((doc) {
              return CashbackRedeemModel.fromJson(doc.data());
            }).toList();
      });
    } catch (error, stackTrace) {
      log('Error fetching redeemed cashback data: $error', stackTrace: stackTrace);
    }

    return redeemedDocs;
  }

  static Future<bool?> setCashbackRedeemModel(CashbackRedeemModel cashbackRedeemModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.cashbackRedeem)
        .doc(cashbackRedeemModel.id)
        .set(cashbackRedeemModel.toJson())
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    return isAdded;
  }

  /// [extraFields] are written in the same call, on top of the model (e.g.
  /// `scheduledNotificationSent: false` for an order placed for later,
  /// `ScheduledOrderNotice.orderFields`).
  static Future<bool?> setOrder(OrderModel orderModel, {Map<String, dynamic> extraFields = const {}}) async {
    bool isAdded = false;
    // vendor_orders.regionId = the store's region (spec 18.12).
    orderModel.regionId ??= RegionService.regionOfVendor(orderModel.vendor) ?? await RegionService.resolveVendorRegion(orderModel.vendorID);
    // Known fields only, so a save never clears what the Driver / Store app
    // wrote meanwhile (e.g. the proof-of-delivery `pod`, POD-OTP-CONTRACT).
    await fireStore
        .collection(CollectionName.vendorOrders)
        .doc(orderModel.id)
        .setKnownFields({...orderModel.toJson(), ...extraFields})
        .then((value) {
          isAdded = true;
        })
        .catchError((error) {
          log("Failed to update user: $error");
          isAdded = false;
        });
    if (isAdded) await addCustomerRegion(orderModel.regionId);
    return isAdded;
  }

  /// Adds [regionId] to the customer's `users.regionIds` (every region the
  /// customer has ordered in). Skipped when the region is unknown.
  static Future<void> addCustomerRegion(String? regionId) async {
    if (regionId == null || regionId.isEmpty || auth.FirebaseAuth.instance.currentUser == null) return;
    try {
      await fireStore.collection(CollectionName.users).doc(getCurrentUid()).update({
        'regionIds': FieldValue.arrayUnion([regionId]),
      });
      final user = Constant.userModel;
      if (user != null && user.id == getCurrentUid()) {
        user.regionIds = {...?user.regionIds, regionId}.toList();
      }
    } catch (e) {
      log("addCustomerRegion failed: $e");
    }
  }

  static Future<List<CouponModel>> getOfferByVendorId(String vendorId) async {
    List<CouponModel> couponList = [];
    await fireStore
        .collection(CollectionName.coupons)
        .where("vendorID", isEqualTo: vendorId)
        .where("isEnabled", isEqualTo: true)
        .where("isPublic", isEqualTo: true)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel favouriteModel = CouponModel.fromJson(element.data());
            couponList.add(favouriteModel);
          }
        });
    return couponList;
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

  static Future<VendorCategoryModel?> getVendorCategoryById(String categoryId) async {
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

  static Future<List<RatingModel>> getVendorReviews(String vendorId) async {
    List<RatingModel> ratingList = [];
    await fireStore.collection(CollectionName.itemsReview).where('VendorId', isEqualTo: vendorId).get().then((value) {
      for (var element in value.docs) {
        RatingModel giftCardsOrderModel = RatingModel.fromJson(element.data());
        ratingList.add(giftCardsOrderModel);
      }
    });
    return ratingList;
  }

  /// Loads every gateway's settings into Preferences (unchanged, shared by
  /// every checkout) and remembers each gateway's `regionIds` (spec 18.7).
  /// Checkouts read them back through `RegionService.gatewaySettings`, which
  /// disables a gateway not offered in the checkout's region.
  static Future getPaymentSettingsData() async {
    await fireStore.collection(CollectionName.settings).doc("payFastSettings").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.payFastSettings, value.data()!['regionIds']);
        PayFastModel payFastModel = PayFastModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.payFastSettings, jsonEncode(payFastModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("MercadoPago").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.mercadoPago, value.data()!['regionIds']);
        MercadoPagoModel mercadoPagoModel = MercadoPagoModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.mercadoPago, jsonEncode(mercadoPagoModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("paypalSettings").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.paypalSettings, value.data()!['regionIds']);
        PayPalModel payPalModel = PayPalModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.paypalSettings, jsonEncode(payPalModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("stripeSettings").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.stripeSettings, value.data()!['regionIds']);
        StripeModel stripeModel = StripeModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.stripeSettings, jsonEncode(stripeModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("flutterWave").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.flutterWave, value.data()!['regionIds']);
        FlutterWaveModel flutterWaveModel = FlutterWaveModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.flutterWave, jsonEncode(flutterWaveModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("payStack").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.payStack, value.data()!['regionIds']);
        PayStackModel payStackModel = PayStackModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.payStack, jsonEncode(payStackModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("PaytmSettings").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.paytmSettings, value.data()!['regionIds']);
        PaytmModel paytmModel = PaytmModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.paytmSettings, jsonEncode(paytmModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("walletSettings").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.walletSettings, value.data()!['regionIds']);
        WalletSettingModel walletSettingModel = WalletSettingModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.walletSettings, jsonEncode(walletSettingModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("razorpaySettings").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.razorpaySettings, value.data()!['regionIds']);
        RazorPayModel razorPayModel = RazorPayModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.razorpaySettings, jsonEncode(razorPayModel.toJson()));
      }
    });
    await fireStore.collection(CollectionName.settings).doc("CODSettings").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.codSettings, value.data()!['regionIds']);
        CodSettingModel codSettingModel = CodSettingModel.fromJson(value.data()!);
        await Preferences.setString(Preferences.codSettings, jsonEncode(codSettingModel.toJson()));
      }
    });

    await fireStore.collection(CollectionName.settings).doc("midtrans_settings").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.midTransSettings, value.data()!['regionIds']);
        MidTrans midTrans = MidTrans.fromJson(value.data()!);
        await Preferences.setString(Preferences.midTransSettings, jsonEncode(midTrans.toJson()));
      }
    });

    await fireStore.collection(CollectionName.settings).doc("orange_money_settings").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.orangeMoneySettings, value.data()!['regionIds']);
        OrangeMoney orangeMoney = OrangeMoney.fromJson(value.data()!);
        await Preferences.setString(Preferences.orangeMoneySettings, jsonEncode(orangeMoney.toJson()));
      }
    });

    await fireStore.collection(CollectionName.settings).doc("xendit_settings").get().then((value) async {
      if (value.exists) {
        RegionService.rememberGatewayRegions(Preferences.xenditSettings, value.data()!['regionIds']);
        Xendit xendit = Xendit.fromJson(value.data()!);
        await Preferences.setString(Preferences.xenditSettings, jsonEncode(xendit.toJson()));
      }
    });
  }

  /// Adds [amount] (negative to debit) to a user's `wallet_amount` in a
  /// transaction, so two concurrent credits/debits can't overwrite each other.
  static Future<bool?> updateUserWallet({required String amount, required String userId}) async {
    final num delta = num.tryParse(amount) ?? 0;
    try {
      final num? total = await fireStore.runTransaction<num?>((transaction) async {
        final ref = fireStore.collection(CollectionName.users).doc(userId);
        final snap = await transaction.get(ref);
        if (!snap.exists) return null;
        final num next = (num.tryParse(snap.data()?['wallet_amount']?.toString() ?? '') ?? 0) + delta;
        transaction.update(ref, {'wallet_amount': next});
        return next;
      });
      if (total != null && userId == getCurrentUid() && Constant.userModel != null) {
        Constant.userModel!.walletAmount = total;
      }
      return total != null;
    } catch (error) {
      log("Failed to update wallet: $error");
      return false;
    }
  }

  /// Debits [amount] (positive) from [userId]'s wallet in ONE transaction that
  /// re-reads `wallet_amount` and refuses to go below zero. When
  /// [walletTransaction] is given, its `wallet` row is written in the same
  /// transaction, so the row exists only if the debit happened. Returns true
  /// only when the debit was committed.
  static Future<bool> debitWalletIfSufficient({required num amount, required String userId, WalletTransactionModel? walletTransaction}) async {
    if (amount <= 0) return false;
    try {
      final num? total = await fireStore.runTransaction<num?>((transaction) async {
        final ref = fireStore.collection(CollectionName.users).doc(userId);
        final snap = await transaction.get(ref);
        if (!snap.exists) return null;
        final num balance = num.tryParse(snap.data()?['wallet_amount']?.toString() ?? '') ?? 0;
        if (balance < amount) return null;
        final num next = balance - amount;
        transaction.update(ref, {'wallet_amount': next});
        if (walletTransaction != null) {
          transaction.set(fireStore.collection(CollectionName.wallet).doc(walletTransaction.id), walletTransaction.toJson());
        }
        return next;
      });
      if (total != null && userId == getCurrentUid() && Constant.userModel != null) {
        Constant.userModel!.walletAmount = total;
      }
      return total != null;
    } catch (error) {
      log("Failed to debit wallet: $error");
      return false;
    }
  }

  /// Stores saved with "" for `latitude` (report 02#2: three live stores, ""
  /// for both coordinates) that pass the list's own filters - see
  /// [VendorModel.matchesListFilters]. They have no geohash, so the radius
  /// queries below can never return them; [VendorModel.withUnplacedLast] adds
  /// them after the nearby stores. One single-field equality query (no
  /// composite index), a handful of documents platform-wide; any failure
  /// gives an empty list, never a broken store list.
  static Future<List<VendorModel>> vendorsWithoutPosition({String? sectionId, String? zoneId, String? categoryId, bool dineInOnly = false}) async {
    try {
      final snapshot = await fireStore.collection(CollectionName.vendors).where('latitude', isEqualTo: '').get();
      return [
        for (final doc in snapshot.docs)
          if (VendorModel.matchesListFilters(doc.data(), sectionId: sectionId, zoneId: zoneId, categoryId: categoryId, dineInOnly: dineInOnly)) VendorModel.fromJson(doc.data()),
      ].where((v) => !v.hasPosition).toList();
    } catch (e) {
      log("vendorsWithoutPosition failed: $e");
      return [];
    }
  }

  static StreamController<List<VendorModel>>? getNearestVendorByCategoryController;

  static Stream<List<VendorModel>> getAllNearestRestaurantByCategoryId({bool? isDining, required String categoryId, bool ecommarce = false}) async* {
    try {
      getNearestVendorByCategoryController = StreamController<List<VendorModel>>.broadcast();
      Query<Map<String, dynamic>> query;
      if (ecommarce == true) {
        query =
            isDining == true
                ? fireStore.collection(CollectionName.vendors).where('categoryID', arrayContains: categoryId).where("enabledDiveInFuture", isEqualTo: true)
                : fireStore.collection(CollectionName.vendors).where('categoryID', arrayContains: categoryId);
      } else {
        query =
            isDining == true
                ? fireStore
                    .collection(CollectionName.vendors)
                    .where('categoryID', arrayContains: categoryId)
                    .where('zoneId', isEqualTo: Constant.selectedZone!.id.toString())
                    .where("enabledDiveInFuture", isEqualTo: true)
                : fireStore.collection(CollectionName.vendors).where('categoryID', arrayContains: categoryId).where('zoneId', isEqualTo: Constant.selectedZone!.id.toString());
      }
      GeoFirePoint center = Geoflutterfire().point(latitude: Constant.selectedLocation.location!.latitude ?? 0.0, longitude: Constant.selectedLocation.location!.longitude ?? 0.0);
      String field = 'g';

      Stream<List<DocumentSnapshot>> stream = Geoflutterfire()
          .collection(collectionRef: query)
          .within(center: center, radius: double.parse(Constant.sectionConstantModel!.nearByRadius.toString()), field: field, strictMode: true);

      // Report 02#2: stores without a position, listed after the nearby ones.
      final Future<List<VendorModel>> unplaced = vendorsWithoutPosition(
        zoneId: ecommarce == true ? null : Constant.selectedZone!.id.toString(),
        categoryId: categoryId,
        dineInOnly: isDining == true,
      );

      stream.listen((List<DocumentSnapshot> documentList) async {
        final List<VendorModel> nearby = [for (final document in documentList) VendorModel.fromJson(document.data() as Map<String, dynamic>)];
        final List<VendorModel> vendorList = [];
        for (final VendorModel vendorModel in VendorModel.withUnplacedLast(nearby, await unplaced)) {
          if ((Constant.isSubscriptionModelApplied == true || vendorModel.adminCommission?.isEnabled == true) && vendorModel.subscriptionPlan != null) {
            if (vendorModel.subscriptionTotalOrders == "-1") {
              vendorList.add(vendorModel);
            } else {
              if ((vendorModel.subscriptionExpiryDate != null && vendorModel.subscriptionExpiryDate!.toDate().isBefore(DateTime.now()) == false) || vendorModel.subscriptionPlan?.expiryDay == '-1') {
                if (vendorModel.subscriptionTotalOrders != '0') {
                  vendorList.add(vendorModel);
                }
              }
            }
          } else {
            vendorList.add(vendorModel);
          }
        }
        getNearestVendorByCategoryController!.sink.add(vendorList);
      });

      yield* getNearestVendorByCategoryController!.stream;
    } catch (e) {
      print(e);
    }
  }

  static StreamController<List<VendorModel>>? getNearestVendorController;

  static Stream<List<VendorModel>> getAllNearestRestaurant({bool? isDining, bool ecommarce = false}) async* {
    try {
      getNearestVendorController = StreamController<List<VendorModel>>.broadcast();
      Query<Map<String, dynamic>> query;
      if (ecommarce == true) {
        query =
            isDining == true
                ? fireStore.collection(CollectionName.vendors).where('section_id', isEqualTo: Constant.sectionConstantModel!.id).where("enabledDiveInFuture", isEqualTo: true)
                : fireStore.collection(CollectionName.vendors).where('section_id', isEqualTo: Constant.sectionConstantModel!.id);
      } else {
        query =
            isDining == true
                ? fireStore
                    .collection(CollectionName.vendors)
                    .where('section_id', isEqualTo: Constant.sectionConstantModel!.id)
                    .where('zoneId', isEqualTo: Constant.selectedZone?.id.toString())
                    .where("enabledDiveInFuture", isEqualTo: true)
                : fireStore.collection(CollectionName.vendors).where('section_id', isEqualTo: Constant.sectionConstantModel!.id).where('zoneId', isEqualTo: Constant.selectedZone?.id.toString());
      }

      GeoFirePoint center = Geoflutterfire().point(latitude: Constant.selectedLocation.location!.latitude ?? 0.0, longitude: Constant.selectedLocation.location!.longitude ?? 0.0);
      String field = 'g';

      Stream<List<DocumentSnapshot>> stream = Geoflutterfire()
          .collection(collectionRef: query)
          .within(center: center, radius: double.parse(Constant.sectionConstantModel!.nearByRadius.toString()), field: field, strictMode: true);

      // Report 02#2: stores without a position, listed after the nearby ones.
      final Future<List<VendorModel>> unplaced = vendorsWithoutPosition(
        sectionId: Constant.sectionConstantModel!.id,
        zoneId: ecommarce == true ? null : Constant.selectedZone?.id.toString() ?? '',
        dineInOnly: isDining == true,
      );

      stream.listen((List<DocumentSnapshot> documentList) async {
        final List<VendorModel> nearby = [for (final document in documentList) VendorModel.fromJson(document.data() as Map<String, dynamic>)];
        final List<VendorModel> vendorList = [];
        for (final VendorModel vendorModel in VendorModel.withUnplacedLast(nearby, await unplaced)) {
          if ((Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel!.adminCommision?.isEnabled == true) && vendorModel.subscriptionPlan != null) {
            if (vendorModel.subscriptionTotalOrders == "-1") {
              vendorList.add(vendorModel);
            } else {
              if ((vendorModel.subscriptionExpiryDate != null && vendorModel.subscriptionExpiryDate!.toDate().isBefore(DateTime.now()) == false) || vendorModel.subscriptionPlan?.expiryDay == "-1") {
                if (vendorModel.subscriptionTotalOrders != '0') {
                  vendorList.add(vendorModel);
                }
              }
            }
          } else {
            vendorList.add(vendorModel);
          }
        }
        getNearestVendorController!.sink.add(vendorList);
      });

      yield* getNearestVendorController!.stream;
    } catch (e) {
      print(e);
    }
  }

  static Future<List<VendorCategoryModel>> getHomePageShowCategory() async {
    List<VendorCategoryModel> vendorCategoryList = [];
    await fireStore
        .collection(CollectionName.vendorCategories)
        .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
        .where("show_in_homepage", isEqualTo: true)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            VendorCategoryModel vendorCategoryModel = VendorCategoryModel.fromJson(element.data());
            vendorCategoryList.add(vendorCategoryModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return vendorCategoryList;
  }

  static Future<List<WalletTransactionModel>?> getWalletTransaction() async {
    List<WalletTransactionModel> walletTransactionList = [];
    log("FireStoreUtils.getCurrentUid() :: ${FireStoreUtils.getCurrentUid()}");
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

  static Future<List<ProductModel>> getProductListByCategoryId(String categoryId) async {
    List<ProductModel> productList = [];
    List<ProductModel> categorybyProductList = [];
    QuerySnapshot<Map<String, dynamic>> currencyQuery = await fireStore.collection(CollectionName.vendorProducts).where('categoryID', isEqualTo: categoryId).where('publish', isEqualTo: true).get();
    await Future.forEach(currencyQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        final ProductModel product = ProductModel.fromJson(document.data());
        // Wholesale-only products are not shown to a customer without an
        // approved business account (WEB spec §19).
        if (!product.hiddenForCustomer) productList.add(product);
      } catch (e) {
        print('FireStoreUtils.getCurrencys Parse error $e');
      }
    });

    List<VendorModel?> vendorList = await getAllStoresFuture();
    List<ProductModel> allProduct = <ProductModel>[];

    for (var vendor in vendorList) {
      await getAllProducts(vendor!.id.toString()).then((value) {
        if (Constant.isSubscriptionModelApplied == true || vendor.adminCommission?.isEnabled == true) {
          if (vendor.subscriptionPlan != null && Constant.isExpire(vendor) == false) {
            if (vendor.subscriptionPlan?.itemLimit == '-1') {
              allProduct.addAll(value);
            } else {
              int selectedProduct = value.length < int.parse(vendor.subscriptionPlan?.itemLimit ?? '0') ? (value.isEmpty ? 0 : (value.length)) : int.parse(vendor.subscriptionPlan?.itemLimit ?? '0');
              allProduct.addAll(value.sublist(0, selectedProduct));
            }
          }
        } else {
          allProduct.addAll(value);
        }
      });
    }

    for (var element in productList) {
      bool productIsInList = allProduct.any((product) => product.id == element.id);
      if (productIsInList) {
        categorybyProductList.add(element);
      }
    }

    return categorybyProductList;
  }

  static Future<List<ProductModel>> getAllProducts(String vendorId) async {
    List<ProductModel> products = [];

    QuerySnapshot<Map<String, dynamic>> productsQuery =
        await fireStore
            .collection(CollectionName.vendorProducts)
            .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
            .where('vendorID', isEqualTo: vendorId)
            .where('publish', isEqualTo: true)
            .orderBy('createdAt', descending: false)
            .get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        final ProductModel product = ProductModel.fromJson(document.data());
        // Wholesale-only products are not shown to a customer without an
        // approved business account (WEB spec §19).
        if (!product.hiddenForCustomer) products.add(product);
      } catch (e) {
        print('product**-FireStoreUtils.getAllProducts Parse error $e');
      }
    });
    return products;
  }

  static Future<List<VendorModel>> getAllStoresFuture({String? categoryId, bool ecommarce = false}) async {
    List<VendorModel> vendors = [];

    try {
      Query<Map<String, dynamic>> collectionReference;
      if (ecommarce == true) {
        collectionReference =
            categoryId == null
                ? fireStore.collection(CollectionName.vendors).where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
                : fireStore.collection(CollectionName.vendors).where("section_id", isEqualTo: Constant.sectionConstantModel!.id).where("categoryID", isEqualTo: categoryId);
      } else {
        collectionReference =
            categoryId == null
                ? fireStore.collection(CollectionName.vendors).where("section_id", isEqualTo: Constant.sectionConstantModel!.id).where("zoneId", isEqualTo: Constant.selectedZone!.id.toString())
                : fireStore
                    .collection(CollectionName.vendors)
                    .where("section_id", isEqualTo: Constant.sectionConstantModel!.id)
                    .where("categoryID", isEqualTo: categoryId)
                    .where("zoneId", isEqualTo: Constant.selectedZone!.id.toString());
      }
      GeoFirePoint center = Geoflutterfire().point(latitude: Constant.selectedLocation.location!.latitude ?? 0.0, longitude: Constant.selectedLocation.location!.longitude ?? 0.0);

      String field = 'g';

      List<DocumentSnapshot> documentList =
          await Geoflutterfire()
              .collection(collectionRef: collectionReference)
              .within(center: center, radius: double.parse(Constant.sectionConstantModel!.nearByRadius.toString()), field: field, strictMode: true)
              .first; // Fetch the data once as a Future

      // Report 02#2: stores without a position, listed after the nearby ones.
      final List<VendorModel> listed = VendorModel.withUnplacedLast(
        [for (final document in documentList) VendorModel.fromJson(document.data() as Map<String, dynamic>)],
        await vendorsWithoutPosition(
          sectionId: Constant.sectionConstantModel!.id,
          zoneId: ecommarce == true ? null : Constant.selectedZone!.id.toString(),
          categoryId: categoryId,
        ),
      );

      if (listed.isNotEmpty) {
        for (final VendorModel vendorModel in listed) {
          if (Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) {
            if (vendorModel.subscriptionPlan != null && Constant.isExpire(vendorModel) == false) {
              if (vendorModel.subscriptionTotalOrders == "-1") {
                vendors.add(vendorModel);
              } else {
                if ((vendorModel.subscriptionExpiryDate != null && vendorModel.subscriptionExpiryDate!.toDate().isBefore(DateTime.now()) == false) || vendorModel.subscriptionPlan?.expiryDay == "-1") {
                  if (vendorModel.subscriptionTotalOrders != '0') {
                    vendors.add(vendorModel);
                  }
                }
              }
            }
          } else {
            vendors.add(vendorModel);
          }
        }
      }
    } catch (e) {
      print('Error fetching vendors: $e');
    }

    return vendors;
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

  static Future<List<VendorCategoryModel>> getVendorCategory() async {
    List<VendorCategoryModel> list = [];
    await fireStore
        .collection(CollectionName.vendorCategories)
        .where('section_id', isEqualTo: Constant.sectionConstantModel!.id)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            print("====>${value.docs.length}");
            VendorCategoryModel walletTransactionModel = VendorCategoryModel.fromJson(element.data());
            list.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return list;
  }

  static Future<GiftCardsOrderModel> placeGiftCardOrder(GiftCardsOrderModel giftCardsOrderModel) async {
    print("=====>");
    await fireStore.collection(CollectionName.giftPurchases).doc(giftCardsOrderModel.id).set(giftCardsOrderModel.toJson());
    return giftCardsOrderModel;
  }

  static Future removeFavouriteRestaurant(FavouriteModel favouriteModel) async {
    await fireStore.collection(CollectionName.favoriteVendor).where("store_id", isEqualTo: favouriteModel.restaurantId).get().then((value) {
      value.docs.forEach((element) async {
        await fireStore.collection(CollectionName.favoriteVendor).doc(element.id).delete();
      });
    });
  }

  static Future<void> setFavouriteRestaurant(FavouriteModel favouriteModel) async {
    favouriteModel.sectionId = Constant.sectionConstantModel!.id;
    log("setFavouriteRestaurant :: ${favouriteModel.toJson()}");
    await fireStore.collection(CollectionName.favoriteVendor).add(favouriteModel.toJson());
  }

  static Future<void> removeFavouriteItem(FavouriteItemModel favouriteModel) async {
    try {
      final favoriteCollection = fireStore.collection(CollectionName.favoriteItem);
      final querySnapshot = await favoriteCollection.where("product_id", isEqualTo: favouriteModel.productId).get();
      for (final doc in querySnapshot.docs) {
        await favoriteCollection.doc(doc.id).delete();
      }
    } catch (e) {
      print("Error removing favourite item: $e");
    }
  }

  static Future<void> setFavouriteItem(FavouriteItemModel favouriteModel) async {
    favouriteModel.sectionId = Constant.sectionConstantModel!.id;
    await fireStore.collection(CollectionName.favoriteItem).add(favouriteModel.toJson());
  }

  static Future<Url> uploadChatImageToFireStorage(File image, BuildContext context) async {
    ShowToastDialog.showLoader("Please wait".tr);
    var uniqueID = const Uuid().v4();
    Reference upload = FirebaseStorage.instance.ref().child('images/$uniqueID.png');
    UploadTask uploadTask = upload.putFile(image);
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();
    var metaData = await storageRef.getMetadata();
    ShowToastDialog.closeLoader();
    return Url(mime: metaData.contentType ?? 'image', url: downloadUrl.toString());
  }

  static Future<List<CouponModel>> getHomeCoupon() async {
    List<CouponModel> list = [];
    await fireStore
        .collection(CollectionName.coupons)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .where("isPublic", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel walletTransactionModel = CouponModel.fromJson(element.data());
            list.add(walletTransactionModel);
          }
        })
        .catchError((error) {
          log(error.toString());
        });
    return list;
  }

  static Future<List<BannerModel>> getHomeTopBanner() async {
    List<BannerModel> bannerList = [];
    await fireStore
        .collection(CollectionName.bannerItems)
        .where("is_publish", isEqualTo: true)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where("position", isEqualTo: "top")
        .orderBy("set_order", descending: false)
        .get()
        .then((value) {
          for (var element in value.docs) {
            BannerModel bannerHome = BannerModel.fromJson(element.data());
            bannerList.add(bannerHome);
          }
        });
    return bannerList;
  }

  static Future<List<StoryModel>> getStory() async {
    List<StoryModel> storyList = [];
    await fireStore.collection(CollectionName.story).where('sectionID', isEqualTo: Constant.sectionConstantModel!.id).get().then((value) {
      print("Number of Stories Fetched: ${value.docs.length}");
      for (var element in value.docs) {
        StoryModel walletTransactionModel = StoryModel.fromJson(element.data());
        storyList.add(walletTransactionModel);
      }
    });
    return storyList;
  }

  static Future<GiftCardsOrderModel?> checkRedeemCode(String giftCode) async {
    GiftCardsOrderModel? giftCardsOrderModel;
    await fireStore.collection(CollectionName.giftPurchases).where("giftCode", isEqualTo: giftCode).get().then((value) {
      if (value.docs.isNotEmpty) {
        giftCardsOrderModel = GiftCardsOrderModel.fromJson(value.docs.first.data());
      }
    });
    return giftCardsOrderModel;
  }

  static Future<void> sendTopUpMail({required String amount, required String paymentMethod, required String tractionId}) async {
    EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.walletTopup);

    String newString = emailTemplateModel!.message.toString();
    newString = newString.replaceAll("{username}", Constant.userModel!.firstName.toString() + Constant.userModel!.lastName.toString());
    newString = newString.replaceAll("{date}", DateFormat('yyyy-MM-dd').format(Timestamp.now().toDate()));
    newString = newString.replaceAll("{amount}", Constant.amountShow(amount: amount, currency: RegionService.customerCurrency));
    newString = newString.replaceAll("{paymentmethod}", paymentMethod.toString());
    newString = newString.replaceAll("{transactionid}", tractionId.toString());
    newString = newString.replaceAll("{newwalletbalance}.", Constant.amountShow(amount: Constant.userModel!.walletAmount.toString(), currency: RegionService.customerCurrency));
    await Constant.sendMail(subject: emailTemplateModel.subject, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
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

      return ChatVideoContainer(videoUrl: Url(url: videoUrl.toString(), mime: metaData.contentType ?? 'video'), thumbnailUrl: thumbnailUrl);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error: ${e.toString()}");
      return null;
    }
  }

  static Future<OrderModel?> getOrderByOrderId(String orderId) async {
    OrderModel? orderModel;
    try {
      await fireStore.collection(CollectionName.vendorOrders).doc(orderId).get().then((value) {
        if (value.data() != null) {
          orderModel = OrderModel.fromJson(value.data()!);
        }
      });
    } catch (e, s) {
      print('FireStoreUtils.firebaseCreateNewUser $e $s');
      return null;
    }
    return orderModel;
  }

  static Future<List<CouponModel>> getCabCoupon() async {
    List<CouponModel> ordersList = [];
    await fireStore
        .collection(CollectionName.promos)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel bannerHome = CouponModel.fromJson(element.data());
            ordersList.add(bannerHome);
          }
        });
    return ordersList;
  }

  static Future<List<CouponModel>> getParcelCoupon() async {
    List<CouponModel> ordersList = [];
    await fireStore
        .collection(CollectionName.parcelCoupons)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel bannerHome = CouponModel.fromJson(element.data());
            ordersList.add(bannerHome);
          }
        });
    return ordersList;
  }

  static Future<List<CouponModel>> getRentalCoupon() async {
    List<CouponModel> ordersList = [];
    await fireStore
        .collection(CollectionName.rentalCoupons)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .where("isEnabled", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel bannerHome = CouponModel.fromJson(element.data());
            ordersList.add(bannerHome);
          }
        });
    return ordersList;
  }

  static Future<bool?> deleteUser() async {
    bool? isDelete;
    try {
      await fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).delete();

      // delete user  from firebase auth
      await deleteAuthUser(FireStoreUtils.getCurrentUid());
      isDelete = true;
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return false;
    }
    return isDelete;
  }

  static Future<bool> deleteAuthUser(String uid) async {
    try {
      final user = auth.FirebaseAuth.instance.currentUser;
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

  static Future<List<ParcelCategory>> getParcelServiceCategory() async {
    List<ParcelCategory> parcelCategoryList = [];
    await fireStore
        .collection(CollectionName.parcelCategory)
        .where('publish', isEqualTo: true)
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('set_order', descending: false)
        .get()
        .then((value) {
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

  static Future<List<ParcelWeightModel>> getParcelWeight() async {
    List<ParcelWeightModel> parcelWeightList = [];
    await fireStore.collection(CollectionName.parcelWeight).get().then((value) {
      for (var element in value.docs) {
        try {
          ParcelWeightModel category = ParcelWeightModel.fromJson(element.data());
          parcelWeightList.add(category);
        } catch (e, stackTrace) {
          print('getParcelWeight parse error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return parcelWeightList;
  }

  static Future<bool> setParcelOrder(ParcelOrderModel orderModel, double totalAmount) async {
    // try {
    //   final firestore = FirebaseFirestore.instance;
    //   final isNew = orderModel.id.isEmpty;
    //
    //   final docRef = firestore.collection(CollectionName.parcelOrders).doc(isNew ? null : orderModel.id);
    //   if (isNew) {
    //     orderModel.id = docRef.id;
    //   }
    //
    //   // Handle wallet payment if needed
    //   if (orderModel.paymentCollectByReceiver == false && orderModel.paymentMethod == "wallet") {
    //     WalletTransactionModel transactionModel = WalletTransactionModel(
    //       id: Constant.getUuid(),
    //       serviceType: 'parcel-service',
    //       amount: totalAmount,
    //       date: Timestamp.now(),
    //       paymentMethod: PaymentGateway.wallet.name,
    //       transactionUser: "customer",
    //       userId: FireStoreUtils.getCurrentUid(),
    //       isTopup: false,
    //       orderId: orderModel.id,
    //       note: "Order Amount debited".tr,
    //       paymentStatus: "success".tr,
    //     );
    //
    //     await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
    //       if (value == true) {
    //         await FireStoreUtils.updateUserWallet(amount: "-$totalAmount", userId: FireStoreUtils.getCurrentUid());
    //       }
    //     });
    //   }
    //
    //   // Set the parcel order in Firestore
    //   await firestore.collection(CollectionName.parcelOrders).doc(orderModel.id).set(orderModel.toJson());
    //
    //   return true;
    // } catch (e) {
    //   debugPrint("Failed to place parcel order: $e");
    //   return false;
    // }
    return true;
  }

  static Future<void> sendParcelBookEmail({required ParcelOrderModel orderModel}) async {
    try {
      EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.newParcelBook);

      String newString = emailTemplateModel!.message.toString();
      newString = newString.replaceAll("{passengername}", "${Constant.userModel!.firstName} ${Constant.userModel!.lastName}");
      newString = newString.replaceAll("{parcelid}", orderModel.id.toString());
      newString = newString.replaceAll("{date}", DateFormat('dd-MM-yyyy').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{sendername}", orderModel.sender!.name.toString());
      newString = newString.replaceAll("{senderphone}", orderModel.sender!.phone.toString());
      newString = newString.replaceAll("{note}", orderModel.note.toString());
      newString = newString.replaceAll("{deliverydate}", DateFormat('dd-MM-yyyy').format(orderModel.receiverPickupDateTime!.toDate()));

      String subjectNewString = emailTemplateModel.subject.toString();
      subjectNewString = subjectNewString.replaceAll("{orderid}", orderModel.id.toString());
      await Constant.sendMail(subject: subjectNewString, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
    } catch (e) {
      log("SIGNUP :: 22 :::::: $e");
    }
  }

  static Future<void> sendCabBookEmail({required CabOrderModel orderModel}) async {
    try {
      final sid = orderModel.sectionId ?? '';
      String vType = '';
      String brand = '';
      String carModel = '';
      String plate = '';
      if (orderModel.driver?.vehicleDetails?.containsKey(sid) == true) {
        final vehicle = orderModel.driver?.vehicleDetails?[sid];
        vType = vehicle['vehicleType']?.toString() ?? '';
        brand = vehicle['carBrand']?.toString() ?? '';
        carModel = vehicle['carModel']?.toString() ?? '';
        plate = vehicle['carPlateNumber']?.toString() ?? '';
      }
      EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.newCabRideBook);
      String newString = emailTemplateModel!.message.toString();
      newString = newString.replaceAll("{passengername}", orderModel.author?.fullName() ?? '');
      newString = newString.replaceAll("{rideid}", orderModel.id.toString());
      newString = newString.replaceAll("{date}", DateFormat('dd-MM-yyyy').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{time}", DateFormat('hh:mm a').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{pickuplocation}", displayAddress(orderModel.sourceLocationName));
      newString = newString.replaceAll("{dropofflocation}", displayAddress(orderModel.destinationLocationName));
      newString = newString.replaceAll("{drivername}", orderModel.driver?.fullName() ?? '');
      newString = newString.replaceAll("{vehicle}", "${vType.toString()} | ${brand.toString()} | ${carModel.toString()}");
      newString = newString.replaceAll("{carnumber}", plate.toString());
      newString = newString.replaceAll("{driverphone}", orderModel.driver?.phoneNumber ?? '');
      String subjectNewString = emailTemplateModel.subject.toString();
      await Constant.sendMail(subject: subjectNewString, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
    } catch (e) {
      log("SIGNUP :: 22 :::::: $e");
    }
  }

  static Future<void> sendCarBookEmail({required RentalOrderModel orderModel}) async {
    try {
      EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.newCarRideBook);
      String newString = emailTemplateModel!.message.toString();
      newString = newString.replaceAll("{username}", orderModel.author?.fullName() ?? '');
      newString = newString.replaceAll("{passengername}", orderModel.author?.fullName() ?? '');
      newString = newString.replaceAll("{date}", DateFormat('dd-MM-yyyy').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{time}", DateFormat('hh:mm a').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{pickuplocation}", displayAddress(orderModel.sourceLocationName));

      String subjectNewString = emailTemplateModel.subject.toString();
      await Constant.sendMail(subject: subjectNewString, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
    } catch (e) {
      log("SIGNUP :: 22 :::::: $e");
    }
  }

  static Stream<List<ParcelOrderModel>> listenParcelOrders() {
    return fireStore
        .collection(CollectionName.parcelOrders)
        .where('authorID', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            log("===>");
            return ParcelOrderModel.fromJson(doc.data());
          }).toList();
        });
  }

  static Future<List<VehicleType>> getVehicleType() async {
    List<VehicleType> vehicleTypeList = [];
    await fireStore.collection(CollectionName.vehicleType).where('sectionId', isEqualTo: Constant.sectionConstantModel!.id).where("isActive", isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        try {
          VehicleType category = VehicleType.fromJson(element.data());
          vehicleTypeList.add(category);
        } catch (e, stackTrace) {
          print('getVehicleType error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return vehicleTypeList;
  }

  static Future<List<PopularDestination>> getPopularDestination() async {
    List<PopularDestination> popularDestination = [];
    await fireStore.collection(CollectionName.popularDestinations).where("sectionId", isEqualTo: Constant.sectionConstantModel!.id).where('is_publish', isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        try {
          PopularDestination category = PopularDestination.fromJson(element.data());
          popularDestination.add(category);
        } catch (e, stackTrace) {
          print('Get PopularDestination error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return popularDestination;
  }

  // These three create AND update their documents, so they write known fields
  // only: fields owned by the Driver app / admin panel (e.g. `regionId`)
  // survive a customer-side update.
  /// Drops [orderId] from the signed-in customer's `inProgressOrderID` (a
  /// field update, so nothing else on the user document is rewritten).
  static Future<void> removeInProgressOrder(String orderId) async {
    final String uid = auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || orderId.isEmpty) return;
    try {
      await fireStore.collection(CollectionName.users).doc(uid).update({
        'inProgressOrderID': FieldValue.arrayRemove([orderId]),
      });
      Constant.userModel?.inProgressOrderID?.remove(orderId);
    } catch (e) {
      log('removeInProgressOrder failed: $e');
    }
  }

  /// The customer's payment choice on a ride after it was created (method
  /// change, payment). Only the payment fields are written: the ride's
  /// `status`, `driverId` / `driverID` and `rejectedByDrivers` belong to the
  /// dispatch Cloud Function and the Driver app, and a whole-model write from
  /// the screen's copy could put back a stale status ("Order Placed"
  /// re-triggers `cabDispatch`), a driver who has since declined, or drop a
  /// driver from the dispatch's exclusion list.
  static Future<void> updateRidePayment(CabOrderModel orderModel) => _updateBookingPayment(CollectionName.rides, orderModel.id, paymentMethod: orderModel.paymentMethod, paymentStatus: orderModel.paymentStatus, regionId: orderModel.regionId);

  /// [updateRidePayment] for `rental_orders`.
  static Future<void> updateRentalPayment(RentalOrderModel orderModel) => _updateBookingPayment(CollectionName.rentalOrders, orderModel.id, paymentMethod: orderModel.paymentMethod, paymentStatus: orderModel.paymentStatus, regionId: orderModel.regionId);

  static Future<void> _updateBookingPayment(String collection, String? orderId, {String? paymentMethod, bool? paymentStatus, String? regionId}) async {
    if (orderId == null || orderId.isEmpty) throw StateError('booking id is empty');
    await fireStore.collection(collection).doc(orderId).update({
      'paymentMethod': paymentMethod,
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      // Fill-only on the model side (`regionId ??= driver's region`): an
      // existing region is written back unchanged, a missing one is not
      // written at all.
      if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
    });
  }

  // Parcel orders are created / paid through ParcelShippingService.save and
  // cancelled through ParcelCancellation (field updates): there is no
  // whole-model parcel write here, so nothing the dispatch, the driver or the
  // SMS trigger wrote can be replaced by a stale copy.


  /// `rides` / `rental_orders`.`regionId` is resolved through the DRIVER
  /// (admin spec §1) — never through the store, and never through the pickup
  /// once a driver is on the record. The Driver app stamps its own region when
  /// it accepts; this is the customer-side safety net so a record that reached
  /// a driver can never stay unplaced (invisible to a region-bound admin).
  ///
  /// It only ever FILLS an empty value: the transaction re-reads the document
  /// and gives up the moment it finds a `regionId` there, so it is idempotent
  /// and can never replace the driver's region with the pickup region. Single
  /// known field, so nothing else on the document is touched.
  ///
  /// Returns the region the record carries afterwards (null when still none).
  static Future<String?> ensureRideRegion({required String collection, required String? orderId, required String? driverId, String? currentRegionId}) async {
    if (currentRegionId != null && currentRegionId.isNotEmpty) return currentRegionId;
    if (orderId == null || orderId.isEmpty || driverId == null || driverId.isEmpty) return currentRegionId;
    final String? driverRegion = await RegionService.userRegionId(driverId);
    if (driverRegion == null || driverRegion.isEmpty) return currentRegionId;
    final ref = fireStore.collection(collection).doc(orderId);
    try {
      return await fireStore.runTransaction<String?>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return null;
        final String existing = snap.data()?['regionId']?.toString() ?? '';
        if (existing.isNotEmpty) return existing;
        tx.update(ref, {'regionId': driverRegion});
        return driverRegion;
      });
    } catch (e) {
      log("ensureRideRegion($collection/$orderId) failed: $e");
      return currentRegionId;
    }
  }

  static Future<CabOrderModel?> getCabOrderById(String orderId) async {
    CabOrderModel? orderModel;
    try {
      final doc = await fireStore.collection(CollectionName.rides).doc(orderId).get();
      if (doc.data() != null) {
        final model = CabOrderModel.fromJson(doc.data()!);
        if (model.rideType == "ride") {
          orderModel = model;
        }
      }
    } catch (e, s) {
      print('getCabOrderById error: $e\n$s');
      return null;
    }
    return orderModel;
  }

  static Future<CabOrderModel?> getIntercityOrder(String orderId) async {
    CabOrderModel? orderModel;
    try {
      final doc = await fireStore.collection(CollectionName.rides).doc(orderId).get();
      if (doc.data() != null) {
        final model = CabOrderModel.fromJson(doc.data()!);
        if (model.rideType == "intercity") {
          orderModel = model;
        }
      }
    } catch (e, s) {
      print('getCabOrderById error: $e\n$s');
      return null;
    }
    return orderModel;
  }

  static Future<UserModel?> getDriver(String userId) async {
    UserModel? userModel;

    try {
      final doc = await fireStore.collection(CollectionName.users).doc(userId).get();

      if (doc.data() != null) {
        userModel = UserModel.fromJson(doc.data()!);
      }
    } catch (e) {
      log("getDriver error: $e");
    }

    return userModel;
  }

  // static Future<List<CabOrderModel>> getCabDriverOrders() async {
  //   List<CabOrderModel> ordersList = [];
  //   await fireStore.collection(CollectionName.rides).where('authorID', isEqualTo: FireStoreUtils.getCurrentUid()).orderBy('createdAt', descending: true).get().then((value) {
  //     for (var element in value.docs) {
  //       CabOrderModel orderModel = CabOrderModel.fromJson(element.data());
  //       ordersList.add(orderModel);
  //     }
  //   });
  //   return ordersList;
  // }

  static Stream<List<CabOrderModel>> getCabDriverOrders() {
    return fireStore
        .collection(CollectionName.rides)
        .where('authorID', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) {
          List<CabOrderModel> ordersList = [];
          for (var element in query.docs) {
            ordersList.add(CabOrderModel.fromJson(element.data()));
          }
          return ordersList;
        });
  }

  static Future<List<CategoryModel>> getOnDemandCategory() async {
    List<CategoryModel> categoryList = [];
    await fireStore
        .collection(CollectionName.providerCategories)
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
        .where("level", isEqualTo: 0)
        .where("publish", isEqualTo: true)
        .get()
        .then((value) {
          for (var element in value.docs) {
            CategoryModel orderModel = CategoryModel.fromJson(element.data());
            categoryList.add(orderModel);
          }
        });
    return categoryList;
  }

  static Future<CategoryModel?> getCategoryById(String categoryId) async {
    CategoryModel? categoryModel;
    await fireStore.collection(CollectionName.providerCategories).doc(categoryId).get().then((value) {
      if (value.exists) {
        categoryModel = CategoryModel.fromJson(value.data()!);
      }
    });
    return categoryModel;
  }

  static Future<List<ProviderServiceModel>> getProviderFuture({String categoryId = ''}) async {
    List<ProviderServiceModel> providerList = [];

    try {
      Query<Map<String, dynamic>> collectionReference;

      if (categoryId.isNotEmpty) {
        collectionReference = fireStore
            .collection(CollectionName.providersServices)
            .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
            .where('categoryId', isEqualTo: categoryId)
            .where("publish", isEqualTo: true);
      } else {
        collectionReference = fireStore.collection(CollectionName.providersServices).where("sectionId", isEqualTo: Constant.sectionConstantModel!.id).where("publish", isEqualTo: true);
      }

      GeoFirePoint center = Geoflutterfire().point(latitude: Constant.selectedLocation.location!.latitude ?? 0.0, longitude: Constant.selectedLocation.location!.longitude ?? 0.0);

      String field = 'g';

      await Geoflutterfire()
          .collection(collectionRef: collectionReference)
          .within(center: center, radius: double.parse(Constant.sectionConstantModel!.nearByRadius.toString()), field: field, strictMode: true)
          .first
          .then((documentList) {
            for (var document in documentList) {
              ProviderServiceModel providerServiceModel = ProviderServiceModel.fromJson(document.data() as Map<String, dynamic>);

              log(
                ":: isExpireDate(expiryDay :: ${Constant.isExpireDate(expiryDay: (providerServiceModel.subscriptionPlan?.expiryDay == '-1'), subscriptionExpiryDate: providerServiceModel.subscriptionExpiryDate)}",
              );

              if (Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) {
                if (providerServiceModel.subscriptionPlan != null &&
                    Constant.isExpireDate(expiryDay: (providerServiceModel.subscriptionPlan?.expiryDay == '-1'), subscriptionExpiryDate: providerServiceModel.subscriptionExpiryDate) == false) {
                  if (providerServiceModel.subscriptionTotalOrders == "-1" || providerServiceModel.subscriptionTotalOrders != '0') {
                    providerList.add(providerServiceModel);
                  }
                }
              } else {
                providerList.add(providerServiceModel);
              }
            }
          })
          .catchError((error) {
            log('Error fetching providers: $error');
          });
    } catch (e) {
      log('Error in getProviderFuture: $e');
    }

    return providerList;
  }

  static Future<List<ProviderServiceModel>> getAllProviderServiceByAuthorId(String authId) async {
    List<ProviderServiceModel> providerService = [];
    await fireStore.collection(CollectionName.providersServices).where('author', isEqualTo: authId).where('publish', isEqualTo: true).orderBy('createdAt', descending: false).get().then((value) {
      for (var element in value.docs) {
        ProviderServiceModel orderModel = ProviderServiceModel.fromJson(element.data());
        providerService.add(orderModel);
      }
    });
    return providerService;
  }

  static Future<CategoryModel?> getSubCategoryById(String categoryId) async {
    CategoryModel? categoryModel;
    await fireStore.collection(CollectionName.providerCategories).doc(categoryId).get().then((value) {
      if (value.exists) {
        categoryModel = CategoryModel.fromJson(value.data()!);
      }
    });
    return categoryModel;
  }

  static Future<List<RatingModel>> getReviewByProviderServiceId(String serviceId) async {
    List<RatingModel> providerReview = [];
    await fireStore.collection(CollectionName.itemsReview).where('productId', isEqualTo: serviceId).get().then((value) {
      for (var element in value.docs) {
        RatingModel orderModel = RatingModel.fromJson(element.data());
        providerReview.add(orderModel);
      }
    });
    return providerReview;
  }

  static Future<List<ProviderServiceModel>> getProviderServiceByProviderId({required String providerId}) async {
    List<ProviderServiceModel> providerList = [];

    try {
      final collectionReference = fireStore
          .collection(CollectionName.providersServices)
          .where("author", isEqualTo: providerId)
          .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id)
          .where("publish", isEqualTo: true);

      // Geolocation center point
      GeoFirePoint center = Geoflutterfire().point(latitude: Constant.selectedLocation.location!.latitude ?? 0.0, longitude: Constant.selectedLocation.location!.longitude ?? 0.0);

      String field = 'g';

      // Query within radius
      await Geoflutterfire()
          .collection(collectionRef: collectionReference)
          .within(center: center, radius: double.parse(Constant.sectionConstantModel!.nearByRadius.toString()), field: field, strictMode: true)
          .first
          .then((documentList) {
            for (var document in documentList) {
              ProviderServiceModel providerServiceModel = ProviderServiceModel.fromJson(document.data() as Map<String, dynamic>);

              log(
                ":: isExpireDate(expiryDay :: ${Constant.isExpireDate(expiryDay: (providerServiceModel.subscriptionPlan?.expiryDay == '-1'), subscriptionExpiryDate: providerServiceModel.subscriptionExpiryDate)}",
              );

              //Subscription & Commission check
              if (Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) {
                if (providerServiceModel.subscriptionPlan != null &&
                    Constant.isExpireDate(expiryDay: (providerServiceModel.subscriptionPlan?.expiryDay == '-1'), subscriptionExpiryDate: providerServiceModel.subscriptionExpiryDate) == false) {
                  if (providerServiceModel.subscriptionTotalOrders == "-1" || providerServiceModel.subscriptionTotalOrders != '0') {
                    providerList.add(providerServiceModel);
                  }
                }
              } else {
                providerList.add(providerServiceModel);
              }
            }
          })
          .catchError((error) {
            log('Error fetching provider services: $error');
          });
    } catch (e) {
      log('Error in getProviderServiceByProviderId: $e');
    }

    return providerList;
  }

  static Future<List<CouponModel>> getProviderCoupon(String providerId) async {
    List<CouponModel> offers = [];
    await fireStore
        .collection(CollectionName.providersCoupons)
        .where('providerId', isEqualTo: providerId)
        .where("isEnabled", isEqualTo: true)
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel favouriteOndemandServiceModel = CouponModel.fromJson(element.data());
            offers.add(favouriteOndemandServiceModel);
          }
        });
    return offers;
  }

  static Future<List<CouponModel>> getProviderCouponAfterExpire(String providerId) async {
    List<CouponModel> coupon = [];
    await fireStore
        .collection(CollectionName.providersCoupons)
        .where('providerId', isEqualTo: providerId)
        .where('isEnabled', isEqualTo: true)
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .where('isPublic', isEqualTo: true)
        .where('expiresAt', isGreaterThanOrEqualTo: Timestamp.now())
        .get()
        .then((value) {
          for (var element in value.docs) {
            CouponModel favouriteOndemandServiceModel = CouponModel.fromJson(element.data());
            coupon.add(favouriteOndemandServiceModel);
          }
        });
    return coupon;
  }

  static Future<OnProviderOrderModel> onDemandOrderPlace(OnProviderOrderModel orderModel, double totalAmount) async {
    DocumentReference<Map<String, dynamic>> documentReference;
    if (orderModel.id.isEmpty) {
      documentReference = fireStore.collection(CollectionName.providerOrders).doc();
      orderModel.id = documentReference.id;
    } else {
      documentReference = fireStore.collection(CollectionName.providerOrders).doc(orderModel.id);
    }
    // provider_orders.regionId = the provider's region (spec 18.12).
    final bool isNewRegion = orderModel.regionId == null;
    if (isNewRegion) {
      orderModel.regionId = await RegionService.providerRegionId(orderModel.provider);
    }
    await documentReference.setKnownFields(orderModel.toJson());
    if (isNewRegion) await addCustomerRegion(orderModel.regionId);

    return orderModel;
  }

  static Future<void> sendOrderOnDemandServiceEmail({required OnProviderOrderModel orderModel}) async {
    // Receipt = history: the booking's own region currency.
    final CurrencyModel? orderCurrency = RegionService.currencyForRecord(orderModel.regionId);
    try {
      String firstHTML = """
       <table style="width: 100%; border-collapse: collapse; border: 1px solid rgb(0, 0, 0);">
    <thead>
        <tr>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Product Name<br></th>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Quantity<br></th>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Price<br></th>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Total<br></th>
        </tr>
    </thead>
    <tbody>
    """;

      EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(Constant.newOnDemandBook);

      if (emailTemplateModel != null) {
        String newString = emailTemplateModel.message.toString();
        newString = newString.replaceAll("{username}", "${Constant.userModel?.firstName ?? ''} ${Constant.userModel?.lastName ?? ''}");
        newString = newString.replaceAll("{orderid}", orderModel.id);
        newString = newString.replaceAll("{date}", DateFormat('dd-MM-yyyy').format(orderModel.createdAt.toDate()));
        newString = newString.replaceAll("{address}", orderModel.address!.getFullAddress());
        newString = newString.replaceAll("{paymentmethod}", orderModel.payment_method);

        double total = 0.0;
        double discount = 0.0;
        double taxAmount = 0.0;
        List<String> htmlList = [];

        if (orderModel.provider.disPrice == "" || orderModel.provider.disPrice == "0") {
          total = double.parse(orderModel.provider.price.toString()) * orderModel.quantity;
        } else {
          total = double.parse(orderModel.provider.disPrice.toString()) * orderModel.quantity;
        }

        String product = """
        <tr>
            <td style="width: 20%; border-top: 1px solid rgb(0, 0, 0);">${orderModel.provider.title}</td>
            <td style="width: 20%; border: 1px solid rgb(0, 0, 0);" rowspan="2">${orderModel.quantity}</td>
            <td style="width: 20%; border: 1px solid rgb(0, 0, 0);" rowspan="2">${Constant.amountShow(amount: (orderModel.provider.disPrice == "" || orderModel.provider.disPrice == "0") ? orderModel.provider.price.toString() : orderModel.provider.disPrice.toString(), currency: orderCurrency)}</td>
            <td style="width: 20%; border: 1px solid rgb(0, 0, 0);" rowspan="2">${Constant.amountShow(amount: (total).toString(), currency: orderCurrency)}</td>
        </tr>
    """;
        htmlList.add(product);

        if (orderModel.couponCode != null && orderModel.couponCode!.isNotEmpty) {
          discount = double.parse(orderModel.discount.toString());
        }
        List<String> taxHtmlList = [];
        if (orderModel.taxModel != null) {
          for (var element in orderModel.taxModel!) {
            taxAmount = taxAmount + Constant.getTaxValue(amount: (total - discount).toString(), taxModel: element);
            String taxHtml =
                """<span style="font-size: 1rem;">${element.title}: ${Constant.amountShow(amount: Constant.getTaxValue(amount: (total - discount).toString(), taxModel: element).toString(), currency: orderCurrency)}${orderModel.taxModel!.indexOf(element) == orderModel.taxModel!.length - 1 ? "</span>" : "<br></span>"}""";
            taxHtmlList.add(taxHtml);
          }
        }

        var totalamount = total + taxAmount - discount;

        newString = newString.replaceAll("{subtotal}", Constant.amountShow(amount: total.toString(), currency: orderCurrency));
        newString = newString.replaceAll("{coupon}", '(${orderModel.couponCode.toString()})');
        newString = newString.replaceAll("{discountamount}", orderModel.couponCode == null ? "0.0" : Constant.amountShow(amount: orderModel.discount.toString(), currency: orderCurrency));
        newString = newString.replaceAll("{totalAmount}", Constant.amountShow(amount: totalamount.toString(), currency: orderCurrency));

        String tableHTML = htmlList.join();
        String lastHTML = "</tbody></table>";
        newString = newString.replaceAll("{productdetails}", firstHTML + tableHTML + lastHTML);
        newString = newString.replaceAll("{taxdetails}", taxHtmlList.join());
        newString = newString.replaceAll("{newwalletbalance}.", Constant.amountShow(amount: Constant.userModel?.walletAmount.toString(), currency: RegionService.customerCurrency));

        String subjectNewString = emailTemplateModel.subject.toString();
        subjectNewString = subjectNewString.replaceAll("{orderid}", orderModel.id);
        await Constant.sendMail(subject: subjectNewString, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel?.email]);
      }
    } catch (e) {
      log("SIGNUP :: 22 :::::: $e");
    }
  }

  /// [extra] fields go out in the same write (e.g. the cancellation contract
  /// fields with a server timestamp alongside the status change).
  static Future<void> updateOnDemandOrder(OnProviderOrderModel orderModel, {Map<String, dynamic>? extra}) async {
    if (orderModel.id.isEmpty) {
      throw Exception("Order ID cannot be empty");
    }

    try {
      final docRef = fireStore.collection(CollectionName.providerOrders).doc(orderModel.id);
      await docRef.set({...orderModel.toJson(), ...?extra}, SetOptions(merge: true));
    } catch (e) {
      print("Error updating OnDemand order: $e");
      rethrow;
    }
  }

  // static Future<void> updateOnDemandOrder(OnProviderOrderModel orderModel) async {
  //   if (orderModel.id.isEmpty) {
  //     throw Exception("Order ID cannot be empty");
  //   }
  //
  //   try {
  //     final docRef = fireStore.collection(CollectionName.providerOrders).doc(orderModel.id);
  //
  //     // Convert model to map
  //     final Map<String, dynamic> data = orderModel.toJson();
  //
  //     // Remove null values so we only update non-null fields
  //     final Map<String, dynamic> updateData = {};
  //     data.forEach((key, value) {
  //       if (value != null) {
  //         updateData[key] = value;
  //       }
  //     });
  //
  //     if (updateData.isNotEmpty) {
  //       await docRef.set(updateData, SetOptions(merge: true));
  //       print("Order ${orderModel.id} updated dynamically: $updateData");
  //     } else {
  //       print("No fields to update for order ${orderModel.id}");
  //     }
  //   } catch (e) {
  //     print("Error updating OnDemand order: $e");
  //     rethrow;
  //   }
  // }

  // static Future<List<OnProviderOrderModel>> getProviderOrders() async {
  //   List<OnProviderOrderModel> ordersList = [];
  //   await fireStore
  //       .collection(CollectionName.providerOrders)
  //       .where("authorID", isEqualTo: FireStoreUtils.getCurrentUid())
  //       .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id.toString())
  //       .orderBy("createdAt", descending: true)
  //       .get()
  //       .then((value) {
  //         for (var element in value.docs) {
  //           OnProviderOrderModel orderModel = OnProviderOrderModel.fromJson(element.data());
  //           ordersList.add(orderModel);
  //         }
  //       });
  //   return ordersList;
  // }

  static Stream<List<OnProviderOrderModel>> getProviderOrdersStream() {
    return fireStore
        .collection(CollectionName.providerOrders)
        .where("authorID", isEqualTo: getCurrentUid())
        .where("sectionId", isEqualTo: Constant.sectionConstantModel!.id.toString())
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => OnProviderOrderModel.fromJson(doc.data())).toList());
  }

  static Future<WorkerModel?> getWorker(String id) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc = await fireStore.collection(CollectionName.providersWorkers).doc(id).get();

      if (doc.exists && doc.data() != null) {
        return WorkerModel.fromJson(doc.data()!);
      }
    } catch (e) {
      print("FireStoreUtils.getWorker error: $e");
    }
    return null;
  }

  static Future<OnProviderOrderModel?> getProviderOrderById(String orderId) async {
    OnProviderOrderModel? orderModel;
    await fireStore.collection(CollectionName.providerOrders).doc(orderId).get().then((value) {
      if (value.exists) {
        orderModel = OnProviderOrderModel.fromJson(value.data()!);
      }
    });
    return orderModel;
  }

  static Future<RatingModel?> getReviewsByProviderID(String orderId, String providerId) async {
    RatingModel? ratingModel;

    await fireStore
        .collection(CollectionName.itemsReview)
        .where('orderid', isEqualTo: orderId)
        .where('VendorId', isEqualTo: providerId)
        .limit(1)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            ratingModel = RatingModel.fromJson(snapshot.docs.first.data());
          }
        })
        .catchError((error) {
          print('Error fetching review for provider: $error');
        });

    return ratingModel;
  }

  static Future<RatingModel?> getReviewsByWorkerID(String orderId, String workerId) async {
    RatingModel? ratingModel;

    await fireStore
        .collection(CollectionName.itemsReview)
        .where('orderid', isEqualTo: orderId)
        .where('driverId', isEqualTo: workerId)
        .limit(1)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            ratingModel = RatingModel.fromJson(snapshot.docs.first.data());
          }
        })
        .catchError((error) {
          print('Error fetching review by worker ID: $error');
        });

    return ratingModel;
  }

  static Future<ProviderServiceModel?> getCurrentProvider(String uid) async {
    try {
      final doc = await fireStore.collection(CollectionName.providersServices).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return ProviderServiceModel.fromJson(doc.data()!);
      }
    } catch (e, stackTrace) {
      print('Error fetching current provider: $e');
      print(stackTrace);
    }
    return null;
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

  static Future<ProviderServiceModel?> updateProvider(ProviderServiceModel provider) async {
    try {
      await fireStore.collection(CollectionName.providersServices).doc(provider.id).setKnownFields(provider.toJson());
      return provider;
    } catch (e, stackTrace) {
      print('Error updating provider: $e');
      print(stackTrace);
      return null;
    }
  }

  /// Adds a customer's rating to a worker's review totals: only `reviewsCount`
  /// and `reviewsSum`, as increments. It used to write back the whole
  /// [WorkerModel] loaded when the review screen opened, which restored a
  /// stale `fcmToken` (cleared on sign-out), `online` or `active`.
  static Future<bool> addWorkerReviewTotals(String? workerId, {required num countDelta, required num sumDelta}) {
    return _addReviewTotals(CollectionName.providersWorkers, workerId, countDelta: countDelta, sumDelta: sumDelta);
  }

  static Future<ParcelOrderModel?> getParcelOrder(String orderId) async {
    try {
      final doc = await fireStore.collection(CollectionName.parcelOrders).doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        return ParcelOrderModel.fromJson(doc.data()!);
      }
    } catch (e, stackTrace) {
      print('Error fetching current provider: $e');
      print(stackTrace);
    }
    return null;
  }

  static Stream<UserModel?> driverStream(String userId) {
    return fireStore.collection(CollectionName.users).doc(userId).snapshots().map((doc) {
      if (doc.data() != null) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    });
  }

  static Future<List<RentalVehicleType>> getRentalVehicleType() async {
    List<RentalVehicleType> vehicleTypeList = [];
    await fireStore.collection(CollectionName.rentalVehicleType).where('sectionId', isEqualTo: Constant.sectionConstantModel!.id).where("isActive", isEqualTo: true).get().then((value) {
      for (var element in value.docs) {
        try {
          RentalVehicleType category = RentalVehicleType.fromJson(element.data());
          vehicleTypeList.add(category);
        } catch (e, stackTrace) {
          print('getVehicleType error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return vehicleTypeList;
  }

  static Future<List<RentalPackageModel>> getRentalPackage(String vehicleId) async {
    List<RentalPackageModel> rentalPackageList = [];
    await fireStore.collection(CollectionName.rentalPackages).where("vehicleTypeId", isEqualTo: vehicleId).orderBy("ordering", descending: false).get().then((value) {
      for (var element in value.docs) {
        try {
          log('Rental Package Data: ${element.data()}');
          RentalPackageModel category = RentalPackageModel.fromJson(element.data());
          rentalPackageList.add(category);
        } catch (e, stackTrace) {
          print('getVehicleType error: ${element.id} $e');
          print(stackTrace);
        }
      }
    });
    return rentalPackageList;
  }

  static Stream<List<RentalOrderModel>> getRentalOrders() {
    return fireStore
        .collection(CollectionName.rentalOrders)
        .where('authorID', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('sectionId', isEqualTo: Constant.sectionConstantModel!.id)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) {
          List<RentalOrderModel> ordersList = [];
          for (var element in query.docs) {
            ordersList.add(RentalOrderModel.fromJson(element.data()));
          }
          return ordersList;
        });
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

  static Future<RentalOrderModel?> getRentalOrderById(String orderId) async {
    RentalOrderModel? orderModel;
    await fireStore.collection(CollectionName.rentalOrders).doc(orderId).get().then((value) {
      if (value.exists) {
        orderModel = RentalOrderModel.fromJson(value.data()!);
      }
    });
    return orderModel;
  }

  static Future<RatingModel?> getReviewsbyID(String orderId) async {
    RatingModel? ratingModel;

    await fireStore
        .collection(CollectionName.itemsReview)
        .where('orderid', isEqualTo: orderId)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            ratingModel = RatingModel.fromJson(snapshot.docs.first.data());
          }
        })
        .catchError((error) {
          print('Error fetching review for provider: $error');
        });

    return ratingModel;
  }

  static Future<dynamic> getOrderByIdFromAllCollections(String orderId) async {
    final List<String> collections = [CollectionName.parcelOrders, CollectionName.rentalOrders, CollectionName.providerOrders, CollectionName.rides, CollectionName.vendorOrders];

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

  static Future<void> setSos(String orderId, UserLocation userLocation) {
    DocumentReference documentReference = fireStore.collection(CollectionName.sos).doc();

    Map<String, dynamic> sosMap = {'id': documentReference.id, 'orderId': orderId, 'status': "Initiated", 'latLong': userLocation.toJson()};

    return documentReference
        .set(sosMap)
        .then((_) {
          print("SOS request created successfully for order: $orderId");
        })
        .catchError((error) {
          print("Failed to create SOS request: $error");
        });
  }

  static Future<bool> getSOS(String orderId) {
    return fireStore
        .collection(CollectionName.sos)
        .where('orderId', isEqualTo: orderId)
        .get()
        .then((querySnapshot) {
          bool isAdded = false;
          for (var element in querySnapshot.docs) {
            if (element['orderId'] == orderId) {
              isAdded = true;
              break;
            }
          }
          return isAdded;
        })
        .catchError((error) {
          print("Error checking SOS: $error");
          return false;
        });
  }

  static Future<void> setRideComplain({
    required String orderId,
    required String title,
    required String description,
    required String driverID,
    required String driverName,
    required String customerID,
    required String customerName,
  }) async {
    try {
      DocumentReference docRef = fireStore.collection(CollectionName.complaints).doc();
      // complaints.regionId = the region of the driver the complaint is about.
      final String? regionId = await RegionService.userRegionId(driverID);

      Map<String, dynamic> complaintData = {
        'id': docRef.id,
        'createdAt': Timestamp.now(),
        'description': description,
        'driverId': driverID,
        'driverName': driverName,
        'orderId': orderId,
        'customerName': customerName,
        'customerId': customerID,
        'status': "Initiated",
        'title': title,
        if (regionId != null) 'regionId': regionId,
      };

      await docRef.set(complaintData);
    } catch (e) {
      print("Error adding ride complain: $e");
      rethrow;
    }
  }

  static Future<bool> isRideComplainAdded(String orderId) async {
    try {
      QuerySnapshot querySnapshot = await fireStore.collection(CollectionName.complaints).where('orderId', isEqualTo: orderId).limit(1).get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking ride complain: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getRideComplainData(String orderId) async {
    try {
      QuerySnapshot querySnapshot = await fireStore.collection(CollectionName.complaints).where('orderId', isEqualTo: orderId).limit(1).get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data() as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      print("Error fetching ride complain data: $e");
      return null;
    }
  }

  static void removeFavouriteOndemandService(FavouriteOndemandServiceModel favouriteModel) {
    fireStore.collection(CollectionName.favoriteService).where("user_id", isEqualTo: favouriteModel.user_id).where("service_id", isEqualTo: favouriteModel.service_id).get().then((value) {
      for (var element in value.docs) {
        fireStore.collection(CollectionName.favoriteService).doc(element.id).delete().then((value) {
          print("Remove Success!");
        });
      }
    });
  }

  static Future<void> setFavouriteOndemandSection(FavouriteOndemandServiceModel favouriteModel) async {
    await fireStore.collection(CollectionName.favoriteService).add(favouriteModel.toJson()).then((value) {
      print("===FAVOURITE ADDED=== ${favouriteModel.toJson()}");
    });
  }

  static Future<List<FavouriteOndemandServiceModel>> getFavouritesServiceList(String userId) async {
    List<FavouriteOndemandServiceModel> lstFavourites = [];

    QuerySnapshot<Map<String, dynamic>> favourites =
        await fireStore.collection(CollectionName.favoriteService).where('user_id', isEqualTo: userId).where("section_id", isEqualTo: Constant.sectionConstantModel!.id).get();

    await Future.forEach(favourites.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        lstFavourites.add(FavouriteOndemandServiceModel.fromJson(document.data()));
      } catch (e) {
        print('FavouriteModel.getCurrencys Parse error $e');
      }
    });

    return lstFavourites;
  }

  static Future<List<ProviderServiceModel>> getCurrentProviderService(FavouriteOndemandServiceModel model) async {
    List<ProviderServiceModel> providerService = [];

    QuerySnapshot<Map<String, dynamic>> reviewQuery =
        await fireStore.collection(CollectionName.providersServices).where('id', isEqualTo: model.service_id).where('sectionId', isEqualTo: model.section_id).get();
    await Future.forEach(reviewQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        providerService.add(ProviderServiceModel.fromJson(document.data()));
      } catch (e) {
        print('FireStoreUtils.getReviewByProviderServiceId Parse error ${document.id} $e');
      }
    });
    return providerService;
  }

  static StreamSubscription<QuerySnapshot>? adminChatSeenSubscription;

  static void setSeen() {
    final currentUserId = FireStoreUtils.getCurrentUid();
    // `collection.doc('')` throws ArgumentError ("A document path must be a
    // non-empty string"), and this runs from a controller's onInit: the
    // exception took the rest of that init with it and the screen never left
    // its loader. No id, nothing to mark as seen.
    if (currentUserId.isEmpty) return;
    adminChatSeenSubscription?.cancel();

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
    // Nullable, not `late`: when setSeen() returned early (or threw) the old
    // `late` field was never assigned and closing the screen threw a
    // LateInitializationError on top of the first failure.
    adminChatSeenSubscription?.cancel();
    adminChatSeenSubscription = null;
  }

  static StreamSubscription<QuerySnapshot>? orderChatSeenSubscription;

  /// The unseen messages of `chat/{threadId}/thread` addressed to
  /// [receiverId] and, when [senderId] is set, sent by that peer only: the
  /// store and driver chats of one order (and the provider and worker chats
  /// of one booking) share the thread, so the peer tells the conversations
  /// apart. Equality filters only (no composite index needed). Shared by the
  /// inbox badge (ChatUnreadService) and [setSeenChatForOrder].
  static Query<Map<String, dynamic>> unreadOrderChatQuery({required String threadId, required String receiverId, String senderId = ''}) {
    Query<Map<String, dynamic>> query = fireStore.collection(CollectionName.chat).doc(threadId.trim()).collection("thread").where('receiverId', isEqualTo: receiverId);
    if (senderId.trim().isNotEmpty) query = query.where('senderId', isEqualTo: senderId.trim());
    return query.where('seen', isEqualTo: false);
  }

  /// Marks seen, while the chat is open, the messages [senderId] sent to this
  /// customer in the order thread [orderId] (the conversation the screen
  /// shows, not the other party's messages in the same thread).
  static void setSeenChatForOrder({required String orderId, String senderId = ''}) {
    // An order chat is keyed by the order id. A thread reached without one (an
    // inbox row whose `orderId` field is missing) used to build the document
    // path `chat/` + '' and throw ArgumentError out of the controller's
    // getArgument(), so `isLoading` was never cleared and the chat screen
    // stayed blank.
    if (orderId.trim().isEmpty) return;
    orderChatSeenSubscription?.cancel();
    // The messages addressed to this customer that are still unseen: exactly
    // what the inbox row's unread badge counts (ChatUnreadService). Equality
    // filters only: the old `senderId != me` + `seen == false` mixes an
    // inequality with an equality, which Firestore serves only from a
    // composite index; without one the listener failed and nothing was
    // marked seen.
    final String me = auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    if (me.isEmpty) return;
    orderChatSeenSubscription = unreadOrderChatQuery(threadId: orderId, receiverId: me, senderId: senderId)
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

  static void stopSeenForOrderListener() {
    orderChatSeenSubscription?.cancel();
    orderChatSeenSubscription = null;
  }

  /// The document that holds a thread: the order for an order chat, the sender
  /// for an admin one.
  ///
  /// `doc(null)` quietly invents an auto-id (the message would be written to a
  /// document nobody reads) and `doc('')` throws, so a thread with neither id
  /// is refused here rather than half-written.
  static String? chatThreadId({required String? orderId, required String? senderId, required bool isAdmin}) {
    final String primary = (isAdmin ? senderId : orderId)?.trim() ?? '';
    if (primary.isNotEmpty) return primary;
    final String fallback = (isAdmin ? orderId : senderId)?.trim() ?? '';
    return fallback.isEmpty ? null : fallback;
  }

  static Future<ConversationModel> addChat(ConversationModel conversationModel) async {
    final chatCollection = fireStore.collection(CollectionName.chat);
    final docId = chatThreadId(
      orderId: conversationModel.orderId,
      senderId: conversationModel.senderId,
      isAdmin: conversationModel.receiverId?.contains('admin') != false,
    );
    if (docId == null) throw ArgumentError('Chat message has neither an order id nor a sender id');
    await chatCollection.doc(docId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson());
    return conversationModel;
  }

  static Future<InboxModel> addInbox(InboxModel inboxModel) async {
    final collection = fireStore.collection(CollectionName.chat);
    final docId = chatThreadId(
      orderId: inboxModel.orderId,
      senderId: inboxModel.senderId,
      isAdmin: inboxModel.senderReceiverId?.contains('admin') != false,
    );
    if (docId == null) throw ArgumentError('Chat thread has neither an order id nor a sender id');
    await collection.doc(docId).set(inboxModel.toJson());
    return inboxModel;
  }
}
