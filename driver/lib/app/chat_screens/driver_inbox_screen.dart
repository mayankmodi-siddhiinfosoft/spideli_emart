import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/inbox_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:driver/widget/firebase_pagination/src/models/view_type.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Driver inbox (archetype J): one card per order conversation, with the
/// customer's avatar, the order id and when it was last touched.
class DriverInboxScreen extends StatelessWidget {
  const DriverInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DsScaffold(
      backgroundColor: context.dsColors.background,
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
      body: DsResponsive(
        child: FirestorePagination(
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
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.xs, DsSpace.lg, DsSpace.xs),
                      child: DsSkeletonList(itemCount: 1, padding: EdgeInsets.zero),
                    );
                  } else {
                    UserModel? customerData = snapshot.data;
                    return DsFadeSlideIn(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.xs, DsSpace.lg, DsSpace.xs),
                        child: _InboxCard(
                          name: "${customerData?.fullName()}",
                          imageUrl: customerData?.profilePictureURL ?? '',
                          time: Constant.timestampToDate(inboxModel.createdAt!),
                          orderLabel: "${"Order".tr} ${Constant.orderId(orderId: inboxModel.orderId.toString())}",
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
                        ),
                      ),
                    );
                  }
                });
          },

          shrinkWrap: true,
          onEmpty: DsEmptyState(
            icon: Icons.forum_outlined,
            compact: true,
            title: "No Conversion found".tr,
          ),
          // orderBy is compulsory to enable pagination
          //Change types customerId
          viewType: ViewType.list,
          initialLoader: const DsSkeletonList(),
          // to fetch real-time data
          isLive: true,
        ),
      ),
    );
  }
}

/// One conversation row.
class _InboxCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String time;
  final String orderLabel;
  final VoidCallback onTap;

  const _InboxCard({required this.name, required this.imageUrl, required this.time, required this.orderLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpace.md),
      child: Row(
        children: [
          DsAvatar(imageUrl: imageUrl, name: name, size: 48),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        textAlign: TextAlign.start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSm.w600,
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    Text(
                      time,
                      textAlign: TextAlign.start,
                      style: t.caption.tabular,
                    ),
                  ],
                ),
                const DsGap(DsSpace.xs),
                Text(
                  orderLabel,
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySm.tabular,
                ),
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          Icon(Icons.chevron_right_rounded, color: context.dsColors.textMuted),
        ],
      ),
    );
  }
}
