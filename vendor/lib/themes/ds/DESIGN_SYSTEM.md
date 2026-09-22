# spideli Store – Design System (DS)

```dart
import 'package:vendor/themes/ds/ds.dart';   // everything: tokens, layout, motion, components
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
   or brand surfaces, and `Colors.transparent`. Never use `AppThemeData.primary600/50`
   (their names are inverted). The brand color comes from `c.brand`, which is
   read at runtime from Firestore.
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
`DsTone.fromStatus(order.status)` maps any status string in the app (order,
ads, payout, dine-in) to a tone.

### Typography: `final t = context.dsText;`
`displayLg 34`, `display 28`, `headline 22`, `title 18`, `titleSm 16`,
`bodyLg 16`, `body 14`, `bodyStrong 14/500`, `bodySecondary`, `bodySm 13`,
`label 14/600`, `labelSm 12/600`, `caption 12/500 muted`, `overline 11 caps`,
`metric 26/700 tabular`, `metricLg 36`, `link`.
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
DsFormSection(title: 'Store details'.tr, icon: Icons.storefront_outlined, children: [
  DsTextField(label: 'Store name'.tr, hint: '...'.tr, controller: c.nameController, requiredMark: true, validator: ...),
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
`DsBrandTheme` re-themes when the Firestore brand color loads.
Page transitions: `GetMaterialApp(customTransition: DsPageTransition(), transitionDuration: DsMotion.page)`.
Android gets a shared-axis slide and fade. iOS keeps the native slide with swipe-back.
Legacy widgets (`RoundedButtonFill`, `RoundedButtonBorder`, `TextFieldWidget`,
`CustomDialogBox`, EasyLoading) have the DS look with unchanged APIs. You may
keep them, but prefer DS components in redesigned screens.

---

## 5. Screen recipe
1. Keep the outer `Obx` / `GetX(init:)` / `GetBuilder` exactly as it is. Inside it: `final c = context.dsColors; final t = context.dsText; final l = context.dsLayout;`.
2. Replace `Scaffold` + `AppBar` with a `DsScaffold` variant that fits the archetype.
3. Wrap the loading branch with a skeleton (`DsAsync` or `isLoading ? DsSkeletonX() : ...`).
4. Build content from DS components and wrap list items in `DsFadeSlideIn(index: i)`.
5. Put primary actions in a `DsStickyBar` (forms, detail) or a FAB (lists).
6. Check light and dark, a phone and an iPad (768+), and text scale 1.3.
7. Run `flutter analyze --no-pub` and fix any errors or warnings.

---

## 6. Screen archetypes (pick one per screen and vary them)

**A. Dashboard / home**: use `DsScaffold.hero` (or `DsHeroHeader` in a tab). Put a greeting and store status in the hero, with 2–4 `DsStatTile(variant: onBrand)` or a `heroOverlap` quick-actions card. Below it, add `DsSectionHeader` sections, a `DsAdaptiveGrid` of KPI or shortcut tiles (2 columns on phone, 4 on tablet) and recent activity as `DsCard` rows. Load with `DsSkeletonDashboard`.

**B. List / feed** (orders, products, coupons, drivers, employees): use `DsScaffold.collapsing` with a pinned filter row (`SliverPersistentHeader` or `SliverToBoxAdapter` holding `DsSearchBar` and `DsSegmentedTabs(scrollable)`). Show `SliverList` rows as `DsCard.outlined` with `DsStatusChip`, animated with `DsFadeSlideIn(index:)`. Add pull-to-refresh with `onRefresh` if the controller already exposes a loader, and use a FAB for "Add". On tablets, switch to a 2-column grid (`DsLayout.gridDelegate`) or a list/detail split. Use `DsEmptyState` when there are no items and `DsSkeletonList` while loading.

**C. Detail** (order, product, ad, plan): use a hero media area (`DsImage` with a `heroTag`, or a gradient) under a transparent `DsAppBar`. Add a title block with price or status, then info sections in `DsCard` with `DsListTile` rows and a `DsTimeline` for status history. Put the actions in a `DsStickyBar`, for example `Row[Expanded(DsButton.dangerTonal('Reject')), Expanded(DsButton.primary('Accept'))]`. On tablets, show media on the left and details on the right. Load with `DsSkeletonDetail`.

**D. Form / wizard** (add product, restaurant, offer, driver, subscription plan): use `DsScaffold` with a `DsStepper` or `DsProgressBar` at the top when the form is long, a sequence of `DsFormSection` cards, and fields made from `DsTextField`, `DsDropdown` and read-only pickers. Put the submit button in a `DsStickyBar` as `DsButton.primary(expand, loading)`. Cap the width at `DsLayout.contentMax`, and on tablets place short fields two per row with `DsAdaptiveGrid(minItemWidth: 260)`. Load with `DsSkeletonForm`.

**E. Settings / menu / profile**: use a profile header card (`DsAvatar(ring)` with name, email and `DsBadge` status) followed by `DsTileGroup` groups of `DsListTile(leadingIcon, showChevron)`. Put destructive rows (logout, delete) in a final group with `destructive: true`, and use switches as the `trailing` of a tile. On tablets, use two columns of groups.

**F. Auth** (login, signup, OTP, forgot password): on phones, use a brand mark on top (logo in `DsIconWell` or a gradient blob), a large `display` title, a focused form with `DsTextField`s, a primary CTA, `DsDivider(label: 'OR')` and social buttons as `DsButton.secondary(leading: SvgPicture)`. On tablets (`l.isWide`), split the screen: the left half is a `DsGradients.brand` panel with the logo, tagline and illustration, and the right half is the form card (max 440).

**G. Wallet / finance** (wallet, withdraw, payout methods, earnings): the hero is a `DsCard.gradient(gradient: DsGradients.deep(context))` balance card with a `DsAnimatedCounter` using `metricLg`, plus Withdraw and Top-up actions. Add a summary row of `DsStatTile`s (credit and debit) or `DsProgressRing`/`DsProgressBar` visuals as a chart-like summary. Below that, show transactions grouped by date with `DsListTile` rows (tone icon wells: success for credit, danger for debit) and amounts as `t.titleSm.tabular`.

**H. Chat**: use a `DsAppBar` with a `DsAvatar` and status in `titleWidget`. Show a bubble list: yours use `c.brand` with `onBrand` text, theirs use `c.surface` with a border, each with `radius lg` and one sharp corner and a `caption` timestamp. The composer is a `DsStickyBar` containing a pill `TextField` (use `DsInputDecoration`) and a filled send `DsIconButton`.

**I. Empty / status / maintenance / success**: center a `DsEmptyState` (or a custom illustration with `DsFadeSlideIn`) with one clear action. Use a tone that matches the status: success for done, warning for pending verification, danger for blocked.

Mix the details within an archetype too. For example, give the orders list tinted status cards, give the product list image-led grid cards, and give the drivers list avatar rows. Screens that share an archetype should still differ in their hero content and their main visual.
