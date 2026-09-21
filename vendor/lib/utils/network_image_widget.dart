import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/themes/responsive.dart';

class NetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final Widget? errorWidget;
  final BoxFit? fit;
  final double? borderRadius;
  final Color? color;

  final bool showShimmer;

  const NetworkImageWidget({super.key, this.height, this.width, this.fit, required this.imageUrl, this.borderRadius, this.errorWidget, this.color, this.showShimmer = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = width ?? Responsive.width(15, context);
    final h = height ?? Responsive.height(8, context);
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit ?? BoxFit.fitWidth,
      height: h,
      width: w,
      color: color,
      placeholder: (context, url) => showShimmer
          ? Shimmer.fromColors(
              baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
              highlightColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
              child: Container(height: h, width: w, color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0)),
            )
          : SizedBox(height: h, width: w),
      errorWidget: (context, url, error) => errorWidget ?? Image.network(Constant.placeholderImage, fit: fit ?? BoxFit.cover, height: h, width: w),
    );
  }
}
