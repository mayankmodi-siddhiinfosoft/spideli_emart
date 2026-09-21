import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/FlutterWaveSettingDataModel.dart';
import 'package:spideliprovider/model/paypalSettingData.dart';
import 'package:spideliprovider/model/razorpayKeyModel.dart';
import 'package:spideliprovider/model/stripeSettingData.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/model/withdraw_method_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/ui/bank_details/enter_bank_details_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({Key? key}) : super(key: key);

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  WithdrawMethodModel? withdrawMethodModel = WithdrawMethodModel();

  final accountNumberFlutterWave = TextEditingController();
  final bankCodeFlutterWave = TextEditingController();

  final emailPaypal = TextEditingController();
  final accountIdRazorPay = TextEditingController();
  final accountIdStripe = TextEditingController();

  UserBankDetails? userBankDetails;
  bool isBankDetailsAdded = false;

  void initState() {
    getPaymentSetting();
    getPaymentMethod();
    super.initState();
  }

  bool isLoading = true;
  RazorPayModel? razorPayModel;
  PaypalSettingData? paypalDataModel;
  StripeSettingData? stripeSettingData;
  FlutterWaveSettingData? flutterWaveSettingData;

  getPaymentSetting() async {
    setState(() {
      isLoading = true;
    });
    await FireStoreUtils.firestore.collection(Setting).doc("razorpaySettings").get().then((user) {
      debugPrint(user.data().toString());
      try {
        razorPayModel = RazorPayModel.fromJson(user.data() ?? {});
      } catch (e) {
        debugPrint('FireStoreUtils.getUserByID failed to parse user object ${user.id}');
      }
    });

    await FireStoreUtils.firestore.collection(Setting).doc("paypalSettings").get().then((paypalData) {
      try {
        paypalDataModel = PaypalSettingData.fromJson(paypalData.data() ?? {});
      } catch (error) {
        debugPrint(error.toString());
      }
    });

    await FireStoreUtils.firestore.collection(Setting).doc("stripeSettings").get().then((paypalData) {
      try {
        stripeSettingData = StripeSettingData.fromJson(paypalData.data() ?? {});
      } catch (error) {
        debugPrint(error.toString());
      }
    });

    await FireStoreUtils.firestore.collection(Setting).doc("flutterWave").get().then((paypalData) {
      try {
        flutterWaveSettingData = FlutterWaveSettingData.fromJson(paypalData.data() ?? {});
      } catch (error) {
        debugPrint(error.toString());
      }
    });
    setState(() {
      isLoading = false;
    });
  }

  getPaymentMethod() async {
    setState(() {
      isLoading = true;
    });
    accountNumberFlutterWave.clear();
    bankCodeFlutterWave.clear();
    emailPaypal.clear();
    accountIdRazorPay.clear();
    accountIdStripe.clear();

    userBankDetails = MyAppState.currentUser!.userBankDetails;
    isBankDetailsAdded = userBankDetails!.accountNumber.isNotEmpty;

    await FireStoreUtils.getWithdrawMethod().then(
      (value) {
        if (value != null) {
          setState(() {
            withdrawMethodModel = value;

            if (withdrawMethodModel!.flutterWave != null) {
              accountNumberFlutterWave.text = withdrawMethodModel!.flutterWave!.accountNumber.toString();
              bankCodeFlutterWave.text = withdrawMethodModel!.flutterWave!.bankCode.toString();
            }

            if (withdrawMethodModel!.paypal != null) {
              emailPaypal.text = withdrawMethodModel!.paypal!.email.toString();
            }

            if (withdrawMethodModel!.razorpay != null) {
              accountIdRazorPay.text = withdrawMethodModel!.razorpay!.accountId.toString();
            }
            if (withdrawMethodModel!.stripe != null) {
              accountIdStripe.text = withdrawMethodModel!.stripe!.accountId.toString();
            }
          });
        }
      },
    );
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          child: isLoading == true
              ? Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // if you need this
                        side: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Image.asset(
                                        "assets/images/ic_bank_line.png",
                                        color: themeChange.getTheme() ? AppColors.colorGrey : null,
                                        height: 20,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text(
                                        "Bank Transfer",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: themeChange.getTheme() ? AppColors.colorGrey : Colors.black, fontSize: 16),
                                      )
                                    ],
                                  ),
                                  isBankDetailsAdded
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            InkWell(
                                              onTap: () async {
                                                var result = await Navigator.of(context).push(new MaterialPageRoute(builder: (context) => EnterBankDetailScreen()));
                                                print("--->" + result.toString());
                                                if (result) {
                                                  User? user = await FireStoreUtils.getCurrentUser(MyAppState.currentUser!.id);
                                                  setState(() {
                                                    MyAppState.currentUser = user;
                                                    userBankDetails = MyAppState.currentUser!.userBankDetails;
                                                    print(MyAppState.currentUser!.userBankDetails.bankName);
                                                    isBankDetailsAdded = true;
                                                  });
                                                }
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.all(Radius.circular(30))),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: Icon(
                                                    Icons.edit,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : SizedBox()
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Divider(),
                            SizedBox(
                              height: 10,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                              child: isBankDetailsAdded
                                  ? Text(
                                      "Setup was Done",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: Colors.green),
                                    )
                                  : Row(
                                      children: [
                                        Text(
                                          "Setup is Pending.".tr,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: Colors.orange),
                                        ),
                                        SizedBox(
                                          width: 5,
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            var result = await Navigator.of(context).push(new MaterialPageRoute(builder: (context) => EnterBankDetailScreen()));
                                            print("--->" + result.toString());
                                            if (result) {
                                              User? user = await FireStoreUtils.getCurrentUser(MyAppState.currentUser!.id);
                                              setState(() {
                                                MyAppState.currentUser = user;
                                                userBankDetails = MyAppState.currentUser!.userBankDetails;
                                                print(MyAppState.currentUser!.userBankDetails.bankName);
                                                isBankDetailsAdded = true;
                                              });
                                            }
                                          },
                                          child: Text(
                                            "Setup Now".tr,
                                            style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: AppColors.medium, color: Colors.blue),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    flutterWaveSettingData != null && flutterWaveSettingData!.isWithdrawEnabled == false
                        ? SizedBox()
                        : Card(
                            color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10), // if you need this
                              side: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Image.asset(
                                          "assets/images/flutterwave.png",
                                          color: themeChange.getTheme() ? AppColors.colorGrey : null,
                                          height: 20,
                                        ),
                                        withdrawMethodModel!.flutterWave != null
                                            ? Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (BuildContext context) {
                                                          return flutterWaveDialog();
                                                        },
                                                      );
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.all(Radius.circular(30))),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Icons.edit,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 10,
                                                  ),
                                                  InkWell(
                                                    onTap: () async {
                                                      withdrawMethodModel!.flutterWave = null;
                                                      await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then(
                                                        (value) async {
                                                          ShowToastDialog.showLoader("Please wait..");

                                                          await getPaymentMethod();
                                                          ShowToastDialog.closeLoader();
                                                          ShowToastDialog.showToast("Payment Method remove successfully");
                                                        },
                                                      );
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.all(Radius.circular(30))),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Icons.delete,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : SizedBox(),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Divider(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                    child: withdrawMethodModel!.flutterWave != null
                                        ? Text(
                                            "Setup was Done",
                                            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: Colors.green),
                                          )
                                        : Row(
                                            children: [
                                              Text(
                                                "Setup is Pending.".tr,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: Colors.orange),
                                              ),
                                              SizedBox(
                                                width: 5,
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (BuildContext context) {
                                                      return flutterWaveDialog();
                                                    },
                                                  );
                                                },
                                                child: Text(
                                                  "Setup Now".tr,
                                                  style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: AppColors.medium, color: Colors.blue),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    paypalDataModel != null && paypalDataModel!.isWithdrawEnabled == false
                        ? SizedBox()
                        : Card(
                            color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10), // if you need this
                              side: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Image.asset(
                                          "assets/images/paypal.png",
                                          color: themeChange.getTheme() ? AppColors.colorGrey : null,
                                          height: 20,
                                        ),
                                        withdrawMethodModel!.paypal != null
                                            ? Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (BuildContext context) {
                                                          return payPalDialog();
                                                        },
                                                      );
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.all(Radius.circular(30))),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Icons.edit,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 10,
                                                  ),
                                                  InkWell(
                                                    onTap: () async {
                                                      withdrawMethodModel!.paypal = null;
                                                      await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then(
                                                        (value) async {
                                                          ShowToastDialog.showLoader("Please wait..");

                                                          await getPaymentMethod();
                                                          ShowToastDialog.closeLoader();
                                                          ShowToastDialog.showToast("Payment Method remove successfully");
                                                        },
                                                      );
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.all(Radius.circular(30))),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Icons.delete,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : SizedBox(),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Divider(),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                    child: withdrawMethodModel!.paypal != null
                                        ? Text(
                                            "Setup was Done",
                                            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: Colors.green),
                                          )
                                        : Row(
                                            children: [
                                              Text(
                                                "Setup is Pending.".tr,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: Colors.orange),
                                              ),
                                              SizedBox(
                                                width: 5,
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (BuildContext context) {
                                                      return payPalDialog();
                                                    },
                                                  );
                                                },
                                                child: Text(
                                                  "Setup Now".tr,
                                                  style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: AppColors.medium, color: Colors.blue),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    razorPayModel != null && razorPayModel!.isWithdrawEnabled == false
                        ? SizedBox()
                        : Card(
                            color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10), // if you need this
                              side: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          child: Image.asset(
                                            "assets/images/razorpay.png",
                                            height: 20,
                                            color: themeChange.getTheme() ? AppColors.colorGrey : null,
                                          ),
                                        ),
                                        withdrawMethodModel!.razorpay != null
                                            ? Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (BuildContext context) {
                                                          return razorPayDialog();
                                                        },
                                                      );
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.all(Radius.circular(30))),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Icons.edit,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 10,
                                                  ),
                                                  InkWell(
                                                    onTap: () async {
                                                      withdrawMethodModel!.razorpay = null;
                                                      await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then(
                                                        (value) async {
                                                          ShowToastDialog.showLoader("Please wait..");

                                                          await getPaymentMethod();
                                                          ShowToastDialog.closeLoader();
                                                          ShowToastDialog.showToast("Payment Method remove successfully");
                                                        },
                                                      );
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.all(Radius.circular(30))),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Icons.delete,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : SizedBox(),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Divider(),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                    child: withdrawMethodModel!.razorpay != null
                                        ? Text(
                                            "Setup was Done",
                                            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: Colors.green),
                                          )
                                        : Row(
                                            children: [
                                              Text(
                                                "Setup is Pending.".tr,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: Colors.orange),
                                              ),
                                              SizedBox(
                                                width: 5,
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (BuildContext context) {
                                                      return razorPayDialog();
                                                    },
                                                  );
                                                },
                                                child: Text(
                                                  "Setup Now".tr,
                                                  style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: AppColors.medium, color: Colors.blue),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    stripeSettingData != null && stripeSettingData!.isWithdrawEnabled == false
                        ? SizedBox()
                        : Card(
                            color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10), // if you need this
                              side: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Image.asset(
                                          "assets/images/stripe.png",
                                          height: 20,
                                          color: themeChange.getTheme() ? AppColors.colorGrey : null,
                                        ),
                                        withdrawMethodModel!.stripe != null
                                            ? Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (BuildContext context) {
                                                          return stripeDialog();
                                                        },
                                                      );
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.all(Radius.circular(30))),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Icons.edit,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 10,
                                                  ),
                                                  InkWell(
                                                    onTap: () async {
                                                      withdrawMethodModel!.stripe = null;
                                                      await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then(
                                                        (value) async {
                                                          ShowToastDialog.showLoader("Please wait..");

                                                          await getPaymentMethod();
                                                          ShowToastDialog.closeLoader();
                                                          ShowToastDialog.showToast("Payment Method remove successfully");
                                                        },
                                                      );
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.all(Radius.circular(30))),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: Icon(
                                                          Icons.delete,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : SizedBox(),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Divider(),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                    child: withdrawMethodModel!.stripe != null
                                        ? Text(
                                            "Setup was Done",
                                            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: withdrawMethodModel!.paypal != null ? Colors.green : Colors.red),
                                          )
                                        : Row(
                                            children: [
                                              Text(
                                                "Setup is Pending.".tr,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: Colors.orange),
                                              ),
                                              SizedBox(
                                                width: 5,
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (BuildContext context) {
                                                      return stripeDialog();
                                                    },
                                                  );
                                                },
                                                child: Text(
                                                  "Setup Now".tr,
                                                  style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: AppColors.medium, color: Colors.blue),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
        ),
      ),
    );
  }

  flutterWaveDialog() {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "Account Number".tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.black),
                ),
              ),
              TextFormField(
                  controller: accountNumberFlutterWave,
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.next,
                  validator: validateEmptyField,
                  // onSaved: (text) => line1 = text,
                  style: TextStyle(fontSize: 18.0),
                  keyboardType: TextInputType.streetAddress,
                  cursorColor: AppColors.colorPrimary,
                  // initialValue: MyAppState.currentUser!.shippingAddress.line1,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    hintText: 'Account Number'.tr,
                    hintStyle: TextStyle(color: themeChange.getTheme() ? Colors.white : Color(0Xff333333), fontFamily: "Poppinsm", fontSize: 16),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.colorPrimary),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0XFFCCD6E2)),
                      // borderRadius: BorderRadius.circular(8.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0XFFCCD6E2)),
                      // borderRadius: BorderRadius.circular(8.0),
                    ),
                  )),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "Bank Code".tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.black),
                ),
              ),
              TextFormField(
                  controller: bankCodeFlutterWave,
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.next,
                  validator: validateEmptyField,
                  // onSaved: (text) => line1 = text,
                  style: TextStyle(fontSize: 18.0),
                  keyboardType: TextInputType.streetAddress,
                  cursorColor: AppColors.colorPrimary,
                  // initialValue: MyAppState.currentUser!.shippingAddress.line1,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    hintText: 'Account Number'.tr,
                    hintStyle: TextStyle(color: themeChange.getTheme() ? Colors.white : Color(0Xff333333), fontFamily: "Poppinsm", fontSize: 16),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.colorPrimary),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0XFFCCD6E2)),
                      // borderRadius: BorderRadius.circular(8.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0XFFCCD6E2)),
                      // borderRadius: BorderRadius.circular(8.0),
                    ),
                  )),
              SizedBox(
                height: 20,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colorPrimary,
                    padding: EdgeInsets.only(top: 12, bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      side: BorderSide(
                        color: AppColors.colorPrimary,
                      ),
                    ),
                  ),
                  child: Text(
                    'Save'.tr,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeChange.getTheme() ? Colors.white : Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    if (accountNumberFlutterWave.text.isEmpty) {
                      ShowToastDialog.showToast("Enter your Account number");
                    } else if (bankCodeFlutterWave.text.isEmpty) {
                      ShowToastDialog.showToast("Enter your bank code");
                    } else {
                      FlutterWave? flutterWave = withdrawMethodModel!.flutterWave;
                      if (flutterWave != null) {
                        flutterWave.accountNumber = accountNumberFlutterWave.value.text;
                        flutterWave.bankCode = bankCodeFlutterWave.value.text;
                      } else {
                        flutterWave = FlutterWave(accountNumber: accountNumberFlutterWave.value.text, bankCode: bankCodeFlutterWave.value.text, name: "FlutterWave");
                      }
                      withdrawMethodModel!.flutterWave = flutterWave;
                      await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then(
                        (value) async {
                          ShowToastDialog.showLoader("Please wait..");

                          await getPaymentMethod();
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast("Payment Method save successfully");
                          Navigator.pop(context);
                        },
                      );
                    }
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  payPalDialog() {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "Paypal Email".tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.black),
                ),
              ),
              TextFormField(
                  controller: emailPaypal,
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.next,
                  validator: validateEmptyField,
                  // onSaved: (text) => line1 = text,
                  style: TextStyle(fontSize: 18.0),
                  keyboardType: TextInputType.streetAddress,
                  cursorColor: AppColors.colorPrimary,
                  // initialValue: MyAppState.currentUser!.shippingAddress.line1,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    hintText: 'Paypal Email'.tr,
                    hintStyle: TextStyle(color: themeChange.getTheme() ? Colors.white : Color(0Xff333333), fontFamily: "Poppinsm", fontSize: 16),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.colorPrimary),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0XFFCCD6E2)),
                      // borderRadius: BorderRadius.circular(8.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0XFFCCD6E2)),
                      // borderRadius: BorderRadius.circular(8.0),
                    ),
                  )),
              SizedBox(
                height: 10,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "Insert your paypal email id".tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.grey),
                ),
              ),
              SizedBox(
                height: 20,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colorPrimary,
                    padding: EdgeInsets.only(top: 12, bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      side: BorderSide(
                        color: AppColors.colorPrimary,
                      ),
                    ),
                  ),
                  child: Text(
                    'Save'.tr,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeChange.getTheme() ? Colors.white : Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    if (emailPaypal.text.isEmpty) {
                      ShowToastDialog.showToast("Enter your paypal email id");
                    } else {
                      Paypal? payPal = withdrawMethodModel!.paypal;
                      if (payPal != null) {
                        payPal.email = emailPaypal.value.text;
                      } else {
                        payPal = Paypal(email: emailPaypal.value.text, name: "PayPal");
                      }
                      withdrawMethodModel!.paypal = payPal;
                      await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then(
                        (value) async {
                          ShowToastDialog.showLoader("Please wait..");

                          await getPaymentMethod();
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast("Payment Method save successfully");
                          Navigator.pop(context);
                        },
                      );
                    }
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  razorPayDialog() {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "Razorpay account Id".tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.black),
                ),
              ),
              TextFormField(
                  controller: accountIdRazorPay,
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.next,
                  validator: validateEmptyField,
                  // onSaved: (text) => line1 = text,
                  style: TextStyle(fontSize: 18.0),
                  keyboardType: TextInputType.streetAddress,
                  cursorColor: AppColors.colorPrimary,
                  // initialValue: MyAppState.currentUser!.shippingAddress.line1,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    hintText: 'Account Number'.tr,
                    hintStyle: TextStyle(color: themeChange.getTheme() ? Colors.white : Color(0Xff333333), fontFamily: "Poppinsm", fontSize: 16),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.colorPrimary),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0XFFCCD6E2)),
                      // borderRadius: BorderRadius.circular(8.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0XFFCCD6E2)),
                      // borderRadius: BorderRadius.circular(8.0),
                    ),
                  )),
              SizedBox(
                height: 10,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "Add your Account ID. For example, acc_GLGeLkU2JUeyDZ".tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.grey),
                ),
              ),
              SizedBox(
                height: 20,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colorPrimary,
                    padding: EdgeInsets.only(top: 12, bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      side: BorderSide(
                        color: AppColors.colorPrimary,
                      ),
                    ),
                  ),
                  child: Text(
                    'Save'.tr,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeChange.getTheme() ? Colors.white : Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    if (accountIdRazorPay.text.isEmpty) {
                      ShowToastDialog.showToast("Enter your Razorpay id");
                    } else {
                      RazorpayModel? razorPay = withdrawMethodModel!.razorpay;
                      if (razorPay != null) {
                        razorPay.accountId = accountIdRazorPay.value.text;
                      } else {
                        razorPay = RazorpayModel(accountId: accountIdRazorPay.value.text, name: "RazorPay");
                      }
                      withdrawMethodModel!.razorpay = razorPay;
                      await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then(
                        (value) async {
                          ShowToastDialog.showLoader("Please wait..");

                          await getPaymentMethod();
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast("Payment Method save successfully");
                          Navigator.pop(context);
                        },
                      );
                    }
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  stripeDialog() {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "Stripe Account Id".tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.black),
                ),
              ),
              TextFormField(
                  controller: accountIdStripe,
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.next,
                  validator: validateEmptyField,
                  // onSaved: (text) => line1 = text,
                  style: TextStyle(fontSize: 18.0),
                  keyboardType: TextInputType.streetAddress,
                  cursorColor: AppColors.colorPrimary,
                  // initialValue: MyAppState.currentUser!.shippingAddress.line1,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    hintText: 'Stripe Account Id'.tr,
                    hintStyle: TextStyle(color: themeChange.getTheme() ? Colors.white : Color(0Xff333333), fontFamily: "Poppinsm", fontSize: 16),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.colorPrimary),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0XFFCCD6E2)),
                      // borderRadius: BorderRadius.circular(8.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0XFFCCD6E2)),
                      // borderRadius: BorderRadius.circular(8.0),
                    ),
                  )),
              SizedBox(
                height: 10,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  "Go to your Stripe account settings > Account details > Copy your account ID on the right-hand side. For example, acc_GLGeLkU2JUeyDZ".tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.grey),
                ),
              ),
              SizedBox(
                height: 20,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colorPrimary,
                    padding: EdgeInsets.only(top: 12, bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      side: BorderSide(
                        color: AppColors.colorPrimary,
                      ),
                    ),
                  ),
                  child: Text(
                    'Save'.tr,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeChange.getTheme() ? Colors.white : Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    if (accountIdStripe.text.isEmpty) {
                      ShowToastDialog.showToast("Enter your Stripe Account id");
                    } else {
                      Stripe? stripe = withdrawMethodModel!.stripe;
                      if (stripe != null) {
                        stripe.accountId = accountIdStripe.value.text;
                      } else {
                        stripe = Stripe(accountId: accountIdStripe.value.text, name: "Stripe");
                      }
                      withdrawMethodModel!.stripe = stripe;
                      await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then(
                        (value) async {
                          ShowToastDialog.showLoader("Please wait..");

                          await getPaymentMethod();
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast("Payment Method save successfully");
                          Navigator.pop(context);
                        },
                      );
                    }
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
