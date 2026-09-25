# App Spec — Store Panel

**Panel:** Spideli eMart store / vendor panel (`spideli-emart-store`)
**Written:** 24 September 2026
**Status:** everything below is **built and live** unless the section says
otherwise.

**This file replaces three separate specs** — `app-spec-multiple-stores.md`,
`app-spec-vendor-subscription.md` and `app-spec-wholesale-pricing.md`. Those
stay on disk as history. **Edit this one.**

> **`APP-SPEC-ADMIN.md` in the admin repo is the master.** Fields shared across
> panels — regions, currency, payment methods, platform subscriptions, service
> groups — are defined there and are **not repeated here**. This file covers
> what the store panel owns or reads differently.

---

## Contents, against the client's own list

| § | Feature | Client's list | Built |
|---|---|---|---|
| 1 | The panel follows the region, and writes one | points 1, 2 | ✅ |
| 2 | Multiple stores on one account | point 3 | ✅ |
| 3 | Wholesale pricing | point 17 | ✅ |
| 4 | Subscriptions a store sells to its customers | point 19 | ✅ selling side |
| 5 | The store's own platform subscription | Document 1 | ✅ |
| 6 | Open questions | — | — |

---

## 1. The panel follows the region

Region fields are defined in `APP-SPEC-ADMIN.md` §1. What is specific here:

- A vendor's stores, orders and figures stay inside their region.
- **Store creation asks for the region first**, then offers only the zones
  belonging to it. Getting that order wrong was a real bug — a zone from
  another region could be attached to a store.
- The region falls back, in order, to: an explicit choice → the owning user's
  `regionId` → the vendor record's `regionId`.

### What the store panel WRITES a region onto

The panel is not only a reader. Three screens stamp a `regionId` at creation
time, and if they stop doing it the records arrive unplaced and vanish from a
region-bound admin's lists:

| Screen | Writes | Region comes from |
|---|---|---|
| Vendor registration (`auth/register`, `auth/phone_register`) | `users/{id}.regionId` | the region chosen on the form — **required**, registration is blocked without it |
| Driver creation (`deliveryman/create`) | `users/{driverId}.regionId` | `resolveVendorRegionId(vendor)` — the creating store's region |
| POS orders (`pos/index`) | the order's `regionId` | `resolveVendorRegionId(vendor)` |

`resolveVendorRegionId()` follows the rule in `APP-SPEC-ADMIN.md` §1: the
vendor's own `regionId` first, and its zone only when that zone serves exactly
one region.

---

## 2. Multiple stores on one account

### The field that changed meaning, not shape

```json
// users/{ownerId}
{ "vendorID": "store_a" }
```

`vendorID` stays a single store id, but now means **"the store currently
selected in the panel"** rather than "the one store this user owns". Every
existing read keeps working. Switching store writes a different id here.

**A user's stores are derived, not stored:** `vendors where author == {userId}`.
There is no array of store ids to keep in step.

### The owner lookup that was wrong

`users where vendorID == storeId` asks *"whose **selected** store is this?"* —
which is wrong the moment a vendor holds several. Read `vendors/{id}.author`.

This was fixed on 17 September. Anywhere still using the old pattern will
silently attribute a store to whoever happens to have it selected.

### What each store now carries separately

| | |
|---|---|
| **Wallet** | Each store has its own `wallet_amount` and its own payout requests |
| **Subscription** | Checked against the **store**, not the account, so one store expiring does not close the others. Expiry writes the store as well as the account |
| **Employees** | Attached to a store; the Employees list has a store filter |
| **Sections** | Deleting a section removes an owner's login **only when they have no stores left** |

### Deliberately not changed

`payoutRequests/provider/*` owner lookups. Providers are one-person service
people and are unaffected by multi-store.

### Two known gaps

> **Nothing credits `vendors/{id}.wallet_amount` on order completion.** The app
> must do it. Until then a vendor cannot withdraw what they earned.
>
> **`subscription_history` rows carry no store id.**

---

## 3. Wholesale pricing

Client point 17, Document 1's Commercial Management.

```json
// vendor_products/{id}
{
  "wholesaleEnabled": true,
  "wholesalePrice": "700",
  "wholesaleMinQty": "10"
}
```

| Field | Type | Notes |
|---|---|---|
| `wholesaleEnabled` | bool | **Off by default** — the *"certain products"* of the client's wording |
| `wholesalePrice` | string | Unit price once the threshold is met. String, matching how `price` and `disPrice` are already stored |
| `wholesaleMinQty` | string | Units required to qualify |

Variants carry the same three fields on `item_attribute.variants[]`.

### The price-resolution rule

Applied in this order, and **the retail path is unchanged** when wholesale is
off:

1. `wholesaleEnabled` is false or absent → retail, exactly as today
2. quantity **below** `wholesaleMinQty` → retail
3. quantity **at or above** `wholesaleMinQty` → `wholesalePrice`

**A discount does not stack on a wholesale price.** Wholesale already *is* the
reduced price; applying `disPrice` on top of it discounts twice.

---

## 4. Subscriptions a store sells to its customers

Client point 19 — the restaurant-delivers-bread example. **This is the third
subscription system and it must not touch the other two.**

| System | Collection | Who sells | Who buys |
|---|---|---|---|
| Platform → vendor | `subscription_plans`, `planFor: "vendor"` | Spideli | a store |
| Platform → customer | `subscription_plans`, `planFor: "customer"` | Spideli | a customer |
| **Store → customer** | `vendor_subscription_*` | **a store** | **a customer** |

The third uses **its own collections** precisely so it cannot collide with the
shared `subscription_plans`.

```json
// vendor_subscription_plans — what a store offers
{
  "id": "…",
  "vendorID": "…",
  "name": "Daily bread — monthly",
  "price": 15000,
  "duration": 30,
  "points": ["…"],
  "isEnable": true,
  "regionIds": ["…"]
}
```

```json
// vendor_subscriptions — who is subscribed
{ "planId": "…", "vendorID": "…", "customerId": "…", "expiryDate": "<Timestamp>" }
```

```json
// vendor_subscription_payments
{ "planId": "…", "vendorID": "…", "customerId": "…",
  "amount": 15000, "adminCommission": 1500, "createdAt": "<Timestamp>" }
```

**The commission is recorded on each payment**, not read from the store's
current rate. Changing the platform's cut later must never rewrite what an
older payment earned. **Preserve this when writing a payment.**

### What is built, and what is not

| Part | State |
|---|---|
| A store creates and edits its plans, and picks which of its stores a plan belongs to | ✅ built |
| A plan carries its points — what the customer actually gets | ✅ built |
| The store sees its subscribers and their payments | ✅ built |
| The platform sees every plan, subscriber and payment | ✅ built in admin |
| **A customer browses, subscribes and pays** | ⬜ **missing** |

> **It is provisional.** These screens were built against an option with **no
> automatic fulfilment**. A restaurant can sell a monthly bread subscription
> and see who bought it, but nothing creates the daily deliveries. The client's
> wording — *"to deliver bread to customers' homes"* — reads like recurring
> delivery, which is a far larger feature and has not been confirmed.

---

## 5. The store's own platform subscription

A store buys and renews its own plan from Spideli. The payment is recorded
against the **store** rather than the account, which is what makes §2's
per-store expiry work.

Plans are read from `subscription_plans` filtered by `sectionId` — which is
exactly why customer plans carry `sectionId: null` (see `APP-SPEC-ADMIN.md` §9).
They are invisible to these screens by construction, with no filter needed.

> **Store plans now carry `regionIds`, but nothing reads it.** The store
> subscription screens still offer plans by section alone. Recorded
> deliberately — per-region subscription *pricing* was never asked for in
> either client document, and one price is correct while regions share the
> pegged XAF/XOF.

---

## 6. Open questions

**With the client:**

- [ ] **Per-store subscription price — ANSWERED 22 Sep: confirmed final**,
      *"store wise subscription"*. A vendor with three stores pays three
      subscriptions. No longer provisional.
- [ ] Is store→customer subscription meant to create recurring **deliveries**,
      or only to record who paid? (§4)

**With the app developer:**

- [ ] Credit `vendors/{id}.wallet_amount` on order completion (§2).
- [ ] The customer half of §4 — browsing and paying for a store's plan.
- [ ] Wholesale in the cart: does the app apply the threshold per line, or
      across the basket? (§3)

**Closed:** legacy wallet balances. The client said on 22 September that the
current data is temporary and will be replaced, so **no migration is being
built**. That is a reason not to migrate, **not** authority to delete anything —
the cutover has never been written down.
