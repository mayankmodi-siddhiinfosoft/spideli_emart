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
| `FinSection(title, actionLabel, onAction, children, divided, footnote, top, surface)` | A titled group in one surface; `surface: false` for children that are surfaces themselves (`FinMetrics`). The action link is a 48 dp button |
| `FinSurface(child, onTap)` | A bare surface |
| `FinRow(label, value, sub, valueColor, strong)` | A label / value line, value right-aligned and tabular |
| `FinListTile(icon, iconTone, title, subtitle, amount, amountColor, status, statusLabel, chevron, onTap)` | Rows of lists: transactions, goals, loans, policies… Below 300 dp (scaled with the text size) the amount and status go under the title instead of beside it |
| `FinMetrics(items: [FinMetric(label, value, sub)])` | 2-column key figures in one surface |
| `FinProgress(value, label, trailing, tone)` | A labelled progress bar |
| `FinTrack(steps, current, ended, endedLabel)` | Where a record is in its workflow |
| `FinActions(actions: [FinAction], onHero)` | Up to 4 per row primary actions (icon square + label) |
| `FinStatusChip(status, label, icon)` / `FinStatus.tone(status)` | The one status catalogue for every module |
| `FinNotice(message, title, tone, actionLabel, onAction)` | Disclosures, estimates, requirements, errors |
| `FinState.loading / error / empty` | Section states with the same footprint (layouts stay still) |
| `FinState.of(snapshot, gone, onRetry)` | The state of a one-record stream: loading, error with Retry, or "no longer available" for a missing document (never an endless skeleton); null when there is data |
| `FinConfig<T>(load, builder)` | Loads a module's settings once; on failure an error with Retry instead of "not available" |
| `FinMissing(items)` | "To continue: …" above a disabled button: why it is disabled |
| `finPickDate` / `finPickDateRange` | Date pickers in the navy, wherever they are opened from |
| `finConfirm(title, message, lines, total, confirmLabel, destructive)` | Confirmation sheet listing the figures before a sensitive action |
| `FinBarChart` | Grouped bars per period with a tap read-out; shows as many recent periods as fit (≥ 40 dp each), a wrapping legend, "No figures for this period yet." when empty, always left to right |
| `FinShareBar(parts, percent)` | Allocation / split bar: 8 hues with dark variants; the legend names each part with its amount (and share with `percent: true`) |
| `FinanceLineChart` (finance_widgets) | A value over time |
| `FinAmountField(label, controller, currency, currencies, min, max, helper)` (finance_widgets) | Amount entry: currency suffix, decimals per currency, inline min / max / format errors; the currency picker goes under the field on narrow screens |
| `FinPickerField` / `finPickOne` (finance_widgets) | A choice: a dropdown up to 8 options, a searchable sheet from 9 (banks, countries, billers, packages) |

Existing pieces kept and restyled by the accent:
- `DsButton.*`, with built-in `loading` and disabled states;
- `DsTextField`, `DsDropdown`, `DsSegmentedTabs`, `DsBottomSheet`, `DsInlineAlert`, `DsSkeleton*`;
- `FinancePaySheet`, which chooses the payment method and shows the result; one sheet at a time, a failed payment offers "Try again" with the same request key;
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
  - `FinSection`s grouping related fields (`DsTextField` / `DsDropdown` / `FinPickerField`); mandatory fields marked, optional ones labelled;
  - each field shows its own error once touched (not toasts); `FinMissing` above the action lists what is still needed;
  - `FinAmountField` for amounts (numeric keyboard, currency suffix, limits inline);
  - an estimate / summary section showing fees, commission, interest and obligations **before** the action, then `finConfirm` for money and destructive actions;
  - the action in the sticky bottom bar, disabled until valid, with its `loading` state while the call runs;
  - one request key per intent (`FinanceRequestKeys.of(intent)`), so a second tap or a retry after a timeout can never charge twice; released with `done` after success;
  - what the user typed stays when they come back from a sheet, a failure or a scroll;
  - money operations end in `FinancePaySheet`, where success shows only when the server confirms.
- **Sheets:** short contextual tasks (amount entry, confirmation, details). Workflows get screens.

### 4.1 The finance workflow (Finance dashboard)

Spideli Finance is a service of the service list (`FinanceSection`): the
admin's own section with `serviceTypeFlag: "finance-service"` when there is
one, else a built-in "Spideli Finance" bubble (navy, wallet icon) - always on
the circle and in "More". It is no longer in the Profile screen. It opens
`FinanceDashboardScreen`: five tabs in a bottom bar, each built on first open
with its own scroll position; Back on another tab returns to Home, Back on
Home leaves Finance.

| Tab | Screen | Content |
|---|---|---|
| Home | `FinanceHomeScreen` | wallet hero (Send, Pay bills, Save, Invest; Retry when the balance fails), needs your action, coming up, this month (money in / out vs the month before → Insights), your money, recent activity ("See all" → Wallet tab) |
| Wallet | `TransactionsScreen(asTab: true)` | wallets per currency (the dashboard currency first, as on Home), debounced search that looks a few pages back, type and date filters, "Load more", details with copy reference, statement |
| Services | `FinanceServicesTab` | the nine services, each with what it is for: Pay and send (money transfer, payment, virtual card), Save and invest (collective savings, tontine, investment), Borrow and protect (loan, online insurance), Get help (AI assistant) |
| Insights | `FinanceInsightsTab` | cash flow, last 30 days, AI assistant, markets, statement |
| Profile | `FinanceProfileTab` | identity header, document verification, groups, wallets, statement, help, other Spideli services |

"Needs your action" (`FinanceActionsSection`, all of them in
`FinanceActionsScreen`) comes from `FinanceActionsService`: tontine and
savings goal invitations, loans to vote on (not voted yet) or fund, the
user's loan agreement or overdue repayment, valid insurance quotes, claims
the insurer asked about, transfers and bill payments waiting for their
confirmation. Urgent first, then the soonest due; each opens the screen where
it is done. The rules are pure (`utils/finance_actions.dart`, tested); the
service shares one subscription per source and re-checks expiries every
minute. Hidden when nothing waits.

Diagram to screens: document verification → Profile; statistics → Insights
(and "Your money" on Home); groups → Profile › Groups (`FinanceGroupsScreen`);
multi-currency wallet → Wallet; Investment → `InvestmentsScreen` + "Funding
and markets"; AI assistant → `AiAssistantScreen` (coach, simulators).

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

Reads: the profile, the accounts and the summary are shared streams (`SharedLatest`): one Firestore listener each whatever the number of widgets, the latest value at once for a widget built later, closed when the last one leaves. `FinanceService.retry()` reopens them after an error (permission denied, offline at start). A source the user cannot read counts as nothing to show in "Needs your action", never as an error of the dashboard.

## 7. Accessibility, platforms

- Touch targets ≥ 48 dp (section links, chips, icon buttons).
- `MergeSemantics` on rows. The hero and charts carry readable semantic labels, and section titles are headers.
- Colour plus text plus icon for every status.
- Text scales: amounts use `FittedBox(scaleDown)` instead of clipping.
- Motion is limited to bar animations, which are disabled when the system asks to reduce motion.
- RTL: `AlignmentDirectional` / `EdgeInsetsDirectional` throughout; chevrons follow the reading direction.
- Small screens and large text: `test/finance_layout_test.dart` lays every component out at 320 × 640 dp with text at 1.0 and 1.3, right to left and dark, and fails on any overflow.
- Sensitive screens (card details) call `FinanceSecureScreen`: FLAG_SECURE on Android, a navy cover in the iOS app switcher (`AppDelegate.swift`).
- Platform conventions come from the DS: Material 3 on Android (system bars, back gesture), Cupertino-style navigation on iOS (safe areas, swipe back); sheets are DS sheets on both.
