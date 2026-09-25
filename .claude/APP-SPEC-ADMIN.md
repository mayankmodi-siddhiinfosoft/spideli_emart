# App Spec — Admin Panel

**Panel:** Spideli eMart admin panel (`spideli-emart-admin`)
**Written:** 24 September 2026
**Status:** everything below is **built and live** unless the section says
otherwise.

**This file replaces six separate specs** — `app-spec-region-features.md`,
`app-spec-customer-subscription.md`, `app-spec-service-groups.md`,
`app-spec-carrier-delivery.md`, `app-spec-pickup-points.md` and
`app-spec-parcel-sms.md`. Those stay on disk as history. **Edit this one.**

**This is the master of the three.** The admin panel writes most of what the
other panels read, so **every shared field is defined here**.
`APP-SPEC-STORE.md` and `APP-SPEC-WEB.md` point back at this file rather than
restating a shape — that is what stops the three drifting apart.

> **Everything is additive with a fallback.** A missing field reproduces the
> behaviour from before this work, so the apps and the other panels keep
> working until they take each item up.

---

## Contents, against the client's own list

| § | Feature | Client's list | Built |
|---|---|---|---|
| 1 | Regions, what carries one, admin-user binding, statistics, backfill | points 1, 2 | ✅ |
| 2 | Currency by region | point 2 | ✅ |
| 3 | Payment methods by region | point 2 | ✅ |
| 4 | Delivery charge by region | Document 1 | ✅ |
| 5 | Region defaults | — | ✅ |
| 6 | Service groups | page 9 | ✅ |
| 7 | Multiple stores per vendor | point 3 | ✅ |
| 8 | Free order-history limit | point 12 | ✅ |
| 9 | Platform subscriptions for customers | points 12, 19 | ✅ |
| 10 | Wholesale pricing | point 17 | ✅ |
| 11 | Carriers (delivery companies) | points 10, 24, 28 | ✅ stored, ⬜ unused |
| 12 | Pickup points | points 21, 26 | ✅ |
| 13 | Document verification | points 25, 27 | ✅ |
| 14 | Delivery assignment and resend | points 4, 9 | ✅ manual only |
| 15 | Admin commission on deliveries | point 23 | ✅ |
| 16 | SMS gateway | page 10 | ✅ built, ⬜ nothing triggers it |
| 17 | Parcel SMS to the receiver | client answer, 22 Sep | ⬜ specified only |
| 18 | Open questions | — | — |

---

## 1. Regions, and what carries one

Collection: **`regions`** — new.

```json
{
  "id": "FTngBVrRNngciHsCzXnA",
  "name": "Cameroon",
  "code": "CM",
  "countryCode": "CM",
  "currencyId": "…",
  "zoneIds": ["…"],
  "publish": true
}
```

**Never match a country using `code`.** It is a free-text label the admin
chose, and Gabon carries `code: "GB"`. Match on `countryCode`.

### Which documents carry a region

| Collection | Field | Notes |
|---|---|---|
| `vendors` | `regionId` | string — the store's region |
| `zone` | `regionIds` | **array** — every region this zone serves |
| `zone` | `regionId` | string — **deprecated**, holds only the first entry. Read the array |
| `users` (vendor, driver, provider) | `regionId` | string |
| `users` (customer) | `regionIds` | **array** — every region the customer has ordered in |
| `vendor_orders` | `regionId` | inherited from the store |
| `providers_services`, `providers_workers` | `regionId` | string |
| `rides`, `rental_orders` | `regionId` | **resolved through the DRIVER (`driverId`)**, not the store |
| `provider_orders` | `regionId` | resolved through `provider.author` |
| `complaints` | `regionId` | resolved through `driverId` |
| `order_transactions` | `regionId` | resolved through `vendorId` |

**Field names differ across collections.** `vendor_orders` uses `vendorID`;
`rides` and `rental_orders` use `driverId`. Read the actual document, never a
similarly-named variable nearby.

### The rule that saves work

**Before adding a `regionId` to a record, check whether something it already
points at carries one.** Payouts name a party (`vendorID` or `driverID`) and
that party already has a region, so payouts carry **no region field at all** —
it is resolved at render time. No field, no backfill, no index, nothing for the
app to write.

### Admin users bound to a region — client point 1

An admin user is bound to one or more regions through the
`admin_user_regions` pivot (MySQL, not Firestore — it belongs to the login,
which Laravel owns). A bound user sees only those regions and cannot switch to
the rest of the platform.

This is the first half of the client's point 1: *"assign a zone management to a
role for admin users, or create an admin user and assign them a management
zone"*.

### Statistics and dashboards — client point 2

The client's point 2 names **statistics** explicitly. All six dashboards scope
their figures to the selected region.

**How, and why it matters for cost:** dashboard counters filter **in memory**
with `regionDocs()` — no composite index. Only `.limit()` top-N queries use a
real query filter. Filtering every stat query would have needed about **114
indexes** against Firestore's limit of 200. The 38 that are needed are listed in
`firestore-indexes.md`.

### Guarded, not filtered — dine-in bookings and reviews

Both are reached **only** as one store's tab (`/booktable/{id}`,
`/reviews/{id}`), with no platform-wide list. Every row already belongs to one
store, and the store carries the region. So there is **no row filtering and no
index** — just an `isInActiveRegion(store)` guard on the screen.

**The lesson generalises:** check how a screen is *reached* before deciding how
to scope it. Pagination style alone is misleading.

### The region backfill tool

`/region/backfill` attaches a region to everything created before this work
existed. Dry run first — it only counts — then apply.

Covers vendors, stores, orders, drivers, providers, services, workers, rides,
rental orders, bookings, complaints and order transactions, with a driver→region
parent map for the collections that resolve through a driver.

> **It skips anything that already has a `regionId`.** It can fill an empty
> value; it can never correct a wrong one. A record placed wrongly must be
> cleared before a re-run will move it.

### A zone can serve several regions

Confirmed by the client, built 18 September. The consequence matters: **a zone
is no longer a reliable way to work out a record's region.** Read the record's
own `regionId`, and fall back to its zone **only when that zone serves exactly
one region**.

---

## 2. Currency by region

`regions/{id}.currencyId` names a `currencies` document.

**The store's region decides its prices** — settled 22 September from the
client's documents. Not the customer's location. A French store reads in euros
to a visitor browsing from Douala.

Resolution order, with a fallback at every step:

1. the record's own `regionId`
2. that region's `currencyId`
3. failing either, the globally active currency (`isActive == true`)

Only one currency document carries `isActive == true`, so anything not
converted renders every price in that one currency — which is exactly the bug
this closes.

---

## 3. Payment methods by region

Each gateway document carries `regionIds` — an array.

**Empty or absent means available in every region.** That is the fallback that
keeps existing gateways working untouched.

---

## 4. Delivery charge by region

Document: **`settings/DeliveryCharge`**.

```json
{
  "vendor_can_modify": false,
  "delivery_charges_per_km": 12,
  "minimum_delivery_charges": 10,
  "minimum_delivery_charges_within_km": 3,

  "regions": {
    "FTngBVrRNngciHsCzXnA": {
      "delivery_charges_per_km": 20,
      "minimum_delivery_charges": 15,
      "minimum_delivery_charges_within_km": 2
    }
  }
}
```

Every top-level field is unchanged and remains the global default. The only
addition is the optional `regions` map, keyed by region id. A region absent
from the map follows the global figures.

Per the client's page 5: **deliveries within a city use the default setting.**

---

## 5. Region defaults

Document: **`settings/RegionDefaults`** — new, 22 September.

```json
{ "defaultRegionId": "FTngBVrRNngciHsCzXnA" }
```

Used **only** when a visitor's location and country match no region. It never
overrides a region already resolved. Empty by default, which is exactly the
behaviour from before it existed.

---

## 6. Service groups

Collections: **`service_groups`** (new) and **`sections`** (one new field).

```json
// sections
{ "id": "…", "name": "Restaurant", "order": 3, "serviceGroup": "shopping" }
```

| | |
|---|---|
| `serviceGroup` | The `id` of a `service_groups` document, or `""` |
| `""` or absent | Ungrouped. **Every service saved before this change is in that state** |
| `order` | Unchanged — still orders services **within** a group |

**The groups are client-managed data, not a fixed list.** Name, order and
publish are editable in Settings → Service Groups. **Do not hardcode them.**
A group's id is fixed for its lifetime, so renaming never detaches its
services, and a group holding services cannot be deleted.

**An ungrouped service belongs under "Others"** — one of the client's own five
groups on page 9, holding the AI Assistant. Confirmed from their document on
22 September, so the home screen must never render only known groups.

---

## 7. Multiple stores per vendor

**`users/{ownerId}.vendorID`** keeps its shape — a single store id — but is now
read as *"the store currently selected"*, not *"the one store this user owns"*.
Switching store writes a different id.

A user's store list is **derived**, not stored: `vendors where author ==
{userId}`.

**The owner lookup that was wrong:** `users where vendorID == storeId` asks
*"whose selected store is this?"* — wrong once a vendor holds several. Read
`vendors/{id}.author`.

Each store carries its own `wallet_amount` and its own payout requests.

> **Gap, and it blocks vendors from their money:** nothing credits
> `vendors/{id}.wallet_amount` on order completion. The app must do it.

---

## 8. Free order-history limit

Document: **`settings/OrderHistory`**.

```json
{ "isLimitEnabled": true, "freeOrderLimit": 5 }
```

The client's two documents disagreed — five orders in one, eight in the other —
so it is a setting, not a constant. **Read it; hardcode neither number.**

**It must apply ONLY to a customer viewing their own history.** If it goes into
a shared data layer rather than the customer's own history screen, a store
owner silently starts seeing only their five most recent orders — and that
surfaces as a store-panel bug months later with nobody remembering why.

---

## 9. Platform subscriptions for customers

Collection: **`subscription_plans`** — shared with vendor plans.

```json
{
  "planFor": "customer",
  "sectionId": null,
  "type": "paid",
  "price": "2000",
  "expiryDay": "30",
  "isEnable": true,
  "features": { "fullOrderHistory": true },
  "regionIds": ["…"]
}
```

| Field | Meaning |
|---|---|
| `planFor` | `"vendor"` or `"customer"`. **Absent means `"vendor"`** — every existing plan keeps working |
| `sectionId` | `null` on customer plans. Vendor screens filter on `sectionId`, so customer plans are invisible to them by construction |
| `expiryDay` | Days. `"30"` monthly, `"365"` annual, `"-1"` never expires. No new billing-period field |
| `features.fullOrderHistory` | `true` unlocks the complete history |
| `regionIds` | Empty or absent = sold everywhere |

The customer's state uses **exactly the field names vendors already use**, so
one shape is read everywhere:

```json
// users/{customerId}
{
  "subscriptionPlanId": "…",
  "subscription_plan": { },
  "subscriptionExpiryDate": "<Timestamp|null>"
}
```

`subscription_plan` is a **snapshot at purchase time** — a later price change
never alters what the customer bought.

**The purchase is written by the web panel** (24 September), in one Firestore
transaction. See `APP-SPEC-WEB.md` §5 for the exact shape. The app may do the
same or call whatever it prefers, but the shape is now fixed by working code.

---

## 10. Wholesale pricing

Written by the store panel. See `APP-SPEC-STORE.md` §3 for field shapes and the
price-resolution rule. Admin mirrors the same fields on its own product screens.

---

## 11. Carriers (delivery companies)

Collection: **`delivery_carriers`** — new.

```json
{
  "name": "Express Cameroun",
  "code": "EXPCM",
  "countryCode": "+237",
  "phone": "677123456",
  "regionIds": ["…"],

  "operatingLicence": "OL-2024-4471",
  "commercialRegister": "RC/DLA/2019/B/1234",
  "uniqueIdNumber": "M071912345678X",
  "operatingLicenceFile": "https://…",
  "commercialRegisterFile": "https://…",
  "uniqueIdNumberFile": "https://…",
  "isVerified": true,

  "baseCharge": 500,
  "perKmCharge": 75,
  "perKgCharge": 200,
  "minimumCharge": 1000,
  "maxWeight": 30,
  "minDeliveryTime": 1,
  "maxDeliveryTime": 3,
  "deliveryTimeUnit": "days",
  "conditions": "…"
}
```

The three document fields answer the client's points 24 and 28; pricing,
delivery times and conditions answer Document 1's Service Provider Management.

### Settled from the client's documents, 22 September

- **The carrier's rate is what the system uses** — *"which the system will then
  use"*. Within a city the default delivery setting applies; the carrier rate
  drives inter-city and inter-country. An admin override exists.
- **The customer chooses the carrier** during shipment creation.
- **The admin delivery commission applies to companies too** — *"on deliveries"*
  has no carve-out, and companies are to deliver *"like individual deliver"*.

> **Nothing consumes these.** Carriers and their rates are stored and unused —
> not by orders, not by the apps.
>
> **The blocker, unanswered by anyone:** a carrier has no login, no app and no
> device token, so nothing can notify it of a job or let it mark one done.
>
> **Proposed way out:** the client asks that companies deliver *"like individual
> deliver"*. If a company's work is carried out by **drivers registered under
> that company**, those drivers already have the app and a token, and the gap
> closes — a company becomes an owner of drivers rather than a new actor.

---

## 12. Pickup points

Collection: **`pickup_points`** — new.

```json
{
  "name": "Bonamoussadi Relay",
  "quarter": "Bonamoussadi",
  "town": "Douala",
  "phone": "677123456",
  "countryCode": "+237",
  "location": { "latitude": 4.0911, "longitude": 9.7679 },
  "regionId": "…",
  "publish": true
}
```

The five fields the client listed in point 26, plus the housekeeping every
collection here carries. **Names are unique per region, not globally.** A point
holding parcels cannot be deleted. Location is optional but range-validated.

`parcel_orders.pickupPointId` links a parcel to its point.

### Settled from the client's documents

- **The sender chooses the point**, at the moment of sending.
- **A parcel at a point needs states of its own** — a notification fires when it
  is *available*, and "operations history" needs a *collected* state after it.

> **Parcel is paused by the client.** This was built because the fields were the
> one fully-specified part of the document. **No parcel screen is
> region-scoped** — parcel was paused before regions rolled out, so
> `parcel_orders` carries no `regionId` while every other record does. Close
> that when parcel resumes.

---

## 13. Document verification

Collection: **`documents`** — existing, with `provider` and `worker` types.

Per the client: providers supply a **commercial register** and a **unique
identification number**; delivery companies supply those plus an **operating
licence** (held on `delivery_carriers`, §11).

---

## 14. Delivery assignment and resend

An order can be assigned to a named driver by hand, with the assignment
recorded and a manual resend button.

> **Half of point 9 is missing.** The manual resend is built. The **automatic**
> queue — re-notifying drivers who log in *after* an order was placed — is not,
> and it needs an app-side trigger. Two separate features.

---

## 15. Admin commission on deliveries

Set in Settings, not fixed in code. Answers point 23, and per §11 it applies to
delivery companies as well as individual drivers.

---

## 16. SMS gateway

Document: **`settings/SMSGateway`**.

```json
{ "isEnabled": true, "apiKey": "…", "senderId": "SPIDELI", "apiUrl": "https://obitsms.com/api/v2" }
```

OBITSMS v2 authenticates with **`key_api` alone** — the username and password on
the client's page 10 are the web portal login, not API credentials. Two GET
endpoints: `/bulksms?key_api&sender&destination&message` and `/solde?key_api`.
JSON `{success, code, message}`. Codes: **900** sent, **901** no credit,
**902** bad number, **903** bad message.

`SmsController` sends from Laravel and reads the key from Firestore, so the key
never travels in a request and CORS is sidestepped. Balance checks are free;
sends cost.

Sender name max **11 characters**. Destination must be plain digits with country
code, normalised server-side — `normaliseNumber()` strips non-digits but
**cannot invent a missing country code**.

> **Nothing triggers an SMS.** See §17.

---

## 17. Parcel SMS to the receiver — specified, not built

The client answered on 22 September: **SMS is for the parcel service only.**
A customer placing a parcel order gives the **receiver's** mobile number, and
the receiver is texted as the parcel moves — a running series, not one
confirmation.

**Ruled out:** sign-in one-time codes, ordinary orders, driver assignment,
delivery. The OTP was the expensive option — it would have changed both apps
and the auth flow.

**Why SMS here and nowhere else:** the receiver is **not a platform user**. No
account, no app, no device token. Push cannot reach them.

Full field shapes, the event list as a cost decision, and the message-format
traps are in **`app-spec-parcel-sms.md`**, which is still current — it is the
one old spec not folded in here, because none of it is built.

**The hard part, unresolved:** what actually calls the SMS endpoint? This panel
queries Firestore from the browser and the apps write to it directly, so a
status written by a driver never passes through Laravel. A Cloud Function
watching `parcel_orders` is the only candidate that fires whoever moved the
parcel.

> **App half built, 25 Sep.** Both apps now write one request document to
> `parcel_sms_outbox` in the same batch as the tracking status, gated on
> `settings/SMSGateway.isEnabled` and `.parcelEvents` (absent = inert). The
> sender is still to be built: read pending, send via OBITSMS, stamp
> `sendState`/`sentAt`/`error`. Contract: **`.claude/PARCEL-SMS-OUTBOX.md`**.

---

## 18. Open questions

**With the client:**

- [ ] Does parcel restart? Gates the rate tables, pickup-point pricing, the
      receiver SMS and three smaller questions.
- [ ] CabCar variables (point 7) — *"such as traffic jams"* is not a list we can
      build from.

**With the app developer:**

- [ ] Who owns the SMS trigger? (§17)
- [ ] The automatic driver-notification queue (§14).
- [ ] Crediting `vendors/{id}.wallet_amount` on order completion (§7).
- [ ] The app must write `regionId` when it creates a ride or a rental order —
      rides take the driver's region, rentals the driver's too. Without it every
      new record arrives unplaced and is invisible to a region-bound admin.
- [ ] Service availability — the customer's location, or their account?

**Answered from the client's own documents, 22 September** — do not re-ask:
ungrouped services go under "Others"; the store's region decides pricing and
payment methods; the customer chooses the carrier at shipment creation.

---

## House rules

1. **Any new admin-configurable value belongs in Settings**, not on a feature
   screen.
2. **App-dependent points get a gate** — describe the flow and the Firestore
   structure, separate what each side owns, and get App-developer sign-off
   *before* writing code.
3. **A list that fetches everything** (`ref.get()`) filters in memory and needs
   no index. **One that pages** (`limit`/`startAfter`) needs a query filter and
   a composite index. Decide which before writing the query.
4. **Check how a screen is reached** before deciding how to scope it. A screen
   reached only as one store's tab needs a guard, not a filter — and therefore
   no index.
5. **Firestore Security Rules are unchanged, by decision** (22 Sep). Region
   scoping is enforced in browser queries only. Disclosed to the client in
   `DEPLOYMENT-CHECKLIST.md`.
