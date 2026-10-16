# Spideli Finance per region: what the customer app and the rules do

**For:** the admin panel team. **From:** the customer app, 16 Oct 2026.
**Answers:** `APP-SPEC-FINANCE-REGION-SETTINGS.md` (15 Oct), `APP-DEV-BRIEF-16-10-2026-FINANCE-ADMIN.md` (16 Oct) and Phases A to D of the admin panel.

## 1. The customer's Finance region

The Finance region is the region the app already resolves for the customer (`RegionService`), on its usual ladder:
1. an explicit region choice;
2. else the published delivery zone around the customer's location;
3. else their country;
4. else `settings/RegionDefaults`.

It is **never widened to the rest of the country**, as for every amount of money in the app.

- Only a published region with `regions/{id}.financeEnabled == true` offers Finance.
- When a zone serves several Finance regions (a country region and a city region), the app uses the most specific one: the region the fewest zones serve. The customer can switch on **Finance › Profile › Region**, and the choice is remembered.
- Where no region offers Finance, the Finance dashboard says "Spideli Finance is not available in your region yet". Where the region cannot be told, it asks the customer to choose a delivery location. The service list itself is unchanged.
- Before the first request of a session, the region is added to `users/{uid}.regionIds` with `arrayUnion`, because the rules check it (spec 3.1).

Code: `customer/lib/service/finance_region_service.dart` (`FinanceRegion`) and `customer/lib/utils/finance_region_rules.dart` (pure, unit tested).

## 2. Settings

- Every module reads `finance_settings/{regionId}_{module}`. **Nothing reads `platform_settings` any more**, and there is no fallback to it.
- A missing document, or one naming another region or module, means "… is not available yet", exactly as before.
- **A new request** uses the customer's region.
- **A record already made** keeps the settings of its own `regionId`, whoever acts on it. This covers a goal's invitations and schedule, a tontine's start, a loan's vote and agreement, a card's top-up, withdrawal, limits and renewal, a KYC application's documents, and a financing application's edits and documents. A record without `regionId` uses the customer's region.
- **Live.** While the Finance dashboard is open, the app listens to `regions` and to the settings documents it has read. When the admin switches Finance on or off, or saves a module, the open screens reload with the new values.
- **Payment methods.** The pay sheet offers only the gateways that serve the Finance region (their "Available in Regions").
- **Catalogs.** Investment funds and insurance products are listed only in the region's `currencies`.

## 3. `regionId` on what the customer creates

The app adds `regionId` when it creates any of these:
- `wallet_operations`, including a gateway deposit that pays another request (it carries that request's region);
- `money_transfers`, `utility_payment_requests`;
- `virtual_cards`, `card_funding_requests` (the card's own region);
- `savings_goals`, `tontines`, `loan_applications`;
- `investment_subscriptions`, `insurance_quotes`;
- `financing_applications`, `kyc_applications`.

It also adds it to:
- `financing_projects`, whose sectors and stages are the region's settings;
- **every `ledger_transactions` posting** the customer creates (spec 3.5): the region of the request it pays, or of the goal, tontine or loan it moves money in or out of.

Accounts (`financial_accounts`) are unchanged, as spec 5 requires.

## 4. Security rules (`firestore.rules.draft`)

- `fRegionSettings(regionId, module)` reads `finance_settings/{regionId}_{module}` in place of every `platform_settings` read.
- Each create listed in section 3 must name a `regionId` that is one of the caller's `users.regionIds` and whose region has `financeEnabled == true` (`fFinanceRegion`). Its currency must be one of that document's `currencies`.
- A gateway deposit that pays a request needs only a well-formed `regionId`.
- An update, or a record under another (a contribution, a funding), reads the settings of the record's own `regionId`.
- A posting may carry `regionId`. Postings without one, like the panel's, are still accepted.
- `finance_settings` is readable by signed-in users. `platform_settings` stays readable for older app versions.
- Read budget: `users/{uid}` is already read for restrictions, so a request adds only the `regions` document.
- **Tested on the emulator: 85/85 pass.** That is the 79 earlier tests, plus 6 new ones in `finance/rules-test/test/region.test.js`:
  - no region;
  - a region without Finance;
  - another user's region;
  - a currency of another region;
  - Finance switched off;
  - settings taken from the region, never from `platform_settings`;
  - a record keeping its own region.

## 5. The rest of the admin's notes, checked against the app

| Item | In the app |
|---|---|
| `financeNotificationPrefs` (brief 2.2) | Already written in exactly that shape, with booleans only. Defaults are push on for everything, SMS and e-mail for `payments` only. |
| Opening the right screen from a panel push (brief 2.3) | **Added.** A push tap, and a tap on a Notification Center row (`data`), open the record of each type family. Without an id, the service's list opens. (`lib/utils/finance_push_tap.dart`, `lib/screen_ui/finance/finance_push_opener.dart`) |
| Restrictions `{status, scopes, reason, since, by}`, removed when lifted (brief 3) | Already read. All seven scopes apply (`all`, `wallet`, `transfers`, `payments`, `savings`, `tontines`, `loans`). |
| Payouts end `reversed` (money back) or `failed` (no money moved) (brief 3) | Already shown that way: "Refunded", with the money back in the wallet. |
| KYC document `note` (Phase B) | **Added:** shown under a refused document. |
| Savings withdrawal `rejectionReason` (Phase C) | **Added:** shown as "Refused: …"; the member's own `reason` stays. |
| Cards without `terms` (brief 1) | The parser already refuses them, so the Virtual card entry says "Virtual cards are not available yet." |
| Bank reconciliation (Phase D) | Panel only; nothing in the app. |

## 6. Answers to your questions

**Spec 7.1 (is the selected region the right source?)** Yes, as section 1 describes. The app's region choice comes first; without one, the customer's location decides.

**Spec 7.2 / brief 4.1 (`regionId` on postings? When?)** Yes, on every customer posting (section 3), in this version of the app. The rules must be deployed with it.

**Brief 4.2 (demo records).** Please remove them from live. They have no `regionId`, so a customer update to them is refused under the new rules.

**Brief 4.3 (`financeNotificationPrefs` shape).** Yes, exactly the shape of 2.2.

## 7. Before go-live

1. Deploy `firestore.rules.draft` together with this app version. The previous rules refuse the new `regionId` field, and the new rules refuse a request without one, so older app versions can no longer make Finance requests.
2. Keep `platform_settings/*` until older app versions are gone. These rules and this app do not read it.
3. Records made before this version have no `regionId`: only the `demo: true` records on live.

Local QA: `finance/qa-env/seed.py` now seeds the region `qa_douala` with Finance on, its 12 `finance_settings` documents, the zone's `regionIds` and the customers' `regionIds`.
