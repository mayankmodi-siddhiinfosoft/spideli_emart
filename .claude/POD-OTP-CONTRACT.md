# Proof of Delivery by customer OTP — one contract for the Customer, Driver and Store apps

Client requirement (3 Oct 2026). Scope: **multivendor and e-commerce delivery
orders** (`vendor_orders`, not takeaway). Not dine-in, not parcel (parcel keeps
its own receiver code), not cab / rental.

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
Written as a known-fields merge; never cleared by a later save. Never contains the code.

## Verification (Driver app, and Store app for self-delivery)
One Firestore transaction on `order_pod/{orderId}`: status must be `pending`, now
< `expiresAt`, `attempts < 5`, entered code == `code`. On success set `status:
verified`, `verifiedAt`, and the order's `pod` to `verified`. On failure increment
`attempts` (and set `expired` at 5). **Then** run the app's existing completion
(wallet credit exactly once — unchanged). If completion fails after a successful
verification, a retry must not ask for a new code (the order's `pod.status` is
already `verified`).

## Store app — self-delivery
When the store completes a self-delivery order itself ("Mark as Completed"), the
same flow applies with `verifiedByRole: "vendor"`: the store generates the code,
the customer reads it from their app, the store enters it. Takeaway ("Delivered")
and e-commerce courier shipments ("Mark Deliver", no delivery man) are unchanged.

## Order Details — what everyone sees once verified
- Delivery status: **Delivered**
- POD status: **OTP Verified**
- Verification date and time (`pod.verifiedAt`)
- Delivery man: name, phone, photo (`pod.deliveredBy`)

Customer, Store and Driver order details show this block. Orders completed before
this existed show nothing extra (no "null"). The admin panel reads the same `pod`.
