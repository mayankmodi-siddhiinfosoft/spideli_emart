import 'package:customer/models/currency_model.dart';
import 'package:customer/utils/region_service.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as maths;
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/models/payment_model/flutter_wave_model.dart';
import 'package:customer/models/payment_model/mercado_pago_model.dart';
import 'package:customer/models/payment_model/mid_trans.dart';
import 'package:customer/models/payment_model/orange_money.dart';
import 'package:customer/models/payment_model/pay_fast_model.dart';
import 'package:customer/models/payment_model/pay_stack_model.dart';
import 'package:customer/models/payment_model/paypal_model.dart';
import 'package:customer/models/payment_model/razorpay_model.dart';
import 'package:customer/models/payment_model/stripe_model.dart';
import 'package:customer/models/payment_model/xendit.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../payment/mercado_pago_screen.dart';
import '../payment/pay_fast_screen.dart';
import '../payment/midtrans_screen.dart';
import '../payment/orange_pay_screen.dart';
import '../payment/paystack/pay_stack_screen.dart';
import '../payment/paystack/pay_stack_url_model.dart';
import '../payment/paystack/paystack_url_genrater.dart';
import '../payment/stripe_failed_model.dart';
import '../payment/xendit_model.dart';
import '../payment/xendit_screen.dart';
import '../service/fire_store_utils.dart';
import 'package:customer/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../themes/show_toast_dialog.dart';

class WalletController extends GetxController {
  RxBool isLoading = true.obs;

  Rx<TextEditingController> topUpAmountController = TextEditingController().obs;

  RxList<WalletTransactionModel> walletTransactionList = <WalletTransactionModel>[].obs;

  /// orderId -> regionId for order-based rows without their own `regionId`.
  RxMap<String, String> orderRegions = <String, String>{}.obs;

  /// Currency of a wallet row: a row tied to an order uses that order's
  /// region (history); a top-up uses the customer's region; otherwise global.
  CurrencyModel? currencyFor(WalletTransactionModel transaction) {
    final String? own = transaction.regionId;
    if (own != null && own.isNotEmpty) return RegionService.currencyForRecord(own);
    final String? orderId = transaction.orderId;
    if (orderId == null || orderId.isEmpty) return RegionService.customerCurrency;
    return RegionService.currencyForRecord(orderRegions[orderId]);
  }

  Rx<UserModel> userModel = UserModel().obs;
  RxString selectedPaymentMethod = "".obs;

  // ── Spideli Finance checkout (FinancePaymentService) ─────────────────
  // Finance payments run the same gateways. With [onPaid] set, a gateway
  // success calls it (gateway key, its transaction id when the gateway gives
  // one) instead of crediting the shopping wallet, a failed or cancelled
  // checkout calls [onPaymentFailed], and the shopping-wallet steps around
  // them (toasts, closing the top-up screen) are skipped. [chargeCurrency] /
  // [chargeUnits] replace the gateway's default currency and its amount in
  // the gateway's smallest unit (Stripe, PayStack). All null for the shopping
  // wallet, whose behaviour is unchanged.
  Future<void> Function(String method, String? reference)? onPaid;
  void Function(String method, String? message)? onPaymentFailed;
  String? chargeCurrency;
  int? chargeUnits;
  String? _stripeIntentId;
  String? _midtransOrderId;

  bool get _financeCheckout => onPaid != null;

  /// A finance checkout ended ([ok] or not): true when it was one (the caller stops there).
  bool _financeResult(String method, bool ok, String? reference) {
    if (!_financeCheckout) return false;
    if (ok) {
      onPaid!(method, reference);
    } else {
      onPaymentFailed?.call(method, null);
    }
    return true;
  }

  /// A finance checkout failed before or inside the gateway: true when it was one.
  bool _financeFailed(String method, [String? message]) {
    if (!_financeCheckout) return false;
    onPaymentFailed?.call(method, message);
    return true;
  }

  @override
  void onInit() {
    // TODO: implement onInit
    getPaymentSettings();
    getWalletTransaction();
    super.onInit();
  }

  Rx<PayFastModel> payFastModel = PayFastModel().obs;
  Rx<MercadoPagoModel> mercadoPagoModel = MercadoPagoModel().obs;
  Rx<PayPalModel> payPalModel = PayPalModel().obs;
  Rx<StripeModel> stripeModel = StripeModel().obs;
  Rx<FlutterWaveModel> flutterWaveModel = FlutterWaveModel().obs;
  Rx<PayStackModel> payStackModel = PayStackModel().obs;
  Rx<RazorPayModel> razorPayModel = RazorPayModel().obs;
  Rx<MidTrans> midTransModel = MidTrans().obs;
  Rx<OrangeMoney> orangeMoneyModel = OrangeMoney().obs;
  Rx<Xendit> xenditModel = Xendit().obs;

  Future<void> getPaymentSettings() async {
    // A top-up is not tied to a store: methods of the customer's current
    // region when it resolves to one, else all of them (spec 18.7).
    await RegionService.ensureLoaded();
    await FireStoreUtils.getPaymentSettingsData().then((value) {
      payFastModel.value = PayFastModel.fromJson(RegionService.gatewaySettings(Preferences.payFastSettings, RegionService.customerRegionId));
      mercadoPagoModel.value = MercadoPagoModel.fromJson(RegionService.gatewaySettings(Preferences.mercadoPago, RegionService.customerRegionId));
      payPalModel.value = PayPalModel.fromJson(RegionService.gatewaySettings(Preferences.paypalSettings, RegionService.customerRegionId));
      stripeModel.value = StripeModel.fromJson(RegionService.gatewaySettings(Preferences.stripeSettings, RegionService.customerRegionId));
      flutterWaveModel.value = FlutterWaveModel.fromJson(RegionService.gatewaySettings(Preferences.flutterWave, RegionService.customerRegionId));
      payStackModel.value = PayStackModel.fromJson(RegionService.gatewaySettings(Preferences.payStack, RegionService.customerRegionId));
      razorPayModel.value = RazorPayModel.fromJson(RegionService.gatewaySettings(Preferences.razorpaySettings, RegionService.customerRegionId));

      midTransModel.value = MidTrans.fromJson(RegionService.gatewaySettings(Preferences.midTransSettings, RegionService.customerRegionId));
      orangeMoneyModel.value = OrangeMoney.fromJson(RegionService.gatewaySettings(Preferences.orangeMoneySettings, RegionService.customerRegionId));
      xenditModel.value = Xendit.fromJson(RegionService.gatewaySettings(Preferences.xenditSettings, RegionService.customerRegionId));

      Stripe.publishableKey = stripeModel.value.clientpublishableKey.toString();
      Stripe.merchantIdentifier = 'GoRide';
      // An invalid publishable key in the admin settings must not throw an
      // unhandled error when the checkout opens: Stripe stays unusable, the
      // other payment methods work.
      Stripe.instance.applySettings().catchError((Object e) => log('Stripe settings not applied: $e'));
      setRef();

      razorPay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
      razorPay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWaller);
      razorPay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);
    });
  }

  Future<void> getWalletTransaction() async {
    if (Constant.userModel != null) {
      await FireStoreUtils.getWalletTransaction().then((value) {
        if (value != null) {
          walletTransactionList.value = value;
        }
      });
      // Region of order-based rows written before rows carried `regionId`.
      orderRegions.value = await RegionService.orderRegionIds(
        walletTransactionList.where((t) => (t.regionId ?? '').isEmpty && (t.orderId ?? '').isNotEmpty).map((t) => t.orderId),
      );
      await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
        if (value != null) {
          userModel.value = value;
        }
      });
    }
    isLoading.value = false;
  }

  Future<void> walletTopUp() async {
    WalletTransactionModel transactionModel = WalletTransactionModel(
      id: Constant.getUuid(),
      amount: double.parse(topUpAmountController.value.text),
      date: Timestamp.now(),
      paymentMethod: selectedPaymentMethod.value,
      transactionUser: "user",
      userId: FireStoreUtils.getCurrentUid(),
      isTopup: true,
      note: "Wallet Top-up",
      paymentStatus: "success",
    );

    await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
      if (value == true) {
        await FireStoreUtils.updateUserWallet(amount: topUpAmountController.value.text, userId: FireStoreUtils.getCurrentUid()).then((value) {
          getWalletTransaction();
          Get.back();
        });
      }
    });

    ShowToastDialog.showToast("Amount Top-up successfully".tr);
  }

  // Strip
  Future<void> stripeMakePayment({required String amount}) async {
    log(double.parse(amount).toStringAsFixed(0));
    try {
      Map<String, dynamic>? paymentIntentData = await createStripeIntent(amount: amount);
      if (paymentIntentData!.containsKey("error")) {
        if (_financeFailed('stripe')) return;
        Get.back();
        ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      } else {
        _stripeIntentId = paymentIntentData['id']?.toString();
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntentData['client_secret'],
            allowsDelayedPaymentMethods: false,
            googlePay: PaymentSheetGooglePay(merchantCountryCode: 'US', testEnv: true, currencyCode: chargeCurrency ?? "USD"),
            // A finance payment is confirmed by the sheet itself (no custom flow).
            customFlow: !_financeCheckout,
            style: ThemeMode.system,
            appearance: PaymentSheetAppearance(colors: PaymentSheetAppearanceColors(primary: AppThemeData.primary300)),
            merchantDisplayName: 'GoRide',
          ),
        );
        if (_financeCheckout) {
          await displayStripePaymentSheet(amount: amount);
        } else {
          displayStripePaymentSheet(amount: amount);
        }
      }
    } catch (e, s) {
      log("$e \n$s");
      if (_financeFailed('stripe')) return;
      ShowToastDialog.showToast("exception:$e \n$s");
    }
  }

  Future<void> displayStripePaymentSheet({required String amount}) async {
    try {
      await Stripe.instance.presentPaymentSheet().then((value) {
        if (_financeResult('stripe', true, _stripeIntentId)) return;
        ShowToastDialog.showToast("Payment successfully".tr);
        walletTopUp();
      });
    } on StripeException catch (e) {
      var lo1 = jsonEncode(e);
      var lo2 = jsonDecode(lo1);
      StripePayFailedModel lom = StripePayFailedModel.fromJson(lo2);
      if (_financeFailed('stripe', lom.error.message)) return;
      ShowToastDialog.showToast(lom.error.message);
    } catch (e) {
      if (_financeFailed('stripe', e.toString())) return;
      ShowToastDialog.showToast(e.toString());
    }
  }

  Future createStripeIntent({required String amount}) async {
    try {
      Map<String, dynamic> body = {
        'amount': (chargeUnits ?? (double.parse(amount) * 100).round()).toString(),
        'currency': chargeCurrency ?? "USD",
        'payment_method_types[]': 'card',
        "description": "Strip Payment",
        "shipping[name]": userModel.value.fullName(),
        "shipping[address][line1]": "510 Townsend St",
        "shipping[address][postal_code]": "98140",
        "shipping[address][city]": "San Francisco",
        "shipping[address][state]": "CA",
        "shipping[address][country]": "US",
      };
      var stripeSecret = stripeModel.value.stripeSecret;
      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {'Authorization': 'Bearer $stripeSecret', 'Content-Type': 'application/x-www-form-urlencoded'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      log(e.toString());
    }
  }

  //mercadoo
  Future<Null> mercadoPagoMakePayment({required BuildContext context, required String amount}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final headers = {'Authorization': 'Bearer ${mercadoPagoModel.value.accessToken}', 'Content-Type': 'application/json'};

    final body = jsonEncode({
      "items": [
        {
          "title": "Test",
          "description": "Test Payment",
          "quantity": 1,
          "currency_id": chargeCurrency ?? "BRL", // or your preferred currency
          "unit_price": double.parse(amount),
        },
      ],
      "payer": {"email": userModel.value.email},
      "back_urls": {"failure": "${Constant.globalUrl}payment/failure", "pending": "${Constant.globalUrl}payment/pending", "success": "${Constant.globalUrl}payment/success"},
      "auto_return": "approved", // Automatically return after payment is approved
    });

    final response = await http.post(Uri.parse("https://api.mercadopago.com/checkout/preferences"), headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      ShowToastDialog.closeLoader();
      Get.to(MercadoPagoScreen(initialURl: data['init_point']))!.then((value) {
        if (_financeResult('mercadopago', value == true, data['id']?.toString())) return;
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          walletTopUp();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      ShowToastDialog.closeLoader();
      if (_financeFailed('mercadopago')) return null;
      ShowToastDialog.showToast("Something want wrong please contact administrator".tr);
      print('Error creating preference: ${response.body}');
      return null;
    }
  }

  void paypalPaymentSheet(String amount, context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (BuildContext context) => _financePaypalPage(UsePaypal(
              sandboxMode: payPalModel.value.isLive == true ? false : true,
              clientId: payPalModel.value.paypalClient ?? '',
              secretKey: payPalModel.value.paypalSecret ?? '',
              returnURL: "com.parkme://paypalpay",
              cancelURL: "com.parkme://paypalpay",
              transactions: [
                {
                  "amount": {
                    "total": amount,
                    "currency": chargeCurrency ?? "USD",
                    "details": {"subtotal": amount},
                  },
                },
              ],
              note: "Contact us for any questions on your order.",
              onSuccess: (Map params) async {
                if (_financeResult('paypal', true, params['paymentId']?.toString())) return;
                walletTopUp();
                ShowToastDialog.showToast("Payment Successful!!".tr);
              },
              // A finance checkout never pops here: the PayPal pages close
              // themselves, and an extra pop would close the finance screen.
              onError: (error) {
                if (_financeFailed('paypal', error is Map ? error['message']?.toString() : null)) return;
                Get.back();
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
              onCancel: (params) {
                if (_financeFailed('paypal')) return;
                Get.back();
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
            )),
      ),
    );
  }

  /// A finance checkout learns that the PayPal page was closed without paying
  /// (back button: PayPal reports nothing then). The shopping wallet's page is unchanged.
  Widget _financePaypalPage(Widget page) {
    if (!_financeCheckout) return page;
    return PopScope(onPopInvokedWithResult: (didPop, _) => didPop ? _financeFailed('paypal') : null, child: page);
  }

  ///PayStack Payment Method
  Future<void> payStackPayment(String totalAmount) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await PayStackURLGen.payStackURLGen(
      amount: chargeUnits?.toString() ?? (double.parse(totalAmount) * 100).round().toString(),
      currency: chargeCurrency ?? "ZAR",
      secretKey: payStackModel.value.secretKey.toString(),
      userModel: userModel.value,
    ).then((value) async {
      if (value != null) {
        PayStackUrlModel payStackModel0 = value;
        ShowToastDialog.closeLoader();
        Get.to(
          PayStackScreen(
            secretKey: payStackModel.value.secretKey.toString(),
            callBackUrl: payStackModel.value.callbackURL.toString(),
            initialURl: payStackModel0.data.authorizationUrl,
            amount: totalAmount,
            reference: payStackModel0.data.reference,
          ),
        )!.then((value) {
          if (_financeResult('paystack', value == true, payStackModel0.data.reference)) return;
          if (value) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            walletTopUp();
          } else {
            ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
          }
        });
      } else {
        ShowToastDialog.closeLoader();
        if (_financeFailed('paystack')) return;
        ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      }
    });
  }

  //flutter wave Payment Method
  Future<Null> flutterWaveInitiatePayment({required BuildContext context, required String amount}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final url = Uri.parse('https://api.flutterwave.com/v3/payments');
    final headers = {'Authorization': 'Bearer ${flutterWaveModel.value.secretKey}', 'Content-Type': 'application/json'};

    // A finance payment has its own unique reference; it lets Flutterwave
    // offer every method of the currency (Mobile Money in XAF / XOF...).
    final String? txRef = _financeCheckout ? 'SPF-${const Uuid().v4()}' : _ref;
    final body = jsonEncode({
      "tx_ref": txRef,
      "amount": amount,
      "currency": chargeCurrency ?? "NGN",
      "redirect_url": "${Constant.globalUrl}payment/success",
      if (!_financeCheckout) "payment_options": "ussd, card, barter, payattitude",
      "customer": {
        "email": userModel.value.email.toString(),
        "phonenumber": userModel.value.phoneNumber, // Add a real phone number
        "name": userModel.value.fullName(), // Add a real customer name
      },
      "customizations": {"title": "Payment for Services", "description": "Payment for XYZ services"},
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      ShowToastDialog.closeLoader();
      Get.to(MercadoPagoScreen(initialURl: data['data']['link']))!.then((value) {
        if (_financeResult('flutterwave', value == true, txRef)) return;
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          walletTopUp();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      ShowToastDialog.closeLoader();
      if (_financeFailed('flutterwave')) return null;
      print('Payment initialization failed: ${response.body}');
      return null;
    }
  }

  String? _ref;

  void setRef() {
    maths.Random numRef = maths.Random();
    int year = DateTime.now().year;
    int refNumber = numRef.nextInt(20000);
    if (Platform.isAndroid) {
      _ref = "AndroidRef$year$refNumber";
    } else if (Platform.isIOS) {
      _ref = "IOSRef$year$refNumber";
    }
  }

  // payFast
  Future<void> payFastPayment({required BuildContext context, required String amount}) {
    ShowToastDialog.showLoader("Please wait".tr);
    return PayStackURLGen.getPayHTML(payFastSettingData: payFastModel.value, amount: amount.toString(), userModel: userModel.value).then((String? value) async {
      ShowToastDialog.closeLoader();
      if (_financeCheckout) {
        // Closing the page (no result) is a cancelled payment, never a crash.
        final dynamic done = value == null ? false : await Get.to(PayFastScreen(htmlData: value, payFastSettingData: payFastModel.value));
        _financeResult('payfast', done == true, null);
        return;
      }
      bool isDone = await Get.to(PayFastScreen(htmlData: value!, payFastSettingData: payFastModel.value));
      if (isDone) {
        Get.back();
        ShowToastDialog.showToast("Payment successfully".tr);
        walletTopUp();
      } else {
        Get.back();
        ShowToastDialog.showToast("Payment Failed".tr);
      }
    });
  }

  ///RazorPay payment function
  final Razorpay razorPay = Razorpay();

  void openCheckout({required amount, required orderId}) async {
    var options = {
      'key': razorPayModel.value.razorpayKey,
      'amount': amount * 100,
      'name': 'spideli',
      'order_id': orderId,
      "currency": "INR",
      'description': 'wallet Topup',
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {'contact': userModel.value.phoneNumber, 'email': userModel.value.email},
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      razorPay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
      _financeFailed('razorpay');
    }
  }

  void handlePaymentSuccess(PaymentSuccessResponse response) {
    if (_financeResult('razorpay', true, response.paymentId)) return;
    ShowToastDialog.showToast("Payment Successful!!".tr);
    walletTopUp();
  }

  void handleExternalWaller(ExternalWalletResponse response) {
    // An external wallet's outcome is not reported back: not a confirmed finance payment.
    if (_financeFailed('razorpay')) return;
    Get.back();
    ShowToastDialog.showToast("Payment Processing!! via".tr);
  }

  void handlePaymentError(PaymentFailureResponse response) {
    if (_financeFailed('razorpay', response.message)) return;
    Get.back();
    ShowToastDialog.showToast("Payment Failed!!".tr);
  }

  //Midtrans payment
  Future<void> midtransMakePayment({required String amount, required BuildContext context}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await createPaymentLink(amount: amount).then((url) {
      ShowToastDialog.closeLoader();
      if (url != '') {
        final String? orderId = _midtransOrderId;
        Get.to(() => MidtransScreen(initialURl: url))!.then((value) {
          if (_financeResult('midtrans', value == true, orderId)) return;
          if (value == true) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            walletTopUp();
          } else {
            ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          }
        });
      } else {
        _financeFailed('midtrans');
      }
    });
  }

  Future<String> createPaymentLink({required dynamic amount}) async {
    var ordersId = const Uuid().v1();
    _midtransOrderId = ordersId;
    final url = Uri.parse(midTransModel.value.isSandbox! ? 'https://api.sandbox.midtrans.com/v1/payment-links' : 'https://api.midtrans.com/v1/payment-links');

    final response = await http.post(
      url,
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': generateBasicAuthHeader(midTransModel.value.serverKey!)},
      body: jsonEncode({
        'transaction_details': {'order_id': ordersId, 'gross_amount': double.parse(amount.toString()).toInt()},
        'usage_limit': 2,
        "callbacks": {"finish": "https://www.google.com?merchant_order_id=$ordersId"},
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      return responseData['payment_url'];
    } else {
      ShowToastDialog.showToast("something went wrong, please contact admin.".tr);
      return '';
    }
  }

  String generateBasicAuthHeader(String apiKey) {
    String credentials = '$apiKey:';
    String base64Encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $base64Encoded';
  }

  //Orangepay payment
  static String accessToken = '';
  static String payToken = '';
  static String orderId = '';
  static String amount = '';

  Future<void> orangeMakePayment({required String amount, required BuildContext context}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    reset();
    var id = const Uuid().v4();
    var paymentURL = await fetchToken(context: context, orderId: id, amount: amount, currency: chargeCurrency ?? 'USD');
    ShowToastDialog.closeLoader();
    if (paymentURL.toString() != '') {
      final String paidOrder = orderId;
      Get.to(() => OrangeMoneyScreen(initialURl: paymentURL, accessToken: accessToken, amount: amount, orangePay: orangeMoneyModel.value, orderId: orderId, payToken: payToken))!.then((value) {
        if (_financeResult('orange_money', value == true, paidOrder)) return;
        if (value == true) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          walletTopUp();
        }
      });
    } else {
      if (_financeFailed('orange_money')) return;
      ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
    }
  }

  Future fetchToken({required String orderId, required String currency, required BuildContext context, required String amount}) async {
    String apiUrl = 'https://api.orange.com/oauth/v3/token';
    Map<String, String> requestBody = {'grant_type': 'client_credentials'};

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{'Authorization': "Basic ${orangeMoneyModel.value.auth!}", 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.body);

      accessToken = responseData['access_token'];
      return await webpayment(context: context, amountData: amount, currency: currency, orderIdData: orderId);
    } else {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return '';
    }
  }

  Future webpayment({required String orderIdData, required BuildContext context, required String currency, required String amountData}) async {
    orderId = orderIdData;
    amount = amountData;
    String apiUrl = orangeMoneyModel.value.isSandbox! == true ? 'https://api.orange.com/orange-money-webpay/dev/v1/webpayment' : 'https://api.orange.com/orange-money-webpay/cm/v1/webpayment';
    Map<String, String> requestBody = {
      "merchant_key": orangeMoneyModel.value.merchantKey ?? '',
      "currency": orangeMoneyModel.value.isSandbox == true ? "OUV" : currency,
      "order_id": orderId,
      "amount": amount,
      "reference": 'Y-Note Test',
      "lang": "en",
      "return_url": orangeMoneyModel.value.returnUrl!.toString(),
      "cancel_url": orangeMoneyModel.value.cancelUrl!.toString(),
      "notif_url": orangeMoneyModel.value.notifUrl!.toString(),
    };

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode(requestBody),
    );
    print(response.statusCode);

    // Handle the response
    if (response.statusCode == 201) {
      Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['message'] == 'OK') {
        payToken = responseData['pay_token'];
        return responseData['payment_url'];
      } else {
        return '';
      }
    } else {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return '';
    }
  }

  static void reset() {
    accessToken = '';
    payToken = '';
    orderId = '';
    amount = '';
  }

  //XenditPayment
  Future<void> xenditPayment(context, amount) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await createXenditInvoice(amount: amount).then((model) {
      ShowToastDialog.closeLoader();
      if (model.id != null) {
        Get.to(() => XenditScreen(initialURl: model.invoiceUrl ?? '', transId: model.id ?? '', apiKey: xenditModel.value.apiKey!.toString()))!.then((value) {
          if (_financeResult('xendit', value == true, model.id)) return;
          if (value == true) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            walletTopUp();
          } else {
            ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          }
        });
      } else {
        _financeFailed('xendit');
      }
    });
  }

  Future<XenditModel> createXenditInvoice({required dynamic amount}) async {
    const url = 'https://api.xendit.co/v2/invoices';
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': generateBasicAuthHeader(xenditModel.value.apiKey!.toString()),
      // 'Cookie': '__cf_bm=yERkrx3xDITyFGiou0bbKY1bi7xEwovHNwxV1vCNbVc-1724155511-1.0.1.1-jekyYQmPCwY6vIJ524K0V6_CEw6O.dAwOmQnHtwmaXO_MfTrdnmZMka0KZvjukQgXu5B.K_6FJm47SGOPeWviQ',
    };

    final body = jsonEncode({
      'external_id': const Uuid().v1(),
      'amount': amount,
      'payer_email': 'customer@domain.com',
      'description': 'Test - VA Successful invoice payment',
      'currency': chargeCurrency ?? 'IDR', //IDR, PHP, THB, VND, MYR
    });

    try {
      final response = await http.post(Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        XenditModel model = XenditModel.fromJson(jsonDecode(response.body));
        return model;
      } else {
        return XenditModel();
      }
    } catch (e) {
      return XenditModel();
    }
  }
}
