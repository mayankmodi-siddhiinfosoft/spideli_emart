
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:get/get.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String? otp;

  VerifyOtpScreen({Key? key, required this.otp}) : super(key: key);

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  String otp = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: Icon(Icons.arrow_back)),
      ),
      body: Column(
        children: [
          Text("Collect OTP from customer".tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(
            height: 20,
          ),
          OtpTextField(
            numberOfFields: 6,
            borderColor: AppColors.colorPrimary,
            //set to true to show as box or false to show as dash
            showFieldAsBox: false,
            //runs when a code is typed in
            onSubmit: (String verificationCode) {
              setState(() {
                otp = verificationCode;
              });
            }, // end onSubmit
          ),
          Padding(
            padding: const EdgeInsets.only(right: 40.0, left: 40.0, top: 40),
            child: ConstrainedBox(
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
                  "Verify OTP".tr,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                onPressed: () async {
                  if (otp == widget.otp) {
                    Navigator.pop(context, true);
                  } else {
                    ShowToastDialog.showToast("OTP Invalid");
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
