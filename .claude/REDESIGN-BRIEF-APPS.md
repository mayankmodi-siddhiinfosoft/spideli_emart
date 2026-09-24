# Spideli app screen redesign — brief for every screen agent

App: the app folder named in your task (under /Users/mayankmodi/Documents/GitHub/spideli_emart1/; Flutter 3.47.4,
GetX). Work IN PLACE on the current branch. Do NOT create worktrees/branches, do NOT commit, do NOT run
`git checkout`/`git stash`/`git reset` (many other agents are editing other folders of the same working tree at
the same time).

## Goal (from the client)
Redesign every screen with a modern, professional, premium, enterprise-level UI/UX. Each screen gets a unique,
purpose-driven layout and visual hierarchy (don't repeat the same card/list arrangement screen after screen) while
following ONE design system. Better typography, spacing, colors, icons, buttons, cards, navigation, forms. Smooth
professional animations/transitions, shimmer skeletons for loading, animated progress. Responsive for phones,
tablets and iPad. Accessible. Keep the brand colors and logo.

## The design system (already built — use it)
Read `<app>/lib/themes/ds/DESIGN_SYSTEM.md` FIRST, then skim the component sources in `<app>/lib/themes/ds/`.
Import the app's `themes/ds/ds.dart`. Use `context.dsColors`, `context.dsText`, DsSpace/DsRadius/DsShadows, Ds*
components, DsShimmer skeletons / DsAsync for every async load, DsFadeSlideIn (+stagger) for entrances,
DsPressable for tappable cards, DsResponsive / DsAdaptiveGrid for tablet/iPad max-width and columns.
Never hard-code colors; support light and dark. Pick a screen archetype from the guide that fits the screen's
purpose. Do NOT edit files in lib/themes/ds/ — if something is missing, build a small private widget in your own
screen file (or a `widgets/` file inside your folder) and mention it in your report.

## HARD RULES — functionality must not change
- Change only presentation code (build methods, private widgets, styling, layout, animations).
- Do NOT change controllers, models, services, utils, FireStoreUtils/firebase helpers, constants, routes, or
  anything outside your assigned folders.
- Keep every controller call, every onTap/onPressed action, every validation, every Get.to/Get.back/Get.off
  (same destination, same arguments, same `result`), every Obx/GetBuilder/GetX binding (init:, tag:, global:,
  id:), every TextEditingController, FocusNode, form key, every conditional that shows/hides UI by role,
  permission, subscription/plan, status or platform. If a button existed, it still exists and does the same thing.
- Keep every user-visible string and its `.tr` (you may restyle; you may add short new labels with `.tr`).
- Keep keys used by tests/scrolling, keep ScrollControllers, pagination listeners and pull-to-refresh behaviour.
- Keep map widgets, markers, polylines, camera/controller calls and location streams exactly as they are.
- Don't change image/asset paths or add packages. Don't touch pubspec.yaml.
- Dart 3.13: no `var` on parameters; `import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;` if needed.
- Text must not clip at 1.3x text scale; min 48dp touch targets; Semantics labels on icon-only buttons.

## Verify before reporting
Run `cd <app> && flutter analyze --no-pub <each of your folders>` → 0 errors, 0 warnings in your files.
(Don't run the whole-app analyze and don't worry about errors in other folders — other agents are mid-edit.)
Then do a self-review diff (`git diff -- <your folders>`) specifically hunting for any lost onTap/controller
call/navigation/condition/string; fix anything lost.

## Report (short)
Per screen: file, archetype/layout chosen, notable animations/loading states. Plus any behaviour you were unsure
about and left exactly as it was, and any private helper widgets you created.

## LESSONS FROM THE STORE APP REDESIGN — reactivity (these caused crashes; check every screen)
GetX 4.7.3: an `Obx`/`GetX` rebuilds only for observables read SYNCHRONOUSLY inside its builder, and an `Obx`/`GetX`
whose builder reads NO observable THROWS "improper use of GetX" (red/grey box). Reads inside a child widget's own
`build()`, a `Builder`, `StatefulBuilder`, `LayoutBuilder`, `AnimatedBuilder` or any lazily-run builder are NOT
tracked by the parent observer. So when you move code into private widgets or builders:
- Never write `Obx(() => _MyWidget(...))` / `Obx(() => Builder(...))` unless the closure itself reads an observable.
- Never put a read behind a condition that can skip it (`a == true && rx.value == 1` — read rx first).
- If a child widget/builder reads controller observables, wrap that body in `DsObserve(builder: ...)` (the app's DS
  provides it: an observer that tolerates zero reads) or read the values in the tracked builder and pass them down.
- `DsAsync(builder:)` already observes its builder closure; child widgets inside it still need DsObserve.
- Screens using `GetBuilder` + `controller.update()` are not affected by the above, but keep their `id:`s.
- Provider (`ChangeNotifier`/`Consumer`/`context.watch`) screens: keep the same Consumer/watch scope.
