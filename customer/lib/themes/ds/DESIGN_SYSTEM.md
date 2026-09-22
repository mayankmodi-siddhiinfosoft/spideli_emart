# spideli Customer – Design System (DS)

```dart
import 'package:customer/themes/ds/ds.dart';   // everything: tokens, sections, layout, motion, components
```

Every screen redesign uses **only** what is in `lib/themes/ds/`. If you think
something is missing, compose it from DS primitives inside your screen file.
Do not add a new token or package (`shimmer`, `flutter_svg`,
`cached_network_image` are already available).

The same public API (`Ds*`, `context.dsColors/dsText/dsLayout`) exists in the
Store (`vendor/`) app. The customer app adds **service sections**
(`DsSection`, `c.sectionAccent`, `DsAccentScope`, `DsGradients.section`).

---

## 0. Hard rules

1. **Do not touch behaviour.** Keep every controller call, `Obx`, `GetBuilder`,
   `GetX(init: ...)`, `Get.to/off/offAll/back`, route arguments, validators,
   `onTap` handlers, Firestore/API calls, payment flows, map callbacks and `.tr`
   strings exactly as they are. You only change the widget tree around them.
   If a handler is inline, move it verbatim.
2. **No hard-coded colors.** Use `context.dsColors` (`c.surface`,
   `c.textPrimary`, `c.brand`...). Only exceptions: `Colors.white` on gradient
   or brand surfaces, `Colors.transparent`, and map/marker assets.
   Replace `AppThemeData.primary300` with `c.brand`, and
   `isDark ? AppThemeData.primary600 : AppThemeData.primary50` with
   `c.brandSoft` (the `primary50/600` constants are always orange, they do not
   follow the section). Replace `Constant.statusColor(status:)` in new UI with
   `DsStatusChip(status:)` / `DsTone.fromStatus`.
3. **Section identity.** `c.brand` *is* the active service's color (see §1.1).
   Never pick a section palette constant (`AppThemeData.taxiBooking300`,
   `ecommerce300`, `parcelService300`...) directly; use `c.brand`, or
   `c.sectionAccent(DsSection.x)` when a screen must show *another* section.
4. **Light + dark.** Everything from `context.dsColors` / `context.dsText`
   follows the theme. Existing screens get `isDark` from
   `themeController.isDark.value`. You can keep that `Obx` (it is what triggers
   rebuilds) but pick colors from `c`, not `isDark ? a : b`.
5. **Text styles from `context.dsText`** (or `DsTypography.*` with an explicit
   color). All DS styles set `fontWeight` (EssentialSans is selected by
   weight: 400 regular, 500 medium, 600 semibold, 700 bold). Do not use fixed
   heights on containers that hold text. Use `minHeight` and padding so layouts
   survive 1.3x–2x text scale.
6. **Responsive.** Constrain page content with `DsResponsive` or
   `DsSliverResponsive`. Use `context.dsLayout` for gutters, columns and
   `isWide` two-pane layouts. Never use `Responsive.width(100)` for new UI.
   Maps stay edge-to-edge (`maxContentWidth: null`).
7. **Motion.** Lists and sections enter with `DsFadeSlideIn` (staggered by
   index). Tappable cards use `DsCard(onTap:)`, which already has press feedback.
   Page transitions are app-wide, so do not pass `transition:` to `Get.to`.
8. **Loading.** Every async load shows a skeleton (`DsSkeleton*`) through
   `DsAsync` or a ternary. Use `Constant.loader()` / `DsBrandLoader` only when no
   layout is known yet (splash, payment gateway, map warming up). Blocking
   actions keep `ShowToastDialog.showLoader`, which is already styled.
9. **Accessibility.** Icon-only buttons must be `DsIconButton` and need a
   `semanticLabel` (use `.tr`). Touch targets are at least 48dp, and DS components
   guarantee this. Do not put text inside a fixed-size box. Text on a solid accent
   uses `c.onBrand` / `accent.onMain` (dark on amber, green and cyan).
10. **Reactivity (GetX).** An `Obx` only tracks `.value` reads made *while its
    builder runs*. `DsAsync(builder:)` wraps its builder in `DsObserve`, so
    reads there are tracked. For `ListView.builder` item builders, bottom-sheet
    content, or small child widgets that read `controller.x.value` in their own
    `build`, wrap that part in `Obx(...)` or `DsObserve(builder: ...)`
    (`DsObserve` also tolerates reading no observable). Never read `.value` in a
    widget whose only observer is a parent `Obx` that has already returned.
11. **Stay distinct.** Pick one archetype from section 6 for each screen, and use
    the hero, tint and gradient variants on purpose. A screen should not look
    like its neighbour, and the six services should not look like recolours of
    each other.

---

## 1. Tokens

| Token | Values |
|---|---|
| `DsSpace` | `xxs 2, xs 4, sm 8, md 12, lg 16, xl 20, xxl 24, xxxl 32, huge 40, giant 56`, `gutter 16` |
| `DsGap` | `DsGap(12)`, `DsGap.sm/md/lg/xl/xxl/xxxl` (works in Row and Column), `DsGap.sliver(24)` |
| `DsRadius` | `xs 6, sm 10, md 14, lg 18, xl 24, xxl 32, pill`; BorderRadius: `brXs…brXxl, brPill, sheetTop` |
| `DsShadows` | `xs/sm/md/lg(context)` soft layered shadows (dark aware), `glow(context, color:)` for brand heroes |
| `DsMotion` | durations `instant 90, fast 160, base 240, slow 380, slower 600, page 340`, `stagger 45ms`; curves `standard, emphasized, decelerate, accelerate, spring`; `DsMotion.of(context, d)` returns zero when the user turned on reduce motion |
| `DsGradients` | `brand(context)` (active section), `section(context, DsSection.cab)`, `brandFrom(color)`, `deep(context)` (wallet/premium), `subtle(context)`, `tone(context, DsTone.x)`, `imageScrim` |

### 1.1 Brand = active service section
`AppThemeData.primary300` is a runtime value. The app sets it from
`globalSettings.app_customer_color` at start-up (`FireStoreUtils`), then to the
tapped section's Firestore `color` in `ServiceListController.onServiceTap`.
`c.brand` reads it at call time and `DsBrandTheme` re-themes Material widgets on
the next navigation, so inside a service everything that uses `c.brand`,
`DsTone.brand`, `DsButton.primary`, `DsGradients.brand`, switches, tabs and the
bottom navigation is that service's color. **You get section identity for free
by using `c.brand`.**

| `DsSection` | `serviceTypeFlag` | Palette (`AppThemeData`) | Accent | `onMain` |
|---|---|---|---|---|
| `food` | `delivery-service` | `multiVendor*` | red `#FE5D5D` | white |
| `ecommerce` | `ecommerce-service` | `ecommerce*` | blue `#3974FF` | white |
| `cab` | `cab-service` (taxi + intercity) | `taxiBooking*` | amber `#FFB32C` | dark ink |
| `parcel` | `parcel_delivery` | `parcelService*` | green `#2AD587` | dark ink |
| `rental` | `rental-service` | `carRent*` | green `#47CF88` | dark ink |
| `onDemand` | `ondemand-service` | `onDemand*` | cyan `#0DBDFD` | dark ink |
| `none` | no section yet (splash, auth, service list) | app brand | orange `#FF6839` by default | white |

```dart
final c = context.dsColors;
c.brand                                   // live accent of the active section
c.section / context.dsSection / DsSection.current   // which section is active
final cab = c.sectionAccent(DsSection.cab);          // explicit palette: main / strong / soft / onMain
final tile = c.accentFrom(DsColors.fromHex(section.color) ?? c.brand); // Firestore SectionModel.color
DsSection.fromServiceFlag(section.serviceTypeFlag)
DsSection.cab.icon                                  // default icon per section
DsAccentScope.section(section: DsSection.parcel, child: ...)   // pin a subtree to a section
DsAccentScope(color: DsColors.fromHex(section.color)!, child: ...)
```
- Use `DsAccentScope` where a screen shows a section other than the active one:
  service-list tiles, cross-service order history, "more services" sheet, a
  parcel card inside the food home. Inside it `c.brand`, `DsTone.brand`, DS
  components and (with `retheme: true`, the default) Material widgets use that
  accent.
- The service list is shown *after* returning from a service too, and
  `primary300` keeps the last section's color. On `service_list_screen.dart`
  and `more_services_sheet.dart`, color each tile from its own
  `section.color` (`c.accentFrom` / `DsAccentScope`), and keep neutral chrome
  (`c.surface`, `c.textPrimary`) for the rest.
- `brandStrong` and `sectionAccent(...).strong` are guaranteed ≥ 4.5:1 on
  `c.surface`; `DsGradients.brand/section` are deepened for light accents so
  white hero text stays readable. Use `strong` for accent-colored text, never
  `main`.
- Sections with a `theme` variant (`SectionModel.theme == "theme_2"` switches
  the food home between `HomeScreen` and `HomeScreenTwo`) keep both variants;
  redesign both on the same archetype but give them different hero treatments.

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
| `brand`, `brandStrong` (for brand-colored text or pressed states), `brandSoft`, `brandMuted`, `onBrand` | active section accent |
| `sectionAccent(s)`, `accentFrom(color)` | explicit section / Firestore accents (`DsToneColors`) |
| `success/warning/danger/info` + `…Strong` (readable text) + `…Soft` (bg) | semantic |
| `scrim`, `shimmerBase`, `shimmerHighlight`, `focusRing` | misc |
| `DsColors.onColor(fill)`, `DsColors.readableOn(color, bg)`, `DsColors.contrast(a, b)`, `DsColors.fromHex(hex)` | helpers |

`DsTone { neutral, brand, success, warning, danger, info }` → `c.tone(t)`
gives `main / strong / soft / onMain`.
`DsTone.fromStatus(status)` maps any status string in the app to a tone:
`Order Placed`/`booking_placed` → brand, `Order Accepted`/`Driver Accepted`/
`Order Completed`/`SUCCESS`/`PAID`/`SETTLED` → success, `Driver Pending`/
`countered`/scheduled → warning, `Order Shipped`/`In Transit`/`Order Ongoing`/
`Order Assigned` → info, `Order Rejected`/`Order Cancelled`/`Driver Rejected`/
`FAILED` → danger.

### Typography: `final t = context.dsText;`
`displayLg 34`, `display 28`, `headline 22`, `title 18`, `titleSm 16`,
`bodyLg 16`, `body 14`, `bodyStrong 14/500`, `bodySecondary`, `bodySm 13`,
`label 14/600`, `labelSm 12/600`, `caption 12/500 muted`, `overline 11 caps`,
`metric 26/700 tabular`, `metricLg 36`, `link`.
Helpers: `t.title.withColor(c.brand)`, `.w500/.w600/.w700`, `.tabular`, `.strike` (old price).
Prices, fares, ETAs, OTPs and counters use `.tabular`.

### Context helpers
`context.dsColors`, `context.dsText`, `context.dsLayout`, `context.dsIsDark`, `context.dsSection`.

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

On tablets and iPad, use two panes for list/detail (orders, bookings), map + panel for rides, split auth screens, and 3–5 column grids for storefronts and catalogues.

---

## 3. Components

### Scaffold and navigation
```dart
DsScaffold(title: 'My Orders'.tr, actions: [...], body: ..., bottomBar: DsStickyBar(child: ...))
DsScaffold.collapsing(title: 'Restaurants'.tr, subtitle: '24 nearby', onRefresh: controller.getData, slivers: [...])
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
DsFormSection(title: 'Personal details'.tr, icon: Icons.person_outline, children: [
  DsTextField(label: 'First name'.tr, hint: '...'.tr, controller: c.nameController, requiredMark: true, validator: ...),
  DsTextField(label: 'Password'.tr, controller: c.passwordController, obscurable: true),
  DsDropdown<String>(label: 'Vehicle type'.tr, value: c.catId.value, items: [...], onChanged: (v) => c.catId.value = v),
])
TextFormField(decoration: DsInputDecoration.of(context, hint: 'Name'.tr, prefixIcon: Icons.person_outline))
DsFieldLabel('Pickup time'.tr, required: true)
DsSearchBar(hint: 'Search'.tr, controller: c.searchController, onChanged: c.onSearch, trailing: DsIconButton(...))
DsSegmentedTabs(segments: [DsSegment('Active'.tr, count: 3), DsSegment('Completed'.tr), DsSegment('Cancelled'.tr)], index: c.tab.value, onChanged: (i) => c.tab.value = i)
DsSegmentedTabs(scrollable: true, ...)            // chip row for many filters
DsTabBar(controller: tabController, tabs: [...])  // when the screen already uses a TabController
```
`DsTextField` passes every `TextFormField` parameter through unchanged: controller, initialValue, validator, formatters, keyboardType, onChanged, onTap, readOnly, enabled, maxLines and maxLength. For pickers (date, time, image, map), use `DsTextField(readOnly: true, onTap: existingHandler, suffix: Icon(...))`.

### Feedback and overlays
```dart
DsEmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet'.tr, message: '...'.tr, actionLabel: 'Start shopping'.tr, onAction: ..., compact: false)
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
DsProgressBar(value: 0.6, label: 'Gift card balance used'.tr, showPercent: true)   // value: null → indeterminate
DsProgressRing(value: 0.72, size: 96, center: Text('72%', style: t.titleSm), onBrand: false)
DsTimeline(steps: [DsTimelineStep(title:, subtitle:, meta:, state: DsStepState.done|current|upcoming|error, icon:, content:)])
DsStepper(steps: ['Sender'.tr, 'Receiver'.tr, 'Parcel'.tr, 'Carrier'.tr], current: c.step.value)
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
`Constant.loader()` now returns a `DsBrandLoader`, and `Constant.showEmptyView(message:)` returns a compact `DsEmptyState`. Both follow the active section accent.

### Motion
```dart
itemBuilder: (_, i) => DsFadeSlideIn(index: i, child: RestaurantCard(...))
Column(children: DsFadeSlideIn.stagger([banner, categories, nearby]))
DsAnimatedCounter(value: c.walletAmount.value, style: t.metric, format: (v) => Constant.amountShow(amount: v.toString()))
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
`DsBrandTheme` re-themes when `AppThemeData.primary300` changes (app color from `globalSettings.app_customer_color`, then the tapped section's color), so opening a service re-themes switches, pickers, the bottom navigation and selection handles to that service.
Page transitions: `GetMaterialApp(customTransition: DsPageTransition(), transitionDuration: DsMotion.page)`.
Android gets a shared-axis slide and fade. iOS keeps the native slide with swipe-back.
Legacy widgets (`RoundedButtonFill`, `RoundedButtonBorder`, `TextFieldWidget`,
`CustomDialogBox`, `ShowToastDialog`/EasyLoading, `Constant.loader()`/`showEmptyView()`) have the DS look with unchanged APIs. Default label color on a colored `RoundedButtonFill` is now the readable ink for that fill (dark on amber/green/cyan). You may
keep them, but prefer DS components in redesigned screens.

---

## 5. Screen recipe
1. Keep the outer `Obx` / `GetX(init:)` / `GetBuilder` exactly as it is. Inside it: `final c = context.dsColors; final t = context.dsText; final l = context.dsLayout;`. Anything built lazily (`DsAsync.builder`, `itemBuilder`, a child widget's own `build`) that reads `.value` must be inside its own `Obx`/`DsObserve` (see rule 10).
2. Replace `Scaffold` + `AppBar` with a `DsScaffold` variant that fits the archetype.
3. Wrap the loading branch with a skeleton (`DsAsync` or `isLoading ? DsSkeletonX() : ...`).
4. Build content from DS components and wrap list items in `DsFadeSlideIn(index: i)`.
5. Put primary actions in a `DsStickyBar` (forms, detail) or a FAB (lists).
6. Check light and dark, a phone and an iPad (768+), text scale 1.3, **and at least two service sections** (e.g. food red and cab amber) so accent contrast holds.
7. Run `flutter analyze --no-pub` and fix any errors or warnings.

---

## 6. Screen archetypes (pick one per screen and vary them)

**A. Service home / storefront** (food `HomeScreen`/`HomeScreenTwo`, `home_e_commerce_screen`, `cab_home_screen`, `intercity_home_screen`, `home_parcel_screen`, `rental_home_screen`, `on_demand_home_screen`, `service_list_screen`): a `DsHeroHeader` in a `SliverToBoxAdapter` (dashboard tabs are not routes) with the delivery address / greeting, a `DsSearchBar(onTap:)` in `heroOverlap`, then banners (`DsImage` carousel with `radius lg`), a category rail (circular `DsIconWell`/`DsImage` + `labelSm`), `DsSectionHeader(actionLabel: 'View all'.tr)` sections and horizontal card rails. Give each service its own hero: food = image-led restaurant cards with rating `DsBadge`; e-commerce = product grid (`DsLayout.gridDelegate(maxItemWidth: 200)`) with brand chips; cab/intercity = "Where to?" destination card over a map peek plus saved places as `DsListTile`s and vehicle-type chips; parcel = "Send a parcel" `DsCard.gradient` + parcel-category tiles; rental = vehicle-type cards with hourly/km packages; on-demand = category grid + popular-provider rail with `DsAvatar`. Service list: section tiles in a `DsAdaptiveGrid(minItemWidth: 150)`, each wrapped in `DsAccentScope(color: DsColors.fromHex(section.color))` with `DsSection.x.icon` as a fallback. Load with `DsSkeletonDashboard` / `DsSkeletonGrid`. Tablets: 3–5 column grids, banners capped at `DsLayout.wideMax`.

**B. Catalogue / list and product or store detail** (`restaurant_details_screen`, category/brand product lists, `provider_screen`, `on_demand_details_screen`, search, favourites): list pages use `DsScaffold.collapsing` with a pinned `DsSearchBar` + `DsSegmentedTabs(scrollable: true)` filter row; rows as `DsCard.outlined` with `DsImage(heroTag:)`, price `t.titleSm.tabular` (old price `t.bodySm.strike`), veg/non-veg or stock `DsBadge`, and an add stepper made of `DsIconButton(variant: tonal)`. Detail pages: hero media (`DsImage` with the list's `heroTag`) under a transparent `DsAppBar` with favourite/share `DsIconButton(semanticLabel:)`, title block (name, rating, distance, open/closed `DsStatusChip`), offers as `DsCard.tinted(tone: DsTone.brand)`, menu/product sections with sticky category tabs, variants/add-ons in a `DsSheet`. A `DsStickyBar` "View cart" summary appears when the cart has items. Tablets: media left, details right; menu as 2 columns. Load with `DsSkeletonDetail`.

**C. Cart / checkout** (`cart_screen`, `oder_placing_screens`, `select_payment_screen`, `coupon_list_screen`, `parcel_order_confirmation`, `rental_conformation_screen`, `on_demand_payment_screen`, `gateway_checkout_screen`): `DsScaffold` with grouped `DsCard` sections — delivery address (`DsListTile` + "Change"), items with steppers, delivery option `DsSegmentedTabs` (delivery / takeaway / schedule), coupon row (`DsCard.tinted` when applied), tip chips, bill summary rows (`t.body` label, `t.bodyStrong.tabular` value, total `t.title.tabular`), payment method `DsTileGroup` with radio trailing. `DsStickyBar` with total + `DsButton.primary(size: lg, expand: true, loading:)`. Cap at `DsLayout.contentMax`; on tablets, summary card on the right. Payment redirection waits use `DsBrandLoader(label:)`.

**D. Live ride / map tracking** (`cab_booking_screen`, `live_tracking_screen`, `parcel_tracking_screen`, intercity booking): edge-to-edge map (`DsScaffold(maxContentWidth: null)` or a `Stack`), floating `DsIconButton(variant: filled)` back / recenter buttons with `semanticLabel`, and a draggable bottom panel (`DraggableScrollableSheet` holding a `DsSheet`-styled container with `DsRadius.sheetTop`). The panel shows the current step as a `DsStatusChip(pulse: true)`, ETA/fare as `t.metric.tabular`, the driver as `DsAvatar(ring: true)` + vehicle plate `DsBadge(style: outline)` + call/chat `DsIconButton(variant: tonal)`, OTP as large tabular digits in `DsCard.tinted`, and cancel as `DsButton.dangerTonal`. Vehicle selection rows are `DsCard.outlined(borderColor: selected ? c.brand : null)`. Keep all map/marker/polyline code untouched. Tablets / landscape: map left, panel as a fixed 400-wide side card.

**E. Booking wizard** (`book_parcel_screen` + carrier / pickup-point selection, rental booking, `on_demand_booking_screen`, dine-in booking, subscriptions checkout): `DsScaffold` with a `DsStepper` (or `DsProgressBar`) at the top, one `DsFormSection` per step (sender, receiver, parcel details, schedule), `DsTextField(readOnly: true, onTap: existingPicker)` for address/date/time/map pickers, choice cards as `DsCard.outlined` with `borderColor` for the selected option and a price `DsBadge`, and `DsStickyBar` with Back (`secondary`) + Continue/Book (`primary`). Width `DsLayout.contentMax`; on tablets, short fields two per row via `DsAdaptiveGrid(minItemWidth: 260)`. Load with `DsSkeletonForm`.

**F. Order / booking history and tracking timeline** (`order_screen`, `order_details_screen`, `my_cab_booking_screen`, `cab_order_details`, `parcel_my_booking` / `parcel_order_details`, `my_rental_booking_screen`, `rental_order_details_screen`, `my_booking_on_demand_screen`, `on_demand_order_details_screen`, dine-in bookings): lists use `DsScaffold.collapsing` + `DsSegmentedTabs` (Active / Completed / Cancelled) and `DsCard.outlined` rows with store/vehicle image, id `t.caption`, date, total `t.titleSm.tabular` and `DsStatusChip(status:)`; vary rows per service (food = store image, cab = route A→B with dots, parcel = package icon + tracking id, rental = vehicle image + dates, on-demand = provider avatar). Details: status hero (`DsCard.tinted(tone: DsTone.fromStatus(status))`), a `DsTimeline` of status history (`done/current/upcoming/error`), then items, addresses, driver, bill summary and actions (track, reorder, review, cancel, complaint, receipt PDF) in a `DsStickyBar`. Tablets: list/detail split. Load with `DsSkeletonList` / `DsSkeletonDetail`.

**G. Wallet / finance** (`wallet_screen`, `cashback_screen`, gift cards + redeem/history, refer-a-friend, saved payment methods, business account): the hero is a `DsCard.gradient(gradient: DsGradients.deep(context))` balance card with `DsAnimatedCounter` in `metricLg` and Top-up / Send actions; gift cards use `DsGradients.brand` cards with a code in `t.titleSm.tabular`; referral = code card + copy/share `DsIconButton`. Below, a `DsStatTile` row (credit / debit / cashback) and transactions grouped by date with `DsListTile` rows (success icon well for credit, danger for debit), amounts in `t.titleSm.tabular`. Top-up amount chips via `DsSegmentedTabs(scrollable: true)`.

**H. Profile / settings / menu** (`profile_screen`, `edit_profile_screen`, `change_language`, `change_password_screen`, address list, help & support, terms, subscriptions/plans): profile header card (`DsAvatar(ring: true)` with name, email/phone, membership `DsBadge`), then `DsTileGroup`s of `DsListTile(leadingIcon:, showChevron: true)` — account, services, app (dark mode switch as `trailing`, language), support; log out and delete account in a final group with `destructive: true` (keep the existing `CustomDialogBox` calls or pass `DsDialog` to the same `showDialog`). Address list: `DsCard.outlined` rows with type `DsBadge` (Home / Work) and a FAB "Add address". Tablets: two columns of groups.

**I. Auth / onboarding** (`login_screen`, `mobile_login_screen`, `otp_verification_screen`, `sign_up_screen`, `forgot_password_screen`, `on_boarding_screen`, `location_permission_screen`): phones use the logo (`assets/images/ic_logo.png`) in a `DsIconWell`/gradient blob on top, a `display` title, a focused form with `DsTextField`s (phone with the existing country-code picker as `prefix`), OTP as individual boxes styled with `DsInputDecoration`, a primary CTA, `DsDivider(label: 'OR'.tr)` and social logins as `DsButton.secondary(leading: SvgPicture.asset(...))`. Onboarding = full-bleed illustration pages + dots + `DsButton.primary`. On tablets (`l.isWide`), split: left `DsGradients.brand` panel with logo and tagline, right form card (max 440). Auth runs before a section is chosen, so `c.brand` is the app brand.

**J. Chat** (`chat_screens`, `provider_inbox_screen`, `worker_inbox_screen`): `DsAppBar` with `DsAvatar` + name + order id caption in the title; bubble list — yours use `c.brand` with `c.onBrand` text, theirs `c.surface` with a border, `radius lg` with one sharp corner, `caption` timestamps, image messages as `DsImage(radius: md)`; inbox rows as `DsListTile` with unread `DsBadge(style: solid)`. Composer: `DsStickyBar` with a pill `TextField` (`DsInputDecoration`), attach `DsIconButton` and a filled send `DsIconButton(semanticLabel: 'Send'.tr)`.

**K. Empty / status / result** (`order_successfully_placed`, maintenance mode, no zone / location off, payment success/failure, review submitted, empty cart/favourites/orders): center a `DsEmptyState` (or a Lottie/illustration with `DsFadeSlideIn`) with one clear action. Tone matches the status: success for placed/paid, warning for pending/maintenance, danger for failed/blocked; success pages may use a `DsGradients.tone(context, DsTone.success)` hero. Reviews (`*_review_screen`, rate product): star row with 48dp `DsIconButton`s, tags as `DsSegmentedTabs(scrollable)`, comment `DsTextField(maxLines: 4)`, `DsStickyBar` submit.

Mix the details within an archetype too, and remember the six services: the same archetype must still read as food vs e-commerce vs cab vs parcel vs rental vs on-demand through imagery, hero content and the section accent.
