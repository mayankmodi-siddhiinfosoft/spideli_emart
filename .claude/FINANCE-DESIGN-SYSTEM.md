# Spideli Finance — design system

The finance layer on top of the app design system (`customer/lib/themes/ds`). Code: `customer/lib/screen_ui/finance/fin_ds.dart`. Every Spideli Finance screen uses it, so the module reads as one institutional product whatever service section the user came from.

## 1. Identity

- **One accent: deep navy.** `FinColors.navy` `#0B2A4A` (light) / `FinColors.navyDark` `#8DB4FF` (dark). It's used for primary actions, selections, links and the balance panel. `FinScaffold` pins it with `DsAccentScope`, so DS buttons, chips, switches and pickers use it. The finance module never takes the orange or blue of the service section the user came from.
- **Neutral surfaces carry content.**
  - Page background: `FinColors.page` (`#F4F6F9`).
  - White surfaces: `FinSurface`, 1 px `border`, radius 12.
  - Hairline `divider` between rows.
  - No gradients, glows, decorative backgrounds or stacked shadows.
- **Semantic tones carry states only:** success, info, warning, danger and neutral, from `FinStatus`. Colour is never the only cue: status chips can carry an icon, and every status has a text label.
- **Typography:** the app's DS scale.
  - Amounts always use **tabular figures**, right-aligned in rows.
  - The hero amount is 32 px bold (`FinText.heroAmount`), and detail headline amounts are 24 px (`FinText.amount`).
  - Section titles are small uppercase overlines (`FinText.sectionTitle`).

## 2. Layout

- Page padding: `FinSpace.pagePadding` (16 px sides).
- `FinSpace.section` (24 px) between sections.
- Content is capped at `DsLayout.contentMax` on tablets.
- **One focal point per screen:** the `FinHero` on overview screens, the `FinHeader` on detail screens.
- **Group, don't stack:** related lines go in one `FinSection` surface, divided by hairlines, never in one card per line.
- Long workflows use `FinTrack`: a segmented bar plus the current and next step. The full vertical `DsTimeline` is reserved for short (≤ 5 step) histories where every step matters.

## 3. Components (`fin_ds.dart`)

| Component | Use |
|---|---|
| `FinScaffold(title, actions, body, bottomBar)` | Every finance screen: navy identity, page background, content width |
| `FinBody(children)` | The scrolling body with the standard padding |
| `FinHero(label, amount, caption, stats, footer)` | The focal amount (available balance, portfolio value, card balance) with up to 3 `FinHeroStat` and actions |
| `FinHeader(overline, title, subtitle, status, statusLabel, icon, below)` | The headline of a detail screen: what it is, the amount, the status |
| `FinSection(title, actionLabel, onAction, children, divided, footnote, top)` | A titled group in one surface |
| `FinSurface(child, onTap)` | A bare surface |
| `FinRow(label, value, sub, valueColor, strong)` | A label / value line, value right-aligned and tabular |
| `FinListTile(icon, iconTone, title, subtitle, amount, amountColor, status, statusLabel, chevron, onTap)` | Rows of lists: transactions, goals, loans, policies… |
| `FinMetrics(items: [FinMetric])` | 2-column key figures in one surface |
| `FinProgress(value, label, trailing, tone)` | A labelled progress bar |
| `FinTrack(steps, current, ended, endedLabel)` | Where a record is in its workflow |
| `FinActions(actions: [FinAction], onHero)` | Up to 4 per row primary actions (icon square + label) |
| `FinStatusChip(status, label, icon)` / `FinStatus.tone(status)` | The one status catalogue for every module |
| `FinNotice(message, title, tone, actionLabel, onAction)` | Disclosures, estimates, requirements, errors |
| `FinState.loading / error / empty` | Section states with the same footprint (layouts stay still) |
| `finConfirm(title, message, lines, total, confirmLabel, destructive)` | Confirmation sheet listing the figures before a sensitive action |
| `FinBarChart` | Grouped bars per period with a tap read-out |
| `FinShareBar` | Allocation / split bar with legend |
| `FinanceLineChart` (finance_widgets) | A value over time |

Existing pieces kept and restyled by the accent:
- `DsButton.*`, with built-in `loading` and disabled states;
- `DsTextField`, `DsDropdown`, `DsSegmentedTabs`, `DsBottomSheet`, `DsInlineAlert`, `DsSkeleton*`;
- `FinancePaySheet`, which chooses the payment method and shows the result;
- `FinanceKycGate`.

## 4. Screen patterns

- **Overview / list screens:**
  - `FinHero` when there's a balance;
  - then `DsSegmentedTabs` for sibling lists;
  - then a `FinSection(divided: true)` of `FinListTile`;
  - the primary action goes in a `DsStickyBar` bottom bar.
- **Detail screens:**
  - `FinHeader` (amount, status chip), then `FinTrack` for the workflow;
  - then `FinSection`s of `FinRow`s (terms, figures, dates, references);
  - then history lists;
  - destructive actions last, as ghost buttons behind `finConfirm`.
- **Forms:**
  - `FinSection`s grouping related fields (`DsTextField` / `DsDropdown`); mandatory fields marked;
  - numeric keyboards for amounts;
  - an estimate / summary section showing fees and obligations **before** the action;
  - the action in the sticky bottom bar, disabled until valid;
  - money operations end in `FinancePaySheet`, where success shows only when the server confirms.
- **Sheets:** short contextual tasks (amount entry, confirmation, details). Workflows get screens.

### 4.1 The finance workflow (home structure)

The finance home follows the client's workflow diagram: the user in the
centre, nine services around them. Tile names and module screen titles use
the diagram's names.

| Diagram | Home | Opens |
|---|---|---|
| User: document verification | My account › Document verification | `KycScreen` |
| User: statistics | My account › Statistics | `FinanceStatisticsScreen` (your money, cash flow, statement) |
| User: group (and chat) | My account › Groups | `FinanceGroupsScreen` → tontines, collective savings, loan groups (no member chat yet) |
| User: multi-currency wallet | Wallet hero + My account › Wallets | `TransactionsScreen` (one wallet per currency; no conversion yet) |
| Money transfer | Services › Pay and send | `TransfersScreen` |
| Payment (bills) | Services › Pay and send | `BillsScreen` |
| Virtual card | Services › Pay and send | `CardsScreen` |
| Collective savings | Services › Save and invest | `SavingsListScreen` (shared goals by invitation) |
| Tontine | Services › Save and invest | `TontineListScreen` |
| Investment (funds, funding, markets) | Services › Save and invest | `InvestmentsScreen` + "Funding and markets": `IntelligenceScreen(view: funding)`, `FinancingScreen`, `IntelligenceScreen(view: markets)` |
| Loan (credit scoring) | Services › Borrow, protect and get help | `LoansScreen` |
| Online insurance (buy, claims) | Services › Borrow, protect and get help | `InsuranceScreen` |
| AI assistant (coach, simulator) | Services › Borrow, protect and get help | `AiAssistantScreen` → `CoachScreen`, return simulator, insurance premium |

Not built yet (they need a server contract first): IPO tracking, stocks and
stock collections, group chat, wallet currency conversion, product payments,
a user-visible loan restriction.

## 5. Money, dates, references

- Amounts: `FinanceMoney.format(minor, currency)`, and `FinanceMoney.signed` for in/out. Both are left-to-right isolates, so they read correctly in Arabic.
- Money in shows in `finAmountColor` (success green); money out shows in the default text colour, never red. Red is for failures and overdue.
- Dates: `FinanceUi.date` (date and time) and `FinanceUi.day` (date). References: `ltrRef(...)`, which never breaks onto two lines.
- Estimates, projections and targets are always labelled as such (`FinNotice`). Actual values come only from the server.

## 6. States

Every async section shows:
- `FinState.loading` (skeleton), `FinState.error` (with retry where possible), `FinState.empty` (what to do next);
- the content.

Firestore's offline cache keeps the last data on screen when the connection drops. Actions report the server's refusal through `FinanceErrors`, and forms keep what the user typed.

## 7. Accessibility, platforms

- Touch targets ≥ 44 px.
- `MergeSemantics` on rows. The hero and charts carry readable semantic labels, and section titles are headers.
- Colour plus text plus icon for every status.
- Text scales: amounts use `FittedBox(scaleDown)` instead of clipping.
- Motion is limited to bar animations, which are disabled when the system asks to reduce motion.
- RTL: `AlignmentDirectional` / `EdgeInsetsDirectional` throughout; chevrons follow the reading direction.
- Platform conventions come from the DS: Material 3 on Android (system bars, back gesture), Cupertino-style navigation on iOS (safe areas, swipe back); sheets are DS sheets on both.
