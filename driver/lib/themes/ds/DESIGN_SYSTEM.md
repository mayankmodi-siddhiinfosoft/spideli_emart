# spideli Driver – Design System (DS)

```dart
import 'package:driver/themes/ds/ds.dart';   // everything: tokens, layout, motion, components
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
   or brand surfaces, and `Colors.transparent`. Do not use the `AppThemeData`
   section palettes (`taxiBooking300`, `parcelService300`, `secondary300`,
   `driverApp300`...) directly: use `c.brand` for actions and
   `c.section(DsSection.x)` / `DsSectionBadge` only to *tag* a service. The
   brand color comes from `c.brand`, which is read at runtime from Firestore
   (`app_driver_color`).
3. **Light + dark.** Everything from `context.dsColors` / `context.dsText`
   follows the theme. Existing screens get `isDark` from
   `themeController.isDark.value`. You can keep that `Obx` (it is what triggers
   rebuilds) but pick colors from `c`, not `isDark ? a : b`.
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
   `DsAsync` or a ternary. Use `Constant.loader()` / `DsBrandLoader` only when no
   layout is known yet (splash, payment). Blocking actions keep
   `ShowToastDialog.showLoader`, which is already styled.
8. **Accessibility and the road.** Icon-only buttons must be `DsIconButton`
   (or `DsMapButton` over a map) and need a `semanticLabel` (use `.tr`). Touch
   targets are at least 48dp, and DS components guarantee this. Actions a driver
   takes while the phone is mounted (accept / reject, go online, start / complete
   trip, picked up, delivered) use `DsButtonSize.xl` (64dp) or
   `DsSlideToConfirm`. Never rely on color alone for state: pair it with an icon
   and a label (`DsStatusChip`, `DsOnlineToggle`). `DsColors` switches to a
   high-contrast palette when the OS asks for it; do not hard-code greys that
   bypass it. Do not put text inside a fixed-size box.
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
| `online`, `onlineStrong`, `offline`, `offlineSoft`, `busy` | driver availability state (online = success, offline = neutral slate, never red; busy = info) |
| `routePickup`, `routeDrop` | map markers / route accents (brand / danger) |
| `scrim`, `shimmerBase`, `shimmerHighlight`, `focusRing` | misc |
| `c.highContrast` | true when the OS asks for more contrast: secondary text, borders and brand text are stronger |

`DsTone { neutral, brand, success, warning, danger, info }` → `c.tone(t)`
gives `main / strong / soft / onMain`.
`DsTone.fromStatus(order.status)` maps any status string in the app to a tone:
`Driver Pending` → warning, `Driver Accepted` / `Order Completed` / delivered →
success, `Order Shipped` / `In Transit` / picked up / arrived / started → info,
rejected / cancelled / failed → danger, `Offline` → neutral, `Order Placed` / new
request → brand.

`DsSection { cab, parcel, rental, delivery, onDemand }` tags the service a
driver works in. `DsSection.fromServiceType('cab-service' | 'parcel_delivery' |
'rental-service' | 'delivery-service' | 'ecommerce-service')` maps the stored
service type; `c.section(s)` gives `main / strong / soft / onMain` from the
existing section palettes (taxi yellow, parcel green, rental green, multi-vendor
red, on-demand blue) and `s.icon` a default icon. Section colors *tag*; they
never replace the brand color on buttons.

### Typography: `final t = context.dsText;`
`displayLg 34`, `display 28`, `headline 22`, `title 18`, `titleSm 16`,
`bodyLg 16`, `body 14`, `bodyStrong 14/500`, `bodySecondary`, `bodySm 13`,
`label 14/600`, `labelSm 12/600`, `caption 12/500 muted`, `overline 11 caps`,
`metric 26/700 tabular`, `metricLg 36`, `metricXl 44` (glanceable numbers
while driving: countdown, ETA, live fare), `link`.
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
Map screens are edge-to-edge: `DsScaffold(maxContentWidth: null, ...)` (or keep the
existing `Scaffold`) and let `DsMapPanel` handle width (docked on phones,
floating card on tablets). Keep the map widget, its controller, markers and
polylines exactly as they are.

---

## 3. Components

### Scaffold and navigation
```dart
DsScaffold(title: 'Orders'.tr, actions: [...], body: ..., bottomBar: DsStickyBar(child: ...))
DsScaffold.collapsing(title: 'Trip history'.tr, subtitle: '12 trips', onRefresh: c.refresh, slivers: [...])
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
DsButton.success(label: 'Accept'.tr, icon: Icons.check_rounded, size: DsButtonSize.xl, expand: true, onPressed: ...)
DsIconButton(icon: Icons.tune_rounded, semanticLabel: 'Filters'.tr, variant: DsIconButtonVariant.tonal, badgeCount: 2, onPressed: ...)
```
Sizes are `sm 40`, `md 48` (default), `lg 56` and `xl 64` (on-the-road actions), and every size gets a 48dp hit target.
Variants: `primary`, `secondary`, `tonal`, `ghost`, `danger`, `dangerTonal`, `success` (positive, time-critical: Accept, Go online, Delivered). `onPressed: null` disables the button, and `loading` keeps its width.
Icon button variants are `plain`, `tonal`, `brand`, `outlined` and `filled`.

### Forms
```dart
DsFormSection(title: 'Vehicle details'.tr, icon: Icons.directions_car_outlined, children: [
  DsTextField(label: 'Vehicle number'.tr, hint: '...'.tr, controller: c.nameController, requiredMark: true, validator: ...),
  DsTextField(label: 'Password'.tr, controller: c.passwordController, obscurable: true),
  DsDropdown<String>(label: 'Vehicle type'.tr, value: c.typeId.value, items: [...], onChanged: (v) => c.typeId.value = v),
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
DsStepper(steps: ['Profile'.tr, 'Vehicle'.tr, 'Documents'.tr], current: c.step.value)
```

### Driver components (`components/ds_driver.dart`)
All are presentational: pass values and the screen's existing handlers.
```dart
// Availability. Big pill (64dp), tap anywhere, haptic, announces "toggled".
DsOnlineToggle(isOnline: online, loading: busy, onChanged: (v) => existingToggleHandler(v),
               onlineSubtitle: 'Receiving requests'.tr, offlineSubtitle: 'Go online to get requests'.tr)
DsOnlineToggle(compact: true, isOnline: online, onChanged: ...)          // app bar / map overlay pill
DsPulseDot(color: c.online, pulse: true, size: 10)

// Service tag.
DsSectionBadge(section: DsSection.fromServiceType(type), label: 'Parcel'.tr, solid: false)

// Over a full-screen map (Stack: map, top overlays, bottom panel).
DsMapButton(icon: Icons.my_location_rounded, semanticLabel: 'My location'.tr, onPressed: ...)
DsMapButton(icon: Icons.navigation_rounded, label: 'Navigate'.tr, semanticLabel: 'Navigate'.tr, tone: DsTone.brand, onPressed: ...)
DsMapPanel(header: ..., child: ..., actions: ...)  // docked sheet on phones, floating 440-wide card on tablets

// Incoming request (new ride / order / parcel / rental).
DsRequestCard(title: 'New ride request'.tr, section: DsSection.cab, sectionLabel: 'Cab'.tr,
  fare: amount, fareCaption: paymentLabel, countdown: secondsLeft / total, countdownLabel: '$secondsLeft',
  stops: [DsRouteStop(kind: DsStopKind.pickup, label: 'Pickup'.tr, address: a), DsRouteStop(kind: DsStopKind.drop, label: 'Drop-off'.tr, address: b)],
  metrics: [DsTripMetric(icon: Icons.route_rounded, value: '4.2 km', label: 'Distance'.tr)],
  onReject: ..., onAccept: ..., accepting: false, slideToAccept: false)

// Route, numbers, receipts.
DsRouteStops(stops: [...])                  // pickup (brand ring) → stops → drop (red flag), done stops get a check
DsTripMetrics(items: [DsTripMetric(...), ...])   // 2–4 glanceable numbers with hairline separators
DsInfoRow(label: 'Base fare'.tr, value: amount)  DsInfoRow(label: 'Total'.tr, value: total, emphasize: true)

// Irreversible on-the-road actions: deliberate swipe (screen readers get a double-tap button).
DsSlideToConfirm(label: 'Slide to start trip'.tr, icon: Icons.play_arrow_rounded, onConfirmed: c.startTrip)
DsSlideToConfirm(label: 'Slide when delivered'.tr, tone: DsTone.success, loading: c.isLoading.value, onConfirmed: ...)
```
`DsSlideToConfirm` calls `onConfirmed` once per swipe, keeps the thumb at the end
while `loading` is true and slides back afterwards (or after ~600ms if the parent
never sets `loading`). Only use it where the old screen had a single tap action
that is safe to keep behind a swipe; the handler itself must stay unchanged.

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
`Constant.loader()` now returns a `DsBrandLoader`, and `Constant.showEmptyView()` returns a compact `DsEmptyState`.

### Motion
```dart
itemBuilder: (_, i) => DsFadeSlideIn(index: i, child: OrderCard(...))
Column(children: DsFadeSlideIn.stagger([hero, kpis, recent]))
DsAnimatedCounter(value: c.totalOrders.value, style: t.metric, format: (v) => Constant.amountShow(amount: v.toString()))
DsPressable(onTap: ..., child: ...)   // or without onTap around an existing InkWell for press feedback only
```
`DsFadeSlideIn` animates only on first appearance. Items that are recycled while the user scrolls simply appear. It also respects reduce motion.
For richer states, use `AnimatedSwitcher`, `AnimatedContainer` and `AnimatedSize` with `DsMotion` durations and curves.

---

## 4. Theme-level upgrades (already live on every screen)
`main.dart` uses `DsTheme.light()/dark()`. Material widgets are themed:
app bar, cards, chips, buttons, FAB, tabs, switches, checkboxes, radios,
sliders, date and time pickers, dialogs, bottom sheets, snackbars, tooltips,
menus and progress indicators. The global input theme only sets hint, label and
error styles. Borders and fills come from `DsInputDecoration` or `DsTextField`,
because legacy fields use `InputBorder.none` inside custom boxes.
`DsBrandTheme` re-themes when the Firestore brand color (`app_driver_color`,
set in `FireStoreUtils.getSettings`) loads; it re-checks after every navigation.
`GetMaterialApp` also gets `highContrastTheme` / `highContrastDarkTheme`, and
`DsColors.of(context)` follows the OS contrast setting.
Font: the app font is `EssentialSans` (`AppThemeData.fontFamily`). It was not
declared in `pubspec.yaml` before (only unused `Urbanist-*` families were), so
text rendered in the platform font. It is now declared once with weights
400/500/600/700, and every DS style sets `fontWeight`. Do not use the
`Urbanist-*` family names.
Page transitions: `GetMaterialApp(customTransition: DsPageTransition(), transitionDuration: DsMotion.page)`.
Android gets a shared-axis slide and fade. iOS keeps the native slide with swipe-back.
Legacy widgets (`RoundedButtonFill`, `RoundedButtonBorder`, `TextFieldWidget`,
`CustomDialogBox`, EasyLoading) have the DS look with unchanged APIs.
`CustomDialogBox` shows a secondary + danger pair when `negativeString` is set
(log out / delete account) and a single primary button otherwise ("Okay").
`Constant.loader()` / `Constant.showEmptyView()` return DS widgets. You may
keep them, but prefer DS components in redesigned screens.

---

## 5. Screen recipe
1. Keep the outer `Obx` / `GetX(init:)` / `GetBuilder` exactly as it is. Inside it: `final c = context.dsColors; final t = context.dsText; final l = context.dsLayout;`.
2. Replace `Scaffold` + `AppBar` with a `DsScaffold` variant that fits the archetype.
3. Wrap the loading branch with a skeleton (`DsAsync` or `isLoading ? DsSkeletonX() : ...`).
4. Build content from DS components and wrap list items in `DsFadeSlideIn(index: i)`.
5. Put primary actions in a `DsStickyBar` (forms, detail) or a FAB (lists).
6. Check light and dark, high contrast, a phone and an iPad (768+), and text scale 1.3. For map
   screens, check the panel over both a light and a dark map.
7. Run `flutter analyze --no-pub` and fix any errors or warnings.

---

## 6. Screen archetypes (pick one per screen and vary them)

The driver app is used on the move. Every archetype keeps the primary action in
the bottom third of the screen (thumb reach), uses `xl` buttons or a slide for
on-the-road actions, and keeps state visible as icon + label + color.

**A. Online / offline home with map** (`home_screen`, `cab_home_screen`,
`parcel_home_screen`, `rental_home_screen`, multi-service dashboard tab): the
map stays full-bleed under everything. Top overlay: a safe-area row with the
menu / profile `DsIconButton(variant: tonal)` (or `DsMapButton`), a
`DsOnlineToggle(compact: true)` and wallet / notification buttons. Right edge:
`DsMapButton`s (recenter, navigation). Bottom: a `DsMapPanel` whose content
depends on state: offline → `DsOnlineToggle` (full) + a short reason line and
today's `DsTripMetrics` (trips / earnings / hours); online and idle → pulsing
"Looking for requests" row (`DsPulseDot` + `t.titleSm`) + the toggle; on a job →
archetype C. Show `DsInlineAlert(tone: warning)` above the toggle when documents
are unverified or the wallet is below the minimum deposit. On tablets the panel
floats bottom-start (automatic). Load with `DsSkeletonCard` inside the panel,
never a full-screen loader over the map.

**B. Incoming request** (new order / ride / parcel / rental popup or card):
`DsRequestCard` in a `DsMapPanel(showHandle: false)` or a bottom sheet, with the
section badge, countdown ring (`countdown` 0..1, turns red under 30%), the fare in
`metricLg`, `DsRouteStops` pickup → drop, `DsTripMetrics` (distance, ETA, items /
weight) and `Reject` (dangerTonal) + `Accept` (success, twice the width) at
`xl` size. Keep the existing timer, ringtone and accept / reject handlers. Use
`slideToAccept: true` only if the old flow was already confirm-style. Multiple
pending requests: a horizontal `PageView` of cards with a page indicator.

**C. Live trip / navigation panel** (pickup order, deliver order, cab / rental
trip in progress, parcel pickup and delivery): map + `DsMapPanel`. Header row:
`DsStatusChip(label: status.tr, status: rawStatus, pulse: true)`, ETA / distance
in `t.titleSm.tabular` and a `DsMapButton(label: 'Navigate'.tr)` that calls the
existing map-launcher code. Body: customer / store row (`DsListTile` with
`DsAvatar` and call / chat `DsIconButton(variant: brand)` in `trailing`),
`DsRouteStops` with the reached stop `done: true`, optional OTP / payment
`DsInlineAlert`. Actions: the step's single action as `DsSlideToConfirm`
("Slide to confirm pickup", "Slide to complete trip") or `DsButton.primary(xl)`;
secondary actions (cancel, report issue) as `DsButton.ghost` below. Keep every
status update call and navigation exactly as it is.

**D. Parcel scan / timeline** (parcel details, scanner, tracking, delivery
proof, manifest): `DsScaffold` with a `DsCard` summary at the top (tracking id
in `t.title.tabular` with a copy `DsIconButton`, `DsSectionBadge(parcel)`,
`DsStatusChip`). Scanner screens keep the camera full-bleed with a rounded
viewfinder overlay (`DsRadius.xl` border in `c.brand`, `c.scrim` outside) and a
`DsMapPanel`-style bottom panel with the instruction, last scan result
(`DsInlineAlert` success / danger) and a manual-entry `DsTextField`. Tracking
uses `DsTimeline` (done / current / upcoming / error). Proof of delivery:
`DsFormSection` with photo / signature tiles and a `DsStickyBar` primary. Load
with `DsSkeletonDetail`.

**E. Earnings / wallet** (wallet, withdraw, payout methods, earnings history):
`DsScaffold.hero` with `heroGradient: DsGradients.deep(context)`, balance as
`DsAnimatedCounter` in `metricLg` (white) and Withdraw / Top-up
`DsButton` pair in `heroOverlap`. Below: `DsSegmentedTabs` (Today / Week /
Month or Earnings / Withdrawals), a `DsAdaptiveGrid` of `DsStatTile`s (trips,
online hours, tips, cash collected), then transactions grouped by date as
`DsListTile` rows with tone icon wells (success credit, danger debit) and
amounts in `t.titleSm.tabular`. Minimum-withdrawal and minimum-deposit rules as
`DsInlineAlert(tone: info)`. Load with `DsSkeletonDashboard`.

**F. Documents / verification** (verification screen, document upload): a
`DsProgressBar(label: 'Documents verified'.tr, showPercent: true)` or `DsStepper`
at the top, then one `DsCard.outlined` per document: `DsIconWell` (tone from
status), name, `DsStatusChip(status: doc.status)`, front / back thumbnails with
`DsImage`, and an Upload / Replace `DsButton.tonal(size: sm)`. Rejected documents
show the reason in a `DsInlineAlert(tone: danger)`. Upload screen = archetype H
form with large image picker tiles (dashed `c.borderStrong` border, `DsIconWell`,
caption). Everything verified → `DsEmptyState(tone: success)`.

**G. Vehicle info** (vehicle information, owner's drivers / vehicles): a hero
`DsCard` with the vehicle image (`DsImage`, 16:9) or a large `DsIconWell` for the
type, plate number in `t.headline.tabular`, make / model / color as `DsBadge`s,
then details as `DsInfoRow`s in a `DsCard`. Edit form = `DsFormSection`s with
`DsDropdown` (type, make, model) and `DsTextField`, submit in `DsStickyBar`. For
owners, list vehicles / drivers as `DsCard.outlined` rows with `DsAvatar` +
`DsStatusChip` (online / offline / on trip).

**H. Auth and onboarding** (login, phone / OTP, signup, forgot password, service
selection, onboarding): phones get the logo in a soft brand `DsIconWell` or a
gradient blob, a `display` title, the form with `DsTextField`s, a primary
`DsButton(size: lg, expand: true)`, `DsDivider(label: 'OR'.tr)` and social sign-in
as `DsButton.secondary(leading: SvgPicture...)`. OTP boxes keep `pin_code_fields`
styled with DS colors (`c.surfaceAlt` fill, `c.brand` active border,
`DsRadius.md`). Service selection (cab / parcel / rental / delivery) is a
`DsAdaptiveGrid` of selectable `DsCard.outlined(borderColor: selected ? c.brand : null)`
tiles with `DsIconWell` in the section accent. Tablets split into a brand panel +
form card (max 440). Onboarding: full-bleed illustration, `DsStepper`-style dots,
`DsButton.primary(lg)`.

**I. Chat** (customer / store / admin chat, help & support): `DsAppBar` with a
`DsAvatar` + name + order id in `titleWidget` and a call `DsIconButton`. Bubbles:
yours `c.brand` with `c.onBrand` text, theirs `c.surface` with a `c.border`
border, `DsRadius.lg` with one sharp corner, `caption` timestamp and read ticks.
Images as `DsImage(radius: md)`. Composer in a `DsStickyBar`: pill `TextField`
with `DsInputDecoration`, attach `DsIconButton(tonal)`, send
`DsIconButton(filled)`. Quick replies ("I'm here", "On my way") as
`DsSegmentedTabs(scrollable: true)` chips only if the screen already has them.

**J. Lists and history** (order list, trip history, rental bookings, parcel
list): `DsScaffold.collapsing` with `DsSegmentedTabs` (Active / Completed /
Cancelled) pinned, rows as `DsCard.outlined` with section badge, date, compact
`DsRouteStops(addressMaxLines: 1)`, amount (`t.titleSm.tabular`) and
`DsStatusChip`; `DsFadeSlideIn(index:)`; `DsSkeletonList` while loading and
`DsEmptyState` when empty. Detail screens: archetype C layout without the map
(or a static map header) + `DsTimeline` + fare breakdown `DsInfoRow`s.

**K. Settings / profile / menu** (drawer / profile tab, edit profile, change
language, change password, terms): profile header `DsCard` with
`DsAvatar(ring: true, statusTone: online ? DsTone.success : DsTone.neutral)`,
name, phone, rating `DsBadge` and the vehicle plate; then `DsTileGroup`s
(Account, Earnings, Vehicle & documents, App: dark mode switch / language /
support), destructive group last (Log out, Delete account → keep the existing
`CustomDialogBox` calls). Tablets: two columns of groups.

**L. Status / maintenance / success**: centered `DsEmptyState` with the matching
tone (success: trip completed / delivered; warning: pending approval or
documents; danger: blocked / suspended; neutral: maintenance) and one clear action.
Trip-complete summary: `DsProgressRing` / big check, fare in `metricXl`,
`DsInfoRow` breakdown, rating, `DsButton.primary(xl, expand)` "Done".

Vary within an archetype: the cab home can lead with the map and a compact
panel, the parcel home with a scan shortcut card, the rental home with the
booking list; wallet and earnings share archetype E but use different hero
content.
