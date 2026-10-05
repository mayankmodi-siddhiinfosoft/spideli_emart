# Proof of Delivery by customer OTP — one contract for the Customer, Driver and Store apps

Client requirement (3 Oct 2026). Scope: **multivendor and e-commerce delivery
orders** (`vendor_orders`) and, since 5 Oct 2026, **multivendor and e-commerce
takeaway orders** (`takeAway == true`; the store verifies the customer's code at
the counter — see "Store app — takeaway"). Not dine-in, not e-commerce courier
shipments, not POS counter sales, not parcel (parcel keeps its own receiver
code), not cab / rental.

## The flow (client's words, made precise)
1. The driver reaches the customer and taps **"Drop Delivery"** (the existing
   complete-delivery action). The app generates a **new, unique 6-digit OTP** for
   that order — never shown in the Driver app.
2. The OTP appears **directly on the Customer app's order screen**, live, with a
   countdown. The customer app also gets a push ("Your order has arrived — open
   the app for your delivery code"); the push NEVER contains the code.
3. The driver asks the customer for the OTP and types it into the Driver app.
4. Only a valid OTP marks the order Delivered/Completed. **No OTP, no
   completion** — there is no photo or skip path for these orders.
5. **No SMS.** Nothing is sent to the customer's phone number.

## Rules
- Code: 6 digits from `Random.secure()`, different from the previous code for the
  same order. Valid only for that order.
- Expiry: **10 minutes** from generation.
- Attempts: **5 wrong entries** invalidate the code (status `expired`); the driver
  must generate a new one.
- New code (resend): the driver can request a new code after a **60-second
  cooldown**, at most **5 regenerations per order**. Each one replaces the old
  code (the old one stops working immediately).
- Tapping "Drop Delivery" again while a pending, unexpired code exists **reuses
  it** — it does not create a new one.
- Error messages: wrong code ("Incorrect code. N attempts left."), expired ("This
  code has expired. Generate a new one."), too many attempts, no code yet, offline.

## Firestore shapes

### `order_pod/{orderId}` — the code (separate from the order, so it can be
### locked down by rules: customer may read, driver may not)
| Field | Value |
|---|---|
| `orderId`, `customerId`, `driverId`, `vendorId` | strings |
| `code` | the 6 digits, as a string |
| `status` | `pending` \| `verified` \| `expired` |
| `generatedAt` | server timestamp |
| `expiresAt` | Timestamp (generatedAt + 10 min, from the device clock) |
| `generatedBy`, `generatedByRole` | uid and `driver` \| `vendor` of whoever generated the code (whose clock set `expiresAt`) |
| `attempts` | int, wrong entries against this code |
| `regenerations` | int, how many codes this order has had |
| `verifiedAt` | Timestamp, when verified |

### On the order (`vendor_orders/{id}.pod`) — the record everyone displays
```
pod: {
  method: "otp",
  status: "pending" | "verified",
  requestedAt: Timestamp,
  expiresAt: Timestamp,
  verifiedAt: Timestamp,          // when verified
  verifiedBy: "<uid>",            // the driver (or the store, for self-delivery)
  verifiedByRole: "driver" | "vendor",
  deliveredBy: { id, name, phone, photo }   // the delivery man
}
```
Written ONLY by the POD transactions (dotted-path updates in the Driver app,
the whole `pod` map read-and-written inside the Store app's transaction).
No app's `OrderModel.toJson` writes `pod`, so no order save can clear it or
roll a `verified` record back to `pending`. Never contains the code.

## Clock skew
`expiresAt` comes from the generating phone's clock, `generatedAt` from the
server. The device that generated the code (`generatedBy` == its user) checks
expiry against `expiresAt` (same clock, exact). Every other device uses
`generatedAt + 10 min + 30 s` (the 30 s tolerates small skew). The customer
countdown is `generatedAt + 10 min` minus the customer's clock (capped at 10
min), and the digits stay up for the same 30 s grace. The cooldown is measured
the same way.

## Cancellation
Creating, regenerating and verifying a code read the order in the same
transaction. A cancelled / rejected order (or a completed one without a
verified `pod`) gets no code and cannot be verified; a pending code is set to
`expired`. The customer app stops showing the code as soon as the order is
cancelled, rejected, completed or verified.

## Verification (Driver app, and Store app for self-delivery)
One Firestore transaction on `order_pod/{orderId}`: status must be `pending`, now
< `expiresAt`, `attempts < 5`, entered code == `code`. On success set `status:
verified`, `verifiedAt`, and the order's `pod` to `verified`. On failure increment
`attempts` (and set `expired` at 5). **Then** run the app's existing completion.
Every payment in it is once per order: the driver's earning (`wallet/driver_<orderId>`),
the cashback (`wallet/cashback_<orderId>`, both apps) and the referral
(`wallet/referral_<orderId>`) are each written together with the user's
`wallet_amount` in one transaction that first checks the row; the store credit
keeps its existing guard (`vendorCredited` / the vendor `Wallet` row). If completion fails after a successful
verification, a retry must not ask for a new code (the order's `pod.status` is
already `verified`).

## Store app — self-delivery
When the store completes a self-delivery order itself ("Mark as Completed"), the
same flow applies with `verifiedByRole: "vendor"`: the store generates the code,
the customer reads it from their app, the store enters it. E-commerce courier
shipments ("Mark Deliver", no delivery man, not takeaway) are unchanged; an
e-commerce order WITH a delivery man is a delivery and needs the code.

## Store app — takeaway (5 Oct 2026)
Client requirement: "the store did not ask a code from the customer to validate
the completed TAKEAWAY order". A takeaway order (`takeAway == true`, multivendor
and e-commerce) is completed exactly like a self-delivery: the store taps
"Delivered", the app generates (or reuses a live pending) code in
`order_pod/{orderId}` with `generatedByRole: "vendor"`, sends the customer the
same `delivery_otp` push (`{type: delivery_otp, orderId}`, never the code; title
"Your order is ready for pickup", body "Open the app for your pickup code."),
and opens the code entry sheet. Only a verified code runs the existing
completion (cashback once, store credit once, `takeaway_completed` push).
Backing out completes nothing; a cancelled / closed order cannot be completed.
`pod.verifiedByRole` is `vendor`; `pod.deliveredBy` is not set (no delivery man).
A POS order (`isPosOrder == true`, rung up at the counter) has no customer app
and stays exempt. The Driver app never sees takeaway orders and is unchanged.

The scope rule lives in one pure function per app, unit tested:
Store `PodScope.storeCompletion` (`vendor/lib/utils/pod_otp.dart`),
Customer `DeliveryCodeWatcher.shouldWatch` (`customer/lib/widget/delivery_code_card.dart`).

### Wording
Delivery orders keep the delivery wording. Takeaway orders use pickup wording
(en + ar in the Customer app; en, ar, fr in the Store app):
- Customer code card: "Your pickup code"; "Share this code with the store only
  when you collect your order"; expired: "Code expired — ask the store for a new one".
- Store sheet: "Enter the pickup code", field "Pickup code"; waiting note
  "Waiting for the customer's pickup code".
- POD block / history line once verified: "Proof of pickup", "Pickup status ·
  Picked up", "OTP Verified", and "Verified by the store" (shown whenever
  `pod.verifiedByRole == "vendor"`, so also on store self-deliveries).

## Order Details — what everyone sees once verified
- Delivery status: **Delivered**
- POD status: **OTP Verified**
- Verification date and time (`pod.verifiedAt`)
- Delivery man: name, phone, photo (`pod.deliveredBy`)

For a takeaway: Pickup status **Picked up**, POD status **OTP Verified**,
**Verified by the store**, the verification time, no delivery man.

Customer, Store and Driver order details show this block. Orders completed before
this existed show nothing extra (no "null"). The admin panel reads the same `pod`.
