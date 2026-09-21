import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/all_workers_controller.dart';
import 'package:spideliprovider/controller/dashboard_controller.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/ui/add_worker/add_or_update_worker.dart';
import 'package:spideliprovider/ui/dashboard/dashboard_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class AllWorkersScreen extends StatelessWidget {
  const AllWorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<AllWorkersController>(
        init: AllWorkersController(),
        builder: (controller) {
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: controller.user.isEmpty
                  ? Center(child: emptyView(text: 'Worker not available.'.tr, themeChange: themeChange))
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: controller.user.length,
                      itemBuilder: (context, index) {
                        return buildCategoryItem(controller.user[index], context, controller, themeChange);
                      },
                    ),
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: AppColors.colorPrimary,
              onPressed: () {
                Get.to(const AddOrUpdateWorkerScreen())!.then((value) {
                  if (value != null) {
                    controller.getData();
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

  buildCategoryItem(User model, BuildContext context, controller, themeChange) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTap: () async {
          Get.to(const AddOrUpdateWorkerScreen(), arguments: {
            "User": model,
          })!
              .then((value) {
            if (value != null) {
              controller.getData();
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300, width: 1),
            color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorLightGrey,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: model.profilePictureURL != ''
                            ? DecorationImage(
                                image: NetworkImage(model.profilePictureURL.toString()),
                                fit: BoxFit.cover,
                              )
                            : DecorationImage(
                                image: NetworkImage(placeholderImage),
                                fit: BoxFit.cover,
                              ),
                      )),
                ),
                SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        model.firstName + ' ' + model.lastName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        showWorkerDeleteDialog(model, context, controller);
                                      },
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          color: Colors.red,
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  model.email,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Text(
                                  amountShow(amount: model.salary!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          model.online == false ? "Offline".tr : "Online".tr,
                          style: TextStyle(
                            color: model.online == false ? Colors.red : Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
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

  showWorkerDeleteDialog(User User, BuildContext context, controller) {
    Widget okButton = TextButton(
      child: Text(
        "Ok".tr,
      ),
      onPressed: () async {
        ShowToastDialog.showLoader("Please wait".tr);

        FireStoreUtils.deleteWorker(User.id).then((value) async {
          ShowToastDialog.closeLoader();
          controller.getData();
          DashBoardController dashBoardController = Get.put(DashBoardController());
          dashBoardController.onSelectItem(2);
          await Get.to(const DashBoardScreen());
        });
      },
    );
    Widget cancel = TextButton(
      child: Text("Cancel".tr),
      onPressed: () {
        Get.back();
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text(User.fullName()),
      content: Text('Are you sure you want to delete this worker?'.tr),
      actions: [
        okButton,
        cancel,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}
