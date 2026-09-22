# spideli Worker – Design System (DS)

```dart
import 'package:spideliworker/themes/ds/ds.dart';   // everything: tokens, layout, motion, components
```

Every screen redesign uses **only** what is in `lib/themes/ds/`. If you think
something is missing, compose it from DS primitives inside your screen file.
Do not add a new token or package.

---

## 0. Hard rules

1. **Do not touch behaviour.** Keep every controller call, `Obx`, `GetBuilder`,
   `GetX(init: ...)`, `Get.to/off/back`, route arguments, validators,
   `onTap` handlers, Firestore/API calls and `.tr` strings exactly as they are.
   You only change the widget tree around them. If a handler is inline, move it
   verbatim.
2. **No hard-coded colors.** Use `context.dsColors` (`c.surface`,
   `c.textPrimary`, `c.brand`...). Only exceptions: `Colors.white` on gradient
   or brand surfaces, and `Colors.transparent`. The worker brand color is
   `AppColors.colorPrimary` (default green `#00B761`, replaced at runtime by
   Firestore `settings/globalSettings.worker_app_color`); always read it as
   `c.brand`. **Never use `AppThemeData.primary*`** – that is an unrelated
   orange palette (`primary300 = #FF6839`) that a few legacy screens (chat)
   use by mistake. Replace legacy `AppColors.colorDark/colorWhite/
   assetColor*/DARK_BG_COLOR` with DS roles.
3. **Light + dark.** Everything from `context.dsColors` / `context.dsText`
   follows the theme. Dark mode lives in the Provider-based
   `DarkThemeProvider` (`lib/utils/dark_theme_provider.dart`; 0 = dark,
   1 = light, 2 = system). Existing screens do
   `final themeChange = Provider.of<DarkThemeProvider>(context);` and branch on
   `themeChange.getTheme()`. Keep the `Provider.of` call (it subscribes the
   screen to theme changes) but pick colors from `c`, not
   `themeChange.getTheme() ? a : b`. `context.dsColors` resolves from the app
   `Theme` brightness, which `main.dart` builds from the same provider value.
   Where you have no `BuildContext` below the app theme, use
   `DsColors.resolve(themeChange.getTheme())`.
4. **Text styles from `context.dsText`** (or `DsTypography.*` with an explicit
   color). The DS font is the single `Metropolis` family (400/500/600/700/800,
   declared in pubspec.yaml) selected by `fontWeight`; all DS styles set it.
   Do not use the legacy per-weight families (`AppColors.medium`,
   `AppColors.semiBold`, `AppThemeData.*TextStyle`) in redesigned code.
   Do not use fixed heights on containers that hold text. Use `minHeight` and padding
   so layouts survive 1.3x–2x text scale.
5. **Responsive.** Constrain page content with `DsResponsive` or
   `DsSliverResponsive`. Use `context.dsLayout` for gutters, columns and
   `isWide` two-pane layouts. Never use `Responsive.width(...)` /
   `Responsive.height(...)` (lib/themes/responsive.dart, percentage of the
   screen) for new UI – it produces huge buttons and images on iPad.
6. **Motion.** Lists and sections enter with `DsFadeSlideIn` (staggered by
   index). Tappable cards use `DsCard(onTap:)`, which already has press feedback.
   Page transitions are app-wide, so do not pass `transition:` to `Get.to`.
7. **Loading.** Every async load shows a skeleton (`DsSkeleton*`) through
   `DsAsync` or a ternary. Use the global `loader()` (lib/constant/constants.dart)
   / `DsBrandLoader` only when no layout is known yet (splash, uploads).
   Blocking actions keep `ShowToastDialog.showLoader`, which is already styled.
8. **Accessibility.** Icon-only buttons must be `DsIconButton` and need a
   `semanticLabel` (use `.tr`). Touch targets are at least 48dp, and DS components
   guarantee this. Do not put text inside a fixed-size box. Workers use the app
   on the move, often one-handed and outdoors: keep the job's main action in a
   `DsStickyBar` at thumb reach, use `DsButtonSize.lg` for Start / Stop /
   Complete, and never rely on color alone for status (always a label).
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
Worker job statuses (`ORDER_STATUS_*` in lib/constant/constants.dart):
`Order Placed` → brand, `Order Assigned` / `Order Ongoing` → info,
`Order Accepted` / `Order Completed` → success, `Order Rejected` /
`Order Cancelled` → danger. Document statuses: `approved/verified` → success,
`pending/review` → warning, `rejected` → danger.

### Typography: `final t = context.dsText;`
`displayLg 34`, `display 28`, `headline 22`, `title 18`, `titleSm 16`,
`bodyLg 16`, `body 14`, `bodyStrong 14/500`, `bodySecondary`, `bodySm 13`,
`label 14/600`, `labelSm 12/600`, `caption 12/500 muted`, `overline 11 caps`,
`metric 26/700 tabular`, `metricLg 36`, `link`. Use `metric`/`.tabular` for
job timers, OTP digits, prices and extra charges.
Helpers: `t.title.withColor(c.brand)`, `.w500/.w600/.w700`, `.tabular`, `.strike`.

### Context helpers
`context.dsColors`, `context.dsText`, `context.dsLayout`, `context.dsIsDark`.

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
- `DsImage(url: | asset:, width:, height:, radius:, fit:, heroTag:)` shows a shimmer placeholder and an error icon on failure. Use the same `heroTag` on the list and detail screens to animate the image between them. (Legacy `NetworkImageWidget` keeps its API and now shows a shimmer placeholder too.)

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
DsFormSection(title: 'Personal details'.tr, icon: Icons.person_outline, children: [
  DsTextField(label: 'Full name'.tr, hint: '...'.tr, controller: c.nameController, requiredMark: true, validator: ...),
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
Toasts and the blocking loader (`ShowToastDialog`) already use DS styling
(`applyEasyLoadingStyle` in lib/themes/easy_loading_config.dart, re-applied on
theme change). Keep calling them. `showAlertDialog(...)`
(lib/services/helper.dart) now renders a `DsDialog`; keep calling it.

### Progress and steps
```dart
DsProgressBar(value: 0.6, label: 'Profile completion'.tr, showPercent: true)   // value: null → indeterminate
DsProgressRing(value: 0.72, size: 96, center: Text('72%', style: t.titleSm), onBrand: false)
DsTimeline(steps: [DsTimelineStep(title:, subtitle:, meta:, state: DsStepState.done|current|upcoming|error, icon:, content:)])
// Job lifecycle: Assigned → Started (startTime) → Stopped (endTime, hourly) → Completed

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
`DsShimmer` is implemented in-house (a `ShaderMask` sweeping a
base→highlight gradient over its child; no `shimmer` package – do not add
one). It is static when reduce-motion is on.
Loaders: `DsBrandLoader(size:, label:, logo:)` for full-screen waits, and `DsSpinner(size:)` inline, for example as a "loading more" footer.
The global `loader()` now returns a centered `DsBrandLoader`, and
`showEmptyView(message:, themeChange:)` returns a compact `DsEmptyState`
(both in lib/constant/constants.dart, unchanged signatures).

### Motion
```dart
itemBuilder: (_, i) => DsFadeSlideIn(index: i, child: OrderCard(...))
Column(children: DsFadeSlideIn.stagger([hero, kpis, recent]))
DsAnimatedCounter(value: todayJobs.length, style: t.metric)
DsAnimatedCounter(value: total, style: t.metric, format: (v) => amountShow(amount: v.toString(), currency: RegionService.currencyForRegion(order.regionId)))
DsPressable(onTap: ..., child: ...)   // or without onTap around an existing InkWell for press feedback only
```
`DsFadeSlideIn` animates only on first appearance. Items that are recycled while the user scrolls simply appear. It also respects reduce motion.
For richer states, use `AnimatedSwitcher`, `AnimatedContainer` and `AnimatedSize` with `DsMotion` durations and curves.

---

## 4. Theme-level upgrades (already live on every screen)
`main.dart` uses `theme: DsTheme.build(isDarkTheme)` (computed from
`DarkThemeProvider` as before; the app only sets `theme:`, never
`darkTheme:`/`themeMode:`). `Styles.themeData()` also returns the DS theme.
Material widgets are themed:
app bar, cards, chips, buttons, FAB, tabs, switches, checkboxes, radios,
sliders, date and time pickers, dialogs, bottom sheets, snackbars, tooltips,
menus and progress indicators. The global input theme only sets hint, label and
error styles. Borders and fills come from `DsInputDecoration` or `DsTextField`,
because legacy fields use `InputBorder.none` inside custom boxes.
`DsBrandTheme` re-themes when the Firestore brand color loads
(`main.dart` calls `DsBrandTheme.refresh()` right after setting
`AppColors.colorPrimary`; every navigation re-checks too).
Page transitions: `GetMaterialApp(customTransition: DsPageTransition(), transitionDuration: DsMotion.page)`.
Android gets a shared-axis slide and fade. iOS keeps the native slide with swipe-back.
Legacy widgets (`CommonUI.customAppBar`, `CommonUI.showAddExtraChargesDialog`,
`TextFieldWidget`, `NetworkImageWidget`, `showAlertDialog`, EasyLoading) have
the DS look with unchanged APIs. You may keep them, but prefer DS components
in redesigned screens (`DsAppBar`/`DsScaffold`, `DsTextField`, `DsImage`,
`DsDialog`).
Fonts: pubspec.yaml now declares a `Metropolis` family by weight, and the
legacy `AppThemeData` font names (which pointed at unbundled `Urbanist-*`
fonts and silently fell back to the system font) now map to Metropolis.

---

## 5. Screen recipe
1. Keep the outer `Obx` / `GetX(init:)` / `GetBuilder` and the
   `Provider.of<DarkThemeProvider>(context)` line exactly as they are. Inside:
   `final c = context.dsColors; final t = context.dsText; final l = context.dsLayout;`.
   If content is built lazily (a builder, a child widget's own `build`) and
   reads `.obs` values, wrap it in `DsObserve(builder: ...)` – `DsAsync`
   already does this for its `builder`. Never leave an `Obx` that reads no
   observable (it throws "improper use of GetX").
2. Replace `Scaffold` + `AppBar` with a `DsScaffold` variant that fits the archetype.
3. Wrap the loading branch with a skeleton (`DsAsync` or `isLoading ? DsSkeletonX() : ...`).
4. Build content from DS components and wrap list items in `DsFadeSlideIn(index: i)`.
5. Put primary actions in a `DsStickyBar` (forms, detail) or a FAB (lists).
6. Check light and dark, a phone and an iPad (768+), and text scale 1.3.
7. Run `flutter analyze --no-pub` and fix any errors or warnings.

---

## 6. Screen archetypes (pick one per screen and vary them)

### Worker screen map

| Screen (lib/ui/...) | Archetype | Notes |
|---|---|---|
| `dashboard/dashboard_screen.dart` | shell | Keep `PageView` + `BottomNavigationBar` (themed). Remove the hard-coded colors; the theme already uses `c.surface` / `c.brand`. On tablets you may swap to `NavigationRail` inside a `Row` keyed on `l.isWide`, with the same `controller.onItemTapped`. |
| `booking_list/booking_list.dart` (Jobs: Assigned / In progress / Completed) | **J. Today's jobs** | |
| `booking_list/booking_details_screen.dart` | **K. Job detail** | |
| `booking_list/job_actions.dart` (`CompleteJobScreen`: photos + signature) | **L. Proof of completion** | |
| `booking_list/verify_otp_screen.dart` | **M. OTP handover** | |
| `documents/documents_screen.dart`, `documents/document_upload_screen.dart` | **N. Documents / verification** | |
| `profile/profile_screen.dart`, `theme_change_screen/…`, `language_screen.dart` | **E. Settings / profile** | theme & language pickers are `DsTileGroup`s of radio `DsListTile`s |
| `login/login_screen.dart`, `on_boarding_screen.dart` | **F. Auth** / onboarding | |
| `chat_screen/inbox_screen.dart`, `chat_screen/chat_screen.dart` | **B. List** / **H. Chat** | |
| `help_support_screen/help_support_screen.dart` | **O. Help** | |
| `maintenance_mode_screen/…`, `splash_screen/…`, `privacyPolicy/…`, `termsAndCondition/…` | **I. Status** / reading | policy pages: `DsScaffold` + `DsResponsive(maxWidth: DsLayout.contentMax)` around the HTML |

### Worker archetypes

**J. Today's jobs dashboard** (booking_list): make it the worker's home.
Use a `DsHeroHeader` (it is a tab, not a route – `includeTopSafeArea: true`,
`showBack: false`) with a greeting, today's date and 2–3
`DsStatTile(variant: onBrand)` counts (assigned / in progress / completed –
computed from the lists the controller already has; do not add queries).
Replace the Material `TabBar` with `DsSegmentedTabs` (with counts) or keep the
existing `TabController` and use `DsTabBar`. Each job is a `DsCard.outlined`:
service image (`DsImage`), service name, customer, date/time and address rows
with `DsIconWell`s, a `DsStatusChip(status: order.status, pulse: ongoing)`, and
the existing Start / Stop Time / Complete handler as a full-width
`DsButton.primary` (Start), `DsButton.tonal` (Stop Time) or
`DsButton.primary(color: c.success)` (Complete) – call `JobActions.*`
exactly as today. Stagger with `DsFadeSlideIn(index:)`, load with
`DsSkeletonList`, empty with `DsEmptyState(icon: Icons.event_available_outlined)`.
Tablets: `DsLayout.gridDelegate(maxItemWidth: 420)` two-column cards.

**K. Job detail** (booking_details_screen): `DsScaffold` (or `.hero` with the
service image / brand gradient) → summary card (service, `DsStatusChip`,
booking id `orderId(...)`, price with `t.metric.tabular`) → customer card
(`DsAvatar`, name, call / chat `DsIconButton`s wired to the existing
handlers) → address card with the existing map-launch action → a
`DsTimeline` of the job lifecycle built from fields the model already has
(created → assigned/accepted → `startTime` → `endTime` → completed, each step
`done/current/upcoming` from `status` and null checks) → price breakdown
(`DsListTile` rows, extra charges via the existing
`CommonUI.showAddExtraChargesDialog`) → completion proof (photos grid +
signature with `DsImage`). Put the current state's action (Start / Stop Time
/ Complete / Add extra charges) in a `DsStickyBar` with `DsButtonSize.lg`.
Tablets: two panes (summary + timeline left, customer / price / proof right).
Load with `DsSkeletonDetail`.

**L. Proof of completion** (CompleteJobScreen): `DsScaffold` with a
`DsStepper(steps: ['Photos'.tr, 'Signature'.tr], current: …)` or two
`DsFormSection`s. Photos: an adaptive grid of `DsImage`-style thumbnails with
a remove `DsIconButton` (semanticLabel) and an "Add photo" dashed tile.
Signature: keep the `Signature` widget and its `SignatureController` as they
are (white pad is intentional – exported PNG has a white background), framed
by a `DsCard.outlined` with a "Clear" `DsButton.ghost`. Submit is
`DsButton.primary(expand, size: lg)` in a `DsStickyBar`; the existing
`Navigator.pop(context, CompleteJobResult(...))` stays.

**M. OTP handover** (verify_otp_screen): centered, width-capped (≤ 440)
column: `DsIconWell(icon: Icons.lock_outline, size: 64)`, `t.headline`
"Collect OTP from customer", `t.bodySecondary` helper, the existing
`OtpTextField` restyled via its own params (`borderColor: c.brand`,
`focusedBorderColor: c.brand`, `textStyle: t.metric.tabular`,
`fieldWidth` ≥ 44, `showFieldAsBox: true`), then `DsButton.primary(expand,
size: lg)` "Verify OTP" in a `DsStickyBar`. Keep the comparison / toast /
`Navigator.pop(context, true)` logic byte-for-byte.

**N. Documents / verification** (documents_screen, document_upload_screen):
top `DsInlineAlert` summarising verification (warning while any document is
pending / missing, success when all approved, danger if any rejected) and a
`DsProgressBar(label: 'Verification'.tr, showPercent: true)` from counts the
screen already computes. Each document is a `DsCard.outlined` row: `DsIconWell`
(tone from status), title, `DsStatusChip`, chevron → upload screen. Upload
screen: front/back image slots as large dashed `DsCard.outlined` drop zones
showing `DsImage` previews, re-upload via the existing picker, submit in a
`DsStickyBar`. Rejection reason (if the model has one) in a danger
`DsInlineAlert`.

**O. Help** (help_support_screen): `DsScaffold.collapsing` with a
`DsSectionHeader` "Contact us" (call / email / chat `DsListTile`s using the
existing handlers) then the ticket / message list as `DsCard.outlined` rows
with `DsStatusChip`, plus the existing composer / attachment flow in a
`DsStickyBar` or `DsBottomSheet`.

### Shared archetypes

**A. Dashboard / home**: use `DsScaffold.hero` (or `DsHeroHeader` in a tab). Put a greeting and availability status in the hero, with 2–4 `DsStatTile(variant: onBrand)` or a `heroOverlap` quick-actions card. Below it, add `DsSectionHeader` sections, a `DsAdaptiveGrid` of KPI or shortcut tiles (2 columns on phone, 4 on tablet) and recent activity as `DsCard` rows. Load with `DsSkeletonDashboard`.

**B. List / feed** (inbox, job history): use `DsScaffold.collapsing` with a pinned filter row (`SliverPersistentHeader` or `SliverToBoxAdapter` holding `DsSearchBar` and `DsSegmentedTabs(scrollable)`). Show `SliverList` rows as `DsCard.outlined` with `DsStatusChip`, animated with `DsFadeSlideIn(index:)`. Add pull-to-refresh with `onRefresh` if the controller already exposes a loader, and use a FAB for "Add". On tablets, switch to a 2-column grid (`DsLayout.gridDelegate`) or a list/detail split. Use `DsEmptyState` when there are no items and `DsSkeletonList` while loading.

**C. Detail** (generic; for jobs use K): use a hero media area (`DsImage` with a `heroTag`, or a gradient) under a transparent `DsAppBar`. Add a title block with price or status, then info sections in `DsCard` with `DsListTile` rows and a `DsTimeline` for status history. Put the actions in a `DsStickyBar`, for example `Row[Expanded(DsButton.dangerTonal('Reject')), Expanded(DsButton.primary('Accept'))]`. On tablets, show media on the left and details on the right. Load with `DsSkeletonDetail`.

**D. Form / wizard** (edit profile, bank details): use `DsScaffold` with a `DsStepper` or `DsProgressBar` at the top when the form is long, a sequence of `DsFormSection` cards, and fields made from `DsTextField`, `DsDropdown` and read-only pickers. Put the submit button in a `DsStickyBar` as `DsButton.primary(expand, loading)`. Cap the width at `DsLayout.contentMax`, and on tablets place short fields two per row with `DsAdaptiveGrid(minItemWidth: 260)`. Load with `DsSkeletonForm`.

**E. Settings / menu / profile**: use a profile header card (`DsAvatar(ring)` with name, email and `DsBadge` status) followed by `DsTileGroup` groups of `DsListTile(leadingIcon, showChevron)`. Put destructive rows (logout, delete) in a final group with `destructive: true`, and use switches as the `trailing` of a tile. On tablets, use two columns of groups.

**F. Auth** (login, signup, OTP, forgot password): on phones, use a brand mark on top (logo in `DsIconWell` or a gradient blob), a large `display` title, a focused form with `DsTextField`s, a primary CTA, `DsDivider(label: 'OR')` and social buttons as `DsButton.secondary(leading: SvgPicture)`. On tablets (`l.isWide`), split the screen: the left half is a `DsGradients.brand` panel with the logo, tagline and illustration, and the right half is the form card (max 440).

**G. Wallet / finance** (earnings, if added later): the hero is a `DsCard.gradient(gradient: DsGradients.deep(context))` balance card with a `DsAnimatedCounter` using `metricLg`, plus Withdraw and Top-up actions. Add a summary row of `DsStatTile`s (credit and debit) or `DsProgressRing`/`DsProgressBar` visuals as a chart-like summary. Below that, show transactions grouped by date with `DsListTile` rows (tone icon wells: success for credit, danger for debit) and amounts as `t.titleSm.tabular`.

**H. Chat**: use a `DsAppBar` with a `DsAvatar` and status in `titleWidget`. Show a bubble list: yours use `c.brand` with `onBrand` text, theirs use `c.surface` with a border, each with `radius lg` and one sharp corner and a `caption` timestamp. The composer is a `DsStickyBar` containing a pill `TextField` (use `DsInputDecoration`) and a filled send `DsIconButton`.

**I. Empty / status / maintenance / success**: center a `DsEmptyState` (or a custom illustration with `DsFadeSlideIn`) with one clear action. Use a tone that matches the status: success for done, warning for pending verification, danger for blocked.

Mix the details within an archetype too. For example, give the jobs list image-led status cards, the documents list tone icon wells, and the inbox avatar rows. Screens that share an archetype should still differ in their hero content and their main visual.
