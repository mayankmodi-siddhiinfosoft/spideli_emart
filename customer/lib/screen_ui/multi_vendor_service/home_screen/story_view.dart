import 'package:customer/constant/constant.dart';
import 'package:customer/models/story_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/widget/story_view/controller/story_controller.dart';
import 'package:customer/widget/story_view/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../service/fire_store_utils.dart';
import '../../../widget/story_view/widgets/story_view.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

// ignore: must_be_immutable
class MoreStories extends StatefulWidget {
  final List<StoryModel> storyList;
  int index;

  MoreStories({super.key, required this.index, required this.storyList});

  @override
  MoreStoriesState createState() => MoreStoriesState();
}

class MoreStoriesState extends State<MoreStories> {
  StoryController storyController = StoryController();

  @override
  void dispose() {
    storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe to next story
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            if (widget.index < widget.storyList.length - 1) {
              setState(() {
                storyController.dispose();
                storyController = StoryController();
              });
              setState(() {
                widget.index++;
              });
            } else {
              Navigator.pop(context);
            }
          }

          // Swipe to previous story
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            if (widget.index > 0) {
              setState(() {
                storyController.dispose();
                storyController = StoryController();
              });
              setState(() {
                widget.index--;
              });
            }
          }
        },
        child: Stack(
          children: [
            StoryView(
              key: ValueKey(widget.index),
              storyItems:
                  List.generate(widget.storyList[widget.index].videoUrl.length, (i) {
                    return StoryItem.pageVideo(widget.storyList[widget.index].videoUrl[i], controller: storyController);
                  }).toList(),
              onComplete: () {
                debugPrint("--------->");
                debugPrint(widget.storyList.length.toString());
                debugPrint(widget.index.toString());
                if (widget.storyList.length - 1 != widget.index) {
                  setState(() {
                    widget.index = widget.index + 1;
                  });
                } else {
                  Navigator.pop(context);
                }
              },
              progressPosition: ProgressPosition.top,
              repeat: true,
              controller: storyController,
              onVerticalSwipeComplete: (direction) {
                if (direction == Direction.down) {
                  Navigator.pop(context);
                }
              },
            ),
            // Top scrim keeps the store header legible over bright video.
            IgnorePointer(
              child: Container(
                height: MediaQuery.of(context).viewPadding.top + 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top + 30, left: 16, right: 16),
              child: FutureBuilder(
                future: FireStoreUtils.getVendorById(widget.storyList[widget.index].vendorID.toString()),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox();
                  } else {
                    if (snapshot.hasError) {
                      return Center(child: Text('${"Error".tr}: ${snapshot.error}', style: context.dsText.bodySm.withColor(Colors.white)));
                    } else if (snapshot.data == null) {
                      return const SizedBox();
                    } else {
                      VendorModel vendorModel = snapshot.data!;
                      return _StoryHeader(vendorModel: vendorModel);
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Store header shown over the story video: avatar, name, rating and close.
class _StoryHeader extends StatelessWidget {
  final VendorModel vendorModel;
  const _StoryHeader({required this.vendorModel});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DsPressable(
            onTap: () {
              Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DsAvatar(imageUrl: vendorModel.photo.toString(), name: vendorModel.title.toString(), size: 46, ring: true),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendorModel.title.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm.withColor(Colors.white).w700),
                      const DsGap(DsSpace.xxs),
                      Row(
                        children: [
                          SvgPicture.asset("assets/icons/ic_star.svg", width: 14, height: 14),
                          const DsGap(DsSpace.xs),
                          Flexible(
                            child: Text(
                              "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum.toString())} ${'reviews'.tr}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.caption.withColor(Colors.white.withValues(alpha: 0.9)).tabular,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const DsGap(DsSpace.sm),
        DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.16)),
          child: DsIconButton(
            icon: Icons.close_rounded,
            semanticLabel: "Close".tr,
            color: Colors.white,
            onPressed: () async {
              Get.back();
            },
          ),
        ),
      ],
    );
  }
}
