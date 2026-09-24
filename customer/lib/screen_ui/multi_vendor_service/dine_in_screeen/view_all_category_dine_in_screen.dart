import 'package:customer/controllers/view_all_category_controller.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../home_screen/category_restaurant_screen.dart';
import 'widgets/dine_in_widgets.dart';

/// Cuisine directory — an adaptive grid of circular category tiles that grows
/// from 4 columns on a phone to 5+ on a tablet.
class ViewAllCategoryDineInScreen extends StatelessWidget {
  const ViewAllCategoryDineInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ViewAllCategoryController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final List<VendorCategoryModel> categories = controller.vendorCategoryModel.toList();

        return DsScaffold(
          maxContentWidth: DsLayout.wideMax,
          appBar: DsAppBar(title: "Categories".tr, subtitle: isLoading || categories.isEmpty ? null : '${categories.length}'),
          body: isLoading
              ? const SingleChildScrollView(child: DsSkeletonGrid(minItemWidth: 100))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
                  gridDelegate: DsLayout.gridDelegate(maxItemWidth: 110, mainAxisExtent: 128, spacing: DsSpace.md),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    VendorCategoryModel vendorCategoryModel = categories[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: DineInCategoryTile(
                        photo: vendorCategoryModel.photo.toString(),
                        title: '${vendorCategoryModel.title}',
                        maxLines: 2,
                        onTap: () {
                          Get.to(const CategoryRestaurantScreen(), arguments: {"vendorCategoryModel": vendorCategoryModel, "dineIn": true});
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
