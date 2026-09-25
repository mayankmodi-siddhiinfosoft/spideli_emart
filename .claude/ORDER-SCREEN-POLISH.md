# Order / booking detail + list screens — alignment and typography pass

The client reviewed a live order screen and asked for better **alignment, font
style and font size**, and a redesign of the order screens in ALL apps. What
they were looking at (driver order details) showed:

- the order id rendered huge and wrapped over **three lines**, under a "Order"
  label, with a second "Order" word inside the value — duplicated and unreadable;
- the status chip floating beside that wrapped text, vertically misaligned;
- bill rows where the labels wrap ("CGST Tax on Delivery Fee") and the amounts
  do not line up in a column;
- the item row's price and struck-through original competing for weight.

## Rules for every order / booking / job screen you touch

**Order identity**
- One line. Never wrap an id. Show a short form (e.g. the last 8 characters, or
  `#` + short id) in a tabular/monospace style at label size, muted, with the
  full id available on tap-to-copy (keep any existing copy action; if the screen
  had none, a tap-to-copy with the existing "copied" toast is fine).
- Never print the word "Order" twice. One heading, one value.
- The status chip sits on the same row, aligned to the first line of the
  heading, and never wraps.

**Money rows (bill / fare / earnings)**
- One `Row` per line: label left, value right, both vertically centered.
- Labels: muted, one size smaller than the value, `maxLines: 2` with ellipsis.
- Values: **right aligned, tabular figures** so every amount lines up in a
  column; same width treatment for every row of the block.
- The total is separated by a divider, heavier weight, brand or text-primary
  colour — not a different font family or a much larger size.
- Zero rows stay only if the screen showed them before.

**Items**
- Name at body weight, quantity as a compact chip or `x2` at the end of the
  name row, price aligned right, original price struck through **smaller and
  muted** next to it, never the same size as the charged price.

**General**
- Use the app's design system tokens only: `context.dsText` styles,
  `DsSpace`/`DsRadius`/`DsShadows`, `context.dsColors`. No hard-coded colours,
  font sizes, or font families.
- One heading style for section headers on the screen; consistent card padding;
  consistent gaps (no ad-hoc 7/9/13 px).
- Long addresses and names: `maxLines` + ellipsis, never a ragged 3-line block
  pushing the layout around.
- Must not clip at 1.3x text scale; min 48dp touch targets; keep light/dark and
  phone/tablet behaviour.

## Hard rules (unchanged from the redesign work)
- **Presentation only.** Every controller call, action, condition, navigation
  target/arguments/result, validation, Obx/GetBuilder binding, `.tr` string and
  money calculation stays exactly as it is. Figures come from what the screen
  already computes — never recompute for display.
- GetX: an `Obx`/`GetX` builder must read an observable synchronously; use
  `DsObserve` for lazily-built children.
- No new packages. Do not edit anything under `lib/themes/ds/`.
- Verify `flutter analyze --no-pub <your folders>` → 0 errors, 0 warnings.
