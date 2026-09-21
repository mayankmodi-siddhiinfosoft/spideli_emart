import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/coupon_controller.dart';
import 'package:spideliprovider/model/coupon_model.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/ui/coupon/add_or_update_coupon.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class CouponList extends StatelessWidget {
  const CouponList({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetBuilder<CouponController>(
        init: CouponController(),
        builder: (controller) {
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: controller.couponModel.isEmpty
                  ? emptyView(text: "Coupon not found", themeChange: themeChange)
                  : ListView.builder(
                      itemCount: controller.couponModel.length,
                      scrollDirection: Axis.vertical,
                      itemBuilder: (context, index) {
                        CouponModel couponModel = controller.couponModel[index];
                        return GestureDetector(
                          onTap: () {
                            Get.to(AddOrUpdateCouponScreen(), arguments: {'couponModel': couponModel})!.then((value) {
                              if (value != null) {
                                controller.getCouponData();
                              }
                            });
                          },
                          child: Stack(
                            alignment: Alignment.bottomLeft,
                            children: [
                              Container(
                                margin: EdgeInsets.fromLTRB(10, 5, 10, 5),
                                padding: EdgeInsets.fromLTRB(7, 7, 7, 7),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                  color: themeChange.getTheme() ? AppColors.colorDark : Colors.white,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: new BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: couponModel.image!.isEmpty ? "" : couponModel.image!,
                                        height: 100,
                                        width: 100,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) => Container(
                                          width: 100,
                                          height: 100,
                                          decoration: new BoxDecoration(
                                            borderRadius: new BorderRadius.circular(10),
                                            color: Colors.black12,
                                          ),
                                          child: Image(
                                            image: index % 2 == 0 ? AssetImage("assets/images/offer_placeholder_1.png") : AssetImage("assets/images/offer_placeholder_2.png"),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        placeholder: (context, url) => Padding(
                                          padding: const EdgeInsets.all(32.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 15,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            height: 10,
                                          ),
                                          DottedBorder(
                                            options: RoundedRectDottedBorderOptions(
                                              radius: Radius.circular(2),
                                              padding: EdgeInsets.all(2),
                                              color: AppColors.couponBgColor,
                                              strokeWidth: 2,
                                              dashPattern: [5],
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                                              child: Text(
                                                couponModel.code!,
                                                textAlign: TextAlign.left,
                                                style: TextStyle(fontSize: 17, fontFamily: AppColors.medium, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppColors.colorPrimary),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 15,
                                          ),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Image(
                                                image: AssetImage('assets/images/offer_icon.png'),
                                                height: 25,
                                                width: 25,
                                              ),
                                              SizedBox(
                                                width: 10,
                                              ),
                                              Expanded(
                                                  child: Text("This offer is expire on".tr + " " + dateFormatDDMMMYYYY(couponModel.expiresAt!.toDate().toString())!,
                                                      style: TextStyle(fontSize: 15, fontFamily: AppColors.medium, letterSpacing: 0.5, color: Color(0Xff696A75))))
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.bottomStart,
                                child: Container(
                                  child: Stack(
                                    alignment: Alignment.topCenter,
                                    children: [
                                      Container(width: 75, margin: EdgeInsets.only(bottom: 10), child: Image(image: AssetImage("assets/images/offer_badge.png"))),
                                      Container(
                                        margin: EdgeInsets.only(top: 3),
                                        child: Text(
                                          couponModel.discountType == "Fix Price"
                                              ? (currencyData!.symbolatright == true)
                                                  ? "${couponModel.discount}${currencyData!.symbol.toString()} OFF"
                                                  : "${currencyData!.symbol.toString()}${couponModel.discount} OFF"
                                              : "${couponModel.discount} % Off",
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.7),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        );
                      }),
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: AppColors.colorPrimary,
              onPressed: () {
                Get.to(AddOrUpdateCouponScreen())!.then((value) {
                  if (value != null) {
                    controller.getCouponData();
                  }
                });
              },
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
            ),
          );
        });
  }
}
