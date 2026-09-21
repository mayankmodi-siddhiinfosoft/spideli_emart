import 'dart:convert';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/model/payment_model/razorpay_model.dart';
import 'package:spideliprovider/payment/createRazorPayOrderModel.dart';
import 'package:http/http.dart' as http;

class RazorPayController {
  Future<CreateRazorPayOrderModel?> createOrderRazorPay({required int amount, required RazorPayModel? razorpayModel}) async {
    final String orderId = DateTime.now().millisecondsSinceEpoch.toString();
    RazorPayModel razorPayData = razorpayModel!;
    print(razorPayData.razorpayKey);
    print("we Enter In");
    const url = "${globalUrl}payments/razorpay/createorder";
    print(orderId);
    final response = await http.post(
      Uri.parse(url),
      body: {
        "amount": (amount * 100).toString(),
        "receipt_id": orderId,
        "currency": "INR",
        "razorpaykey": razorPayData.razorpayKey,
        "razorPaySecret": razorPayData.razorpaySecret,
        "isSandBoxEnabled": razorPayData.isSandboxEnabled.toString(),
      },
    );

    if (response.statusCode == 500) {
      return null;
    } else {
      final data = jsonDecode(response.body);
      print(data);

      return CreateRazorPayOrderModel.fromJson(data);
    }
  }
}
