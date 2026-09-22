# spideli Provider – Design System (DS)

On-demand **service provider** app (`spideli_provider`, package `spideliprovider`).
Same public API as the Store (vendor) design system, adapted to this app's
theme, brand color, fonts and Provider-based dark mode.

```dart
import 'package:spideliprovider/themes/ds/ds.dart';   // everything: tokens, layout, motion, components
```

Every screen redesign uses **only** what is in `lib/themes/ds/`. If you think
something is missing, compose it from DS primitives inside your screen file.
Do not add a new token or package.

---

## 0. Hard rules

1. **Do not touch behaviour.** Keep every controller call, `Obx`, `GetBuilder`,
   `GetX(init: ...)`, `StreamBuilder`/`FutureBuilder`, `setState`,
   `Provider.of<DarkThemeProvider>`, `Get.to/off/back`, route arguments, validators,
   `onTap` handlers, Firestore/API calls and `.tr` strings exactly as they are.
   You only change the widget tree around them. If a handler is inline, move it
   verbatim.
2. **No hard-coded colors.** Use `context.dsColors` (`c.surface`,
   `c.textPrimary`, `c.brand`...). Only exceptions: `Colors.white` on gradient
   or brand surfaces, and `Colors.transparent`. **The brand color is
   `AppColors.colorPrimary`** (default green `#00B761`, overwritten at startup
   from Firestore `settings/globalSettings.provider_app_color`); `c.brand`
   reads it at call time. `AppThemeData.primary300` is a fixed orange and
   `AppThemeData.secondary300` a fixed purple – they are *not* the brand, so do
   not use them for brand accents in redesigned UI.
3. **Light + dark.** Dark mode is driven by `DarkThemeProvider` (package
   `provider`, not GetX): `main.dart` rebuilds `GetMaterialApp.theme` with
   `DsTheme.build(isDark)` whenever it changes, so `context.dsColors` /
   `context.dsText` / `context.dsIsDark` always match. Existing screens do
   `final themeChange = Provider.of<DarkThemeProvider>(context);` – keep that
   line (it subscribes the widget to theme changes) but pick colors from `c`,
   not `themeChange.getTheme() ? a : b`. `DsColors.resolve(isDark)` exists for
   code without a context.
4. **Text styles from `context.dsText`** (or `DsTypography.*` with an explicit
   color). Weight only renders when `fontWeight` is set, and all DS styles set it.
   Do not use fixed heights on containers that hold text. Use `minHeight` and padding
   so layouts survive 1.3x–2x text scale.
5. **Responsive.** Constrain page content with `DsResponsive` or
   `DsSliverResponsive`. Use `context.dsLayout` for gutters, columns and
   `isWide` two-pane layouts. Never use `Responsive.width(100)` for new UI.
6. **Motion.** Lists and sections enter with `DsFadeSlideIn` (staggered by
   index). Tappable cards use `DsCard(onTap:)`, which already has press feedback.
   Page transitions are app-wide, so do not pass `transition:` to `Get.to`.
7. **Loading.** Every async load shows a skeleton (`DsSkeleton*`) through
   `DsAsync` or a ternary. Use `loader()` (lib/constant/constants.dart) /
   `DsBrandLoader` only when no layout is known yet (splash, payment).
   Blocking actions keep `ShowToastDialog.showLoader`, which is already styled.
8. **Accessibility.** Icon-only buttons must be `DsIconButton` and need a
   `semanticLabel` (use `.tr`). Touch targets are at least 48dp, and DS components
   guarantee this. Do not put text inside a fixed-size box.
9. **Stay distinct.** Pick one archetype from section 6 for each screen, and use
   the hero, tint and gradient variants on purpose. A screen should not look
   like its neighbour.

---

## 1. Tokens

| Token | Values |
|---|---|
| `DsSpace` | `xxs 2, xs 4, sm 8, md 12, lg 16, xl 20, xxl 24, xxxl 32, huge 40, giant 56`, `gutter 16` |
| `DsGap` | `DsGap(12)`, `DsGap.sm/md/lg/xl/xxl/xxxl` (works in Row and Column), `DsGap.sliver(24)` |
| `DsRadius` | `xs 6, sm 10, md 14, lg 18, xl 24, xxl 32, pill`; BorderRadius: `brXs…brXxl, brPill, sheetTop` |
| `DsShadows` | `xs/sm/md/lg(context)` soft layered shadows (dark aware), `glow(context, color:)` for brand heroes |
| `DsMotion` | durations `instant 90, fast 160, base 240, slow 380, slower 600, page 340`, `stagger 45ms`; curves `standard, emphasized, decelerate, accelerate, spring`; `DsMotion.of(context, d)` returns zero when the user turned on reduce motion |
| `DsGradients` | `brand(context)`, `deep(context)` (finance/premium), `subtle(context)`, `tone(context, DsTone.x)`, `imageScrim` |

### Colors: `final c = context.dsColors;`
| Role | Use |
|---|---|
| `background` | scaffold (`#F6F7F9` light / near-black dark) |
| `surface` | cards, bars, sheets |
| `surfaceAlt` | inputs, tracks, icon wells, subtle fills |
| `surfaceRaised` | dialogs, menus, sheets |
| `surfaceInverse` / `onSurfaceInverse` | tooltips, snackbars |
| `border`, `borderStrong`, `divider` | hairlines |
| `textPrimary`, `textSecondary`, `textMuted`, `textDisabled`, `iconDefault` | text hierarchy |
| `brand`, `brandStrong` (for brand-colored text or pressed states), `brandSoft`, `brandMuted`, `onBrand` | brand |
| `success/warning/danger/info` + `…Strong` (readable text) + `…Soft` (bg) | semantic |
| `scrim`, `shimmerBase`, `shimmerHighlight`, `focusRing` | misc |

`DsTone { neutral, brand, success, warning, danger, info }` → `c.tone(t)`
gives `main / strong / soft / onMain`.
`DsTone.fromStatus(order.status)` maps any status string in the app to a tone.
Booking statuses: `ORDER_STATUS_PLACED` → brand, `ORDER_STATUS_ACCEPTED` /
`ORDER_STATUS_COMPLETED` → success, `ORDER_STATUS_ASSIGNED` /
`ORDER_STATUS_ONGOING` → info, `ORDER_STATUS_REJECTED` /
`ORDER_STATUS_CANCELLED` → danger. Payout / document / subscription states
(`pending`, `approved`, `rejected`, `expired`, `active`...) map too.

`DsPalette` holds the raw ramps (brand getter, neutrals, semantic light/dark)
and `DsPalette.fontFamily`. Screens should not need it – use `c`.

### Typography: `final t = context.dsText;`
`displayLg 34`, `display 28`, `headline 22`, `title 18`, `titleSm 16`,
`bodyLg 16`, `body 14`, `bodyStrong 14/500`, `bodySecondary`, `bodySm 13`,
`label 14/600`, `labelSm 12/600`, `caption 12/500 muted`, `overline 11 caps`,
`metric 26/700 tabular`, `metricLg 36`, `link`.
Helpers: `t.title.withColor(c.brand)`, `.w500/.w600/.w700`, `.tabular`, `.strike`.

Font: the DS uses the single weight-mapped family **`Metropolis`** (400/500/600/
700/800 declared in pubspec.yaml) – just set `fontWeight`. Legacy families
(`AppColors.medium` = `Metropolis-Medium`, `AppThemeData.medium` =
`Urbanist-Medium`, ...) still work: each declares its real weight, and the
never-bundled `Urbanist-*` names now alias the Metropolis faces. Do not use
`"Poppinsm"` (not bundled). Prefer `context.dsText` in new code.

### Context helpers
`context.dsColors`, `context.dsText`, `context.dsLayout`, `context.dsIsDark`.

### Reactivity: `DsObserve`
`DsObserve(builder: (context) => ...)` rebuilds when any `.obs` read inside
`builder` changes, like `Obx`, but reading **no** observable is allowed (it
just never rebuilds) instead of throwing "improper use of GetX". Use it:
- for content built lazily (`DsAsync.builder` already wraps itself in one);
- around children whose `build` reads controller state that the enclosing
  `Obx` cannot see (builder callbacks, `itemBuilder`s, `LayoutBuilder`,
  `DsResponsiveBuilder`, sheets);
- where a former `Obx` may end up reading nothing after a refactor.
Never *remove* an existing `Obx`/`GetX`/`GetBuilder`; if you move reads into a
lazily built child, wrap that child in `DsObserve`.

---

## 2. Layout and responsive

```dart
final l = context.dsLayout;          // DsLayout
l.isPhone / l.isTablet / l.isDesktop / l.isWide / l.isLandscape
l.gutter  (16 / 24 / 32)   l.pagePadding
l.value(phone: 1, tablet: 2, desktop: 3)
l.columns(phone: 2)                  // 2 / 4 / 5
l.columnsFor(160)                    // columns that fit 160-px items
DsLayout.contentMax (760)  DsLayout.wideMax (1200)
```
- `DsResponsive(child:, maxWidth: DsLayout.contentMax, padded: false)` centers a box child and caps its width.
- `DsSliverResponsive(sliver:, maxWidth:, top:, bottom:)` centers and pads a sliver.
- `DsAdaptiveGrid(minItemWidth: 150, children: [...])` is a non-scrolling grid for KPI tiles and shortcuts. Rows get equal heights, so don't put a `LayoutBuilder` inside a tile.
- `GridView.builder(gridDelegate: DsLayout.gridDelegate(maxItemWidth: 220, mainAxisExtent: 240), ...)` is the scrolling adaptive grid.
- `DsResponsiveBuilder(builder: (context, l) => l.isWide ? Row(...) : Column(...))`.

On tablets and iPad, use two panes for list/detail and auth screens, and 3–4 column grids for dashboards.

---

## 3. Components

### Scaffold and navigation
```dart
DsScaffold(title: 'Orders'.tr, actions: [...], body: ..., bottomBar: DsStickyBar(child: ...))
DsScaffold.collapsing(title: 'Products'.tr, subtitle: '12 items', onRefresh: c.refresh, slivers: [...])
DsScaffold.hero(title: 'Wallet'.tr, hero: BalanceBlock(), heroOverlap: QuickActionsCard(), slivers: [...])
```
- `DsScaffold` caps the body at `maxContentWidth` (default `wideMax`). Pass `null` for edge-to-edge content such as maps. `appBar:` accepts any custom bar.
- `DsAppBar(title:, subtitle:, actions:, leading:, showBack:, onBack:, bottom:, transparent:, centerTitle:)`. The back button calls `maybePop`. **If the old screen had custom back logic, pass it as `onBack` unchanged.**
- `DsBackButton(onPressed:)`.
- `DsHeroHeader(title:, child:, overlap:, gradient:, includeTopSafeArea:)` is the gradient header on its own, for dashboard tabs that are not routes. Put it in a `SliverToBoxAdapter`.
- `DsStickyBar(child:)` is the bottom action area. It is safe-area aware and centered on tablets.
- Bottom navigation keeps Material `BottomNavigationBar`/`NavigationBar`, which the theme already styles.

### Surfaces
```dart
DsCard(child: ...)                               // elevated (default)
DsCard.outlined(onTap: () => ..., child: ...)    // tap = ripple + press scale
DsCard.tinted(tone: DsTone.warning, child: ...)
DsCard.gradient(child: ...)                      // content defaults to white
DsCard.glass(child: ...)                         // only on gradients / images
```
Parameters: `padding` (default 16), `margin`, `radius`, `color`, `borderColor` (selected state), `semanticLabel`.

- `DsIconWell(icon:, tone:, size: 44, circle:, onBrand:)` is a tinted icon container.
- `DsStatTile(label:, value: | countTo: + format:, icon:, tone:, variant: surface|tinted|onBrand, caption:, delta: '+12%', deltaPositive:, onTap:)`.
- `DsListTile(title:, subtitle:, leading: | leadingIcon: + leadingTone:, trailing:, showChevron:, onTap:, destructive:)`.
- `DsTileGroup(title: 'Account'.tr, children: [DsListTile(...), ...])` builds grouped settings rows.
- `DsSectionHeader(title:, subtitle:, icon:, actionLabel:, onAction:, trailing:)`.
- `DsDivider(label: 'OR'.tr)`, `DsDivider(vertical: true)`.
- `DsBadge(label:, tone:, style: soft|solid|outline, icon:, small:)`.
- `DsStatusChip(label: status.tr, status: rawStatus)` infers the tone. `pulse: true` animates the dot for live states.
- `DsAvatar(imageUrl:, name:, size:, ring:, statusTone:, heroTag:, onTap:)` falls back to initials.
- `DsImage(url: | asset:, width:, height:, radius:, fit:, heroTag:)` shows a shimmer placeholder and an error icon on failure. Use the same `heroTag` on the list and detail screens to animate the image between them.

### Buttons
```dart
DsButton.primary(label: 'Save'.tr, icon: Icons.check_rounded, expand: true, loading: c.isLoading.value, onPressed: c.save)
DsButton.secondary(label: 'Cancel'.tr, onPressed: () => Get.back())
DsButton.tonal(label: 'Add variant'.tr, icon: Icons.add, size: DsButtonSize.sm, onPressed: ...)
DsButton.ghost(label: 'See all'.tr, trailingIcon: Icons.chevron_right, onPressed: ...)
DsButton.danger(label: 'Delete'.tr, onPressed: ...)      DsButton.dangerTonal(label: 'Reject'.tr, onPressed: ...)
DsIconButton(icon: Icons.tune_rounded, semanticLabel: 'Filters'.tr, variant: DsIconButtonVariant.tonal, badgeCount: 2, onPressed: ...)
```
Sizes are `sm 40`, `md 48` (default) and `lg 56`, and every size gets a 48dp hit target. `onPressed: null` disables the button, and `loading` keeps its width.
Icon button variants are `plain`, `tonal`, `brand`, `outlined` and `filled`.

### Forms
```dart
DsFormSection(title: 'Service details'.tr, icon: Icons.handyman_outlined, children: [
  DsTextField(label: 'Service name'.tr, hint: '...'.tr, controller: c.nameController, requiredMark: true, validator: ...),
  DsTextField(label: 'Password'.tr, controller: c.passwordController, obscurable: true),
  DsDropdown<String>(label: 'Category'.tr, value: c.catId.value, items: [...], onChanged: (v) => c.catId.value = v),
])
TextFormField(decoration: DsInputDecoration.of(context, hint: 'Name'.tr, prefixIcon: Icons.person_outline))
DsFieldLabel('Opening hours'.tr, required: true)
DsSearchBar(hint: 'Search'.tr, controller: c.searchController, onChanged: c.onSearch, trailing: DsIconButton(...))
DsSegmentedTabs(segments: [DsSegment('New'.tr, count: 3), DsSegment('Done'.tr)], index: c.tab.value, onChanged: (i) => c.tab.value = i)
DsSegmentedTabs(scrollable: true, ...)            // chip row for many filters
DsTabBar(controller: tabController, tabs: [...])  // when the screen already uses a TabController
```
`DsTextField` passes every `TextFormField` parameter through unchanged: controller, initialValue, validator, formatters, keyboardType, onChanged, onTap, readOnly, enabled, maxLines and maxLength. For pickers (date, time, image, map), use `DsTextField(readOnly: true, onTap: existingHandler, suffix: Icon(...))`.

### Feedback and overlays
```dart
DsEmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet'.tr, message: '...'.tr, actionLabel: 'Refresh'.tr, onAction: c.getOrders, compact: false)
DsErrorState(message: '...'.tr, onRetry: c.load)
DsInlineAlert(tone: DsTone.warning, title: '...'.tr, message: '...'.tr, actionLabel: 'Upload'.tr, onAction: ...)
DsBottomSheet.show(title: 'Filter'.tr, child: ..., actions: DsButton.primary(...))   // Get.bottomSheet under the hood
Get.bottomSheet(DsSheet(title: ..., child: ...), isScrollControlled: true, backgroundColor: Colors.transparent) // to keep an existing call
DsDialog.show(DsDialog(title:, message:, icon:, tone:, content:, primaryLabel:, onPrimary:, secondaryLabel:, onSecondary:, destructive:))
final ok = await DsDialog.confirm(title: 'Delete?'.tr, message: '...'.tr, confirmLabel: 'Delete'.tr, destructive: true);
```
If an existing `showDialog` or `Get.dialog` call site must stay unchanged, only replace the dialog widget passed to it with `DsDialog(...)`.
Toasts and the blocking loader (`ShowToastDialog`) already use DS styling. Keep calling them.

### Progress and steps
```dart
DsProgressBar(value: 0.6, label: 'Profile completion'.tr, showPercent: true)   // value: null → indeterminate
DsProgressRing(value: 0.72, size: 96, center: Text('72%', style: t.titleSm), onBrand: false)
DsTimeline(steps: [DsTimelineStep(title:, subtitle:, meta:, state: DsStepState.done|current|upcoming|error, icon:, content:)])
DsStepper(steps: ['Details'.tr, 'Pricing'.tr, 'Media'.tr], current: c.step.value)
```

### Loading
```dart
Obx(() => DsAsync(
  isLoading: c.isLoading.value,
  skeleton: const DsSkeletonList(),
  isEmpty: c.list.isEmpty,
  empty: DsEmptyState(...),
  builder: (_) => ListView(...),        // built only when not loading
))
```
Ready-made skeletons: `DsSkeletonList(itemCount:, leading:, trailing:, carded:)`,
`DsSkeletonGrid(minItemWidth:)`, `DsSkeletonCard(height:)`,
`DsSkeletonDashboard()`, `DsSkeletonDetail()`, `DsSkeletonForm(fields:)`.
To build your own, use `DsShimmer(child: Column(children: [DsSkeleton.box(height: 120), DsSkeleton.line(width: 140), DsSkeleton.circle(size: 40)]))`.
Loaders: `DsBrandLoader(size:, label:, logo:)` for full-screen waits, and `DsSpinner(size:)` inline, for example as a "loading more" footer.
`loader()` now returns a centered `DsBrandLoader`, and `showEmptyView(message:)` returns a compact `DsEmptyState` (both in lib/constant/constants.dart).
`DsShimmer` is implemented in-house (no `shimmer` package – do not add it): a
sliding gradient composited over the child with `ShaderMask(srcATop)`. It
pauses for reduce-motion and sweeps from the leading edge in RTL.

`StreamBuilder` / `FutureBuilder` screens (bookings, chat, wallet, workers):
```dart
StreamBuilder<List<OnProviderOrderModel>>(stream: ..., builder: (context, snap) => DsAsync(
  isLoading: snap.connectionState == ConnectionState.waiting,
  skeleton: const DsSkeletonList(carded: true),
  hasError: snap.hasError, error: DsErrorState(message: 'Something went wrong'.tr),
  isEmpty: (snap.data ?? []).isEmpty, empty: DsEmptyState(icon: Icons.event_busy_outlined, title: 'No bookings found'.tr),
  builder: (_) => ListView(...),
))
```

### Motion
```dart
itemBuilder: (_, i) => DsFadeSlideIn(index: i, child: OrderCard(...))
Column(children: DsFadeSlideIn.stagger([hero, kpis, recent]))
DsAnimatedCounter(value: walletAmount, style: t.metric, format: (v) => amountShow(amount: v.toString()))
DsPressable(onTap: ..., child: ...)   // or without onTap around an existing InkWell for press feedback only
```
`DsFadeSlideIn` animates only on first appearance. Items that are recycled while the user scrolls simply appear. It also respects reduce motion.
For richer states, use `AnimatedSwitcher`, `AnimatedContainer` and `AnimatedSize` with `DsMotion` durations and curves.

---

## 4. Theme-level upgrades (already live on every screen)
`main.dart` uses `theme: DsTheme.build(isDark)` (isDark from
`DarkThemeProvider`; `Styles.themeData()` now returns the same theme).
Material widgets are themed: app bar, **drawer** (the dashboard shell),
cards, chips, buttons, FAB, tabs, switches, checkboxes, radios, sliders, date
and time pickers, dialogs, bottom sheets, snackbars, tooltips, menus and
progress indicators. The global input theme only sets hint, label and error
styles. Borders and fills come from `DsInputDecoration` or `DsTextField`,
because legacy fields use `InputBorder.none` inside custom boxes.
`DsBrandTheme` re-themes when the Firestore brand color loads (`main.dart`
calls `DsBrandTheme.refresh()` right after setting `AppColors.colorPrimary`,
and `DsBrandTheme.observer` re-checks on every navigation).
Page transitions: `GetMaterialApp(customTransition: DsPageTransition(), transitionDuration: DsMotion.page)`.
Android gets a shared-axis slide and fade. iOS keeps the native slide with swipe-back.
EasyLoading (`ShowToastDialog` loader/toasts) is styled by
`lib/themes/easy_loading_config.dart` (raised panel + `DsBrandLoader`); mask
and tap behaviour are unchanged.

Legacy shared widgets have the DS look with **unchanged APIs and behaviour**:
`RoundedButtonFill` (lib/themes), `CustomDialogBox` (positive action styled
destructive – it is the log-out confirm), `TextFieldWidget`,
`CommonUI.customAppBar` (still returns an `AppBar`; back = `onBackTap ??
Get.back()`), `CommonUI.showAddExtraChargesDialog`, `PermissionDialog`,
`NetworkImageWidget` (shimmer placeholder). You may keep them, but prefer DS
components in redesigned screens.

## 5. Screen recipe
1. Keep the outer `Obx` / `GetX(init:)` / `GetBuilder` / `StreamBuilder` and the `Provider.of<DarkThemeProvider>(context)` line exactly as they are. Inside: `final c = context.dsColors; final t = context.dsText; final l = context.dsLayout;`.
2. Replace `Scaffold` + `AppBar` with a `DsScaffold` variant that fits the archetype. **Exception – drawer tabs:** screens returned by `DashboardController.getDrawerItemWidget` (booking list, all services, workers, documents, coupons, wallet, subscription with `isDrawer: true`, withdraw method, profile, inbox, help, terms, privacy) are the *body* of `DashboardScreen`, which owns the app bar and drawer. If such a screen has no `Scaffold`/`AppBar` of its own today, do not add one – use `DsHeroHeader`/slivers inside the body. If it has one, keep it (same count of Scaffolds).
3. Wrap the loading branch with a skeleton (`DsAsync` or `isLoading ? DsSkeletonX() : ...`).
4. Build content from DS components and wrap list items in `DsFadeSlideIn(index: i)`.
5. Put primary actions in a `DsStickyBar` (forms, detail) or a FAB (lists).
6. Check light and dark, a phone and an iPad (768+), and text scale 1.3.
7. Run `flutter analyze --no-pub` and fix any errors or warnings.

---

## 6. Screen archetypes for the provider app (pick one per screen and vary them)

**A. Dashboard shell** (`dashboard/dashboard_screen.dart`): keep the Scaffold + drawer + `Obx` on `selectedDrawerIndex`. Drawer = profile header (`DsAvatar(ring)`, name, email, `DsStatusChip` for online/verified/subscription), then drawer items as `DsListTile(leading: SvgPicture tinted c.iconDefault / c.brand when selected, selected row = `c.brandSoft` pill with `DsRadius.brMd`)`, log-out last with `destructive: true`. On tablets (`l.isWide`) the drawer content can be shown as a permanent side rail; keep the same item list and `onTap`s.

**B. Dashboard with KPIs** (top of the bookings tab / home): `DsHeroHeader` (brand gradient) with greeting + availability, 2–4 `DsStatTile(variant: onBrand)` (today's bookings, ongoing, completed, earnings via `DsAnimatedCounter` + `amountShow`), then `DsSectionHeader('Recent bookings')` and rows. `DsAdaptiveGrid(minItemWidth: 150)` → 2 columns phone, 4 tablet. Load with `DsSkeletonDashboard`. Only show numbers the controller/stream already provides – do not add queries.

**C. Bookings list** (`booking_list_screen.dart`, `assign_worker_list.dart`): `DsSegmentedTabs(scrollable: true)` status filter (keep the existing TabController → `DsTabBar` if one exists), rows as `DsCard.outlined` with service image (`DsImage`, `heroTag: 'booking-${id}'`), customer name, date/time slot (`t.caption` with `Icons.schedule`), address line, price `t.titleSm.tabular`, and `DsStatusChip(label: status.tr, status: status, pulse: status == ORDER_STATUS_ONGOING)`. New/placed bookings get inline `DsButton.dangerTonal('Reject')` + `DsButton.primary('Accept')` (same handlers). Tablet: `DsLayout.gridDelegate(maxItemWidth: 420)`. Empty: `DsEmptyState(icon: Icons.event_available_outlined)`; loading: `DsSkeletonList(carded: true)`.

**D. Booking detail** (`booking_details_screen.dart`, `verify_otp_screen.dart`): hero `DsImage` (same `heroTag`) under a transparent `DsAppBar`, title block (service name, `DsStatusChip`, booking id `t.caption` + copy), `DsTimeline` of the status history (placed → accepted → assigned → ongoing → completed; `DsStepState.error` for rejected/cancelled) built only from existing fields, customer card (`DsAvatar` + call/chat `DsIconButton`s with semantic labels), schedule & address card (`DsListTile`s), price breakdown card (`t.body` rows, total `t.title.tabular`, extra charges row + "Add charges" `DsButton.tonal` calling the existing `CommonUI.showAddExtraChargesDialog`), assigned-worker card. Actions in a `DsStickyBar` (Accept/Reject, Assign worker, Start with OTP, Complete – exactly the existing conditions and handlers). OTP entry: large centered pin boxes (`DsTypography.metric`), `DsButton.primary(expand, loading)`. Tablet: media + timeline left, details right. Loading: `DsSkeletonDetail`.

**E. Service catalogue** (`all_services_screen.dart`): image-led grid cards (`DsLayout.gridDelegate(maxItemWidth: 260, mainAxisExtent: ...)`): `DsImage` 16:10, name `t.titleSm`, category `t.caption`, price (+ strike-through discount via `.strike`), price-unit `DsBadge` (hourly/fixed), publish switch as trailing if present, edit/delete `DsIconButton`s. FAB "Add service" (`FloatingActionButton.extended` is themed). `DsSearchBar` if the screen already filters. Skeleton: `DsSkeletonGrid`.

**F. Add / edit service, worker, coupon** (`add_or_update_service.dart`, `add_or_update_worker.dart`, `add_or_update_coupon.dart`, `edit_profile_screen.dart`, `enter_bank_details_screen.dart`): `DsScaffold` + `DsFormSection` cards (Basic info / Pricing / Availability & slots / Media / Location), `DsTextField` (keep controllers, validators, formatters), `DsDropdown` for category/sub-category/price unit, day chips as `FilterChip`s (themed), time/date pickers as `DsTextField(readOnly: true, onTap: existing)`, image picker grid as dashed `DsCard.outlined` tiles with `DsImage` thumbnails and remove `DsIconButton`. `DsProgressBar` or `DsStepper` at the top if the form is long. Submit in `DsStickyBar` (`DsButton.primary(expand: true)`). Cap at `DsLayout.contentMax`; on tablets use `DsAdaptiveGrid(minItemWidth: 260)` for short fields. Loading: `DsSkeletonForm`.

**G. Workers directory** (`worker/worker_list.dart`): avatar rows – `DsAvatar(imageUrl, name, statusTone: online ? success : neutral)`, name + phone/email `t.caption`, `DsStatusChip` (active/inactive, online), trailing edit/delete `DsIconButton`s or a `PopupMenuButton` (themed). FAB "Add worker". Tablet: 2–3 column grid of `DsCard.outlined` contact cards. Empty: `DsEmptyState(icon: Icons.groups_outlined)`.

**H. Wallet / earnings** (`wallet/wallet_screen.dart`, `withdraw_history.dart`, `bank_details_Screen.dart`): hero `DsCard.gradient(gradient: DsGradients.deep(context))` balance card with `DsAnimatedCounter` (`metricLg`, `amountShow`) and Withdraw / Top-up actions; a row of `DsStatTile`s (earnings / withdrawn / pending) when the data exists; transaction rows as `DsListTile` with tone icon wells (success = credit, danger = debit), amounts `t.titleSm.tabular` colored by tone, date `t.caption`, grouped by day with `DsSectionHeader`. Payout history uses `DsStatusChip(status:)`. Payment-method pickers inside sheets: `DsSheet` with selectable `DsCard.outlined(borderColor: selected ? c.brand : null)` rows (keep the Radio/onChanged logic). Bank details: masked account card (`DsCard.tinted`) + edit action.

**I. Documents / verification** (`documents/provider_documents_screen.dart`): top `DsInlineAlert` summarising verification (warning = pending, success = approved, danger = rejected) + `DsProgressBar(value: uploaded / required, showPercent: true)`; one `DsCard` per document with `DsIconWell(Icons.badge_outlined)`, name, `DsStatusChip(status:)`, front/back thumbnails (`DsImage` or dashed upload tile), and `DsButton.tonal('Upload'/'Re-upload')` with the existing handler. Rejected docs show the reason in a `DsCard.tinted(tone: danger)`.

**J. Subscription plans** (`subscription_plan_screen.dart`, `select_payment_screen.dart`, `subscription_history_screen.dart`, `app_not_access_screen.dart`): horizontally paged / grid plan cards – the selected/current plan is `DsCard.gradient` (white text) with a `DsBadge('Current plan')`, others `DsCard.outlined(borderColor: selected ? c.brand : null)`; price `t.metric`, duration `t.caption`, feature checklist rows with `Icons.check_circle_rounded` in `c.success`, limits as `DsBadge`s. CTA in `DsStickyBar`. Payment method list as selectable cards with gateway logos. History = timeline-like `DsCard` rows with `DsStatusChip` (active/expired). App-not-access = archetype O.

**K. Coupons** (`coupon/coupon_list.dart`): ticket-style cards – left `DsCard.tinted(tone: brand)` stub with the discount (`t.headline`, "%/flat"), dashed divider, right side code in a monospace-ish `t.label` pill with copy `DsIconButton`, validity `t.caption`, `DsStatusChip` (active / expired via `fromStatus`), enable switch if present. FAB "Add coupon".

**L. Auth** (`auth/auth_screen.dart`, `login/login_screen.dart`, `signUp/signup_screen.dart`, `auth/phone_number_screen.dart`, `auth/otp_screen.dart`, `on_boarding_screen.dart`): phone – logo (`assets/images/app_logo.png`) in a soft brand blob, `t.display` title, `t.bodySecondary` subtitle, focused `DsTextField`s (country-code picker kept as `prefix`), `DsButton.primary(expand, loading)`, `DsDivider(label: 'OR'.tr)`, social/phone buttons as `DsButton.secondary(leading: SvgPicture/Image)`. OTP = 6 pin boxes + resend `DsButton.ghost` with countdown. Tablet (`l.isWide`): split – left `DsGradients.brand` panel with logo/tagline/illustration, right the form card (max 440). Onboarding: full-bleed image, `DsFadeSlideIn` text, dot indicator in `c.brand`, `DsStickyBar` Next/Skip.

**M. Chat** (`chat_screen/inbox_screen.dart`, `chat_screen.dart`): inbox = `DsListTile` rows with `DsAvatar`, last message `t.bodySm` (1 line), time `t.caption`, unread `DsBadge(solid)`. Conversation = `DsAppBar` with `DsAvatar` + name/status in the title; bubbles: mine `c.brand` / `c.onBrand`, theirs `c.surface` + `c.border`, `DsRadius.lg` with one sharp corner, `t.caption` time; images/videos as rounded `DsImage` thumbnails (open the existing full-screen viewers); composer in a `DsStickyBar` with a pill `TextField(decoration: DsInputDecoration.of(...))`, attach `DsIconButton` and a filled send `DsIconButton(variant: filled)`.

**N. Settings / profile / language / theme / help / legal** (`profile_screen.dart`, `language_screen.dart`, `theme_change_screen.dart`, `help_support_screen.dart`, `privacy_policy.dart`, `terms_and_codition.dart`): profile header card (`DsAvatar(ring)`, name, email/phone, `DsBadge` verified / plan) followed by `DsTileGroup`s of `DsListTile(leadingIcon, showChevron)`; destructive rows (delete account, log out) last with `destructive: true`. Language/theme = selectable `DsCard.outlined` rows with a check `DsIconWell` for the selected one (keep `DarkThemeProvider.darkTheme = n` exactly). Legal pages: `DsResponsive(maxWidth: contentMax)` around the HTML/text with `t.bodyLg` line height.

**O. Status / maintenance / splash / blocked** (`maintenance_mode_screen.dart`, `splash_screen.dart`, `app_not_access_screen.dart`): centered `DsEmptyState` or illustration with `DsFadeSlideIn`, one clear action; tone by meaning (warning = maintenance / pending, danger = access blocked). Splash: logo + `DsBrandLoader` only, no layout shift.

Mix the details within an archetype too: tinted status cards for bookings, image-led cards for services, avatar rows for workers, ticket cards for coupons. Screens that share an archetype should still differ in their hero content and their main visual.
