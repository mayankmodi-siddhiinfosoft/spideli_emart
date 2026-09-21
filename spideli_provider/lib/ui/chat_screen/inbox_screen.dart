import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/model/inbox_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/app_them_data.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/ui/chat_screen/chat_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/firebase_pagination/firebase_pagination.dart';
import 'package:spideliprovider/widgets/firebase_pagination/src/firestore_pagination.dart';
import 'package:spideliprovider/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Scaffold(
      body: FirestorePagination(
        query: FireStoreUtils.firestore
            .collection("chat")
            .where("sender_receiver_id", arrayContains: FireStoreUtils.getCurrentUid())
            .where('chatType', isEqualTo: userRoleProvider)
            .where('type', isEqualTo: 'orderChat')
            .orderBy('createdAt', descending: true),
        //item builder type is compulsory.
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, documentSnapshots, index) {
          final data = documentSnapshots[index].data() as Map<String, dynamic>?;
          InboxModel inboxModel = InboxModel.fromJson(data!);

          return FutureBuilder<User?>(
            future: FireStoreUtils.getCurrentUser(inboxModel.receiverId == FireStoreUtils.getCurrentUid() ? inboxModel.senderId! : inboxModel.receiverId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.hasError || snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox();
              } else {
                User? customer = snapshot.data;
                return InkWell(
                  onTap: () async {
                    ShowToastDialog.showLoader("Please wait".tr);
                    User? worker = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
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
                        "chatType": userRoleProvider,
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
        onEmpty: showEmptyView(
          message: "No conversion found".tr,
        ),
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
