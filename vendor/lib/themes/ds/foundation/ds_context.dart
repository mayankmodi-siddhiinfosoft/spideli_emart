import 'package:flutter/material.dart';

import '../tokens/ds_colors.dart';
import '../tokens/ds_typography.dart';
import 'ds_responsive.dart';

/// Convenience accessors. Names are prefixed with `ds` to avoid clashing with
/// GetX's own BuildContext extensions (`context.theme`, `context.width`...).
///
/// ```dart
/// final c = context.dsColors;
/// final t = context.dsText;
/// final l = context.dsLayout;
/// ```
extension DsContextX on BuildContext {
  DsColors get dsColors => DsColors.of(this);
  DsTextTheme get dsText => DsTextTheme.of(this);
  DsLayout get dsLayout => DsLayout.of(this);
  bool get dsIsDark => Theme.of(this).brightness == Brightness.dark;
}
