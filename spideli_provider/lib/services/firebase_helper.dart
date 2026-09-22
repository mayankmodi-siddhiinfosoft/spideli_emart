import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_core/firebase_core.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:video_compress/video_compress.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/chat_video_container.dart';
import 'package:spideliprovider/model/conversation_model.dart';
import 'package:spideliprovider/model/coupon_model.dart';
import 'package:spideliprovider/model/email_template_model.dart';
import 'package:spideliprovider/model/inbox_model.dart';
import 'package:spideliprovider/model/notification_model.dart';
import 'package:spideliprovider/model/on_boarding_model.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/model/payment_model/flutter_wave_model.dart';
import 'package:spideliprovider/model/payment_model/mercado_pago_model.dart';
import 'package:spideliprovider/model/payment_model/mid_trans.dart';
import 'package:spideliprovider/model/payment_model/orange_money.dart';
import 'package:spideliprovider/model/payment_model/pay_fast_model.dart';
import 'package:spideliprovider/model/payment_model/pay_stack_model.dart';
import 'package:spideliprovider/model/payment_model/paypal_model.dart';
import 'package:spideliprovider/model/payment_model/paytm_model.dart';
import 'package:spideliprovider/model/payment_model/razorpay_model.dart';
import 'package:spideliprovider/model/payment_model/wallet_setting_model.dart';
import 'package:spideliprovider/model/payment_model/xendit.dart';
import 'package:spideliprovider/model/provider_service_model.dart';
import 'package:spideliprovider/model/rating_model.dart';
import 'package:spideliprovider/model/referral_model.dart';
import 'package:spideliprovider/model/sectionModel.dart';
import 'package:spideliprovider/model/stripeSettingData.dart';
import 'package:spideliprovider/model/subscription_history.dart';
import 'package:spideliprovider/model/subscription_plan_model.dart';
import 'package:spideliprovider/model/topupTranHistory.dart';
import 'package:spideliprovider/model/withdrawHistoryModel.dart';
import 'package:spideliprovider/model/withdraw_method_model.dart';
import 'package:spideliprovider/services/region_service.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:spideliprovider/model/category_model.dart';
import 'package:spideliprovider/model/currency_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:flutter/material.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart' as apple;
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Update of an existing document that writes only [data]'s keys (contract
/// lesson 2): a full `set(model.toJson())` would delete every field the model
/// doesn't know, such as the panel's `regionId`. Creates the doc if missing.
extension SetKnownFields on DocumentReference<Map<String, dynamic>> {
  Future<void> setKnownFields(Map<String, dynamic> data) {
    return set(data, SetOptions(mergeFields: data.keys.map((k) => FieldPath([k])).toList()));
  }
}

enum FirebaseEnv { defaultDb, staging }

/// Change this to switch between default / staging
const FirebaseEnv currentEnv = FirebaseEnv.defaultDb;

class FireStoreUtils {
  FireStoreUtils._privateConstructor();

  static final FireStoreUtils instance = FireStoreUtils._privateConstructor();

  static late FirebaseFirestore firestore;

  /// Initialize Firestore with a FirebaseApp and optional databaseId
  void init(FirebaseApp app, {String? databaseId}) {
    firestore = FirebaseFirestore.instanceFor(app: app, databaseId: databaseId);
  }

  static Reference storage = FirebaseStorage.instance.ref();
  static FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  static firebaseSignUpWithEmailAndPassword(String emailAddress, String password, File? image, String firstName, String lastName, String mobile, bool? auto_approve_restaurant) async {
    try {
      auth.UserCredential result = await auth.FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailAddress, password: password);
      String profilePicUrl = '';
      if (image != null) {
        ShowToastDialog.showLoader('Uploading image, Please wait...'.tr);
        profilePicUrl = await uploadUserImageToFireStorage(image, result.user?.uid ?? '');
      }
      User user = User(
          email: emailAddress,
          photos: [],
          lastOnlineTimestamp: Timestamp.now(),
          active: auto_approve_restaurant == true ? true : false,
          phoneNumber: mobile,
          firstName: firstName,
          id: result.user?.uid ?? '',
          lastName: lastName,
          role: USER_ROLE_PROVIDER,
          fcmToken: await firebaseMessaging.getToken() ?? '',
          createdAt: Timestamp.now(),
          profilePictureURL: profilePicUrl);
      String? errorMessage = await firebaseCreateNewUser(user);
      if (errorMessage == null) {
        return user;
      } else {
        return "Couldn't sign up for firebase, Please try again.".tr;
      }
    } on auth.FirebaseAuthException catch (error) {
      log('$error${error.stackTrace}');
      String message = "Couldn't sign up".tr;
      switch (error.code) {
        case 'email-already-in-use':
          message = 'Email already in use, Please pick another email!'.tr;
          break;
        case 'invalid-email':
          message = 'Enter valid e-mail'.tr;
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled'.tr;
          break;
        case 'weak-password':
          message = 'Password must be more than 5 characters'.tr;
          break;
        case 'too-many-requests':
          message = 'Too many requests, Please try again later.'.tr;
          break;
      }
      return message;
    } catch (e) {
      return "Couldn't sign up".tr;
    }
  }

  static Future<String> uploadUserImageToFireStorage(File image, String userID) async {
    Reference upload = storage.child('$STORAGE_ROOT/images/$userID.png');
    UploadTask uploadTask = upload.putFile(image);
    var downloadUrl = await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  static Future<String?> firebaseCreateNewUser(User user) async => await firestore.collection(USERS).doc(user.id).set(user.toJson()).then((value) => null, onError: (e) => e);

  static Future<dynamic> loginWithEmailAndPassword(String email, String password) async {
    try {
      auth.UserCredential result = await auth.FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      DocumentSnapshot<Map<String, dynamic>> documentSnapshot = await firestore
          .collection(USERS)
          .doc(result.user?.uid ?? '')
          .
          // where('role',isEqualTo: 'vendor').
          get();
      User? user;

      if (documentSnapshot.exists) {
        user = User.fromJson(documentSnapshot.data() ?? {});
        if (user.role == 'provider') {
          user.fcmToken = await firebaseMessaging.getToken() ?? '';

          return user;
        }
      }
    } on auth.FirebaseAuthException catch (exception, s) {
      log('$exception$s');
      switch ((exception).code) {
        case 'invalid-email':
          return 'Email address is malformed.'.tr;
        case 'wrong-password':
          return 'Wrong password.'.tr;
        case 'user-not-found':
          return 'No user corresponding to the given email address.'.tr;
        case 'user-disabled':
          return 'This user has been disabled.'.tr;
        case 'too-many-requests':
          return 'Too many attempts to sign in as this user.'.tr;
      }
      return 'Unexpected firebase error, Please try again.'.tr;
    } catch (e, s) {
      log('$e$s');
      return 'Login failed, Please try again.'.tr;
    }
  }

  /// Writes only the fields the [User] model knows (contract lesson 2), so
  /// panel-written fields (`regionId`, `isDocumentVerify`, ...) survive.
  static Future<User?> updateCurrentUser(User user) async {
    return await firestore.collection(USERS).doc(user.id).setKnownFields(user.toJson()).then((document) {
      return user;
    });
  }

  /// Merges [data] into `users/{uid}` (creates the doc when missing).
  static Future<void> writeUserFields(String uid, Map<String, dynamic> data) async {
    if (uid.isEmpty || data.isEmpty) return;
    await firestore.collection(USERS).doc(uid).setKnownFields(data);
  }

  /// The signed-in provider's region, for records created by this app
  /// (spec 18.12): the stored `users.regionId`, else the resolved one.
  static String? currentProviderRegionId() {
    final String? own = MyAppState.currentUser?.regionId;
    if (own != null && own.isNotEmpty) return own;
    return RegionService.providerRegionId;
  }

  /// Appends one entry to `provider_orders/{orderId}.assignmentLog` (spec 10).
  /// Append-only: arrayUnion, never a rewrite of the list.
  static Future<void> logWorkerAssignment({required String orderId, required String workerId, required String workerName, String? previousWorkerId}) async {
    if (orderId.isEmpty) return;
    final entry = AssignmentLogEntry(
      workerId: workerId,
      workerName: workerName,
      assignedBy: getCurrentUid(),
      at: Timestamp.now(),
      previousWorkerId: (previousWorkerId == null || previousWorkerId.isEmpty) ? null : previousWorkerId,
    );
    try {
      await firestore.collection(PROVIDER_ORDER).doc(orderId).update({
        'assignmentLog': FieldValue.arrayUnion([entry.toJson()])
      });
    } catch (e) {
      log("Assignment log not written: $e");
    }
  }

  static Future<bool> isMaintenanceMode() async {
    bool isMaintenance = false;
    await firestore.collection(Setting).doc('maintenance_settings').get().then((value) async {
      isMaintenance = value.data()?['isMaintenanceModeForProvider'] == true;
      log("isMaintenance :: $isMaintenance");
    });
    return isMaintenance;
  }

  static Future<User?> getCurrentUser(String uid) async {
    DocumentSnapshot<Map<String, dynamic>> userDocument = await firestore.collection(USERS).doc(uid).get();
    if (userDocument.data() != null && userDocument.exists) {
      return User.fromJson(userDocument.data()!);
    } else {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      // Request credential for the currently signed in Apple account.
      AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        // webAuthenticationOptions: WebAuthenticationOptions(clientId: clientID, redirectUri: Uri.parse(redirectURL)),
      );

      // Create an `OAuthCredential` from the credential returned by Apple.
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in the user with Firebase. If the nonce we generated earlier does
      // not match the nonce in `appleCredential.identityToken`, sign in will fail.
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      return {"appleCredential": appleCredential, "userCredential": userCredential};
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }

  static String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static handleAppleLogin(
    auth.AuthCredential credential,
    apple.AppleIdCredential appleIdCredential,
  ) async {
    auth.UserCredential authResult = await auth.FirebaseAuth.instance.signInWithCredential(credential);
    User? user = await getCurrentUser(authResult.user?.uid ?? '');
    if (user != null) {
      user.role = USER_ROLE_PROVIDER;
      user.fcmToken = await firebaseMessaging.getToken() ?? '';
      dynamic result = await updateCurrentUser(user);
      return result;
    } else {
      user = User(
        email: appleIdCredential.email ?? '',
        firstName: appleIdCredential.fullName?.givenName ?? '',
        profilePictureURL: '',
        id: authResult.user?.uid ?? '',
        lastOnlineTimestamp: Timestamp.now(),
        lastName: appleIdCredential.fullName?.familyName ?? '',
        role: USER_ROLE_PROVIDER,
        active: true,
        fcmToken: await firebaseMessaging.getToken() ?? '',
        phoneNumber: '',
      );
      String? errorMessage = await firebaseCreateNewUser(user);
      if (errorMessage == null) {
        return user;
      } else {
        return errorMessage;
      }
    }
  }

  static Future<dynamic> firebaseSubmitPhoneNumberCode(String verificationID, String code, String phoneNumber,
      {String firstName = 'Anonymous', String lastName = 'User', String emailAddress = 'Email', File? image, bool? auto_approve_provider}) async {
    auth.AuthCredential authCredential = auth.PhoneAuthProvider.credential(verificationId: verificationID, smsCode: code);
    auth.UserCredential userCredential = await auth.FirebaseAuth.instance.signInWithCredential(authCredential);
    User? user = await getCurrentUser(userCredential.user?.uid ?? '');
    if (user != null && user.role == USER_ROLE_PROVIDER) {
      return user;
    } else if (user == null) {
      /// create a new user from phone login
      String profileImageUrl = '';
      if (image != null) {
        profileImageUrl = await uploadUserImageToFireStorage(image, userCredential.user?.uid ?? '');
      }
      User user = User(
          firstName: firstName,
          lastName: lastName,
          fcmToken: await firebaseMessaging.getToken() ?? '',
          phoneNumber: phoneNumber,
          profilePictureURL: profileImageUrl,
          id: userCredential.user?.uid ?? '',
          active: auto_approve_provider == true ? true : false,
          lastOnlineTimestamp: Timestamp.now(),
          photos: [],
          role: USER_ROLE_PROVIDER,
          email: emailAddress,
          createdAt: Timestamp.now());
      String? errorMessage = await firebaseCreateNewUser(user);
      if (errorMessage == null) {
        return user;
      } else {
        return "Couldn't create new user with phone number.".tr;
      }
    }
  }

  ///submit a phone number to firebase to receive a code verification, will
  ///be used later to login
  static firebaseSubmitPhoneNumber(
    String phoneNumber,
    auth.PhoneCodeAutoRetrievalTimeout? phoneCodeAutoRetrievalTimeout,
    auth.PhoneCodeSent? phoneCodeSent,
    auth.PhoneVerificationFailed? phoneVerificationFailed,
    auth.PhoneVerificationCompleted? phoneVerificationCompleted,
  ) {
    auth.FirebaseAuth.instance.verifyPhoneNumber(
      timeout: const Duration(minutes: 2),
      phoneNumber: phoneNumber,
      verificationCompleted: phoneVerificationCompleted!,
      verificationFailed: phoneVerificationFailed!,
      codeSent: phoneCodeSent!,
      codeAutoRetrievalTimeout: phoneCodeAutoRetrievalTimeout!,
    );
  }

  static Future<CurrencyModel?> getCurrency() async {
    CurrencyModel? currency;
    await firestore.collection(Currency).where("isActive", isEqualTo: true).get().then((value) {
      if (value.docs.isNotEmpty) {
        currency = CurrencyModel.fromJson(value.docs.first.data());
      }
    });
    return currency;
  }

  static Future<ProviderServiceModel> firebaseAddOrUpdateProvider(ProviderServiceModel productModel) async {
    if ((productModel.id!).isNotEmpty) {
      // Update: known fields only, so the panel's regionId etc. are kept.
      await firestore.collection(PROVIDERS_SERVICES).doc(productModel.id).setKnownFields(productModel.toJson());
    } else {
      DocumentReference docRef = firestore.collection(PROVIDERS_SERVICES).doc();
      productModel.id = docRef.id;
      // Creation: stamp the provider's region (spec 18.12).
      final String? regionId = currentProviderRegionId();
      docRef.set({...productModel.toJson(), if (regionId != null) 'regionId': regionId});
    }
    return productModel;
  }

  static Future<ProviderServiceModel?> updateProvider(ProviderServiceModel vendor) async {
    return await firestore.collection(PROVIDERS_SERVICES).doc(vendor.id).setKnownFields(vendor.toJson()).then((document) {
      return vendor;
    });
  }

  static Future<List<CategoryModel>> getCategory(String sectionId) async {
    List<CategoryModel> category = [];
    QuerySnapshot<Map<String, dynamic>> productsQuery =
        await firestore.collection(CATEGORIES).where("sectionId", isEqualTo: sectionId).where("level", isEqualTo: 0).where("publish", isEqualTo: true).get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        category.add(CategoryModel.fromJson(document.data()));
      } catch (e) {
        log('**-FireStoreUtils.getCategory Parse error $e');
      }
    });

    return category;
  }

  static Future<CategoryModel?> getCategoryById(String categoryId) async {
    CategoryModel? categoryModel;
    await firestore.collection(CATEGORIES).doc(categoryId).get().then((value) {
      if (value.exists) {
        categoryModel = CategoryModel.fromJson(value.data()!);
      }
    });
    return categoryModel;
  }

  static Future<List<CategoryModel>> getSubCategory(String categoryId) async {
    List<CategoryModel> category = [];

    QuerySnapshot<Map<String, dynamic>> categoryQuery =
        await firestore.collection(CATEGORIES).where("level", isEqualTo: 1).where('parentCategoryId', isEqualTo: categoryId).where("publish", isEqualTo: true).get();
    await Future.forEach(categoryQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        category.add(CategoryModel.fromJson(document.data()));
      } catch (e, stacksTrace) {
        log('FireStoreUtils.getProviderSubCategoryById Parse error ${document.id} $e '
            '$stacksTrace');
      }
    });
    return category;
  }

  static Future<List<ProviderServiceModel>> getProviderServices() async {
    List<ProviderServiceModel> products = [];

    QuerySnapshot<Map<String, dynamic>> productsQuery =
        await firestore.collection(PROVIDERS_SERVICES).where('author', isEqualTo: MyAppState.currentUser!.id).orderBy('createdAt', descending: false).get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        products.add(ProviderServiceModel.fromJson(document.data()));
      } catch (e) {
        log('FireStoreUtils.getVendorProducts Parse error $e');
      }
    });
    return products;
  }

  static Future<String> uploadServiceImage(File image, String progress) async {
    var uniqueID = const Uuid().v4();
    Reference upload = storage.child('$STORAGE_ROOT/provider/serviceImages/$uniqueID.png');
    UploadTask uploadTask = upload.putFile(image);
    uploadTask.snapshotEvents.listen((event) {
      ShowToastDialog.showLoader('Image Uploading..');
    });
    // ignore: body_might_complete_normally_catch_error
    uploadTask.whenComplete(() {}).catchError((onError) {
      log((onError as PlatformException).message.toString());
    });
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();
    return downloadUrl.toString();
  }

  static Future<ProviderServiceModel?>? getProvider(id) async {
    ProviderServiceModel? providerModel;
    QuerySnapshot<Map<String, dynamic>> productsQuery = await firestore.collection(PROVIDERS_SERVICES).where('author', isEqualTo: MyAppState.currentUser!.id).where('id', isEqualTo: id).get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        providerModel = ProviderServiceModel.fromJson(document.data());
      } catch (e) {
        log('FireStoreUtils.getProviderrProducts Parse error $e');
      }
    });
    return providerModel;
  }

  static deleteProduct(String providerId) async {
    await firestore.collection(PROVIDERS_SERVICES).doc(providerId).delete();
  }

  static Future<bool?> deleteUser() async {
    try {
      await firestore.collection(PROVIDERS_SERVICES).where("author", isEqualTo: MyAppState.currentUser!.id).get().then((value) async {
        for (var element in value.docs) {
          firestore.collection(FAVORITE_SERVICES).where('service_id', isEqualTo: element.id).get().then((value0) {
            for (var element0 in value0.docs) {
              firestore.collection(FAVORITE_SERVICES).doc(element0.reference.path).delete();
            }
          });

          await firestore.collection(PROVIDERS_SERVICES).doc(element.id).delete();
        }

        await firestore.collection(FAVORITE_PROVIDER).where('provider_id', isEqualTo: MyAppState.currentUser!.id).get().then((value0) async {
          for (var element0 in value0.docs) {
            await firestore.collection(FAVORITE_PROVIDER).doc(element0.reference.path).delete();
          }
        });
      });

      await firestore.collection(COUPONS).where("providerId", isEqualTo: MyAppState.currentUser!.id).get().then((value) async {
        for (var element in value.docs) {
          await firestore.collection(COUPONS).doc(element.id).delete();
        }
      });
      await firestore.collection(WORKERS).where("providerId", isEqualTo: MyAppState.currentUser!.id).get().then((value) async {
        for (var element in value.docs) {
          await firestore.collection(WORKERS).doc(element.id).delete();
        }
      });

      await firestore.collection(ChatProvider).where("customerId", isEqualTo: MyAppState.currentUser!.id).get().then((value) async {
        for (var element in value.docs) {
          firestore.collection(ChatProvider).doc(element.id).collection('thread').get().then((snapshot) {
            for (DocumentSnapshot doc in snapshot.docs) {
              doc.reference.delete();
            }
          });
          await firestore.collection(ChatProvider).doc(element.id).delete();
        }
      });
      await firestore.collection(ChatProvider).where("restaurantId", isEqualTo: MyAppState.currentUser!.id).get().then((value) async {
        for (var element in value.docs) {
          firestore.collection(ChatProvider).doc(element.id).collection('thread').get().then((snapshot) {
            for (DocumentSnapshot doc in snapshot.docs) {
              doc.reference.delete();
            }
          });
          await firestore.collection(ChatProvider).doc(element.id).delete();
        }
      });

      await firestore.collection(USERS).doc(auth.FirebaseAuth.instance.currentUser!.uid).delete();

      await auth.FirebaseAuth.instance.currentUser!.delete();
    } catch (e, s) {
      print('FireStoreUtils.deleteUser $e $s');
    }
    return null;
    // return isDelete;
  }

  static String getCurrentUid() {
    return auth.FirebaseAuth.instance.currentUser!.uid;
  }

  static Future updateOrder(OnProviderOrderModel onProviderOrderModel) async {
    await firestore.collection(PROVIDER_ORDER).doc(onProviderOrderModel.id).set(onProviderOrderModel.toJson(), SetOptions(merge: true));
  }

  static Future<NotificationModel?> getNotificationContent(String type) async {
    NotificationModel? notificationModel;
    await firestore.collection(dynamicNotification).where('type', isEqualTo: type).get().then((value) {
      print("------>");
      if (value.docs.isNotEmpty) {
        print(value.docs.first.data());

        notificationModel = NotificationModel.fromJson(value.docs.first.data());
      } else {
        notificationModel = NotificationModel(id: "", message: "Notification setup is pending".tr, subject: "setup notification".tr, type: "");
      }
    });
    return notificationModel;
  }

  static Future<List<RatingModel>> getReviewByProviderServiceId(String serviceId) async {
    List<RatingModel> providerReview = [];

    QuerySnapshot<Map<String, dynamic>> reviewQuery = await firestore.collection(Order_Rating).where('orderid', isEqualTo: serviceId).where('VendorId', isEqualTo: MyAppState.currentUser!.id).get();
    await Future.forEach(reviewQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      print(document);
      try {
        providerReview.add(RatingModel.fromJson(document.data()));
      } catch (e) {
        print('FireStoreUtils.getReviewByProviderServiceId Parse error ${document.id} $e');
      }
    });
    return providerReview;
  }

  static Future addProviderInbox(InboxModel inboxModel) async {
    return await firestore.collection(ChatProvider).doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addProviderChat(ConversationModel conversationModel) async {
    return await firestore.collection(ChatProvider).doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addWorkerInbox(InboxModel inboxModel) async {
    return await firestore.collection(ChatWorker).doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static Future addDriverChat(ConversationModel conversationModel) async {
    return await firestore.collection("chat_driver").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addWorkerChat(ConversationModel conversationModel) async {
    return await firestore.collection(ChatWorker).doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addRestaurantChat(ConversationModel conversationModel) async {
    return await firestore.collection("chat_store").doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future<Url> uploadChatImageToFireStorage(File image) async {
    ShowToastDialog.showLoader('Uploading image...');
    var uniqueID = const Uuid().v4();
    Reference upload = FirebaseStorage.instance.ref().child('/chat/images/$uniqueID.png');
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

  Future<String> uploadVideoThumbnailToFireStorage(File file) async {
    var uniqueID = const Uuid().v4();
    Reference upload = FirebaseStorage.instance.ref().child('/thumbnails/$uniqueID.png');
    UploadTask uploadTask = upload.putFile(file);
    var downloadUrl = await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  static Future withdrawWalletAmount({required WithdrawHistoryModel withdrawHistory}) async {
    print("this is te payment id");
    print(withdrawHistory.id);
    print(MyAppState.currentUser!.id);

    await firestore.collection(PAYOUTS).doc(withdrawHistory.id).set(withdrawHistory.toJson()).then((value) {
      firestore.collection(PAYOUTS).doc(withdrawHistory.id).get().then((value) {
        DocumentSnapshot<Map<String, dynamic>> documentData = value;
        print(documentData.data());
      });
    });
    return "updated Amount".tr;
  }

  static Future updateWalletAmount({required String userId, required amount}) async {
    dynamic walletAmountdata = 0;

    await firestore.collection(USERS).doc(userId).get().then((value) async {
      DocumentSnapshot<Map<String, dynamic>> userDocument = value;
      if (userDocument.data() != null && userDocument.exists) {
        try {
          num walletAmount = num.parse("${userDocument.data()?['wallet_amount'] ?? 0}") + amount;
          await firestore.collection(USERS).doc(userId).update({"wallet_amount": walletAmount}).then((value) {
            if (userId == MyAppState.currentUser?.id) {
              MyAppState.currentUser?.walletAmount = walletAmount;
              walletAmountdata = walletAmount;
            }
          });
        } catch (error) {
          print(error);
          if (error.toString() == "Bad state: field does not exist within the DocumentSnapshotPlatform") {
            print("does not exist");
          } else {
            print("went wrong!!");
            walletAmountdata = "ERROR";
          }
        }
        print("data val");
        print(walletAmountdata);
        return walletAmountdata; //User.fromJson(userDocument.data()!);
      } else {
        return 0.111;
      }
    });
  }

  static Future createPaymentId({collectionName = "wallet"}) async {
    DocumentReference documentReference = firestore.collection(collectionName).doc();
    final paymentId = documentReference.id;
    return paymentId;
  }

  /// Claims the provider credit for a booking exactly once (marker
  /// `providerCredited`, set in a transaction). Shared with the Worker app, so
  /// the provider accepting/completing and the worker completing can never
  /// both pay the provider.
  static Future<bool> claimProviderCredit(String orderId) async {
    try {
      return await firestore.runTransaction<bool>((transaction) async {
        final ref = firestore.collection(PROVIDER_ORDER).doc(orderId);
        final snap = await transaction.get(ref);
        if (!snap.exists || snap.data()?['providerCredited'] == true) return false;
        transaction.update(ref, {'providerCredited': true});
        return true;
      });
    } catch (e) {
      log("claimProviderCredit failed: $e");
      return false;
    }
  }

  static Future providerWalletSet(OnProviderOrderModel orderModel, bool isSent) async {
    // Once per booking, whichever app or screen gets here first.
    if (isSent == true && await claimProviderCredit(orderModel.id.toString())) {
      double total = 0.0;
      double discount = 0.0;
      double specialDiscount = 0.0;
      double taxAmount = 0.0;

      if (orderModel.provider.disPrice == "" || orderModel.provider.disPrice == "0") {
        total += orderModel.quantity * double.parse(orderModel.provider.price.toString());
      } else {
        total += orderModel.quantity * double.parse(orderModel.provider.disPrice.toString());
      }

      if (orderModel.discount != null) {
        discount = double.parse(orderModel.discount.toString());
      }
      var totalamount = total - discount - specialDiscount;

      double adminComm = (orderModel.adminCommissionType == 'Percent' || orderModel.adminCommissionType == 'percentage')
          ? (totalamount * double.parse(orderModel.adminCommission!)) / 100
          : double.parse(orderModel.adminCommission!);

      if (orderModel.taxModel != null) {
        for (var element in orderModel.taxModel!) {
          taxAmount = taxAmount + getTaxValue(amount: totalamount.toString(), taxModel: element);
        }
      }
      double finalAmount = totalamount + taxAmount + double.parse(orderModel.extraCharges!.isEmpty ? "0.0" : orderModel.extraCharges.toString());

      if (orderModel.payment_method.toLowerCase() != "cod") {
        TopupTranHistoryModel historyModel = TopupTranHistoryModel(
            amount: finalAmount,
            id: Uuid().v4(),
            orderId: orderModel.id,
            userId: orderModel.provider.author.toString(),
            date: Timestamp.now(),
            isTopup: true,
            paymentMethod: "Wallet",
            paymentStatus: "success",
            serviceType: 'ondemand-service',
            note: 'Booking Amount',
            transactionUser: "provider");

        await firestore.collection(WALLET).doc(historyModel.id).set(historyModel.toJson());
        await updateProviderWalletAmount(amount: finalAmount, userId: orderModel.provider.author.toString());
      }
      if (orderModel.adminCommission != '0') {
        TopupTranHistoryModel adminCommission = TopupTranHistoryModel(
            amount: adminComm,
            id: Uuid().v4(),
            orderId: orderModel.id,
            userId: orderModel.provider.author.toString(),
            date: Timestamp.now(),
            isTopup: false,
            paymentMethod: "Wallet",
            paymentStatus: "success",
            serviceType: 'ondemand-service',
            note: 'Admin commission Deducted',
            transactionUser: "provider");

        await firestore.collection(WALLET).doc(adminCommission.id).set(adminCommission.toJson());
        await updateProviderWalletAmount(amount: -adminComm, userId: orderModel.provider.author.toString());
      }
    }
  }

  static Future updateProviderWalletAmount({required double amount, required String userId}) async {
    await firestore.collection(USERS).doc(userId).get().then((value) async {
      DocumentSnapshot<Map<String, dynamic>> userDocument = value;
      if (userDocument.data() != null && userDocument.exists) {
        try {
          print(userDocument.data());
          User user = User.fromJson(userDocument.data()!);
          user.walletAmount = user.walletAmount + amount;
          await firestore.collection(USERS).doc(user.id).update({'wallet_amount': user.walletAmount}).then((value) => print("north"));
          MyAppState.currentUser?.walletAmount = user.walletAmount;
        } catch (error) {
          if (error.toString() == "Bad state: field does not exist within the DocumentSnapshotPlatform") {
            log("does not exist");
          } else {
            print("went wrong!!");
          }
        }
      } else {
        return 0.111;
      }
    });
  }

  static Future<List<WithdrawHistoryModel>> getWithdrawTransaction(String userId) async {
    List<WithdrawHistoryModel> history = [];

    QuerySnapshot<Map<String, dynamic>> categoryQuery = await firestore.collection(PAYOUTS).where('vendorID', isEqualTo: userId).orderBy('paidDate', descending: true).get();
    await Future.forEach(categoryQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        history.add(WithdrawHistoryModel.fromJson(document.data()));
      } catch (e, stacksTrace) {
        log('FireStoreUtils.getWithdrawTransaction Parse error ${document.id} $e '
            '$stacksTrace');
      }
    });
    return history;
  }

  static Future<List<TopupTranHistoryModel>> getTopUpTransaction(String userId) async {
    List<TopupTranHistoryModel> history = [];

    QuerySnapshot<Map<String, dynamic>> categoryQuery = await firestore.collection(WALLET).where('user_id', isEqualTo: userId).orderBy('date', descending: true).get();
    await Future.forEach(categoryQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        history.add(TopupTranHistoryModel.fromJson(document.data()));
      } catch (e, stacksTrace) {
        log('FireStoreUtils.getTopUpTransaction Parse error ${document.id} $e '
            '$stacksTrace');
      }
    });
    return history;
  }

  static Future topUpWalletAmount({required String userId, required amount, orderId = ""}) async {
    print("this is te payment id");
    print(MyAppState.currentUser!.id);

    TopupTranHistoryModel adminCommission = TopupTranHistoryModel(
        amount: amount,
        id: Uuid().v4(),
        orderId: orderId,
        userId: userId,
        date: Timestamp.now(),
        isTopup: true,
        paymentMethod: "Wallet",
        paymentStatus: "success",
        transactionUser: "customer",
        note: 'Booking amount Refund',
        serviceType: 'ondemand-service');

    await firestore.collection("wallet").doc(adminCommission.id).set(adminCommission.toJson()).then((value) {
      firestore.collection("wallet").doc(adminCommission.id).get().then((value) {
        DocumentSnapshot<Map<String, dynamic>> documentData = value;
        print("nato");
        print(documentData.data());
      });
    });
    return "updated Amount".tr;
  }

  /// Creates `providers_workers/{id}`, stamped with the provider's region
  /// (spec 18.12) when known.
  static Future<String?> firebaseCreateNewWorker(User user) async {
    final String? regionId = user.regionId ?? currentProviderRegionId();
    return await firestore
        .collection(WORKERS)
        .doc(user.id)
        .set({...user.toJson(), if (regionId != null && regionId.isNotEmpty) 'regionId': regionId}).then((value) => null, onError: (e) => e);
  }

  static Future<List<User>> getAllWorkers() async {
    List<User> products = [];
    QuerySnapshot<Map<String, dynamic>> productsQuery = await firestore.collection(WORKERS).where('providerId', isEqualTo: MyAppState.currentUser!.id).get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        products.add(User.fromJson(document.data()));
      } catch (e) {
        log('FireStoreUtils.getVendorProducts Parse error $e');
      }
    });
    return products;
  }

  static Future<List<User>> getAllOnlineWorkers() async {
    List<User> products = [];
    QuerySnapshot<Map<String, dynamic>> productsQuery = await firestore.collection(WORKERS).where('providerId', isEqualTo: MyAppState.currentUser!.id).where('online', isEqualTo: true).get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        products.add(User.fromJson(document.data()));
      } catch (e) {
        log('FireStoreUtils.getVendorProducts Parse error $e');
      }
    });
    return products;
  }

  static Future<User> firebaseUpdateWorker(User User) async {
    await firestore.collection(WORKERS).doc(User.id).setKnownFields(User.toJson());

    return User;
  }

  static deleteWorker(String workerId) async {
    await firestore.collection(WORKERS).doc(workerId).delete();
    HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('deleteUser');
    await callable.call(<String, dynamic>{
      'uid': workerId,
    });
  }

  static getPlaceHolderImage() async {
    var collection = firestore.collection(Setting);
    var docSnapshot = await collection.doc('placeHolderImage').get();
    Map<String, dynamic>? data = docSnapshot.data();
    var value = data?['image'];
    placeholderImage = value;
    return const Center();
  }

  static Future<User?>? getWorker(id) async {
    User? providerModel;
    QuerySnapshot<Map<String, dynamic>> productsQuery = await firestore.collection(WORKERS).where('id', isEqualTo: id).get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        providerModel = User.fromJson(document.data());
      } catch (e) {
        log('FireStoreUtils.getProviderrProducts Parse error $e');
      }
    });
    return providerModel;
  }

  addOffer(CouponModel couponModel, BuildContext context) async {
    DocumentReference docRef = firestore.collection(COUPONS).doc();
    couponModel.id = docRef.id;
    docRef.set(couponModel.toJson()).then((value) {});
  }

  static Future<CouponModel> firebaseAddOrUpdateCoupon(CouponModel couponModel) async {
    if (couponModel.id != null) {
      await firestore.collection(COUPONS).doc(couponModel.id).set(couponModel.toJson());
    } else {
      DocumentReference docRef = firestore.collection(COUPONS).doc();
      couponModel.id = docRef.id;
      docRef.set(couponModel.toJson());
    }
    return couponModel;
  }

  static Future<List<CouponModel>> getCoupons() async {
    List<CouponModel> products = [];

    QuerySnapshot<Map<String, dynamic>> productsQuery = await firestore.collection(COUPONS).where('providerId', isEqualTo: MyAppState.currentUser!.id).get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        products.add(CouponModel.fromJson(document.data()));
      } catch (e) {
        log('FireStoreUtils.getVendorProducts Parse error $e');
      }
    });
    return products;
  }

  Future<OnProviderOrderModel?> getProviderOrderById(String? orderId) async {
    DocumentSnapshot<Map<String, dynamic>> userDocument = await firestore.collection(PROVIDER_ORDER).doc(orderId).get();
    if (userDocument.data() != null && userDocument.exists) {
      return OnProviderOrderModel.fromJson(userDocument.data()!);
    } else {
      return null;
    }
  }

  static sendPayoutMail({required String amount, required String payoutrequestid}) async {
    EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(payoutRequest);

    String body = emailTemplateModel!.subject.toString();
    body = body.replaceAll("{userid}", MyAppState.currentUser!.id);

    String newString = emailTemplateModel.message.toString();
    newString = newString.replaceAll("{username}", MyAppState.currentUser!.firstName + " " + MyAppState.currentUser!.lastName);
    newString = newString.replaceAll("{userid}", MyAppState.currentUser!.id);
    newString = newString.replaceAll("{amount}", amountShow(amount: amount));
    newString = newString.replaceAll("{date}", DateFormat('dd-MM-yyyy').format(Timestamp.now().toDate()));
    newString = newString.replaceAll("{payoutrequestid}", payoutrequestid.toString());
    newString = newString.replaceAll("{usercontactinfo}", "${MyAppState.currentUser!.email}\n${MyAppState.currentUser!.phoneNumber}");
    await sendMail(subject: body, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [MyAppState.currentUser!.email]);
  }

  static Future<EmailTemplateModel?> getEmailTemplates(String type) async {
    EmailTemplateModel? emailTemplateModel;
    await firestore.collection(emailTemplates).where('type', isEqualTo: type).get().then((value) {
      print("------>");
      if (value.docs.isNotEmpty) {
        print(value.docs.first.data());
        emailTemplateModel = EmailTemplateModel.fromJson(value.docs.first.data());
      }
    });
    return emailTemplateModel;
  }

  static Future<bool> getFirestOrderOrNOt(OnProviderOrderModel orderModel) async {
    bool isFirst = true;
    await firestore.collection(PROVIDER_ORDER).where('authorID', isEqualTo: orderModel.authorID).where('section_id', isEqualTo: orderModel.sectionId).get().then((value) {
      if (value.size == 1) {
        isFirst = true;
      } else {
        isFirst = false;
      }
    });
    return isFirst;
  }

  static Future<SectionModel?> getSectionBySectionId(String uid) async {
    DocumentSnapshot<Map<String, dynamic>> userDocument = await firestore.collection(sections).doc(uid).get();
    if (userDocument.data() != null && userDocument.exists) {
      return SectionModel.fromJson(userDocument.data()!);
    } else {
      return null;
    }
  }

  static Future updateReferralAmount(OnProviderOrderModel orderModel) async {
    ReferralModel? referralModel;
    print(orderModel.authorID);
    print(orderModel.sectionId);
    await getSectionBySectionId(orderModel.sectionId.toString()).then((valueSection) async {
      await firestore.collection(REFERRAL).doc(orderModel.authorID).get().then((value) {
        if (value.data() != null) {
          referralModel = ReferralModel.fromJson(value.data()!);
        } else {
          return;
        }
      });

      print("refferealAMount----->${valueSection!.referralAmount.toString()}");
      print("refferealAMount----->${referralModel!.referralBy}");

      if (referralModel != null) {
        if (referralModel!.referralBy != null && referralModel!.referralBy!.isNotEmpty) {
          await firestore.collection(USERS).doc(referralModel!.referralBy).get().then((value) async {
            DocumentSnapshot<Map<String, dynamic>> userDocument = value;
            if (userDocument.data() != null && userDocument.exists) {
              try {
                print(userDocument.data());
                User user = User.fromJson(userDocument.data()!);
                await firestore.collection(USERS).doc(user.id).update({"wallet_amount": user.walletAmount + double.parse(valueSection.referralAmount.toString())}).then((value) => print("north"));

                await FireStoreUtils.createPaymentId().then((value) async {
                  final paymentID = value;
                  await FireStoreUtils.topUpWalletAmountRefral(
                      paymentMethod: "Referral Amount", amount: double.parse(valueSection.referralAmount.toString()), id: paymentID, userId: referralModel!.referralBy);
                });
              } catch (error) {
                print(error);
                if (error.toString() == "Bad state: field does not exist within the DocumentSnapshotPlatform") {
                  print("does not exist");
                } else {
                  print("went wrong!!");
                }
              }
              print("data val");
            }
          });
        } else {
          return;
        }
      }
    });
  }

  static Future topUpWalletAmountRefral({String paymentMethod = "test", bool isTopup = true, required amount, required id, orderId = "", userId}) async {
    print("this is te payment id");
    print(id);
    print(userId);

    await firestore.collection(WALLET).doc(id).set({
      "user_id": userId,
      "payment_method": paymentMethod,
      "amount": amount,
      "id": id,
      "order_id": orderId,
      "isTopUp": isTopup,
      "payment_status": "success",
      "date": DateTime.now(),
      "transactionUser": "driver",
    }).then((value) {
      firestore.collection(WALLET).doc(id).get().then((value) {
        DocumentSnapshot<Map<String, dynamic>> documentData = value;
        print("nato");
        print(documentData.data());
      });
    });

    return "updated Amount".tr;
  }

  static Future<List<OnBoardingModel>> getOnBoardingList() async {
    List<OnBoardingModel> onBoardingModel = [];
    await firestore.collection("on_boarding").where("type", isEqualTo: "provider").get().then((value) {
      for (var element in value.docs) {
        OnBoardingModel documentModel = OnBoardingModel.fromJson(element.data());
        onBoardingModel.add(documentModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return onBoardingModel;
  }

  static Future<WithdrawMethodModel?> getWithdrawMethod() async {
    WithdrawMethodModel? withdrawMethodModel;
    await firestore.collection('withdraw_method').where("userId", isEqualTo: MyAppState.currentUser!.id).get().then((value) async {
      if (value.docs.isNotEmpty) {
        withdrawMethodModel = WithdrawMethodModel.fromJson(value.docs.first.data());
      }
    });
    return withdrawMethodModel;
  }

  static Future<WithdrawMethodModel?> setWithdrawMethod(WithdrawMethodModel withdrawMethodModel) async {
    if (withdrawMethodModel.id == null) {
      withdrawMethodModel.id = Uuid().v4();
      withdrawMethodModel.id = MyAppState.currentUser!.id;
    }
    await firestore.collection('withdraw_method').doc(withdrawMethodModel.id).set(withdrawMethodModel.toJson()).then((value) async {});
    return withdrawMethodModel;
  }

  static Future<List<SectionModel>> getSections() async {
    List<SectionModel> sections = [];
    QuerySnapshot<Map<String, dynamic>> productsQuery = await firestore.collection(SECTION).where("isActive", isEqualTo: true).get();
    await Future.forEach(productsQuery.docs, (QueryDocumentSnapshot<Map<String, dynamic>> document) {
      try {
        if (document.data()['name'] != "Banner") {
          sections.add(SectionModel.fromJson(document.data()));
        }
      } catch (e) {
        print('**-FireStoreUtils.getSection Parse error $e');
      }
    });

    return sections;
  }

  static Future<List<SubscriptionPlanModel>> getAllSubscriptionPlans(String sectionId) async {
    List<SubscriptionPlanModel> subscriptionPlanModels = [];
    await firestore.collection(subscriptionPlans).where("isCommissionPlan", isEqualTo: false).where("sectionId", isEqualTo: sectionId).where('isEnable', isEqualTo: true).get().then((value) async {
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
    print("=====>");
    await firestore.collection(subscriptionPlans).where("isCommissionPlan", isEqualTo: true).where("sectionId", isEqualTo: sectionId).where('isEnable', isEqualTo: true).get().then((value) async {
      if (value.docs.isNotEmpty) {
        for (var element in value.docs) {
          print("=====>");
          print(element.data());
          SubscriptionPlanModel subscriptionPlanModel = SubscriptionPlanModel.fromJson(element.data());
          subscriptionPlanModels.add(subscriptionPlanModel);
        }
      }
    });
    return subscriptionPlanModels;
  }

  static Future<SubscriptionPlanModel> setSubscriptionPlan(SubscriptionPlanModel subscriptionPlanModel) async {
    if (subscriptionPlanModel.id?.isEmpty == true) {
      subscriptionPlanModel.id = const Uuid().v4();
    }
    await firestore.collection(subscriptionPlans).doc(subscriptionPlanModel.id).set(subscriptionPlanModel.toJson()).then((value) async {});
    return subscriptionPlanModel;
  }

  static Future<bool?> setSubscriptionTransaction(SubscriptionHistoryModel subscriptionPlan) async {
    bool isAdded = false;
    await firestore.collection(subscriptionHistory).doc(subscriptionPlan.id).set(subscriptionPlan.toJson()).then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<List<SubscriptionHistoryModel>> getSubscriptionHistory() async {
    List<SubscriptionHistoryModel> subscriptionHistoryList = [];
    await firestore.collection(subscriptionHistory).where('user_id', isEqualTo: MyAppState.currentUser!.id).orderBy('createdAt', descending: true).get().then((value) async {
      if (value.docs.isNotEmpty) {
        for (var element in value.docs) {
          SubscriptionHistoryModel subscriptionHistoryModel = SubscriptionHistoryModel.fromJson(element.data());
          subscriptionHistoryList.add(subscriptionHistoryModel);
        }
      }
    });
    return subscriptionHistoryList;
  }

  static Future<SectionModel?> getSectionsById(String sectionId) async {
    SectionModel? sectionModel;
    await firestore.collection(SECTION).doc(sectionId).get().then((value) {
      sectionModel = SectionModel.fromJson(value.data()!);
    });
    return sectionModel;
  }

  static Future<PayFastModel?> getPayFastSettingData() async {
    PayFastModel? payFastSettingData;
    await firestore.collection(Setting).doc("payFastSettings").get().then((payFastData) {
      debugPrint(payFastData.data().toString());
      try {
        payFastSettingData = PayFastModel.fromJson(payFastData.data()!);
      } catch (error) {
        debugPrint("error>>>122");
        debugPrint(error.toString());
      }
    });
    return payFastSettingData;
  }

  static Future<MercadoPagoModel?> getMercadoPagoSettingData() async {
    MercadoPagoModel? mercadoPagoDataModel;
    await firestore.collection(Setting).doc("MercadoPago").get().then((mercadoPago) {
      try {
        mercadoPagoDataModel = MercadoPagoModel.fromJson(mercadoPago.data()!);
      } catch (error) {
        debugPrint(error.toString());
      }
    });
    return mercadoPagoDataModel;
  }

  static Future<PayPalModel?> getPaypalSettingData() async {
    PayPalModel? paypalDataModel;
    await firestore.collection(Setting).doc("paypalSettings").get().then((paypalData) {
      try {
        paypalDataModel = PayPalModel.fromJson(paypalData.data()!);
      } catch (error) {
        debugPrint(error.toString());
      }
    });
    return paypalDataModel;
  }

  static Future<StripeSettingData?> getStripeSettingData() async {
    StripeSettingData? stripeSettingData;
    await firestore.collection(Setting).doc("stripeSettings").get().then((stripeData) {
      try {
        stripeSettingData = StripeSettingData.fromJson(stripeData.data()!);
      } catch (error) {
        debugPrint(error.toString());
      }
    });
    return stripeSettingData;
  }

  static Future<FlutterWaveModel?> getFlutterWaveSettingData() async {
    FlutterWaveModel? flutterWaveSettingData;
    await firestore.collection(Setting).doc("flutterWave").get().then((flutterWaveData) {
      try {
        flutterWaveSettingData = FlutterWaveModel.fromJson(flutterWaveData.data()!);
      } catch (error) {
        debugPrint("error>>>122");
        debugPrint(error.toString());
      }
    });
    return flutterWaveSettingData;
  }

  static Future<PayStackModel?> getPayStackSettingData() async {
    PayStackModel? payStackSettingData;
    await firestore.collection(Setting).doc("payStack").get().then((payStackData) {
      try {
        payStackSettingData = PayStackModel.fromJson(payStackData.data()!);
      } catch (error) {
        debugPrint("error>>>122");
        debugPrint(error.toString());
      }
    });
    return payStackSettingData;
  }

  static Future<PaytmModel?> getPaytmSettingData() async {
    PaytmModel? paytmSettingData;
    await firestore.collection(Setting).doc("PaytmSettings").get().then((paytmData) {
      try {
        paytmSettingData = PaytmModel.fromJson(paytmData.data()!);
      } catch (error) {
        debugPrint(error.toString());
      }
    });
    return paytmSettingData;
  }

  static Future<WalletSettingModel?> getWalletSettingData() async {
    WalletSettingModel? walletEnable;
    await firestore.collection(Setting).doc('walletSettings').get().then((walletSetting) {
      try {
        walletEnable = WalletSettingModel.fromJson(walletSetting.data()!);
      } catch (e) {
        debugPrint(e.toString());
      }
    });
    return walletEnable;
  }

  static Future<OrangeMoney?> getOrangeMoneySettingData() async {
    OrangeMoney? payStackSettingData;
    await firestore.collection(Setting).doc("orange_money_settings").get().then((payStackData) {
      try {
        payStackSettingData = OrangeMoney.fromJson(payStackData.data()!);
      } catch (error) {
        print(error.toString());
      }
    });
    return payStackSettingData;
  }

  static Future<Xendit?> getXenditSettingData() async {
    Xendit? payStackSettingData;
    await firestore.collection(Setting).doc("xendit_settings").get().then((payStackData) {
      try {
        payStackSettingData = Xendit.fromJson(payStackData.data()!);
      } catch (error) {
        print(error.toString());
      }
    });
    return payStackSettingData;
  }

  static Future<MidTrans?> getMidTransSettingData() async {
    MidTrans? payStackSettingData;
    await firestore.collection(Setting).doc("midtrans_settings").get().then((payStackData) {
      try {
        payStackSettingData = MidTrans.fromJson(payStackData.data()!);
      } catch (error) {
        print(error.toString());
      }
    });
    return payStackSettingData;
  }

  static Future<RazorPayModel?> getRazorPayDemo() async {
    RazorPayModel? userModel;
    await firestore.collection(Setting).doc("razorpaySettings").get().then((user) {
      debugPrint(user.data().toString());
      try {
        userModel = RazorPayModel.fromJson(user.data()!);
      } catch (e) {
        debugPrint('FireStoreUtils.getUserByID failed to parse user object ${user.id}');
      }
    });
    return userModel;
    //yield* razorPayStreamController.stream;
  }

  static Future<bool> userExistOrNot(String uid) async {
    bool isExist = false;

    await firestore.collection(USERS).doc(uid).get().then((value) {
      if (value.exists) {
        isExist = true;
      } else {
        isExist = false;
      }
    }).catchError((error) {
      log("Failed to check user exist: $error");
      isExist = false;
    });
    return isExist;
  }

  static Future<User?> getUserProfile(String uuid) async {
    User? userModel;
    await firestore.collection(USERS).doc(uuid).get().then((value) {
      if (value.exists) {
        userModel = User.fromJson(value.data()!);
        MyAppState.currentUser = userModel;
      }
    });
    return userModel;
  }

  static Future addChat(ConversationModel conversationModel) async {
    return await firestore.collection(ChatWorker).doc(conversationModel.orderId).collection("thread").doc(conversationModel.id).set(conversationModel.toJson()).then((document) {
      return conversationModel;
    });
  }

  static Future addInbox(InboxModel inboxModel) async {
    return await firestore.collection(ChatWorker).doc(inboxModel.orderId).set(inboxModel.toJson()).then((document) {
      return inboxModel;
    });
  }

  static late StreamSubscription<QuerySnapshot> orderChatSeenSubscription;

  static void setSeenChatForOrder({required String orderId}) {
    orderChatSeenSubscription =
        firestore.collection("chat").doc(orderId).collection("thread").where('senderId', isNotEqualTo: FireStoreUtils.getCurrentUid()).where('seen', isEqualTo: false).snapshots().listen(
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

  static late StreamSubscription<QuerySnapshot> adminChatSeenSubscription;

  static void setSeen() {
    final currentUserId = FireStoreUtils.getCurrentUid();

    adminChatSeenSubscription = firestore.collection("chat").doc(currentUserId).collection("thread").where('senderId', isEqualTo: adminType).where('seen', isEqualTo: false).snapshots().listen(
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
