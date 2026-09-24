import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/model/inbox_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/chat_screen/chat_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/firebase_pagination/firebase_pagination.dart';
import 'package:spideliprovider/widgets/firebase_pagination/src/firestore_pagination.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    return Scaffold(
      backgroundColor: c.background,
      body: FirestorePagination(
        query: FireStoreUtils.firestore
            .collection("chat")
            .where("sender_receiver_id", arrayContains: FireStoreUtils.getCurrentUid())
            .where('chatType', isEqualTo: userRoleProvider)
            .where('type', isEqualTo: 'orderChat')
            .orderBy('createdAt', descending: true),
        //item builder type is compulsory.
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(context.dsLayout.gutter, DsSpace.lg, context.dsLayout.gutter, DsSpace.xxxl),
        itemBuilder: (context, documentSnapshots, index) {
          final data = documentSnapshots[index].data() as Map<String, dynamic>?;
          InboxModel inboxModel = InboxModel.fromJson(data!);

          return FutureBuilder<User?>(
            future: FireStoreUtils.getCurrentUser(inboxModel.receiverId == FireStoreUtils.getCurrentUid() ? inboxModel.senderId! : inboxModel.receiverId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.hasError || snapshot.connectionState == ConnectionState.waiting) {
                // Keep the row height while the customer profile resolves.
                return const _InboxRowSkeleton();
              } else {
                User? customer = snapshot.data;
                return DsFadeSlideIn(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.md),
                    child: DsCard.outlined(
                      padding: const EdgeInsets.all(DsSpace.md),
                      semanticLabel: "${customer?.fullName()}",
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
                      child: Row(
                        children: [
                          DsAvatar(imageUrl: customer?.profilePictureURL ?? '', name: customer?.fullName(), size: 52),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text("${customer?.fullName()}", textAlign: TextAlign.start, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                                    ),
                                    const DsGap(DsSpace.sm),
                                    Text(timestampToDate(inboxModel.createdAt!), textAlign: TextAlign.start, style: t.caption),
                                  ],
                                ),
                                const DsGap(DsSpace.xs),
                                Row(
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 14, color: c.textMuted),
                                    const DsGap(DsSpace.xs),
                                    Expanded(
                                      child: Text(
                                        "${"Order".tr} ${orderId(orderId: inboxModel.orderId.toString())}",
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.bodySm,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.sm),
                          Icon(Icons.chevron_right_rounded, color: c.textMuted),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          );
        },

        shrinkWrap: true,
        onEmpty: DsEmptyState(icon: Icons.forum_outlined, title: "No conversion found".tr),
        // orderBy is compulsory to enable pagination
        //Change types customerId
        viewType: ViewType.list,
        initialLoader: const DsSkeletonList(itemCount: 6, carded: true, trailing: false),
        // to fetch real-time data
        isLive: true,
      ),
    );
  }
}

/// Placeholder with the same shape as an inbox row, used while the
/// conversation's customer profile is being fetched.
class _InboxRowSkeleton extends StatelessWidget {
  const _InboxRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: DsCard.outlined(
        padding: const EdgeInsets.all(DsSpace.md),
        child: DsShimmer(
          child: Row(
            children: [
              DsSkeleton.circle(size: 52),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [DsSkeleton.line(width: 140, height: 14), const DsGap(DsSpace.sm), DsSkeleton.line(width: 100)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
