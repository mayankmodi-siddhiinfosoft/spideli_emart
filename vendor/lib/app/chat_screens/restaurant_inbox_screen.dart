import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/chat_screens/chat_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/inbox_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:vendor/widget/firebase_pagination/src/models/view_type.dart';

class RestaurantInboxScreen extends StatelessWidget {
  const RestaurantInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          "Restaurant Inbox".tr,
          textAlign: TextAlign.start,
          style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
        ),
      ),
      body: FirestorePagination(
        query: FireStoreUtils.fireStore
            .collection(CollectionName.chat)
            .where("sender_receiver_id", arrayContains: FireStoreUtils.getCurrentUid())
            .where('chatType', isEqualTo: Constant.userRoleVendor)
            .where('type', isEqualTo: 'orderChat')
            .orderBy('createdAt', descending: true),
        //item builder type is compulsory.
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, documentSnapshots, index) {
          final data = documentSnapshots[index].data() as Map<String, dynamic>?;
          InboxModel inboxModel = InboxModel.fromJson(data!);

          return FutureBuilder<UserModel?>(
            future: FireStoreUtils.getUserProfile(inboxModel.receiverId == FireStoreUtils.getCurrentUid() ? inboxModel.senderId! : inboxModel.receiverId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.hasError || snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox();
              } else {
                UserModel? customer = snapshot.data;
                return InkWell(
                  onTap: () async {
                    ShowToastDialog.showLoader("Please wait".tr);
                    UserModel? restaurant = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
                    UserModel? customer = snapshot.data;
                    ShowToastDialog.closeLoader();
                    log("receivedId.value :: ${customer?.id}");
                    Get.to(
                      const ChatScreen(),
                      arguments: {
                        "senderName": restaurant?.fullName(),
                        "senderId": restaurant?.id,
                        "senderProfileUrl": restaurant?.profilePictureURL,
                        "receivedName": customer?.fullName(),
                        "receivedId": customer?.id,
                        "receivedProfileUrl": customer?.profilePictureURL,
                        "orderId": inboxModel.orderId,
                        "token": restaurant?.fcmToken,
                        "chatType": Constant.userRoleVendor,
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Container(
                      decoration: ShapeDecoration(
                        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(10)),
                              child: NetworkImageWidget(imageUrl: customer?.profilePictureURL ?? '', fit: BoxFit.cover, height: Responsive.height(6, context), width: Responsive.width(12, context)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "${customer?.fullName()}",
                                          textAlign: TextAlign.start,
                                          style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                        ),
                                      ),
                                      Text(
                                        Constant.timestampToDate(inboxModel.createdAt!),
                                        textAlign: TextAlign.start,
                                        style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 16, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "${"Order".tr} ${Constant.orderId(orderId: inboxModel.orderId.toString())}",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey200 : AppThemeData.grey700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
          );
        },

        shrinkWrap: true,
        onEmpty: Constant.showEmptyView(message: "No conversion found".tr, isDark: isDark),
        // orderBy is compulsory to enable pagination
        //Change types customerId
        viewType: ViewType.list,
        initialLoader: Constant.loader(),
        // to fetch real-time data
        isLive: true,
      ),
    );
  }
}

// class RestaurantInboxScreen extends StatelessWidget {
//   const RestaurantInboxScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final themeController = Get.find<ThemeController>();
//     final isDark = themeController.isDark.value;
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
//         centerTitle: false,
//         titleSpacing: 0,
//         title: Text(
//           "Inbox".tr,
//           textAlign: TextAlign.start,
//           style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
//         ),
//       ),
//       body: FirestorePagination(
//         //item builder type is compulsory.
//         physics: const BouncingScrollPhysics(),
//         itemBuilder: (context, documentSnapshots, index) {
//           final data = documentSnapshots[index].data() as Map<String, dynamic>?;
//           InboxModel inboxModel = InboxModel.fromJson(data!);
//           return InkWell(
//             onTap: () async {
//               ShowToastDialog.showLoader("Please wait".tr);

//               UserModel? customer = await FireStoreUtils.getUserById(inboxModel.customerId.toString());
//               UserModel? restaurantUser = await FireStoreUtils.getUserProfile(inboxModel.restaurantId.toString());
//               VendorModel? vendorModel = await FireStoreUtils.getVendorById(restaurantUser!.vendorID.toString());
//               ShowToastDialog.closeLoader();

//               Get.to(
//                 const ChatScreen(),
//                 arguments: {
//                   "customerName": customer!.fullName(),
//                   "restaurantName": vendorModel!.title,
//                   "orderId": inboxModel.orderId,
//                   "restaurantId": restaurantUser.id,
//                   "customerId": customer.id,
//                   "customerProfileImage": customer.profilePictureURL,
//                   "restaurantProfileImage": vendorModel.photo,
//                   "token": customer.fcmToken,
//                   "chatType": inboxModel.chatType,
//                 },
//               );
//             },
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
//               child: Container(
//                 decoration: ShapeDecoration(
//                   color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Row(
//                     children: [
//                       ClipRRect(
//                         borderRadius: const BorderRadius.all(Radius.circular(10)),
//                         child: NetworkImageWidget(imageUrl: inboxModel.customerProfileImage.toString(), fit: BoxFit.cover, height: Responsive.height(6, context), width: Responsive.width(12, context)),
//                       ),
//                       const SizedBox(width: 10),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: Text(
//                                     "${inboxModel.customerName}",
//                                     textAlign: TextAlign.start,
//                                     style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
//                                   ),
//                                 ),
//                                 Text(
//                                   Constant.timestampToDate(inboxModel.createdAt!),
//                                   textAlign: TextAlign.start,
//                                   style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 16, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 5),
//                             Text(
//                               "${inboxModel.lastMessage}",
//                               textAlign: TextAlign.start,
//                               style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey200 : AppThemeData.grey700),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//         shrinkWrap: true,
//         onEmpty: Constant.showEmptyView(message: "No Conversion found".tr, isDark: isDark),
//         // orderBy is compulsory to enable pagination
//         query: FireStoreUtils.fireStore.collection('chat_store').where("restaurantId", isEqualTo: FireStoreUtils.getCurrentUid()).orderBy('createdAt', descending: true),
//         //Change types customerId
//         initialLoader: Constant.loader(),
//         // to fetch real-time data
//         isLive: true,
//         viewType: ViewType.list,
//       ),
//     );
//   }
// }
