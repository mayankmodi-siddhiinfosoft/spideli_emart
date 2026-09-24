import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/inbox_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/chat_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/widget/firebase_pagination/src/fireStore_pagination.dart';
import 'package:customer/widget/firebase_pagination/src/models/view_type.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../service/fire_store_utils.dart';
import '../../themes/show_toast_dialog.dart';
import 'widgets/inbox_widgets.dart';

class WorkerInboxScreen extends StatelessWidget {
  const WorkerInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DsScaffold(
      title: "Worker Inbox".tr,
      subtitle: "Order conversations".tr,
      body: FirestorePagination(
        query: FireStoreUtils.fireStore
            .collection(CollectionName.chat)
            .where("sender_receiver_id", arrayContains: FireStoreUtils.getCurrentUid())
            .where('chatType', isEqualTo: Constant.userRoleWorker)
            .where('type', isEqualTo: 'orderChat')
            .orderBy('createdAt', descending: true),
        //item builder type is compulsory.
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, documentSnapshots, index) {
          final data = documentSnapshots[index].data() as Map<String, dynamic>?;
          InboxModel inboxModel = InboxModel.fromJson(data!);

          return FutureBuilder<UserModel?>(
            future: FireStoreUtils.getUserForChat(inboxModel.receiverId == FireStoreUtils.getCurrentUid() ? inboxModel.senderId! : inboxModel.receiverId!),
            builder: (context, snapshot) {
              if (snapshot.hasData == false || snapshot.hasError || snapshot.connectionState == ConnectionState.waiting) {
                return const InboxRowSkeleton();
              } else {
                UserModel? restaurant = snapshot.data;

                return DsFadeSlideIn(
                  index: index,
                  child: InboxRow(
                    name: "${restaurant?.fullName()}",
                    imageUrl: restaurant?.profilePictureURL ?? '',
                    time: Constant.timestampToDate(inboxModel.createdAt!),
                    orderLabel: "${"Order".tr} ${Constant.orderId(orderId: inboxModel.orderId.toString())}",
                    onTap: () async {
                      ShowToastDialog.showLoader("Please wait".tr);
                      UserModel? customer = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());

                      ShowToastDialog.closeLoader();

                      Get.to(
                        const ChatScreen(),
                        arguments: {
                          "senderName": customer!.fullName(),
                          "senderId": customer.id,
                          "senderProfileUrl": customer.profilePictureURL,
                          "receivedName": restaurant?.fullName(),
                          "receivedId": restaurant?.id,
                          "receivedProfileUrl": restaurant?.profilePictureURL,
                          "orderId": inboxModel.orderId,
                          "token": restaurant?.fcmToken,
                          "chatType": Constant.userRoleWorker,
                        },
                      );
                    },
                  ),
                );
              }
            },
          );
        },

        shrinkWrap: true,
        onEmpty: DsEmptyState(icon: Icons.forum_outlined, title: "No Conversion found".tr, message: "Messages with the assigned workers will appear here.".tr),
        // orderBy is compulsory to enable pagination
        //Change types customerId
        viewType: ViewType.list,
        initialLoader: const InboxListSkeleton(),
        // to fetch real-time data
        isLive: true,
      ),
    );
  }
}
