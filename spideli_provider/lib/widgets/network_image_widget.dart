import 'package:cached_network_image/cached_network_image.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:flutter/material.dart';

class NetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final Widget? errorWidget;
  final BoxFit? fit;
  final double? borderRadius;
  final Color? color;

  const NetworkImageWidget({
    Key? key,
    this.height,
    this.width,
    this.fit,
    required this.imageUrl,
    this.borderRadius,
    this.errorWidget,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit ?? BoxFit.fitWidth,
      height: height ?? Responsive.height(8, context),
      width: width ?? Responsive.width(15, context),
      color: color,
      progressIndicatorBuilder: (context, url, downloadProgress) => loader(),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Image.network(
            placeholderImage,
            fit: BoxFit.cover,
            height: height ?? Responsive.height(8, context),
            width: width ?? Responsive.width(15, context),
          ),
    );
  }
}
