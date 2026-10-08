# Driver dispatch: the app side of the Cloud Function dispatch

**Date:** 7 Oct 2026. **Source:** `DRIVER_DISPATCH_DOCUMENTATION.md` v1.0
(the backend's spec of `deliveryDispatch`, `parcelDispatch`, `cabDispatch` and
`rentalDispatch`), and decisions D1 to D4 taken for the apps. This file covers
what the five apps do, what they write, and what they expect from the
functions. The functions' own source is not in this repository.

Related: `.claude/PUSH-CHANNELS.md` (the `spideli` channel),
`.claude/CANCEL-REASON-CONTRACT.md` (passes vs. final cancellations),
`firestore.rules.draft` (section "Driver dispatch") and
`.claude/FIRESTORE-RULES-DRAFT.md`.

---

## 1. Who does what

| | Owner |
|---|---|
| Picking the driver (radius, zone, service type, wallet, `singleOrderReceive`, `rejectedByDrivers`) | **Cloud Functions** |
| Writing the offer: order `status: "Driver Pending"`, `driverId` = `driverID` = the driver; `users/{driver}.orderRequestData` arrayUnion the order id | **Cloud Functions** |
| The offer push (channel `spideli`, `data.type` order / parcel / cab / rental) | **Cloud Functions** |
| Offering again after `Driver Rejected` (excluding everyone in `rejectedByDrivers`) | **Cloud Functions** |
| `vendor_orders`: `Driver Accepted` -> `Order Shipped` | **Cloud Functions** |
| Auto-cancel after `orderAutoCancelDuration` when nobody accepts | **Cloud Functions** |
| Showing the offer, the countdown, Accept / Reject, the timeout | driver app |
| The accept / reject / timeout writes (section 5) | driver app |
| Showing "looking for a driver" to the customer and the store | customer app, store app |

**No app dispatches (D1).** The earlier app-side broadcasts are removed:
`customer/lib/service/driver_job_notifier.dart`,
`customer/lib/utils/driver_job_push.dart` (with its test and every call site),
`vendor/lib/utils/driver_job_broadcast.dart` (with its test and call site), and
the driver app's own re-dispatch (`updateDriverOrder`, the job queue's
`triggerDelivery` rewrite). No app writes `Driver Pending`, adds an id to
another driver's `orderRequestData`, or pushes a platform driver about an
order it could take (`order_available`, `new_ride`, `new_parcel`, `new_rental`
are no longer sent).

**Not dispatch, unchanged:** a store giving an order to **its own delivery
man** (self delivery). The store app writes `status: "In Transit"`,
`driverID` = `driverId` = that man, and his `driver` snapshot in one
transaction from `Order Placed`, and sends him the templated
`new_delivery_order` push on `driver_jobs`. Because the order never passes
through `Order Accepted`, `deliveryDispatch` is never involved. An admin's hand
assignment (`Order Accepted` or `Driver Pending` with `driverID` set by the
panel) is answered on the module's home card, with no countdown.

---

## 2. What starts each function, and how the apps read it

| Collection | Function | Starts on | `data.type` | Driver field the app queries | `users.serviceTypes` value |
|---|---|---|---|---|---|
| `vendor_orders` | `deliveryDispatch` | `Order Accepted` (the store accepted), `Driver Rejected` | `order` | `driverID` | `delivery-service` (`ecommerce-service` read as delivery) |
| `parcel_orders` | `parcelDispatch` | `Order Placed`, `Driver Rejected` | `parcel` | `driverId` | `parcel_delivery` (`parcel-service` read as parcel) |
| `rides` | `cabDispatch` | `Order Placed`, `Driver Rejected` | `cab` | `driverId` | `cab-service` |
| `rental_orders` | `rentalDispatch` | `Order Placed`, `Driver Rejected` | `rental` | `driverId` | `rental-service` |

The app matches a driver on **either** spelling (`driverId` or `driverID`): the
functions write both, older records have one.

---

## 3. How the driver app finds an offer

Two sources, so a missed push still shows the offer
(`driver/lib/services/incoming_offer_service.dart`):

1. **The push** (`DispatchPush.parse`, `dispatch_offer_rules.dart`): `data.type`
   in order | parcel | cab | rental, the id in `data.orderId` (or `data.id`),
   and `data.click_action == "FLUTTER_NOTIFICATION_CLICK"` or
   `data.status == "Driver Pending"`. Handled:
   - in the foreground (`onMessage`): the order is read from Firestore and the
     dialog opens over any screen; on Android the push is also posted on
     `spideli`;
   - in the background / terminated: the system shows it; the background
     isolate records the offer's start time (section 4); a tap opens the dialog
     (or the module's job screen if the order is no longer pending for this
     driver); a launch from a tap is handled once the dashboard is up.
2. **Live listeners**, started from every dashboard's `users/{me}` listener and
   stopped on sign-out: per served module one query
   `status == "Driver Pending" && <driver field> == me`, plus a document
   listener for every id in `users/{me}.orderRequestData` the queries do not
   return. Only server-confirmed snapshots are shown or timed out.

**Timed offer** (`DispatchOrderRules.isTimedOffer`): `Driver Pending`, names
this driver, not in their `rejectedByDrivers`, not in their
`inProgressOrderID` (a store's own delivery), not a hand assignment the app
recorded itself, not a rental waiting for the customer's answer to this
driver's counter-offer, and its id is in `orderRequestData` **or** a dispatch
push named it. Everything else pending for the driver stays on the module's
home card with no timer.

A company account (`isOwner: true`) holds no jobs: the service never starts
for it.

---

## 4. The incoming-order dialog and its countdown

- **One global dialog** (`driver/lib/app/incoming_offer/incoming_offer_dialog.dart`),
  over any screen; never two for one order; further offers queue. It shows the
  order read from Firestore (`OfferSummary`): pickup and drop labels and
  addresses, fare (parcel: the total the customer was charged, SMS fee
  included), tip, distance, weight, ride type, rental package, scheduled time;
  for a parcel the receiver's name from the flat `receiverName`, else the
  `receiver` map. Accept, Reject (reason sheet), countdown ring.
- **Window:** `settings/DriverNearBy.driverOrderAcceptRejectDuration` seconds,
  read as a number or numeric text; missing, unreadable or <= 0 means **120**.
- **Start** = the earliest known of:
  1. the push's `sentTime` (only while it is at most 10 s before this device
     received it; further back the receipt time is used, so a phone clock set
     ahead cannot eat the window);
  2. a dispatch time written on the order: the first present of `dispatchedAt`,
     `driverDispatchedAt`, `lastDispatchedAt`, `dispatchTime`,
     `driverPendingAt`, `offeredAt` (Timestamp, epoch ms / s, ISO text);
  3. the first time this device saw the offer, persisted per order id
     (SharedPreferences `dispatchOfferSeen`, kept 24 h, at most 200 entries;
     the background isolate writes it too).
  Times before the order's dispatch time are ignored. A dispatch push more than
  10 s after the recorded time starts a **new round** (the same order offered
  to this driver again), so a re-dispatch never inherits an expired window.
- **Expiry:** the timeout flow (section 5) runs **once**, without a reason and
  without opening the reason sheet, and only if the order is still
  `Driver Pending` for this driver. An offer whose window was already over when
  the app opened is rejected the same way, unseen.
- **Accept gates** (as on the module cards): a freelance driver with documents
  pending (not for a hand assignment), an independent driver below
  `minimumDepositToRideAccept`, a company driver whose company wallet is below
  `ownerMinimumDepositToRideAccept`. A blocked accept writes nothing.

---

## 5. What the driver app writes

Every answer re-reads the order **in a transaction** and writes only if the
order is still this driver's to answer (`DispatchOrderRules.acceptCheck` /
`canReject`); only the named fields are written (never a whole model). The
driver's own arrays move field-level afterwards. Code:
`driver/lib/services/dispatch_offer_service.dart`,
`assigned_delivery_orders.dart` (delivery), `dispatch_offer_rules.dart`.

### 5.1 Accept (all four collections)

Precondition: `Driver Pending` naming this driver; or a hand assignment naming
this driver (`vendor_orders` `Order Accepted`; `rides` `Order Placed` /
`Order Accepted`; parcel / rental `Order Placed`); or, naming nobody and not
passed on by this driver, a legacy offer held in `orderRequestData`
(`Driver Pending`; rides also `Order Placed` / `Order Accepted`) or the parcel /
rental open search (`Order Placed`). Never from `Driver Rejected` or an ended
order. An offer whose window is over is answered as a timeout, never accepted
late.

| Write | Fields |
|---|---|
| order | `status: "Driver Accepted"`, `driverId: <me>`, `driverID: <me>`, `driver: <my profile snapshot>`; parcel adds `receiverPickupDateTime: now`; ride / rental add `regionId` when the order has none |
| `users/{me}` | `inProgressOrderID` arrayUnion id, `orderRequestData` arrayRemove id (ride: legacy `ordercabRequestData` deleted when it is this ride) |
| push | the customer: template `driver_accepted` (delivery, ride), `parcel_accepted`, `rental_accepted`; delivery also the store: `driver_accepted` |

Already this driver's job (retried tap, second device, the function already
moved it to `Order Shipped`): nothing is written, the job opens. **The app
never writes `Driver Accepted` back over `Order Shipped`**: every later
`vendor_orders` write is a transaction on the live status.

### 5.2 Reject (manual)

Precondition: `Driver Pending` naming this driver, or a hand assignment naming
this driver, or a legacy unnamed request the driver holds.

| Write | Fields |
|---|---|
| order | `status: "Driver Rejected"`, `rejectedByDrivers` arrayUnion `<me>`, `driverId: null`, `driverID: null` (set to null, not deleted, not `''`), `driverRejections` arrayUnion `{driverId, reason, code, at, afterAccept: false}` |
| `users/{me}` | `orderRequestData` arrayRemove id (and `inProgressOrderID` arrayRemove id, for a ride an older build put there) |

The reason is mandatory (reason sheet); backing out writes nothing. A pass
never writes the final cancellation fields (`cancelReason`, `cancelledBy`, ...).
The automatic decline of a ride outside the driver's region is a reject
without a reason.

### 5.3 Timeout

Precondition: still `Driver Pending` naming this driver (checked in the
transaction; idempotent, a second run finds it gone).

| Write | Fields |
|---|---|
| order | `status: "Driver Rejected"`, `rejectedByDrivers` arrayUnion `<me>`, `driverId: null`, `driverID: null`. **No reason, no `driverRejections` entry** |
| `users/{me}` | `orderRequestData` arrayRemove id |

### 5.4 Pass on an open order (parcel / rental search)

An `Order Placed` order that names nobody, taken from the search list: only
`rejectedByDrivers` arrayUnion `<me>` and the `driverRejections` reason; the
status stays (the functions already exclude `rejectedByDrivers`). If the order
was dispatched to this driver meanwhile, it is a normal reject (5.2).

### 5.5 Hand back after accept (ride or rental, before pickup)

`status: "Driver Rejected"`, `rejectedByDrivers` arrayUnion `<me>`,
`driverId: null`, `driverID: null`, `driver` deleted, `driverRejections`
arrayUnion `{..., afterAccept: true}`; `users/{me}.inProgressOrderID`
arrayRemove id. The function re-offers it like any rejected order.

### 5.6 Never

- a pending offer in `inProgressOrderID`;
- `Driver Pending`, or another driver's id in `driverId` / `driverID`, or
  another uid in `rejectedByDrivers`;
- a whole order model (it rolled back `rejectedByDrivers`, the parcel SMS
  fields and other drivers' writes).

---

## 6. The driver profile the app maintains (`users/{driverId}`)

| Field | How the app writes it |
|---|---|
| `role` | `driver` at sign-up |
| `isActive` | only the driver's online switch; profile saves never write it |
| `fcmToken` | field-level `update`, on start / sign-in / refresh; never `''` |
| `location` | `{latitude, longitude}` numbers by `update` from the location stream only (plus `rotation`); a fix without coordinates is skipped; profile saves never write it |
| `serviceTypes` | array, e.g. `["delivery-service", "parcel_delivery"]`. The legacy single `serviceType` is **deleted** on a profile save: the functions should read `serviceTypes` |
| `wallet_amount` | never by a profile save (wallet transactions only) |
| `zoneId` | the driver's zone; a company also has `zoneIds` (several, `zoneId` = the first) |
| `orderRequestData`, `inProgressOrderID` | created as empty lists at sign-up; afterwards **only** arrayUnion / arrayRemove (accept, reject, housekeeping). Profile saves never write them |
| `ordercabRequestData` | legacy ride request, only deleted |

**Housekeeping** (server data only): an id leaves `orderRequestData` when its
order is no longer dispatched to this driver (answered elsewhere, reassigned,
cancelled, deleted); an id this driver accepted moves to `inProgressOrderID`;
`inProgressOrderID` loses orders that ended or name another driver. So
`singleOrderReceive` never counts a driver as busy for good.

**Hand assignments without a push** (`driver_assignment_watcher.dart`): an
order assigned to the driver by the panel or the store is found from the order
record; a missing id is added to the driver's own `inProgressOrderID`
(accepted) or `orderRequestData` (pending hand assignment). The alert takes its
text from the `dynamic_notification` template `job_assigned`, else
`new_delivery_order`; with neither there is only an in-app toast.

---

## 7. What the customer and store apps show

**Customer** (`customer/lib/utils/booking_status_tabs.dart`):

| Status | Tab / label |
|---|---|
| `Driver Pending`, `Driver Rejected` | with the new bookings, chip **"Looking for a driver"**; never "Rejected" or Cancelled |
| `Driver Accepted`, `Order Shipped`, `In Transit` | on-going (parcel: in transit) |
| `Order Rejected`, `Order Cancelled` | cancelled (who and why from the cancellation fields) |

The driver is shown only once a driver accepted: never at `Order Placed`,
`Driver Pending`, `Driver Rejected` or `Quote Requested` (the functions write
the offered driver's id before anyone accepted); for an ended booking only if
the `driver` snapshot (written by the accept only) names the same driver.

The customer may cancel: rides at `Order Placed`, `Driver Pending`,
`Driver Rejected`, or `Order Accepted` with no driver (written as
`Order Rejected`); rentals at `Order Placed`, `Driver Pending`,
`Driver Rejected`, `Driver Accepted`; parcels at `Order Placed`,
`Quote Requested`, `Driver Pending`, `Driver Rejected` before hand-over. Each
cancel is a transaction on the live status writing only `status` and the
reason fields; from a status where no driver accepted it also sets `driverId`
and `driverID` to null (the offered driver comes off the booking). A ride the
function auto-cancels shows "Your ride was cancelled" with the reason when the
function writes one (section 8).

**Store** (`vendor/lib/utils/store_order_write.dart`): `Driver Pending` and
`Driver Rejected` read "Waiting for a delivery partner" (warning tone); "With
the delivery man" only at `Driver Accepted`, `Order Shipped`, `In Transit`
with a driver set. The order detail loads the delivery man by id when the
`driver` snapshot is missing or names someone else. Every store write
(accept, own delivery man, courier, reject, cancel, complete) is a guarded
transaction that writes only its own fields and never `driverId`,
`rejectedByDrivers` or `driverRejections` (except its own delivery man on self
delivery).

---

## 8. Asked of the Cloud Functions team

1. **Write `dispatchedAt` (server timestamp) on every `Driver Pending`
   dispatch**, next to `driverId` / `driverID`. The app already reads it (first
   of the names in section 4) and then needs no clock guesswork.
2. **A re-dispatch of the same order to the same driver is a new offer:** a
   fresh `dispatchedAt` and a new push.
3. **Check before writing `Driver Pending`, in a transaction,** that the order
   is still in the trigger status (`Order Accepted` / `Order Placed` /
   `Driver Rejected`) and not cancelled, completed or taken by the store's own
   delivery man meanwhile. Otherwise a cancel that lands mid-dispatch is
   overwritten.
4. **Time out server-side too.** The app's timeout runs only while the app is
   running (or when it next opens); a driver whose phone is off never answers.
   The function should treat an offer older than
   `driverOrderAcceptRejectDuration` as rejected (same writes as 5.3).
5. **Exclusions the apps expect:** takeaway and POS orders, self-delivery
   orders, scheduled orders before they are due, parcels bound to a carrier
   (`carrierId`: offered only to that carrier's drivers); drivers who are a store's own delivery men (`vendorID` set),
   company accounts (`isOwner: true`), offline drivers (`isActive` false), and
   everyone in `rejectedByDrivers`. A company's driver (`ownerId` set) should be
   checked against the company's wallet and `ownerMinimumDepositToRideAccept`,
   as the app does.
6. **Auto-cancel** (`orderAutoCancelDuration`): please write the cancellation
   fields of `CANCEL-REASON-CONTRACT.md` (`cancelledBy: "admin"` or a new
   `"system"`, `cancelReason`, `cancelReasonCode`, `cancelAction`,
   `cancelledAt`). Without them the customer sees "Your ride was cancelled"
   with no reason. Please also confirm which status the auto-cancel writes
   (the customer app treats `Order Rejected` and `Order Cancelled` alike).
7. **Push text** should come from `dynamic_notification` templates, like every
   app push, rather than fixed text in the function.
8. **`serviceTypes`:** read the array first (the app deletes the legacy
   `serviceType`).
9. **Order ringtone** (the admin's `settings/globalSettings.order_ringtone_url`
   as the sound of an offer in the background / with the app closed;
   `.claude/PUSH-CHANNELS.md` section "Order ringtone"). Per run (or cached
   for at most a minute), read `order_ringtone_url`, trim it; when it starts
   with `http://` or `https://`, compute
   `key` = 32-bit FNV-1a over its UTF-8 bytes as 8 lowercase hex digits:

   ```js
   function ringtoneKey(url) {
     const s = (url || '').trim();
     if (!/^https?:\/\//i.test(s)) return '';
     let h = 0x811c9dc5;
     for (const b of Buffer.from(s, 'utf8')) { h ^= b; h = Math.imul(h, 0x01000193) >>> 0; }
     return h.toString(16).padStart(8, '0');
   }
   // test vector: 'https://example.com/ring.mp3' -> '955470e2'
   ```

   and send the dispatch push with
   `android.notification.channelId: "driver_jobs_rt_<key>"` (keep
   `sound: "default"`, `android.priority: "high"`) and
   `apns.payload.aps.sound: "order_ringtone_<key>.caf"` (keep
   `apns-priority: 10`); data unchanged (the app recognises an offer by its
   data, section 3). With no ringtone (`key` empty): exactly today's payload
   (`channelId: "spideli"`, `aps.sound: "default"`). A driver device that has
   not prepared the key yet shows the push on `driver_notifications_channel`
   (the manifest default: heads-up, default tone) and iOS plays the default
   tone - nothing is lost or shown twice; it catches up when the app runs or
   any push reaches its background handler. The same rule, with
   `new_order_rt_<key>`, applies to `scheduledOrderNotifier`'s
   `scheduled_order_due` push to the store. Optional: on a change of
   `order_ringtone_url`, a data-only `{type: "ringtone_changed"}` push to the
   topics `driver` and `vendor` (no notification block; APNs background push)
   makes the apps prepare the new sound at once.

---

## 9. Rules

`firestore.rules.draft`, section "Driver dispatch" (not deployed): on the four
collections a client may write `Driver Accepted` only naming itself in both
fields from an order offered to it (or an unnamed one as in 5.1), `Driver
Rejected` only with both fields null and itself in `rejectedByDrivers`,
`rejectedByDrivers` only grown by its own uid, `driverId` / `driverID` cleared
only by the named driver, the customer cancelling before acceptance, or the
store for its own delivery men; nobody but the admin writes `Driver Pending`.
The functions use the Admin SDK and are not affected.

---

## 10. Files

| File | What |
|---|---|
| `driver/lib/services/dispatch_offer_rules.dart` | pure rules: push parsing, settings, timing, accept / reject checks and field maps, offer summary |
| `driver/lib/services/dispatch_offer_service.dart` | the accept / reject / timeout / pass transactions |
| `driver/lib/services/assigned_delivery_orders.dart` | the same for `vendor_orders` |
| `driver/lib/services/incoming_offer_service.dart` | listeners, push entry, countdown, housekeeping |
| `driver/lib/services/offer_seen_store.dart` | first-seen times (also from the background isolate) |
| `driver/lib/app/incoming_offer/incoming_offer_dialog.dart` | the dialog |
| `driver/lib/services/driver_assignment_watcher.dart` | hand assignments without a push |
| `driver/lib/utils/notification_service.dart`, `driver/lib/services/push_message.dart` | the `spideli` channel and push routing |
| `customer/lib/utils/booking_status_tabs.dart` | the customer's tabs, labels and the offered-driver rule |
| `vendor/lib/utils/store_order_write.dart` | the store's guarded order writes |
