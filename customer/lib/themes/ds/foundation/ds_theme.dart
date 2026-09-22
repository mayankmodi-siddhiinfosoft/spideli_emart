import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:customer/themes/app_them_data.dart';

import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';
import '../tokens/ds_typography.dart';
import 'ds_page_transition.dart';

/// Builds the app-wide [ThemeData] from DS tokens so that *every* Material
/// widget (including ones in screens that are not redesigned yet) picks up
/// the modern look: inputs, cards, chips, dialogs, sheets, snackbars, tabs,
/// switches, pickers and page transitions.
///
/// Used by `main.dart`:
/// ```dart
/// theme: DsTheme.light(), darkTheme: DsTheme.dark(),
/// builder: (context, child) => DsBrandTheme(child: ...),
/// ```
abstract final class DsTheme {
  static ThemeData light() => build(false);
  static ThemeData dark() => build(true);

  /// [brand] overrides the accent (used by `DsAccentScope`); by default the
  /// active section color (`AppThemeData.primary300`) is used.
  static ThemeData build(bool isDark, {Color? brand}) {
    final c = DsColors.resolve(isDark, brand: brand);
    final brightness = isDark ? Brightness.dark : Brightness.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: c.onBrand,
      primaryContainer: c.brandSoft,
      onPrimaryContainer: c.brandStrong,
      secondary: c.brandStrong,
      onSecondary: c.onBrand,
      secondaryContainer: c.brandSoft,
      onSecondaryContainer: c.brandStrong,
      tertiary: c.info,
      onTertiary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.dangerStrong,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surfaceRaised,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.borderStrong,
      outlineVariant: c.border,
      shadow: c.shadow,
      scrim: Colors.black,
      inverseSurface: c.surfaceInverse,
      onInverseSurface: c.onSurfaceInverse,
      inversePrimary: c.brandMuted,
      surfaceTint: Colors.transparent,
    );

    final textTheme = TextTheme(
      displayLarge: DsTypography.displayLg.copyWith(color: c.textPrimary),
      displayMedium: DsTypography.display.copyWith(color: c.textPrimary),
      displaySmall: DsTypography.headline.copyWith(color: c.textPrimary),
      headlineLarge: DsTypography.display.copyWith(color: c.textPrimary),
      headlineMedium: DsTypography.headline.copyWith(color: c.textPrimary),
      headlineSmall: DsTypography.title.copyWith(color: c.textPrimary),
      titleLarge: DsTypography.title.copyWith(color: c.textPrimary),
      titleMedium: DsTypography.titleSm.copyWith(color: c.textPrimary),
      titleSmall: DsTypography.label.copyWith(color: c.textPrimary),
      bodyLarge: DsTypography.bodyLg.copyWith(color: c.textPrimary),
      bodyMedium: DsTypography.body.copyWith(color: c.textPrimary),
      bodySmall: DsTypography.bodySm.copyWith(color: c.textSecondary),
      labelLarge: DsTypography.label.copyWith(color: c.textPrimary),
      labelMedium: DsTypography.labelSm.copyWith(color: c.textSecondary),
      labelSmall: DsTypography.caption.copyWith(color: c.textMuted),
    );

    final buttonShape = RoundedRectangleBorder(borderRadius: DsRadius.brMd);
    const buttonMinSize = Size(64, 48);
    const buttonPadding = EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: DsSpace.md);
    final buttonText = DsTypography.label.copyWith(fontSize: 15);

    WidgetStateProperty<Color?> selectedColor(Color on, Color off) =>
        WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.textDisabled : (s.contains(WidgetState.selected) ? on : off));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppThemeData.fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      primaryColor: c.brand,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.surface,
      cardColor: c.surface,
      dividerColor: c.divider,
      hintColor: c.textMuted,
      disabledColor: c.textDisabled,
      splashFactory: InkRipple.splashFactory,
      highlightColor: c.brand.withValues(alpha: 0.06),
      splashColor: c.brand.withValues(alpha: 0.10),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconTheme: IconThemeData(color: c.textPrimary, size: 22),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: DsPageTransitionsBuilder(),
          TargetPlatform.iOS: DsPageTransitionsBuilder(),
          TargetPlatform.macOS: DsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: DsPageTransitionsBuilder(),
          TargetPlatform.linux: DsPageTransitionsBuilder(),
          TargetPlatform.windows: DsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.6,
        shadowColor: c.shadow.withValues(alpha: 0.25),
        centerTitle: false,
        titleSpacing: DsSpace.lg,
        iconTheme: IconThemeData(color: c.textPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: c.textPrimary, size: 22),
        titleTextStyle: DsTypography.title.copyWith(color: c.textPrimary),
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.brand,
        unselectedItemColor: c.textMuted,
        selectedLabelStyle: DsTypography.labelSm,
        unselectedLabelStyle: DsTypography.labelSm.copyWith(fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.brandSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => DsTypography.labelSm.copyWith(color: s.contains(WidgetState.selected) ? c.brandStrong : c.textMuted),
        ),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.brand : c.textMuted, size: 24)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.brandSoft,
        selectedIconTheme: IconThemeData(color: c.brand),
        unselectedIconTheme: IconThemeData(color: c.textMuted),
        selectedLabelTextStyle: DsTypography.labelSm.copyWith(color: c.brandStrong),
        unselectedLabelTextStyle: DsTypography.labelSm.copyWith(color: c.textMuted),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: c.shadow.withValues(alpha: 0.18),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.brLg, side: BorderSide(color: c.border)),
      ),
      // Only non-structural defaults here: many legacy screens rely on
      // `border: InputBorder.none` inside custom containers, so borders,
      // filled and contentPadding are left to each field (DsTextField /
      // DsInputDecoration provide the full DS look).
      inputDecorationTheme: InputDecorationTheme(
        fillColor: c.surfaceAlt,
        hintStyle: DsTypography.body.copyWith(color: c.textMuted),
        labelStyle: DsTypography.body.copyWith(color: c.textSecondary),
        floatingLabelStyle: DsTypography.labelSm.copyWith(color: c.brandStrong),
        helperStyle: DsTypography.caption.copyWith(color: c.textMuted),
        errorStyle: DsTypography.caption.copyWith(color: c.danger),
        prefixIconColor: c.textMuted,
        suffixIconColor: c.textMuted,
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.brand, selectionColor: c.brand.withValues(alpha: 0.28), selectionHandleColor: c.brand),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          disabledBackgroundColor: c.surfaceAlt,
          disabledForegroundColor: c.textDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          disabledBackgroundColor: c.surfaceAlt,
          disabledForegroundColor: c.textDisabled,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.borderStrong),
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brandStrong,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
          shape: buttonShape,
          textStyle: DsTypography.label,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: c.textPrimary)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.brLg),
        extendedTextStyle: buttonText,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceAlt,
        selectedColor: c.brandSoft,
        disabledColor: c.surfaceAlt,
        checkmarkColor: c.brandStrong,
        deleteIconColor: c.textMuted,
        labelStyle: DsTypography.labelSm.copyWith(color: c.textPrimary),
        secondaryLabelStyle: DsTypography.labelSm.copyWith(color: c.brandStrong),
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xs),
        side: BorderSide(color: c.border),
        shape: const StadiumBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        modalBackgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.brXl),
        titleTextStyle: DsTypography.title.copyWith(color: c.textPrimary),
        contentTextStyle: DsTypography.body.copyWith(color: c.textSecondary),
        insetPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl, vertical: DsSpace.xxl),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceInverse,
        contentTextStyle: DsTypography.bodyStrong.copyWith(color: c.onSurfaceInverse),
        actionTextColor: c.isDark ? c.brandStrong : c.brandMuted,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.brMd),
        insetPadding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.lg),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.brandStrong,
        unselectedLabelColor: c.textMuted,
        indicatorColor: c.brand,
        dividerColor: c.divider,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: DsTypography.label,
        unselectedLabelStyle: DsTypography.label.copyWith(fontWeight: FontWeight.w500),
        overlayColor: WidgetStatePropertyAll(c.brand.withValues(alpha: 0.06)),
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        titleTextStyle: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
        subtitleTextStyle: DsTypography.bodySm.copyWith(color: c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
        minVerticalPadding: DsSpace.md,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.brMd),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand, linearTrackColor: c.surfaceAlt, circularTrackColor: Colors.transparent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onBrand : (isDark ? AppThemeData.grey400 : Colors.white)),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brand : c.borderStrong),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brand : Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.onBrand),
        side: BorderSide(color: c.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(fillColor: selectedColor(c.brand, c.borderStrong)),
      sliderTheme: SliderThemeData(activeTrackColor: c.brand, inactiveTrackColor: c.surfaceAlt, thumbColor: c.brand, overlayColor: c.brand.withValues(alpha: 0.12)),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.surfaceInverse, borderRadius: DsRadius.brSm),
        textStyle: DsTypography.caption.copyWith(color: c.onSurfaceInverse),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: c.shadow.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: DsRadius.brMd, side: BorderSide(color: c.border)),
        textStyle: DsTypography.body.copyWith(color: c.textPrimary),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: DsTypography.body.copyWith(color: c.textPrimary),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: DsRadius.brMd)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.brand,
        headerForegroundColor: c.onBrand,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.brXl),
        todayBorder: BorderSide(color: c.brand),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surfaceRaised,
        dialBackgroundColor: c.surfaceAlt,
        hourMinuteColor: c.surfaceAlt,
        hourMinuteTextColor: c.textPrimary,
        dayPeriodTextColor: c.textPrimary,
        dialHandColor: c.brand,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.brXl),
      ),
      badgeTheme: BadgeThemeData(backgroundColor: c.danger, textColor: Colors.white, textStyle: DsTypography.labelSm),
      scrollbarTheme: ScrollbarThemeData(radius: const Radius.circular(8), thickness: const WidgetStatePropertyAll(4), thumbColor: WidgetStatePropertyAll(c.borderStrong)),
    );
  }
}

/// Re-applies the DS theme whenever the runtime brand color
/// (`AppThemeData.primary300`) changes, so Material widgets (switches,
/// pickers, selection handles, bottom navigation...) always use the current
/// accent. In the customer app that color is the app color from
/// `globalSettings.app_customer_color` until a service is opened, then the
/// tapped section's color (`ServiceListController.onServiceTap`).
///
/// Put it in `GetMaterialApp.builder` and add [DsBrandTheme.observer] to
/// `navigatorObservers`; every route change re-checks the brand color, so
/// opening a service re-themes the app to that service's accent.
class DsBrandTheme extends StatefulWidget {
  final Widget child;
  const DsBrandTheme({super.key, required this.child});

  static final ValueNotifier<Color> _brand = ValueNotifier<Color>(AppThemeData.primary300);

  /// Call after changing `AppThemeData.primary300` to re-theme immediately.
  static void refresh() {
    if (_brand.value != AppThemeData.primary300) _brand.value = AppThemeData.primary300;
  }

  /// Navigator observer that calls [refresh] after each navigation.
  static final NavigatorObserver observer = _DsBrandObserver();

  @override
  State<DsBrandTheme> createState() => _DsBrandThemeState();
}

class _DsBrandThemeState extends State<DsBrandTheme> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: DsBrandTheme._brand,
      builder: (context, _, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(data: DsTheme.build(isDark), child: widget.child);
      },
    );
  }
}

class _DsBrandObserver extends NavigatorObserver {
  void _schedule() => SchedulerBinding.instance.addPostFrameCallback((_) => DsBrandTheme.refresh());

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _schedule();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _schedule();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _schedule();
}
