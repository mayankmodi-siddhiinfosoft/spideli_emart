import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/model/inbox_model.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/themes/app_them_data.dart';
import 'package:spideliworker/themes/responsive.dart';
import 'package:spideliworker/ui/chat_screen/chat_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/widgets/network_image_widget.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeChange.getTheme() ? AppThemeData.surfaceDark : AppThemeData.surface,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          "Woker Inbox".tr,
          textAlign: TextAlign.start,
          style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900),
        ),
      ),
      body: FirestorePagination(
        query: FireStoreUtils.firestore
            .collection("chat")
            .where("sender_receiver_id", arrayContains: FireStoreUtils.getCurrentUid())
            .where('chatType', isEqualTo: userRoleWorker)
            .where('type', isEqualTo: 'orderChat')
            .orderBy('createdAt', descending: true),
        //item builder type is compulsory.
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, documentSnapshots, index) {
          final data = documentSnapshots[index].data() as Map<String, dynamic>?;
          InboxModel inboxModel = InboxModel.fromJson(data!);

          return FutureBuilder<User?>(
            future: FireStoreUtils.getUser(inboxModel.receiverId == FireStoreUtils.getCurrentUid() ? inboxModel.senderId! : inboxModel.receiverId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.hasError || snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox();
              } else {
                User? customer = snapshot.data;
                return InkWell(
                  onTap: () async {
                    ShowToastDialog.showLoader("Please wait".tr);
                    User? worker = await FireStoreUtils.getWorkerCurrentUser(FireStoreUtils.getCurrentUid());
                    User? customer = snapshot.data;
                    ShowToastDialog.closeLoader();
                    Get.to(
                      const ChatScreen(),
                      arguments: {
                        "senderName": worker!.fullName(),
                        "senderId": worker.id,
                        "senderProfileUrl": worker.profilePictureURL,
                        "receivedName": customer?.fullName(),
                        "receivedId": customer?.id,
                        "receivedProfileUrl": customer?.profilePictureURL,
                        "orderId": inboxModel.orderId,
                        "token": worker.fcmToken,
                        "chatType": userRoleWorker,
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Container(
                      decoration: ShapeDecoration(
                        color: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey50,
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
                                          style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: themeChange.getTheme() ? AppThemeData.grey100 : AppThemeData.grey800),
                                        ),
                                      ),
                                      Text(
                                        timestampToDate(inboxModel.createdAt!),
                                        textAlign: TextAlign.start,
                                        style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 16, color: themeChange.getTheme() ? AppThemeData.grey400 : AppThemeData.grey500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "${"Order".tr} ${orderId(orderId: inboxModel.orderId.toString())}",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: themeChange.getTheme() ? AppThemeData.grey200 : AppThemeData.grey700),
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
        onEmpty: showEmptyView(message: "No conversion found".tr, themeChange: themeChange.getTheme()),
        // orderBy is compulsory to enable pagination
        //Change types customerId
        viewType: ViewType.list,
        initialLoader: loader(),
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
//     final themeChange.getTheme() = themeController.themeChange.getTheme().value;
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: themeChange.getTheme() ? AppThemeData.surfaceDark : AppThemeData.surface,
//         centerTitle: false,
//         titleSpacing: 0,
//         title: Text(
//           "Inbox".tr,
//           textAlign: TextAlign.start,
//           style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900),
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

//               User? customer = await FireStoreUtils.getUserById(inboxModel.customerId.toString());
//               User? restaurantUser = await FireStoreUtils.getUserProfile(inboxModel.restaurantId.toString());
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
//                   color: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey50,
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
//                                     style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: themeChange.getTheme() ? AppThemeData.grey100 : AppThemeData.grey800),
//                                   ),
//                                 ),
//                                 Text(
//                                   Constant.timestampToDate(inboxModel.createdAt!),
//                                   textAlign: TextAlign.start,
//                                   style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 16, color: themeChange.getTheme() ? AppThemeData.grey400 : AppThemeData.grey500),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 5),
//                             Text(
//                               "${inboxModel.lastMessage}",
//                               textAlign: TextAlign.start,
//                               style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: themeChange.getTheme() ? AppThemeData.grey200 : AppThemeData.grey700),
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
//         onEmpty: Constant.showEmptyView(message: "No Conversion found".tr, themeChange.getTheme(): themeChange.getTheme()),
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

// class InboxScreen extends StatefulWidget {
//   const InboxScreen({super.key});

//   @override
//   State<InboxScreen> createState() => _InboxScreenState();
// }

// class _InboxScreenState extends State<InboxScreen> {
//   @override
//   Widget build(BuildContext context) {
//     final themeChange = Provider.of<DarkThemeProvider>(context);
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
//         title: Text(
//           'Inbox',
//           style: TextStyle(color: themeChange.getTheme() ? AppColors.colorWhite : Colors.black, fontSize: 18, fontFamily: AppColors.medium),
//         ),
//         leading: InkWell(
//             onTap: () {
//               Get.back();
//             },
//             child: const Icon(
//               Icons.arrow_back,
//             )),
//       ),
//       body: PaginateFirestore(
//         //item builder type is compulsory.
//         shrinkWrap: true,
//         itemBuilder: (context, documentSnapshots, index) {
//           final data = documentSnapshots[index].data() as Map<String, dynamic>?;
//           InboxModel inboxModel = InboxModel.fromJson(data!);
//           return InkWell(
//             onTap: () async {
//               ShowToastDialog.showLoader("Please wait");

//               User? customer = await FireStoreUtils.getUser(inboxModel.customerId.toString());
//               User? provider = await FireStoreUtils.getWorkerCurrentUser(inboxModel.restaurantId.toString());
//               ShowToastDialog.closeLoader();
//               Get.to(ChatScreens(
//                 customerName: "${customer!.firstName} ${customer.lastName}",
//                 restaurantName: "${provider!.firstName!} ${provider.lastName!}",
//                 orderId: inboxModel.orderId,
//                 restaurantId: provider.id,
//                 customerId: customer.id,
//                 customerProfileImage: customer.profilePictureURL,
//                 restaurantProfileImage: provider.profilePictureURL,
//                 token: customer.fcmToken,
//                 chatType: inboxModel.chatType,
//               ));
//             },
//             child: ListTile(
//               leading: ClipOval(
//                 child: CachedNetworkImage(
//                     width: 50,
//                     height: 50,
//                     imageUrl: inboxModel.customerProfileImage.toString(),
//                     imageBuilder: (context, imageProvider) => Container(
//                           width: 50,
//                           height: 50,
//                           decoration: BoxDecoration(
//                               image: DecorationImage(
//                             image: imageProvider,
//                             fit: BoxFit.cover,
//                           )),
//                         ),
//                     errorWidget: (context, url, error) => ClipRRect(
//                         borderRadius: BorderRadius.circular(5),
//                         child: Image.network(
//                           placeholderImage,
//                           fit: BoxFit.cover,
//                         ))),
//               ),
//               title: Row(
//                 children: [
//                   Expanded(child: Text(inboxModel.customerName.toString())),
//                   Text(DateFormat('MMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(inboxModel.createdAt!.millisecondsSinceEpoch)), style: const TextStyle(color: Colors.grey, fontSize: 14)),
//                 ],
//               ),
//               subtitle: Text("Order Id : #${inboxModel.orderId}"),
//             ),
//           );
//         },
//         onEmpty: const Center(child: Text("No Conversion found")),
//         // orderBy is compulsory to enable pagination
//         query: FireStoreUtils.firestore.collection(ChatWorker).where("restaurantId", isEqualTo: MyAppState.currentUser!.id).orderBy('createdAt', descending: true),
//         //Change types customerId
//         itemBuilderType: PaginateBuilderType.listView,
//         // to fetch real-time data
//         isLive: true,
//       ),
//     );
//   }
// }
