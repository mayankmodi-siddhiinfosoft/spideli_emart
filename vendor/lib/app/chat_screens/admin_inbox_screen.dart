import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/chat_screens/chat_screen.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/advertisement_model.dart';
import 'package:vendor/models/inbox_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:vendor/widget/firebase_pagination/src/models/view_type.dart';

class AdminInboxScreen extends StatelessWidget {
  const AdminInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsScaffold(
      title: "Admin Chat Inbox".tr,
      maxContentWidth: DsLayout.contentMax,
      body: FirestorePagination(
        //item builder type is compulsory.
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.xxl),
        itemBuilder: (context, documentSnapshots, index) {
          final data = documentSnapshots[index].data() as Map<String, dynamic>?;
          InboxModel inboxModel = InboxModel.fromJson(data!);
          return DsFadeSlideIn(
            index: index,
            child: DsCard.outlined(
              margin: const EdgeInsets.only(bottom: DsSpace.md),
              padding: const EdgeInsets.all(DsSpace.md),
              onTap: () async {
                ShowToastDialog.showLoader("Please wait".tr);
                VendorModel? vendorModel = await FireStoreUtils.getVendorById(Constant.userModel!.vendorID.toString());
                ShowToastDialog.closeLoader();

                Get.to(
                  const ChatScreen(),
                  arguments: {
                    "senderName": vendorModel?.title,
                    "senderId": Constant.userModel?.id,
                    "senderProfileUrl": vendorModel?.photo,
                    "receivedName": 'Admin',
                    "receivedId": 'admin',
                    "receivedProfileUrl": '',
                    "orderId": inboxModel.orderId,
                    "token": '',
                    "chatType": 'admin',
                  },
                );
              },
              child: FutureBuilder(
                future: FireStoreUtils.getAdvertisementById(advertisementId: inboxModel.orderId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    AdvertisementModel advertisementModel = snapshot.data!;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            DsImage(url: advertisementModel.profileImage.toString(), width: 64, height: 64, radius: DsRadius.md),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                                child: DsIconWell(icon: Icons.support_agent_rounded, size: 22, circle: true),
                              ),
                            ),
                          ],
                        ),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "${advertisementModel.title}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.titleSm.withColor(c.textPrimary),
                                    ),
                                  ),
                                  const DsGap(DsSpace.sm),
                                  Text(Constant.timestampToDate(inboxModel.createdAt!), style: t.caption),
                                ],
                              ),
                              const DsGap(DsSpace.xs),
                              Text(
                                "${inboxModel.lastMessage}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySm.withColor(c.textSecondary),
                              ),
                              const DsGap(DsSpace.sm),
                              DsBadge(label: 'Admin'.tr, tone: DsTone.info, icon: Icons.campaign_outlined, small: true),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return DsShimmer(
                      child: Row(
                        children: [
                          DsSkeleton.box(width: 64, height: 64),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [DsSkeleton.line(width: 150), const DsGap(DsSpace.sm), DsSkeleton.line(width: 200), const DsGap(DsSpace.sm), DsSkeleton.line(width: 60)],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          );
        },
        shrinkWrap: true,
        onEmpty: DsEmptyState(icon: Icons.support_agent_rounded, title: "No Conversion found".tr),
        // orderBy is compulsory to enable pagination
        query: FireStoreUtils.fireStore.collection(CollectionName.chatAdmin).where("restaurantId", isEqualTo: FireStoreUtils.getCurrentUid()).orderBy('createdAt', descending: true),
        //Change types customerId
        initialLoader: const DsSkeletonList(itemCount: 6),
        bottomLoader: const Padding(padding: EdgeInsets.all(DsSpace.lg), child: Center(child: DsSpinner())),
        // to fetch real-time data
        isLive: true,
        viewType: ViewType.list,
      ),
    );
  }
}
