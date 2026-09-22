import 'package:cached_network_image/cached_network_image.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/themes/responsive.dart';
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
    super.key,
    this.height,
    this.width,
    this.fit,
    required this.imageUrl,
    this.borderRadius,
    this.errorWidget,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit ?? BoxFit.fitWidth,
      height: height ?? Responsive.height(8, context),
      width: width ?? Responsive.width(15, context),
      color: color,
      fadeInDuration: DsMotion.of(context, DsMotion.base),
      // Shimmer placeholder sized like the final image (design system).
      progressIndicatorBuilder: (context, url, downloadProgress) => DsShimmer(
        child: DsSkeleton.box(
          width: width ?? Responsive.width(15, context),
          height: height ?? Responsive.height(8, context),
          radius: borderRadius ?? 0,
        ),
      ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Image.asset(
            'assets/images/placeholder.png',
            fit: fit ?? BoxFit.fitWidth,
            height: height ?? Responsive.height(8, context),
            width: width ?? Responsive.width(15, context),
          ),
    );
  }
}
