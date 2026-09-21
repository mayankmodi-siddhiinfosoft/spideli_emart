import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/ui/auth/auth_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

//helper method to show alert dialog
showAlertDialog(BuildContext context, String title, String content, bool addOkButton, {bool? login}) {
  // set up the AlertDialog
  Widget? okButton;
  if (addOkButton) {
    okButton = TextButton(
      child: Text('OK'.tr),
      onPressed: () {
        if (login == true) {
          Get.offAll(AuthScreen());
        } else {
          Get.back();
        }
      },
    );
  }

  if (Platform.isIOS) {
    CupertinoAlertDialog alert = CupertinoAlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [if (okButton != null) okButton],
    );
    showCupertinoDialog(
        context: context,
        builder: (context) {
          return alert;
        });
  } else {
    AlertDialog alert = AlertDialog(title: Text(title), content: Text(content), actions: [if (okButton != null) okButton]);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}

showimgAlertDialog(BuildContext context, String title, String content, bool addOkButton) {
  Widget? okButton;
  if (addOkButton) {
    okButton = TextButton(
      child: Text('OK'.tr),
      onPressed: () {
        Get.back();
      },
    );
  }

  if (Platform.isIOS) {
    CupertinoAlertDialog alert = CupertinoAlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [if (okButton != null) okButton],
    );
    showCupertinoDialog(
        context: context,
        builder: (context) {
          return alert;
        });
  } else {
    AlertDialog alert = AlertDialog(title: Text(title), content: Text(content), actions: [if (okButton != null) okButton]);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}

Widget displayCircleImage(String picUrl, double size, hasBorder) => CachedNetworkImage(
    height: size,
    width: size,
    imageBuilder: (context, imageProvider) => _getCircularImageProvider(imageProvider, size, hasBorder),
    imageUrl: picUrl,
    placeholder: (context, url) => loader(),
    errorWidget: (context, url, error) => Image.asset(
          'assets/images/placeholder.png',
          fit: BoxFit.cover,
          height: size,
          width: size,
        ));

Widget _getCircularImageProvider(ImageProvider provider, double size, bool hasBorder) {
  return ClipOval(
      child: Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(size / 2)),
        border: Border.all(
          color: Colors.white,
          style: hasBorder ? BorderStyle.solid : BorderStyle.none,
          width: 1.0,
        ),
        image: DecorationImage(
          image: provider,
          fit: BoxFit.cover,
        )),
  ));
}

bool isDarkMode(BuildContext context) {
  if (Theme.of(context).brightness == Brightness.light) {
    return false;
  } else {
    return true;
  }
}

Widget displayImage(String picUrl) => CachedNetworkImage(
    imageBuilder: (context, imageProvider) => _getFlatImageProvider(imageProvider),
    imageUrl: picUrl,
    placeholder: (context, url) => _getFlatPlaceholderOrErrorImage(true),
    errorWidget: (context, url, error) => _getFlatPlaceholderOrErrorImage(false));

Widget _getFlatPlaceholderOrErrorImage(bool placeholder) => Container(
      child: placeholder
          ? const Center(child: CircularProgressIndicator())
          : Icon(
              Icons.error,
              color: AppColors.colorPrimary,
            ),
    );

Widget _getFlatImageProvider(ImageProvider provider) {
  return Container(
    decoration: BoxDecoration(image: DecorationImage(image: provider, fit: BoxFit.cover)),
  );
}

String? validateEmptyField(String? text) => text == null || text.isEmpty ? "This field can't be empty." : null;
