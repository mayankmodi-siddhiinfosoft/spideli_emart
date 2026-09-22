import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/network_image_widget.dart';

/// Presentation helpers shared by the store / offer / dine-in / advertisement
/// forms. They only render; every action is passed in by the screen.

/// Dashed upload area with an icon well, a title, a caption and a tonal
/// browse button. The whole zone and the button call the same [onPressed].
class FormUploadZone extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final String buttonLabel;
  final VoidCallback onPressed;
  final DsTone tone;
  final double minHeight;
  final bool compact;

  const FormUploadZone({
    super.key,
    required this.title,
    required this.caption,
    required this.buttonLabel,
    required this.onPressed,
    this.icon = Icons.cloud_upload_outlined,
    this.tone = DsTone.brand,
    this.minHeight = 168,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final tc = c.tone(tone);
    return Semantics(
      button: true,
      label: title,
      child: DsPressable(
        onTap: onPressed,
        pressedScale: 0.985,
        child: DottedBorder(
          options: RoundedRectDottedBorderOptions(radius: const Radius.circular(DsRadius.lg), dashPattern: const [6, 5], strokeWidth: 1.4, color: tc.main.withValues(alpha: 0.55)),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: compact ? DsSpace.lg : DsSpace.xl),
            decoration: BoxDecoration(color: Color.alphaBlend(tc.soft.withValues(alpha: 0.6), c.surface), borderRadius: DsRadius.brLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                DsIconWell(icon: icon, tone: tone, size: compact ? 44 : 52, circle: true),
                DsGap(compact ? DsSpace.sm : DsSpace.md),
                Text(title, textAlign: TextAlign.center, style: t.titleSm),
                const DsGap(DsSpace.xs),
                Text(caption, textAlign: TextAlign.center, style: t.caption),
                DsGap(compact ? DsSpace.md : DsSpace.lg),
                DsButton.tonal(label: buttonLabel, icon: Icons.add_photo_alternate_outlined, size: DsButtonSize.sm, onPressed: onPressed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A picked (XFile / File) or uploaded (url String) image.
class FormPickedImage extends StatelessWidget {
  final dynamic source;
  final double? width;
  final double? height;
  final BoxFit fit;

  const FormPickedImage({super.key, required this.source, this.width, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (source is XFile) return Image.file(File((source as XFile).path), fit: fit, width: width, height: height);
    if (source is File) return Image.file(source as File, fit: fit, width: width, height: height);
    return NetworkImageWidget(imageUrl: source.toString(), fit: fit, width: width, height: height);
  }
}

/// Rounded media tile with a remove button in the corner.
class FormMediaThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  final double size;
  final String? caption;

  const FormMediaThumb({super.key, required this.child, required this.onRemove, this.size = 92, this.caption});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(borderRadius: DsRadius.brMd, border: Border.all(color: c.border), boxShadow: DsShadows.xs(context)),
              child: ClipRRect(borderRadius: DsRadius.brMd, child: child),
            ),
          ),
          if (caption != null)
            Positioned(
              left: DsSpace.xs,
              bottom: DsSpace.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: c.scrim, borderRadius: DsRadius.brPill),
                child: Text(caption!, style: DsTypography.labelSm.copyWith(color: Colors.white, fontSize: 10)),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: DsIconButton(icon: Icons.close_rounded, semanticLabel: 'Remove'.tr, size: 26, variant: DsIconButtonVariant.filled, color: c.dangerStrong, onPressed: onRemove),
          ),
        ],
      ),
    );
  }
}

/// Content of the camera / gallery source sheet. Put it inside the existing
/// `showModalBottomSheet` call; the callbacks are the screen's own.
class MediaSourceSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const MediaSourceSheet({super.key, required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return DsSheet(
      title: "Please Select".tr,
      child: Row(
        children: [
          Expanded(child: _SourceOption(icon: Icons.photo_camera_outlined, label: "Camera".tr, tone: DsTone.brand, onTap: onCamera)),
          const DsGap(DsSpace.md),
          Expanded(child: _SourceOption(icon: Icons.photo_library_outlined, label: "Gallery".tr, tone: DsTone.info, onTap: onGallery)),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final DsTone tone;
  final VoidCallback onTap;

  const _SourceOption({required this.icon, required this.label, required this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xl, horizontal: DsSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIconWell(icon: icon, tone: tone, size: 56, circle: true),
          const DsGap(DsSpace.md),
          Text(label, style: t.label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Setting row: icon well + title/subtitle + trailing switch.
class FormSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final DsTone tone;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const FormSwitchTile({super.key, required this.title, this.subtitle, required this.icon, this.tone = DsTone.brand, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
      decoration: BoxDecoration(color: c.surfaceAlt.withValues(alpha: c.isDark ? 0.6 : 0.7), borderRadius: DsRadius.brMd),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: DsMotion.of(context, DsMotion.base),
            child: DsIconWell(key: ValueKey(value), icon: icon, tone: value ? tone : DsTone.neutral, size: 40),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: t.label),
                if (subtitle != null) ...[const DsGap(2), Text(subtitle!, style: t.caption)],
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// [DsTextField] with the defaults of the legacy `TextFieldWidget`
/// (sentence capitalisation, `done` action, text keyboard) so swapping the
/// widget keeps keyboard behaviour identical.
class FormInput extends StatelessWidget {
  final String? label;
  final String hint;
  final String? helper;
  final TextEditingController? controller;
  final String? initialValue;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;
  final Widget? prefix;
  final IconData? prefixIcon;
  final Widget? suffix;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final double bottomSpacing;

  const FormInput({
    super.key,
    this.label,
    required this.hint,
    this.helper,
    this.controller,
    this.initialValue,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textInputAction = TextInputAction.done,
    this.prefix,
    this.prefixIcon,
    this.suffix,
    this.onTap,
    this.onChanged,
    this.bottomSpacing = DsSpace.lg,
  });

  @override
  Widget build(BuildContext context) {
    return DsTextField(
      label: label,
      hint: hint,
      helper: helper,
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.sentences,
      prefix: prefix,
      prefixIcon: prefixIcon,
      suffix: suffix,
      onTap: onTap,
      onChanged: onChanged,
      bottomSpacing: bottomSpacing,
    );
  }
}

/// Currency / unit text used as a field prefix.
class FormAffix extends StatelessWidget {
  final String text;
  const FormAffix(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: DsSpace.lg, end: DsSpace.sm),
      child: Text(text, style: t.titleSm.withColor(context.dsColors.brandStrong)),
    );
  }
}
