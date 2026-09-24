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
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/bank_details/enter_bank_details_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Payout methods (archetype H – finance / payout setup). A setup checklist:
/// a completion alert and progress bar at the top, then the bank account as a
/// masked "card", then the enabled gateways as compact setup cards. Drawer
/// body, so it keeps exactly one Scaffold and no app bar of its own.
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

    await FireStoreUtils.getWithdrawMethod().then((value) {
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
    });
    setState(() {
      isLoading = false;
    });
  }

  /// Opens the bank-details form and refreshes this screen with the saved
  /// account. Identical to the two inline handlers it replaces.
  Future<void> _openBankDetailForm() async {
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
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final bool isDark = themeChange.getTheme();
    final bool showFlutterWave = !(flutterWaveSettingData != null && flutterWaveSettingData!.isWithdrawEnabled == false);
    final bool showPaypal = !(paypalDataModel != null && paypalDataModel!.isWithdrawEnabled == false);
    final bool showRazorPay = !(razorPayModel != null && razorPayModel!.isWithdrawEnabled == false);
    final bool showStripe = !(stripeSettingData != null && stripeSettingData!.isWithdrawEnabled == false);

    return DsScaffold(
      body: DsAsync(
        isLoading: isLoading == true,
        skeleton: const Padding(
          padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
          child: DsSkeletonList(itemCount: 4, trailing: false),
        ),
        builder: (context) {
          final List<Widget> gateways = [
            if (showFlutterWave)
              _MethodCard(
                asset: "assets/images/flutterwave.png",
                tintAsset: isDark,
                configured: withdrawMethodModel!.flutterWave != null,
                detail: withdrawMethodModel!.flutterWave?.accountNumber?.toString(),
                onSetup: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return flutterWaveDialog();
                    },
                  );
                },
                onDelete: () async {
                  withdrawMethodModel!.flutterWave = null;
                  await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then((value) async {
                    ShowToastDialog.showLoader("Please wait..");

                    await getPaymentMethod();
                    ShowToastDialog.closeLoader();
                    ShowToastDialog.showToast("Payment Method remove successfully");
                  });
                },
              ),
            if (showPaypal)
              _MethodCard(
                asset: "assets/images/paypal.png",
                tintAsset: isDark,
                configured: withdrawMethodModel!.paypal != null,
                detail: withdrawMethodModel!.paypal?.email?.toString(),
                onSetup: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return payPalDialog();
                    },
                  );
                },
                onDelete: () async {
                  withdrawMethodModel!.paypal = null;
                  await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then((value) async {
                    ShowToastDialog.showLoader("Please wait..");

                    await getPaymentMethod();
                    ShowToastDialog.closeLoader();
                    ShowToastDialog.showToast("Payment Method remove successfully");
                  });
                },
              ),
            if (showRazorPay)
              _MethodCard(
                asset: "assets/images/razorpay.png",
                tintAsset: isDark,
                configured: withdrawMethodModel!.razorpay != null,
                detail: withdrawMethodModel!.razorpay?.accountId?.toString(),
                onSetup: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return razorPayDialog();
                    },
                  );
                },
                onDelete: () async {
                  withdrawMethodModel!.razorpay = null;
                  await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then((value) async {
                    ShowToastDialog.showLoader("Please wait..");

                    await getPaymentMethod();
                    ShowToastDialog.closeLoader();
                    ShowToastDialog.showToast("Payment Method remove successfully");
                  });
                },
              ),
            if (showStripe)
              _MethodCard(
                asset: "assets/images/stripe.png",
                tintAsset: isDark,
                configured: withdrawMethodModel!.stripe != null,
                // Preserved from the original: the "done" label here was tinted
                // by the PayPal method, not by Stripe.
                doneTone: withdrawMethodModel!.paypal != null ? DsTone.success : DsTone.danger,
                detail: withdrawMethodModel!.stripe?.accountId?.toString(),
                onSetup: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return stripeDialog();
                    },
                  );
                },
                onDelete: () async {
                  withdrawMethodModel!.stripe = null;
                  await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then((value) async {
                    ShowToastDialog.showLoader("Please wait..");

                    await getPaymentMethod();
                    ShowToastDialog.closeLoader();
                    ShowToastDialog.showToast("Payment Method remove successfully");
                  });
                },
              ),
          ];

          final int total = gateways.length + 1;
          final int done =
              (isBankDetailsAdded ? 1 : 0) +
              (showFlutterWave && withdrawMethodModel!.flutterWave != null ? 1 : 0) +
              (showPaypal && withdrawMethodModel!.paypal != null ? 1 : 0) +
              (showRazorPay && withdrawMethodModel!.razorpay != null ? 1 : 0) +
              (showStripe && withdrawMethodModel!.stripe != null ? 1 : 0);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: DsFadeSlideIn.stagger([
                DsInlineAlert(
                  tone: done == 0 ? DsTone.warning : DsTone.success,
                  icon: done == 0 ? Icons.info_outline_rounded : Icons.verified_outlined,
                  title: "Payout methods".tr,
                  message: done == 0 ? "Add at least one payout method so your withdrawals can be paid out.".tr : "You can withdraw your earnings to any method you set up below.".tr,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.lg),
                  child: DsProgressBar(value: total == 0 ? 0.0 : done / total, label: "Setup".tr, showPercent: true),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.sm),
                  child: DsSectionHeader(title: "Bank account".tr, icon: Icons.account_balance_outlined),
                ),
                _BankAccountCard(isDark: isDark, isBankDetailsAdded: isBankDetailsAdded, userBankDetails: userBankDetails, onSetup: _openBankDetailForm),
                if (gateways.isNotEmpty) DsSectionHeader(title: "Payout gateways".tr, icon: Icons.credit_card_outlined) else const SizedBox.shrink(),
                ...gateways,
              ]),
            ),
          );
        },
      ),
    );
  }

  flutterWaveDialog() {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return DsDialog(
      title: "Account Number".tr,
      icon: Icons.account_balance_outlined,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsTextField(
            label: "Account Number".tr,
            hint: 'Account Number'.tr,
            controller: accountNumberFlutterWave,
            textInputAction: TextInputAction.next,
            validator: validateEmptyField,
            // onSaved: (text) => line1 = text,
            keyboardType: TextInputType.streetAddress,
          ),
          DsTextField(
            label: "Bank Code".tr,
            hint: 'Account Number'.tr,
            controller: bankCodeFlutterWave,
            textInputAction: TextInputAction.next,
            validator: validateEmptyField,
            // onSaved: (text) => line1 = text,
            keyboardType: TextInputType.streetAddress,
            bottomSpacing: 0,
          ),
        ],
      ),
      primaryLabel: 'Save'.tr,
      onPrimary: () async {
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
          await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then((value) async {
            ShowToastDialog.showLoader("Please wait..");

            await getPaymentMethod();
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Payment Method save successfully");
            Navigator.pop(context);
          });
        }
      },
    );
  }

  payPalDialog() {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return DsDialog(
      title: "Paypal Email".tr,
      message: "Insert your paypal email id".tr,
      icon: Icons.alternate_email_rounded,
      content: DsTextField(
        label: "Paypal Email".tr,
        hint: 'Paypal Email'.tr,
        controller: emailPaypal,
        textInputAction: TextInputAction.next,
        validator: validateEmptyField,
        // onSaved: (text) => line1 = text,
        keyboardType: TextInputType.streetAddress,
        bottomSpacing: 0,
      ),
      primaryLabel: 'Save'.tr,
      onPrimary: () async {
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
          await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then((value) async {
            ShowToastDialog.showLoader("Please wait..");

            await getPaymentMethod();
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Payment Method save successfully");
            Navigator.pop(context);
          });
        }
      },
    );
  }

  razorPayDialog() {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return DsDialog(
      title: "Razorpay account Id".tr,
      message: "Add your Account ID. For example, acc_GLGeLkU2JUeyDZ".tr,
      icon: Icons.badge_outlined,
      content: DsTextField(
        label: "Razorpay account Id".tr,
        hint: 'Account Number'.tr,
        controller: accountIdRazorPay,
        textInputAction: TextInputAction.next,
        validator: validateEmptyField,
        // onSaved: (text) => line1 = text,
        keyboardType: TextInputType.streetAddress,
        bottomSpacing: 0,
      ),
      primaryLabel: 'Save'.tr,
      onPrimary: () async {
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
          await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then((value) async {
            ShowToastDialog.showLoader("Please wait..");

            await getPaymentMethod();
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Payment Method save successfully");
            Navigator.pop(context);
          });
        }
      },
    );
  }

  stripeDialog() {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return DsDialog(
      title: "Stripe Account Id".tr,
      message: "Go to your Stripe account settings > Account details > Copy your account ID on the right-hand side. For example, acc_GLGeLkU2JUeyDZ".tr,
      icon: Icons.badge_outlined,
      content: DsTextField(
        label: "Stripe Account Id".tr,
        hint: 'Stripe Account Id'.tr,
        controller: accountIdStripe,
        textInputAction: TextInputAction.next,
        validator: validateEmptyField,
        // onSaved: (text) => line1 = text,
        keyboardType: TextInputType.streetAddress,
        bottomSpacing: 0,
      ),
      primaryLabel: 'Save'.tr,
      onPrimary: () async {
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
          await FireStoreUtils.setWithdrawMethod(withdrawMethodModel!).then((value) async {
            ShowToastDialog.showLoader("Please wait..");

            await getPaymentMethod();
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Payment Method save successfully");
            Navigator.pop(context);
          });
        }
      },
    );
  }
}

/// The bank account as a masked "payout card": brand-tinted, with the account
/// number masked from the details already in memory.
class _BankAccountCard extends StatelessWidget {
  final bool isDark;
  final bool isBankDetailsAdded;
  final UserBankDetails? userBankDetails;
  final VoidCallback onSetup;

  const _BankAccountCard({required this.isDark, required this.isBankDetailsAdded, required this.userBankDetails, required this.onSetup});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final String accountNumber = userBankDetails?.accountNumber ?? '';
    return DsCard.tinted(
      tone: isBankDetailsAdded ? DsTone.brand : DsTone.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset("assets/images/ic_bank_line.png", color: isDark ? c.textPrimary : null, height: 20),
              const DsGap(DsSpace.md),
              Expanded(child: Text("Bank Transfer", style: t.titleSm)),
              if (isBankDetailsAdded) DsIconButton(icon: Icons.edit_outlined, semanticLabel: "Edit Bank".tr, variant: DsIconButtonVariant.tonal, onPressed: onSetup),
            ],
          ),
          if (isBankDetailsAdded && accountNumber.isNotEmpty) ...[
            const DsGap(DsSpace.lg),
            Text(maskingString(accountNumber, 4), style: t.title.tabular),
            if ((userBankDetails?.bankName ?? '').isNotEmpty) ...[const DsGap(DsSpace.xxs), Text(userBankDetails!.bankName, style: t.caption)],
          ],
          const DsDivider(spacing: DsSpace.lg),
          if (isBankDetailsAdded)
            DsStatusChip(label: "Setup was Done", tone: DsTone.success)
          else
            Row(
              children: [
                DsStatusChip(label: "Setup is Pending.".tr, tone: DsTone.warning),
                const DsGap(DsSpace.md),
                DsButton.tonal(label: "Setup Now".tr, icon: Icons.add_rounded, size: DsButtonSize.sm, onPressed: onSetup),
              ],
            ),
        ],
      ),
    );
  }
}

/// One gateway payout method: logo, configured status and the setup / edit /
/// remove actions. Every callback is the original inline handler, unchanged.
class _MethodCard extends StatelessWidget {
  final String asset;
  final bool tintAsset;
  final bool configured;
  final String? detail;
  final DsTone? doneTone;
  final VoidCallback onSetup;
  final VoidCallback onDelete;

  const _MethodCard({required this.asset, required this.tintAsset, required this.configured, required this.onSetup, required this.onDelete, this.detail, this.doneTone});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: DsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Image.asset(asset, color: tintAsset ? c.textPrimary : null, height: 20),
                  ),
                ),
                if (configured) ...[
                  DsIconButton(icon: Icons.edit_outlined, semanticLabel: "Edit".tr, variant: DsIconButtonVariant.tonal, onPressed: onSetup),
                  const DsGap(DsSpace.sm),
                  DsIconButton(icon: Icons.delete_outline_rounded, semanticLabel: "Remove".tr, variant: DsIconButtonVariant.tonal, color: c.danger, onPressed: onDelete),
                ],
              ],
            ),
            if (configured && (detail ?? '').isNotEmpty) ...[const DsGap(DsSpace.md), Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm)],
            const DsDivider(spacing: DsSpace.md),
            if (configured)
              DsStatusChip(label: "Setup was Done", tone: doneTone ?? DsTone.success)
            else
              Row(
                children: [
                  DsStatusChip(label: "Setup is Pending.".tr, tone: DsTone.warning),
                  const DsGap(DsSpace.md),
                  DsButton.tonal(label: "Setup Now".tr, icon: Icons.add_rounded, size: DsButtonSize.sm, onPressed: onSetup),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
