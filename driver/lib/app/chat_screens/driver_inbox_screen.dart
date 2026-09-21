import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/inbox_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:driver/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:driver/widget/firebase_pagination/src/models/view_type.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DriverInboxScreen extends StatelessWidget {
  const DriverInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      //   centerTitle: false,
      //   titleSpacing: 0,
      //   title: Text(
      //     "Driver Inbox".tr,
      //     textAlign: TextAlign.start,
      //     style: TextStyle(
      //       fontFamily: AppThemeData.medium,
      //       fontSize: 16,
      //       color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
      //     ),
      //   ),
      // ),
      body: FirestorePagination(
        query: FireStoreUtils.fireStore
            .collection(CollectionName.chat)
            .where("sender_receiver_id", arrayContains: FireStoreUtils.getCurrentUid())
            .where('chatType', isEqualTo: Constant.userRoleDriver)
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
                  UserModel? customerData = snapshot.data;
                  return InkWell(
                    onTap: () async {
                      ShowToastDialog.showLoader("Please wait".tr);
                      UserModel? driverData = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());

                      ShowToastDialog.closeLoader();

                      Get.to(const ChatScreen(), arguments: {
                        "senderName": driverData!.fullName(),
                        "senderId": driverData.id,
                        "senderProfileUrl": driverData.profilePictureURL,
                        "receivedName": customerData!.fullName(),
                        "receivedId": customerData.id,
                        "receivedProfileUrl": customerData.profilePictureURL,
                        "orderId": inboxModel.orderId,
                        "token": customerData.fcmToken,
                        "chatType": Constant.userRoleDriver,
                      });
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
                                child: NetworkImageWidget(
                                  imageUrl: customerData?.profilePictureURL ?? '',
                                  fit: BoxFit.cover,
                                  height: Responsive.height(6, context),
                                  width: Responsive.width(12, context),
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "${customerData?.fullName()}",
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                              fontFamily: AppThemeData.semiBold,
                                              fontSize: 16,
                                              color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          Constant.timestampToDate(inboxModel.createdAt!),
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            fontFamily: AppThemeData.regular,
                                            fontSize: 16,
                                            color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Text(
                                      "${"Order".tr} ${Constant.orderId(orderId: inboxModel.orderId.toString())}",
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        fontFamily: AppThemeData.medium,
                                        fontSize: 14,
                                        color: isDark ? AppThemeData.grey200 : AppThemeData.grey700,
                                      ),
                                    )
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
              });
        },

        shrinkWrap: true,
        onEmpty: Constant.showEmptyView(message: "No Conversion found".tr, isDark: isDark),
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
