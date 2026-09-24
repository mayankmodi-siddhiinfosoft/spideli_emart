import 'dart:developer';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/inbox_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/widgets/chat_widgets.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../widget/firebase_pagination/src/firestore_pagination.dart';
import '../../../widget/firebase_pagination/src/models/view_type.dart';
import 'chat_screen.dart';

/// Archetype **J — inbox**: conversation rows with avatar, order id and time.
class DriverInboxScreen extends StatelessWidget {
  const DriverInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DsScaffold(
      title: "Driver Inbox".tr,
      maxContentWidth: DsLayout.contentMax,
      body: FirestorePagination(
        query: FireStoreUtils.fireStore
            .collection(CollectionName.chat)
            .where("sender_receiver_id", arrayContains: FireStoreUtils.getCurrentUid())
            .where('chatType', isEqualTo: Constant.userRoleDriver)
            .where('type', isEqualTo: 'orderChat')
            .orderBy('createdAt', descending: true),
        //item builder type is compulsory.
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
        itemBuilder: (context, documentSnapshots, index) {
          final data = documentSnapshots[index].data() as Map<String, dynamic>?;
          InboxModel inboxModel = InboxModel.fromJson(data!);
          log("inboxModel :: ${inboxModel.toJson()}");
          return FutureBuilder<UserModel?>(
            future: FireStoreUtils.getUserProfile(inboxModel.receiverId == FireStoreUtils.getCurrentUid() ? inboxModel.senderId! : inboxModel.receiverId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.hasError || snapshot.connectionState == ConnectionState.waiting) {
                return const _InboxRowSkeleton();
              } else {
                UserModel? driver = snapshot.data;
                return DsFadeSlideIn(
                  index: index,
                  child: ChatInboxRow(
                    name: "${driver?.fullName()}",
                    imageUrl: driver?.profilePictureURL,
                    time: Constant.timestampToDate(inboxModel.createdAt!),
                    subtitle: "${"Order".tr} ${Constant.orderId(orderId: inboxModel.orderId.toString())}",
                    onTap: () async {
                      ShowToastDialog.showLoader("Please wait".tr);
                      UserModel? customer = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());

                      ShowToastDialog.closeLoader();

                      Get.to(
                        const ChatScreen(),
                        arguments: {
                          "senderName": '${customer!.fullName()}',
                          "senderId": customer.id,
                          "senderProfileUrl": customer.profilePictureURL,
                          "receivedName": driver!.fullName(),
                          "receivedId": driver.id,
                          "receivedProfileUrl": driver.profilePictureURL,
                          "orderId": inboxModel.orderId,
                          "token": driver.fcmToken,
                          "chatType": Constant.userRoleDriver,
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
        onEmpty: DsEmptyState(icon: Icons.forum_outlined, title: "No Conversion found".tr, message: "Messages with your delivery partners appear here.".tr),
        // orderBy is compulsory to enable pagination
        //Change types customerId
        viewType: ViewType.list,
        initialLoader: const DsSkeletonList(itemCount: 5),
        // to fetch real-time data
        isLive: true,
      ),
    );
  }
}

/// Placeholder while a conversation's profile is being resolved.
class _InboxRowSkeleton extends StatelessWidget {
  const _InboxRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xs),
      child: DsShimmer(
        child: Row(
          children: [
            DsSkeleton.circle(size: 48),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: double.infinity, child: DsSkeleton.line(height: 14)),
                  const DsGap(DsSpace.sm),
                  DsSkeleton.line(width: 140),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
