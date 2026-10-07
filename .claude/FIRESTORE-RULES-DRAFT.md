# Firestore security rules: draft, inventory and test plan

**Status (3 Oct 2026, updated 7 Oct 2026):** `firestore.rules.draft` (repo
root) compiles. It is **not deployed**, and nothing in this repo can deploy it:
`firebase.json` has no `firestore` section on purpose. It must be **merged with
the rules that are live today** before anyone publishes it (section 5).

**7 Oct 2026 changes:** driver-dispatch guards on `vendor_orders`, `rides`,
`parcel_orders` and `rental_orders` (section 1.4,
`.claude/DRIVER-DISPATCH-CONTRACT.md`); the server-owned parcel SMS fields
(`.claude/PARCEL-SMS-CONTRACT.md`); `parcel_sms_outbox` closed to clients (the
outbox is retired) and `sms_log` server only; `regionPricing` allowed on the
company's own carrier (`.claude/COMPANY-CARRIER-LINK.md`). The 3 Oct emulator
suite (`functions/rules-test`, 39 cases) went with the `functions/` folder,
which its owner removed from the repository; the 7 Oct rules were checked
against the local emulator with the cases of section 6.1.

Files:

| File | What |
|---|---|
| `firestore.rules.draft` | the draft rules |
| `.claude/SERVER-PUSH-CONTRACT.md` | why `push_rate_limits` exists and why `settings` must be admin-only |
| `.claude/POD-OTP-CONTRACT.md` | the delivery code that `order_pod` holds |
| `.claude/DRIVER-DISPATCH-CONTRACT.md` | the accept / reject / timeout writes the dispatch guards allow |
| `.claude/PARCEL-SMS-CONTRACT.md` | the parcel SMS fields and who owns them |
| `.claude/COMPANY-CARRIER-LINK.md` | `users.carrierId` and the company's carrier edits |

---

## 1. What the draft enforces

### 1.1 `users/{uid}` (customers, drivers, store owners and employees, providers)

Updates are checked by **which keys the write changes**
(`request.resource.data.diff(resource.data).affectedKeys()`), so the apps'
whole-profile write-backs pass as long as the guarded values are unchanged.
"Same" compares normalised: absent, `null`, `''` and `false` are equal, because
the apps' `fromJson` defaults write them back that way.

| Field | The account itself | Someone else | Brand-new account (self sign-up) |
|---|---|---|---|
| `role` | never changes it | never (store manager / fleet owner neither) | `''`, `customer`, `user`, `driver`, `vendor`, `provider` only. Never `admin` / `employee` |
| `active` | may drop, never raise (legacy provider docs with only `isActive: true` may write `active: true`) | store owner on its own drivers / employees; fleet owner on its drivers; nobody else | `true` only if the app's auto-approve setting is on (`DriverNearBy.auto_approve_driver`, `vendor.auto_approve_vendor`, `provider.auto_approve_provider`; customers always) |
| `isDocumentVerify`, `isAutoVerify` | may drop, never raise | store owner / fleet owner may set `isDocumentVerify` on their own staff; `isAutoVerify` never raised by anyone | `true` only if that verification is switched off in `document_verification_settings` |
| `isOwner` | never raised | never raised | `true` only with role `driver` (company sign-up) |
| `ownerId`, `carrierId`, `employeePermissionId` | never changed | `employeePermissionId` by the store owner; `ownerId` / `carrierId` never (the admin links a company to its carrier, COMPANY-CARRIER-LINK.md) | must be empty |
| `vendorID` | may point at a store it **authors** (`vendors/{id}.author == uid`) or be cleared | never | `''` or a store it authors |
| `subscriptionPlanId`, `subscriptionExpiryDate`, `subscription_plan` | only to an existing, enabled plan of the right kind (`planFor == 'customer'` for customers, anything else for vendor / provider) with an expiry at most one plan period (+1 day) after now, or after the current expiry when renewing early; never-expiring plans (`expiryDay "-1"`) with a null expiry. Customers: the snapshot's `features` / `expiryDay` must equal the plan's | never | no plan |
| `businessProfile` | unchanged, cleared, or (re)submitted as `status: 'pending'` without any review field | never | null or pending |
| `accountType` | free (grants nothing without an approved `businessProfile`) | never | free |
| `wallet_amount` | **any number (KNOWN GAP)**, see section 4 | only accounts that pay others: role `driver`, `vendor`, `employee`, `provider`, or a worker | `0` or absent |
| `email`, `phoneNumber`, `countryCode`, `fcmToken`, `userBankDetails`, `savedPaymentMethods` | free | never, except store owner / fleet owner on their own staff | free |
| everything else (`location`, `rotation`, `isActive`, `inProgressOrderID`, `orderRequestData`, names, photo, `shippingAddress`, `reviewsCount` / `reviewsSum`, `sectionIds`, `zoneId`, `zoneIds`, `companyName`, `companyAddress`, ...) | free | free (order assignment, ratings; see section 4 item 12) | free |

- Create by someone else: a store owner creates `driver` / `employee` accounts
  for a store it manages, a verified active fleet owner creates `driver`
  accounts with `ownerId == uid`; neither may create verified-by-admin
  (`isAutoVerify`), owner, planned, business or funded accounts.
- Delete: the account itself, a fleet owner its driver, an admin.
- Read: any signed-in account (TODO, section 4).

### 1.2 `providers_workers/{uid}` (the worker app's own profile)

| Field | The worker itself | Its provider (`providerId == uid`, role `provider`) | Anyone else (customer rating) |
|---|---|---|---|
| `providerId`, `role` | never changed | never changed | never changed |
| `active`, `isActive` | may drop, never raise (legacy docs with only one of them pass) | free | never changed |
| `salary` | never changed | free | never changed |
| `isDocumentVerify`, `isAutoVerify` | never raised | never raised | never changed |
| `wallet_amount` | any number (KNOWN GAP) | any number | paying accounts only |
| `fcmToken`, `email`, `phoneNumber` | free | free | never changed |
| everything else (`online`, location, `g`, profile, reviews) | free | free | free |

Create: a provider for its own worker (`providerId == uid`, never verified,
no money), or an admin. Delete: the worker, its provider, an admin.

### 1.3 Other collections

| Path | Rule |
|---|---|
| `settings/*` | public read (splash and sign-up read before login), **admin-only write**. No app writes settings (checked). |
| `push_rate_limits/*` | no client access at all (server only). |
| `order_pod/{orderId}` | `get`: the order's customer, its driver, its store (owner or employee), an admin; a missing document reads as missing for anyone signed in (listeners and transactions read it first). `list`: admin. create / update: the order's driver or store (`vendor_orders/{id}.driverID` / `vendorID`), the generating driver after a release, an admin. Delete: admin. |
| `vendor_orders/{id}` | open to signed-in accounts (TODO), **except** `pod.status` may become `verified` only in the same write that marks `order_pod/{id}` verified (both apps' verification transactions do that), and the dispatch guards of 1.4. |
| `rides/{id}`, `rental_orders/{id}` | read / create / delete signed-in (TODO); update open except the dispatch guards of 1.4. |
| `parcel_orders/{id}` | read / delete signed-in (TODO); create: `smsSent` absent, `smsOptOut` absent or `false`, `sendReceiverSms` bool, `smsCharge` number >= 0; update: the dispatch guards of 1.4, nobody but the admin changes `smsSent` / `smsOptOut`, and `sendReceiverSms`, `smsCharge`, `receiverName`, `receiverPhone`, `receiverCountryCode` change only by the order's author while it is `Quote Requested` (the quote payment). |
| `wallet/{rowId}` | rows created with their own `id`; customers read / list only their own rows (`where('user_id', '==', uid)`); paying accounts read all and may re-set a row in a retry (same `user_id`); delete admin only. |
| `parcel_sms_outbox/{id}`, `sms_log/{id}` | **no client access** (server only; the admin through the wildcard). The outbox is retired (PARCEL-SMS-OUTBOX.md): no app writes it since 7 Oct. |
| `subscription_plans/*` | public read, admin write. (`spideli_provider` `FireStoreUtils.setSubscriptionPlan` writes here but is never called.) |
| `subscription_history/*` | create the buyer's own row; read signed-in (TODO). |
| `vendors/{id}` | public read; create with `author == uid`; update keeps `author`; delete by the author. Plan / commission / wallet fields TODO. |
| `delivery_carriers/{id}` | read signed-in; the linked company account (`users/{me}.carrierId`, or the fallback owner fields) may edit only its commercial fields and `regionPricing`, and in `regionPricing` only the entries of regions in the carrier's `regionIds`; create / delete admin. |
| platform configuration (`sections`, `zone`, `regions`, `currencies`, `on_boarding`, `banner_items`, `tax`, vehicle / rental / parcel catalogues, `gift_cards`, `cashback`, coupons, `documents`, ...) | public read, admin write. `admin_products`, `dynamic_notification`, `email_templates`: signed-in read. |
| everything listed under "TODO" in the file | signed-in read and write, as today. |
| any other path | **admin only** (the single wildcard). |

`isAdmin()` = Firebase ID token custom claim `admin: true`, or
`users/{uid}.role == 'admin'`. Clients can never write either.

### 1.4 Driver dispatch guards (`vendor_orders`, `rides`, `parcel_orders`, `rental_orders`)

Evaluated only when a write changes `status`, `driverId`, `driverID` or
`rejectedByDrivers` (an ordinary write reads nothing extra); the admin is
checked last and passes everything. Values are compared normalised (absent,
`null` and `''` are all "nobody"). The dispatch Cloud Functions use the Admin
SDK and are not affected.

| Write | Allowed for |
|---|---|
| `status: "Driver Pending"` | nobody (admin only). No app dispatches (D1) |
| `status: "Driver Accepted"` | the caller named in both `driverId` and `driverID`, on an order that named the caller (offer or hand assignment), or that named nobody, was not passed on by the caller, and is `Driver Pending` (all four), `Order Placed` (rides, parcels, rentals) or `Order Accepted` (rides). Never from `Driver Rejected`, `Order Completed`, `Order Cancelled`, `Order Rejected` |
| `status: "Driver Rejected"` | the caller added to `rejectedByDrivers` and both driver fields null, from `Driver Pending`, `Order Placed`, `Order Accepted` or `Driver Accepted` naming the caller (reject, timeout, hand back), or from an unnamed legacy request |
| `rejectedByDrivers` | only grows, and only by the caller's own uid (a pass on an open order writes just this) |
| `driverId` / `driverID` | unchanged (normalised); or the named driver setting them to itself or null; or the caller taking an unnamed order (`Driver Accepted`); or the order's author (`authorID`) clearing them while cancelling (`Order Cancelled` / `Order Rejected`) from `Order Placed`, `Driver Pending`, `Driver Rejected`, `Quote Requested`; or, on `vendor_orders` only, the store's owner / employee naming or clearing **its own** delivery man (`users/{id}.vendorID == the order's vendorID`) |

Store app writes on `vendor_orders` are field updates in transactions (each
re-reads the order): accept `{status: 'Order Accepted', estimatedTimeToPrepare}`
only from `Order Placed`; self delivery `{status: 'In Transit', driverID,
driverId, driver, estimatedTimeToPrepare}` (its own delivery man); courier
`{status: 'Order Shipped', courierCompanyName, courierTrackingId}` only from
`Order Placed`; complete `{status: 'Order Completed'}` while the order is live;
cancel / reject `{status, cancelReason, cancelReasonCode, cancelledBy,
cancelledByName, cancelAction, cancelledAt}` only while the status is unchanged.
The store never writes `rejectedByDrivers`, `driverRejections` or `pod`.

Customer app writes on `rides` / `rental_orders` after creation: `paymentMethod`,
`paymentStatus`, `regionId`, a cancel (status, the reason fields, and the null
driver fields before acceptance), and the rental price-proposal fields
(`priceProposal`, `subTotal`, `listedPrice`). Never `rejectedByDrivers` or a
driver's id.

---

## 2. What each app writes on its own profile (checked, so no flow breaks)

| App | Own-document writes | Guarded keys it touches, and why it passes |
|---|---|---|
| customer | sign-up stub `{wallet_amount: 0}` then `updateUser` (`setKnownFields`, never `wallet_amount`); `fcmToken`; `savedPaymentMethods`; `accountType` + pending `businessProfile` (`business_account.dart`); plan purchase batch (`customer_plan_service.dart`); wallet debits / credits in transactions; its own `inProgressOrderID` (`arrayRemove` of an ended ride); delete | role `customer` and `active: true` at sign-up (auto-approved); plan matches the plan document; wallet is the known gap |
| driver | `updateUser` (merge set of the model minus `wallet_amount`; after sign-up also minus `fcmToken`, `isActive`, `isDocumentVerify`, `orderRequestData`, `inProgressOrderID`, `ordercabRequestData`, `location`, `rotation`), location / rotation `update`, `isActive` toggle, `fcmToken`, section change, `_openWallet`, `orderRequestData` / `inProgressOrderID` arrayUnion / arrayRemove (accept, reject, housekeeping), company `zoneIds` / `companyAddress`, delete | `active` / `isDocumentVerify` / `isAutoVerify` / `isOwner` at sign-up follow the settings; write-backs carry unchanged values; `carrierId` is written back unchanged |
| store | `updateUser` (`setKnownFields`, no wallet, no plan once it has a store; `isDocumentVerify` / `isAutoVerify` only on a new document), `vendorID` switch to an owned store (`StoreService.selectStore`), `regionId`, `fcmToken`, plan before the first store, delete | `vendorID` only to an authored store; plan check (`planFor != 'customer'`) |
| provider | `updateCurrentUser` (`setKnownFields(user.toJson())`, includes `wallet_amount`, `active`, plan fields, `adminCommission`, `subscriptionTotalOrders`), `writeUserFields`, `fcmToken`, delete | `active` from `auto_approve_provider`; legacy `isActive` case allowed; plan check |
| worker | `providers_workers/{uid}`: `updateCurrentUser` (whole `User.toJson()`), `fcmToken`; `users/{providerId}.wallet_amount` increments | worker self rules (1.2); provider wallet credit allowed because a worker is a paying account |

Cross-user writes that stay allowed: ratings (`reviewsCount` / `reviewsSum`),
order assignment lists (`inProgressOrderID`, `orderRequestData`,
`ordercabRequestData`; since 7 Oct only the store freeing / assigning its own
delivery men and the admin write another account's lists: the dispatch
functions use the Admin SDK), wallet credits by paying apps, a store managing
its delivery men / employees, a fleet owner managing its drivers.

---

## 3. Inventory: collections each app uses

From `grep -E 'collection(Group)?\('` over each app's `lib/` (constants resolved;
`setKnownFields` counted as a write). R = get / list / snapshots, W = set /
update / add, D = delete, t = a reference built there and used in a
transaction, batch or helper (read and / or write). `thread` subcollections
live under the chat collections. No app uses `collectionGroup`. Web panels and
the website are **not** in this table (check them before merging, section 5).

| Collection | customer | driver | store | provider | worker | Draft rule |
|---|---|---|---|---|---|---|
| `admin_products` |  |  | R |  |  | signed-in read, admin write |
| `advertisements` | R |  | RWD |  |  | TODO open |
| `banner_items` | R |  |  |  |  | config |
| `booked_table` | RW |  | RW |  |  | TODO open |
| `brands` | R |  | R |  |  | TODO open |
| `car_make`, `car_model` |  | R |  |  |  | config |
| `cashback` | R |  |  |  |  | config |
| `cashback_redeem` | RW |  | RD |  |  | TODO open |
| `chat` (+ `thread`) | t | t | t | RWDt | RWDt | TODO open |
| `chat_admin` |  |  | Wt |  |  | TODO open |
| `chat_driver` | Wt | Wt |  | t |  | TODO open |
| `chat_provider`, `chat_worker` | Wt |  |  |  |  | TODO open |
| `chat_restaurant` |  | t |  |  |  | TODO open |
| `chat_store` | Wt |  | Wt | t |  | TODO open |
| `complaints` | Rt |  |  |  |  | TODO open |
| `coupons` | R |  | RWD |  |  | TODO open |
| `currencies` | R | R | R | R | R | config |
| `delivery_carriers` | R | RW |  |  |  | linked company: commercial fields + `regionPricing` |
| `documents` |  | R | R | R | R | config |
| `documents_verify` |  | RW | RW | Rt | t | TODO open (see 4) |
| `driver_payouts` |  | RW |  |  |  | TODO open |
| `dynamic_notification` | R | R | R | R | R | signed-in read, admin write |
| `email_templates` | R | R | R | R |  | signed-in read, admin write |
| `favorite_item` | RWt |  | RD |  |  | TODO open |
| `favorite_provider` |  |  |  | RD |  | TODO open |
| `favorite_service` | RWD |  |  | RD |  | TODO open |
| `favorite_vendor` | RWD |  |  |  |  | TODO open |
| `gift_cards` | R |  |  |  |  | config |
| `gift_purchases` | RW |  |  |  |  | TODO open |
| `items_review` | RWt | RWt | RD | R | R | TODO open |
| `on_boarding` | R | R | R | R | R | config |
| `order_pod` | R | t | Rt |  |  | 1.3 |
| `parcel_categories` | R | R |  |  |  | config |
| `parcel_coupons`, `parcel_weight` | R |  |  |  |  | config |
| `parcel_orders` | RWt | RWt |  |  |  | 1.3 (SMS fields) + 1.4 |
| `parcel_sms_outbox` |  |  |  |  |  | server only (retired; no app since 7 Oct) |
| `payouts` |  |  | RW | RW |  | TODO open |
| `pickup_points` | R | R |  |  |  | config |
| `popular_destinations`, `promos` | R |  |  |  |  | config |
| `provider_categories` | R |  |  | R |  | config |
| `provider_orders` | Rt |  |  | RWt | RWt | TODO open |
| `providers_coupons` | R |  |  | RWDt |  | TODO open |
| `providers_services` | RWt |  |  | RWDt |  | TODO open |
| `providers_workers` | RW |  |  | RWD | RWDt | 1.2 |
| `referral` | RW | R | RW | R | R | TODO open |
| `regions` | R | R | R | R | R | config |
| `rental_coupons`, `rental_packages` | R |  |  |  |  | config |
| `rental_orders` | RWt | RWt |  |  |  | 1.4 |
| `rental_vehicle_type`, `vehicle_type` | R | R |  |  |  | config |
| `review_attributes` | R |  | R |  |  | TODO open |
| `rides` | RWt | RWt |  |  |  | 1.4 |
| `sections` | R | R | R | R | R | config |
| `service_groups` | R |  |  |  |  | config |
| `settings` | R | R | R | Rt | Rt | public read, admin write |
| `SOS` | Rt |  |  |  |  | TODO open |
| `story` | R |  | RWD |  |  | TODO open |
| `subscription_history` | Rt |  | RW | RW |  | own row create |
| `subscription_plans` | R |  | R | RW (dead code) |  | public read, admin write |
| `tax` | R | R | R |  |  | config |
| `users` | RWDt | RWDt | RWDt | RWDt | RW | 1.1 |
| `vendor_attributes` | R |  | R |  |  | TODO open |
| `vendor_categories` | R | R | R |  |  | TODO open |
| `vendor_employee_roles` |  |  | RWDt |  |  | TODO open |
| `vendor_orders` | RW | RWt | RWt |  |  | open + POD guard + 1.4 |
| `vendor_products` | RW | R | RWD |  |  | TODO open |
| `vendor_subscription_payments`, `vendor_subscriptions` | Rt |  | R |  |  | TODO open |
| `vendor_subscription_plans` | R |  | RWD |  |  | TODO open |
| `vendors` | RWt | Rt | RWDt |  |  | 1.3 |
| `wallet` | RWt | RWt | RWt | RW | RW | 1.3 |
| `withdraw_method` |  | RW | RW | RW |  | TODO open |
| `zone` | R | R | R | R |  | config |

Server only: `push_rate_limits` (sendPush), `parcel_sms_outbox`, `sms_log`
(the parcel SMS trigger). Panels only (not used by any app):
`order_transactions` (kept open to signed-in, in case the store panel reads it).

---

## 4. Known gaps and TODO markers (in the file as `TODO` / `KNOWN GAP`)

1. **`wallet_amount` on the account's own document accepts any number.**
   Top-ups, refunds, gift cards, earnings and wallet payments all move the
   account's own balance from the phone today. Once credits run server-side,
   allow only decreases from the account itself (the replacement line is in the
   file).
2. **Any signed-in account reads any `users` / `providers_workers` profile**
   (phone, email, bank details, FCM token). The apps need other users' names,
   photos, location and tokens; narrowing needs a public-profile split.
3. **`order_pod` (POD limitation):** the driver app (and the store app for
   self-delivery) generates and verifies the code on the phone, so the code is
   readable by the order's driver and store, not only its customer, and a
   modified driver app could complete without asking. POD-OTP-CONTRACT.md's
   "customer may read, driver may not" needs code generation and verification
   in a Cloud Function; then reduce the rule to customer read and no client
   writes.
4. **`documents_verify`:** an actor could write `status: 'approved'` on its own
   uploaded document. The worker app's `canReceiveJobs` and the provider's
   document screen derive "approved" from those statuses. Rules cannot check
   every element of the `documents` list; use a map keyed by document id, or
   approve server-side. The account flags (`isDocumentVerify`) are protected.
5. `subscriptionTotalOrders` (decremented by the provider / store apps, string
   `'-1'` = unlimited) and `adminCommission` (copied by the provider app from its
   section) are not guarded on `users`.
6. `vendors` plan / commission / wallet fields are as open as before (the
   customer app writes the whole vendor document on a rating; the driver app
   credits `vendors.wallet_amount`).
7. Orders, chats, favourites, reviews, payouts, referral, catalogue
   collections: signed-in read / write, as today (section "TODO" in the file).
8. A legacy `users` document with no `role` is treated as a sign-up on every
   write; if it holds a plan or an approved `businessProfile`, its saves fail
   until the panel sets the role.
9. A plan with `expiryDay "0"` makes the apps write a null expiry, which the
   draft refuses. None is known; check the plans.
10. Races the rules turn from "silent overwrite" into "refused once": a rating
    whose copy of the driver is older than the driver's new `fcmToken`; a worker
    save whose `salary` is older than the provider's edit. A fresh read fixes it.
11. Dead FCM tokens: the store app clears another user's dead `fcmToken`; the
    draft refuses that cross-user write (logged only). With server push on,
    `sendPush` clears dead tokens itself (SERVER-PUSH-CONTRACT.md section 6).
12. **Another account's dispatch lists** (`orderRequestData`,
    `inProgressOrderID`, `ordercabRequestData`) are still writable by any
    signed-in account. Since D1 no app needs that except the store for its own
    delivery men (`storeManagerOf` already covers them) and the admin; narrow
    it once the panels' writers are checked. Until then a client can clear a
    driver's lists (the functions' `singleOrderReceive` would then treat the
    driver as free) or add ids (harmless: the driver app shows an offer only
    for an order that is `Driver Pending` naming the driver).
13. **Order creation** on the four dispatched collections is unguarded: a
    client could create an order already `Driver Pending` / naming a driver.
    Restrict create to the creation statuses (`Order Placed`,
    `Quote Requested`) with no driver once the website's and the panels'
    create paths are checked.
14. **Driver writes on `parcel_orders`** are guarded only on the dispatch and
    SMS fields. The driver app writes nothing else than `status`, `driverId`,
    `driverID`, `driver`, `rejectedByDrivers`, `driverRejections`,
    `receiverPickupDateTime`, `regionId`, `parcelStatus`, `trackingEvents`,
    `deliveryProof`, `driverCredited` (checked 7 Oct); turn that into an
    allowlist once the pickup points' and panels' writers are known.
15. **The website and the store panel** on orders: if the website writes
    `smsSent` at parcel creation, or the store panel assigns a platform driver
    / writes `Driver Pending` while signed in as a vendor (not the admin),
    the draft refuses it. Check both before merging (section 5).

App bugs seen while checking (for the app owners, not rules):

- provider: `updateCurrentUser` writes `wallet_amount` from the in-memory user
  on every profile save (`edit_profile_screen`, bank details, add service), so
  a credit made meanwhile (worker or customer flows increment it) is undone.
- worker: `updateCurrentUser` writes `wallet_amount`, `salary`, `providerId`,
  `active` from the in-memory copy on every save.
- driver: a fleet owner editing a driver runs `_applyCommonFields`, which sets
  `isActive = false`, so every edit takes the driver offline.

---

## 5. Merging with the live rules (before anything is published)

1. Copy the live rules: Firebase console > Firestore Database > Rules (the
   history drop-down keeps earlier versions). Save them as, e.g.,
   `firestore.rules.live` next to the draft.
2. Find **every broad allow** in the live rules, e.g.
   `match /{document=**} { allow read, write: if request.auth != null; }` or
   `if true`. Rules are OR-ed: one such line cancels every restriction in the
   draft. It must go. The draft's only wildcard is the admin one.
3. For every `match` in the live rules:
   - path also in the draft: keep the draft's version unless the live one is
     stricter on purpose; then combine the conditions with `&&`.
   - path not in the draft: it is probably a panel-only or website collection.
     Without a rule it becomes admin-only. Decide: add an explicit `match`
     (copy the live condition), or accept admin-only.
4. Check the web side, which section 3 does not cover:
   - **How the admin panel and the store panel talk to Firestore.** If they
     use the Firebase JS SDK with a Firebase sign-in, the admin account needs
     the `admin: true` custom claim (`getAuth().setCustomUserClaims(uid, {admin: true})`
     from a trusted server or the Admin SDK) or `users/{uid}.role == 'admin'`.
     If they use the Admin SDK on the server, rules do not apply to them. If
     they use the JS SDK **without** signing in, every write restricted here
     breaks for them: find out first.
   - The customer website (`APP-SPEC-WEB.md`): which collections it reads
     signed out (the draft gives public read to settings, plans, config,
     stores and catalogue) and what it writes (plan purchase snapshot, business
     request: both match the customer rules; a parcel order must not carry
     `smsSent` or `smsOptOut: true`; a cancel may clear the driver fields only
     before a driver accepted).
   - The store panel: every order write it makes as a vendor must fit 1.4
     (no `Driver Pending`, no platform driver named; its own delivery men
     only).
5. Keep `rules_version = '2'` and one `service cloud.firestore` block.
6. Run the emulator tests against the merged file (section 6), add a case for
   each rule the merge brought in, and fix until green.
7. Publish in a quiet hour from the console, keep the previous version at hand
   (console > Rules > history), and watch (section 6.3). Roll back by
   re-publishing the previous version.

---

## 6. Testing with the emulator before deploying

### 6.1 Automated checks

The 3 Oct suite (`functions/rules-test`, 39 cases: sign-up per role and
setting, self-escalation, business approval, plan purchase, cross-user edits,
admin by claim and by role, workers, settings, `push_rate_limits`,
subscriptions, unknown collections, `order_pod`, the POD transition, the
wallet ledger) was removed from the repository with `functions/`. Recreate it
outside the repo with `@firebase/rules-unit-testing` and
`firebase emulators:exec --only firestore --project demo-spideli` (a `demo-`
project id never reaches a real project; Java 11+ and the Firebase CLI, no
login).

The 7 Oct changes were checked that way against the local emulator (all
passed). Seed: drivers A and B, customer C, store owner S of store v1 with its
delivery man D, company Co (`isOwner`, `carrierId: c1`), carrier c1
(`regionIds: [r1]`). Cases:

| Allowed | Refused |
|---|---|
| A accepts a parcel offered to A (`Driver Accepted`, both fields A, `driver`, `receiverPickupDateTime`) | B accepts or rejects the offer to A |
| A times out / rejects its offer (`Driver Rejected`, arrayUnion A, both null) | A rejects while adding B to `rejectedByDrivers` |
| A passes an open parcel (`rejectedByDrivers`, `driverRejections` only) | A accepts after its own reject (`Driver Rejected`, A in the list) |
| B accepts an open `Order Placed` parcel | B takes a `Driver Rejected` order |
| C cancels a parcel while it is offered (`Order Cancelled`, both null) | B clears the driver of C's order |
| C pays a priced quote with the SMS option (merge, `driverId: null` unchanged) | C writes `status: "Driver Pending"` |
| C creates a parcel (`sendReceiverSms`, `smsCharge`, `smsOptOut: false`, flat receiver fields) | C creates a parcel with `smsSent`, or `smsOptOut: true` |
| S self-delivers with D (`In Transit`, both fields D) | A writes `smsSent`; C writes `smsOptOut`; A writes `sendReceiverSms` |
| S updates its order (preparation time) | S names platform driver B |
| A accepts the admin's hand assignment (`Order Accepted`, `driverID: A`) | B accepts a delivery offered to A |
| A times out a delivery offer; A hands back an accepted ride (`driver` deleted, `afterAccept`); A times out a rental | C creates a `parcel_sms_outbox` document |
| C pays a ride; C cancels a ride (`Order Rejected`, both null) | Co changes `regionPricing.r2` (not in `regionIds`) or `isVerified` |
| Co changes `regionPricing.r1.baseCharge` and the flat `baseCharge` | Co changes its own `carrierId` |
| A updates its own `orderRequestData` / `inProgressOrderID`; Co writes `companyAddress`, `zoneIds`, `zoneId` | |

Re-run them, with the 3 Oct cases, against the merged file you will publish.

### 6.2 By hand

- Firebase console > Firestore > Rules > **Rules Playground**: paste the
  merged rules (do not publish), simulate a few real documents with real uids,
  e.g. a driver updating `location` on its own doc (allowed), the same driver
  setting `isDocumentVerify: true` (denied), a customer reading another
  customer's `order_pod` (denied).
- Or run an app against the emulator (`FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080)`
  in a debug build, data seeded from an export) and walk sign-up, order, POD,
  wallet and chat.

### 6.3 After publishing

- Firebase console > Firestore > Usage: watch denied requests. Every app logs
  `permission-denied` from its Firestore helpers; ask testers for the screen
  and action.
- Anything unexpected: re-publish the previous version first, investigate
  second.
