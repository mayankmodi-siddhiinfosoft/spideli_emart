import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as maths;

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/payment_model/flutter_wave_model.dart';
import 'package:customer/models/payment_model/mercado_pago_model.dart';
import 'package:customer/models/payment_model/mid_trans.dart';
import 'package:customer/models/payment_model/orange_money.dart';
import 'package:customer/models/payment_model/pay_fast_model.dart';
import 'package:customer/models/payment_model/pay_stack_model.dart';
import 'package:customer/models/payment_model/paypal_model.dart';
import 'package:customer/models/payment_model/razorpay_model.dart';
import 'package:customer/models/payment_model/stripe_model.dart';
import 'package:customer/models/payment_model/wallet_setting_model.dart';
import 'package:customer/models/payment_model/xendit.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/mercado_pago_screen.dart';
import 'package:customer/payment/midtrans_screen.dart';
import 'package:customer/payment/orange_pay_screen.dart';
import 'package:customer/payment/pay_fast_screen.dart';
import 'package:customer/payment/paystack/pay_stack_screen.dart';
import 'package:customer/payment/paystack/pay_stack_url_model.dart';
import 'package:customer/payment/paystack/paystack_url_genrater.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/payment/stripe_failed_model.dart';
import 'package:customer/payment/xendit_model.dart';
import 'package:customer/payment/xendit_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/preferences.dart';
import 'package:customer/utils/region_service.dart';
import 'package:customer/utils/saved_payment_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';

/// A one-off payment (a subscription purchase) through the app's EXISTING
/// gateway integrations - the same calls the gift-card / wallet top-up flows
/// make - with no order attached. On success [onPaid] records the purchase;
/// the checkout screen then closes with `true`.
///
/// Gateways are filtered by [regionId] (spec 18.7). Cash on delivery is not
/// offered (nothing is delivered against it).
class GatewayCheckoutController extends GetxController {
  final String amount;
  final String? regionId;
  final String description;
  final Future<void> Function(String paymentMethod) onPaid;

  GatewayCheckoutController({required this.amount, required this.regionId, required this.description, required this.onPaid});

  RxBool isLoading = true.obs;
  RxString selectedPaymentMethod = ''.obs;
  Rx<UserModel> userModel = UserModel().obs;
  bool _completed = false;

  Rx<WalletSettingModel> walletSettingModel = WalletSettingModel().obs;
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

  final Razorpay razorPay = Razorpay();

  /// Wallet balance is account-level: shown in the customer's currency.
  CurrencyModel? get walletCurrency => RegionService.customerCurrency;

  /// Phone for gateways that take one: the default saved Mobile Money / Wave
  /// number usable in this region, else the account phone.
  String? get payerPhone => SavedPaymentMethods.checkoutPhone(regionId: regionId, fallback: userModel.value.phoneNumber);

  @override
  void onInit() {
    _load();
    super.onInit();
  }

  @override
  void onClose() {
    razorPay.clear();
    super.onClose();
  }

  Future<void> _load() async {
    try {
      final user = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      if (user != null) userModel.value = user;
      await RegionService.ensureLoaded();
      await FireStoreUtils.getPaymentSettingsData();
      Map<String, dynamic> s(String key) => RegionService.gatewaySettings(key, regionId);
      payFastModel.value = PayFastModel.fromJson(s(Preferences.payFastSettings));
      mercadoPagoModel.value = MercadoPagoModel.fromJson(s(Preferences.mercadoPago));
      payPalModel.value = PayPalModel.fromJson(s(Preferences.paypalSettings));
      stripeModel.value = StripeModel.fromJson(s(Preferences.stripeSettings));
      flutterWaveModel.value = FlutterWaveModel.fromJson(s(Preferences.flutterWave));
      payStackModel.value = PayStackModel.fromJson(s(Preferences.payStack));
      razorPayModel.value = RazorPayModel.fromJson(s(Preferences.razorpaySettings));
      midTransModel.value = MidTrans.fromJson(s(Preferences.midTransSettings));
      orangeMoneyModel.value = OrangeMoney.fromJson(s(Preferences.orangeMoneySettings));
      xenditModel.value = Xendit.fromJson(s(Preferences.xenditSettings));
      walletSettingModel.value = WalletSettingModel.fromJson(s(Preferences.walletSettings));

      final available = availableMethods;
      if (available.isNotEmpty) selectedPaymentMethod.value = available.first.name;

      if (stripeModel.value.isEnabled == true) {
        Stripe.publishableKey = stripeModel.value.clientpublishableKey.toString();
        Stripe.merchantIdentifier = 'GoRide';
        Stripe.instance.applySettings();
      }
      _setRef();
      razorPay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) => _success());
      razorPay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) => ShowToastDialog.showToast("Payment Processing!! via".tr));
      razorPay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) => ShowToastDialog.showToast("Payment Failed!!".tr));
    } catch (e, s) {
      log("GatewayCheckoutController load: $e", stackTrace: s);
    }
    isLoading.value = false;
  }

  /// Enabled gateways for this region, in the app's usual order.
  List<PaymentGateway> get availableMethods => [
    if (walletSettingModel.value.isEnabled == true) PaymentGateway.wallet,
    if (stripeModel.value.isEnabled == true) PaymentGateway.stripe,
    if (payPalModel.value.isEnabled == true) PaymentGateway.paypal,
    if (payStackModel.value.isEnable == true) PaymentGateway.payStack,
    if (mercadoPagoModel.value.isEnabled == true) PaymentGateway.mercadoPago,
    if (flutterWaveModel.value.isEnable == true) PaymentGateway.flutterWave,
    if (payFastModel.value.isEnable == true) PaymentGateway.payFast,
    if (razorPayModel.value.isEnabled == true) PaymentGateway.razorpay,
    if (midTransModel.value.enable == true) PaymentGateway.midTrans,
    if (orangeMoneyModel.value.enable == true) PaymentGateway.orangeMoney,
    if (xenditModel.value.enable == true) PaymentGateway.xendit,
  ];

  static String imageOf(PaymentGateway g) {
    switch (g) {
      case PaymentGateway.wallet:
        return "assets/images/ic_wallet.png";
      case PaymentGateway.stripe:
        return "assets/images/stripe.png";
      case PaymentGateway.paypal:
        return "assets/images/paypal.png";
      case PaymentGateway.payStack:
        return "assets/images/paystack.png";
      case PaymentGateway.mercadoPago:
        return "assets/images/mercado-pago.png";
      case PaymentGateway.flutterWave:
        return "assets/images/flutterwave_logo.png";
      case PaymentGateway.payFast:
        return "assets/images/payfast.png";
      case PaymentGateway.razorpay:
        return "assets/images/razorpay.png";
      case PaymentGateway.midTrans:
        return "assets/images/midtrans.png";
      case PaymentGateway.orangeMoney:
        return "assets/images/orange_money.png";
      case PaymentGateway.xendit:
        return "assets/images/xendit.png";
      case PaymentGateway.cod:
        return "assets/images/cod.png";
    }
  }

  // ---------------------------------------------------------------- Pay

  Future<void> pay(BuildContext context) async {
    final method = selectedPaymentMethod.value;
    if (method.isEmpty) {
      ShowToastDialog.showToast("Please select payment method".tr);
      return;
    }
    if (method == PaymentGateway.wallet.name) {
      await _payWithWallet();
    } else if (method == PaymentGateway.stripe.name) {
      await _stripe();
    } else if (method == PaymentGateway.paypal.name) {
      _paypal(context);
    } else if (method == PaymentGateway.payStack.name) {
      await _payStack();
    } else if (method == PaymentGateway.mercadoPago.name) {
      await _mercadoPago();
    } else if (method == PaymentGateway.flutterWave.name) {
      await _flutterWave();
    } else if (method == PaymentGateway.payFast.name) {
      await _payFast();
    } else if (method == PaymentGateway.razorpay.name) {
      await _razorpay();
    } else if (method == PaymentGateway.midTrans.name) {
      await _midtrans();
    } else if (method == PaymentGateway.orangeMoney.name) {
      await _orangeMoney(context);
    } else if (method == PaymentGateway.xendit.name) {
      await _xendit();
    }
  }

  /// Payment confirmed: record it once, then close the checkout with true.
  Future<void> _success() async {
    if (_completed) return;
    _completed = true;
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      await onPaid(selectedPaymentMethod.value);
      ShowToastDialog.closeLoader();
      Get.back(result: true);
    } catch (e) {
      ShowToastDialog.closeLoader();
      log("GatewayCheckoutController record failed: $e");
      ShowToastDialog.showToast("${"Payment received but saving failed. Please contact support.".tr} $e");
    }
  }

  void _failed() => ShowToastDialog.showToast("Payment UnSuccessful!!".tr);

  Future<void> _payWithWallet() async {
    final double value = double.tryParse(amount) ?? 0;
    final double balance = double.tryParse(userModel.value.walletAmount?.toString() ?? '0') ?? 0;
    if (balance < value) {
      ShowToastDialog.showToast("You don't have sufficient wallet balance".tr);
      return;
    }
    final String refId = const Uuid().v4();
    final tx = WalletTransactionModel(
      id: Constant.getUuid(),
      amount: value,
      date: Timestamp.now(),
      paymentMethod: PaymentGateway.wallet.name,
      transactionUser: "user",
      userId: FireStoreUtils.getCurrentUid(),
      isTopup: false,
      orderId: refId,
      note: description,
      paymentStatus: "success",
      regionId: RegionService.customerRegionId,
    );
    final ok = await FireStoreUtils.setWalletTransaction(tx);
    if (ok != true) {
      _failed();
      return;
    }
    await FireStoreUtils.updateUserWallet(amount: "-$amount", userId: FireStoreUtils.getCurrentUid());
    await _success();
  }

  // Stripe
  Future<void> _stripe() async {
    try {
      final body = {
        'amount': ((double.parse(amount) * 100).round()).toString(),
        'currency': "USD",
        'payment_method_types[]': 'card',
        "description": description,
        "shipping[name]": userModel.value.fullName(),
        "shipping[address][line1]": "510 Townsend St",
        "shipping[address][postal_code]": "98140",
        "shipping[address][city]": "San Francisco",
        "shipping[address][state]": "CA",
        "shipping[address][country]": "US",
      };
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {'Authorization': 'Bearer ${stripeModel.value.stripeSecret}', 'Content-Type': 'application/x-www-form-urlencoded'},
      );
      final Map<String, dynamic> intent = jsonDecode(response.body);
      if (intent.containsKey("error")) {
        ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
        return;
      }
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent['client_secret'],
          allowsDelayedPaymentMethods: false,
          googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'US', testEnv: true, currencyCode: "USD"),
          customFlow: true,
          style: ThemeMode.system,
          appearance: PaymentSheetAppearance(colors: PaymentSheetAppearanceColors(primary: AppThemeData.primary300)),
          merchantDisplayName: 'GoRide',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      await _success();
    } on StripeException catch (e) {
      final lom = StripePayFailedModel.fromJson(jsonDecode(jsonEncode(e)));
      ShowToastDialog.showToast(lom.error.message);
    } catch (e) {
      ShowToastDialog.showToast(e.toString());
    }
  }

  // PayPal
  void _paypal(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (BuildContext context) => UsePaypal(
              sandboxMode: payPalModel.value.isLive == true ? false : true,
              clientId: payPalModel.value.paypalClient ?? '',
              secretKey: payPalModel.value.paypalSecret ?? '',
              returnURL: "com.parkme://paypalpay",
              cancelURL: "com.parkme://paypalpay",
              transactions: [
                {
                  "amount": {
                    "total": amount,
                    "currency": "USD",
                    "details": {"subtotal": amount},
                  },
                },
              ],
              note: description,
              onSuccess: (Map params) async => _success(),
              onError: (error) => _failed(),
              onCancel: (params) => _failed(),
            ),
      ),
    );
  }

  // PayStack
  Future<void> _payStack() async {
    ShowToastDialog.showLoader("Please wait".tr);
    final value = await PayStackURLGen.payStackURLGen(
      amount: (double.parse(amount) * 100).round().toString(),
      currency: "ZAR",
      secretKey: payStackModel.value.secretKey.toString(),
      userModel: userModel.value,
    );
    ShowToastDialog.closeLoader();
    if (value == null) {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return;
    }
    final PayStackUrlModel url = value;
    final result = await Get.to(
      PayStackScreen(
        secretKey: payStackModel.value.secretKey.toString(),
        callBackUrl: payStackModel.value.callbackURL.toString(),
        initialURl: url.data.authorizationUrl,
        amount: amount,
        reference: url.data.reference,
      ),
    );
    result == true ? await _success() : _failed();
  }

  // Mercado Pago
  Future<void> _mercadoPago() async {
    ShowToastDialog.showLoader("Please wait".tr);
    final response = await http.post(
      Uri.parse("https://api.mercadopago.com/checkout/preferences"),
      headers: {'Authorization': 'Bearer ${mercadoPagoModel.value.accessToken}', 'Content-Type': 'application/json'},
      body: jsonEncode({
        "items": [
          {"title": description, "description": description, "quantity": 1, "currency_id": "BRL", "unit_price": double.parse(amount)},
        ],
        "payer": {"email": userModel.value.email},
        "back_urls": {"failure": "${Constant.globalUrl}payment/failure", "pending": "${Constant.globalUrl}payment/pending", "success": "${Constant.globalUrl}payment/success"},
        "auto_return": "approved",
      }),
    );
    ShowToastDialog.closeLoader();
    if (response.statusCode != 200 && response.statusCode != 201) {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return;
    }
    final data = jsonDecode(response.body);
    final result = await Get.to(MercadoPagoScreen(initialURl: data['init_point']));
    result == true ? await _success() : _failed();
  }

  // Flutterwave (takes the payer's phone: prefilled from the saved method)
  String? _ref;

  void _setRef() {
    final int refNumber = maths.Random().nextInt(20000);
    final int year = DateTime.now().year;
    _ref = Platform.isIOS ? "IOSRef$year$refNumber" : "AndroidRef$year$refNumber";
  }

  Future<void> _flutterWave() async {
    ShowToastDialog.showLoader("Please wait".tr);
    final response = await http.post(
      Uri.parse('https://api.flutterwave.com/v3/payments'),
      headers: {'Authorization': 'Bearer ${flutterWaveModel.value.secretKey}', 'Content-Type': 'application/json'},
      body: jsonEncode({
        "tx_ref": _ref,
        "amount": amount,
        "currency": "NGN",
        "redirect_url": "${Constant.globalUrl}payment/success",
        "payment_options": "ussd, card, barter, payattitude",
        "customer": {"email": userModel.value.email.toString(), "phonenumber": payerPhone, "name": userModel.value.fullName()},
        "customizations": {"title": description, "description": description},
      }),
    );
    ShowToastDialog.closeLoader();
    if (response.statusCode != 200) {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return;
    }
    final data = jsonDecode(response.body);
    final result = await Get.to(MercadoPagoScreen(initialURl: data['data']['link']));
    result == true ? await _success() : _failed();
  }

  // PayFast
  Future<void> _payFast() async {
    ShowToastDialog.showLoader("Please wait".tr);
    final html = await PayStackURLGen.getPayHTML(payFastSettingData: payFastModel.value, amount: amount, userModel: userModel.value);
    ShowToastDialog.closeLoader();
    final result = await Get.to(PayFastScreen(htmlData: html, payFastSettingData: payFastModel.value));
    result == true ? await _success() : _failed();
  }

  // Razorpay (contact prefilled from the saved method)
  Future<void> _razorpay() async {
    final CreateRazorPayOrderModel? order = await RazorPayController().createOrderRazorPay(amount: double.parse(amount), razorpayModel: razorPayModel.value);
    if (order == null) {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return;
    }
    try {
      razorPay.open({
        'key': razorPayModel.value.razorpayKey,
        'amount': (double.parse(amount) * 100).round(),
        'name': 'spideli',
        'order_id': order.id,
        "currency": "INR",
        'description': description,
        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,
        'prefill': {'contact': payerPhone, 'email': userModel.value.email},
        'external': {
          'wallets': ['paytm'],
        },
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // Midtrans
  Future<void> _midtrans() async {
    ShowToastDialog.showLoader("Please wait".tr);
    final ordersId = const Uuid().v1();
    final response = await http.post(
      Uri.parse(midTransModel.value.isSandbox == true ? 'https://api.sandbox.midtrans.com/v1/payment-links' : 'https://api.midtrans.com/v1/payment-links'),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': _basicAuth(midTransModel.value.serverKey ?? '')},
      body: jsonEncode({
        'transaction_details': {'order_id': ordersId, 'gross_amount': double.parse(amount).toInt()},
        'usage_limit': 2,
        "callbacks": {"finish": "https://www.google.com?merchant_order_id=$ordersId"},
      }),
    );
    ShowToastDialog.closeLoader();
    if (response.statusCode != 200 && response.statusCode != 201) {
      ShowToastDialog.showToast("something went wrong, please contact admin.".tr);
      return;
    }
    final url = jsonDecode(response.body)['payment_url'];
    final result = await Get.to(() => MidtransScreen(initialURl: url));
    result == true ? await _success() : _failed();
  }

  String _basicAuth(String apiKey) => 'Basic ${base64Encode(utf8.encode('$apiKey:'))}';

  // Orange Money (web payment: the payer enters the number on Orange's page)
  Future<void> _orangeMoney(BuildContext context) async {
    ShowToastDialog.showLoader("Please wait".tr);
    String accessToken = '';
    String payToken = '';
    final String orderId = const Uuid().v4();
    String paymentUrl = '';
    try {
      final tokenResponse = await http.post(
        Uri.parse('https://api.orange.com/oauth/v3/token'),
        headers: {'Authorization': "Basic ${orangeMoneyModel.value.auth ?? ''}", 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json'},
        body: {'grant_type': 'client_credentials'},
      );
      if (tokenResponse.statusCode == 200) {
        accessToken = jsonDecode(tokenResponse.body)['access_token'];
        final response = await http.post(
          Uri.parse(orangeMoneyModel.value.isSandbox == true ? 'https://api.orange.com/orange-money-webpay/dev/v1/webpayment' : 'https://api.orange.com/orange-money-webpay/cm/v1/webpayment'),
          headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: json.encode({
            "merchant_key": orangeMoneyModel.value.merchantKey ?? '',
            "currency": orangeMoneyModel.value.isSandbox == true ? "OUV" : 'USD',
            "order_id": orderId,
            "amount": amount,
            "reference": description,
            "lang": "en",
            "return_url": orangeMoneyModel.value.returnUrl.toString(),
            "cancel_url": orangeMoneyModel.value.cancelUrl.toString(),
            "notif_url": orangeMoneyModel.value.notifUrl.toString(),
          }),
        );
        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          if (data['message'] == 'OK') {
            payToken = data['pay_token'];
            paymentUrl = data['payment_url'];
          }
        }
      }
    } catch (e) {
      log("Orange Money: $e");
    }
    ShowToastDialog.closeLoader();
    if (paymentUrl.isEmpty) {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return;
    }
    final result = await Get.to(() => OrangeMoneyScreen(initialURl: paymentUrl, accessToken: accessToken, amount: amount, orangePay: orangeMoneyModel.value, orderId: orderId, payToken: payToken));
    result == true ? await _success() : _failed();
  }

  // Xendit
  Future<void> _xendit() async {
    ShowToastDialog.showLoader("Please wait".tr);
    XenditModel model = XenditModel();
    try {
      final response = await http.post(
        Uri.parse('https://api.xendit.co/v2/invoices'),
        headers: {'Content-Type': 'application/json', 'Authorization': _basicAuth(xenditModel.value.apiKey.toString())},
        body: jsonEncode({'external_id': const Uuid().v1(), 'amount': amount, 'payer_email': userModel.value.email ?? 'customer@domain.com', 'description': description, 'currency': 'IDR'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) model = XenditModel.fromJson(jsonDecode(response.body));
    } catch (_) {}
    ShowToastDialog.closeLoader();
    if (model.id == null) {
      _failed();
      return;
    }
    final result = await Get.to(() => XenditScreen(initialURl: model.invoiceUrl ?? '', transId: model.id ?? '', apiKey: xenditModel.value.apiKey.toString()));
    result == true ? await _success() : _failed();
  }
}
