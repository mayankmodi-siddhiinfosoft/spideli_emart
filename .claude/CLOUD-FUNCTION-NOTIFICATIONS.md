# Cloud Functions — notification code

Two notifications sent from Cloud Functions:

1. **Scheduled order → Store.** When an order placed for a later time becomes
   due, the store owner gets a new-order notification, once.
2. **Order accepted → Driver.** When the store accepts a delivery order, the
   driver the dispatch assigns gets a new-order notification.

**Scope: notification code only.** Nothing in this document changes how
drivers are chosen, how orders move between statuses, sign-in, payments or
any other existing Cloud Function logic. Where code is added to an existing
function, it is a single call placed after the existing logic has done its
work.

The apps are already built for both notifications (Store, Driver and
Customer apps on branch `feature/restaurant-app-panel-parity`). The code
below sends exactly what they expect.

---

## 0. Summary

| | Scheduled order → Store | Order accepted → Driver |
|---|---|---|
| Runs | every minute (`onSchedule`) | inside the existing `deliveryDispatch`, right after it assigns the driver |
| Recipient | store owner: `users/{order.vendor.author}.fcmToken` | assigned driver: `users/{driverId}.fcmToken` |
| Title / body | `dynamic_notification` template `schedule_order` | `dynamic_notification` template `new_delivery_order` |
| `data` | `{ type: "scheduled_order_due", orderId }` | `{ click_action: "FLUTTER_NOTIFICATION_CLICK", type: "order", id, orderId, status: "Driver Pending" }` |
| Android channel | `new_order_rt_<key>` when an admin ringtone is set, else `new_order` | `driver_jobs_rt_<key>` when an admin ringtone is set, else `spideli` |
| iOS sound | `order_ringtone_<key>.caf`, else `order_alert.caf` | `order_ringtone_<key>.caf`, else `default` |
| Sent | once per order (claimed in a transaction) | once per assignment (each new driver after a reject gets their own) |

`<key>` is worked out from the admin's ringtone URL
(`settings/globalSettings.order_ringtone_url`) with the function in §1. The
apps compute the same key, so the channel and sound file named in the push
are the ones the phone has set up. A phone that has not set them up yet falls
back to its default order channel and sound; nothing is lost.

---

## 1. Shared helper — `notifications.js`

Add this file next to the existing functions. It only builds and sends
notifications; it does not change any data.

```js
// notifications.js — notification helpers shared by the functions below.
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const logger = require('firebase-functions/logger');

/** A token that can be sent to (the apps used to write "" or "null"). */
function usableToken(token) {
  if (typeof token !== 'string') return false;
  const t = token.trim();
  return t.length > 0 && t !== 'null' && t !== 'undefined';
}

/**
 * The admin ringtone key: 32-bit FNV-1a of the trimmed URL, 8 hex digits.
 * Must stay identical to the apps' OrderRingtone.keyFor.
 * Test vector: 'https://example.com/ring.mp3' -> '955470e2'.
 */
function ringtoneKey(url) {
  const s = (url || '').trim();
  if (!/^https?:\/\//i.test(s)) return '';
  let h = 0x811c9dc5;
  for (const b of Buffer.from(s, 'utf8')) {
    h ^= b;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, '0');
}

/** The current admin ringtone key ('' when none is set). Read on every send. */
async function currentRingtoneKey() {
  try {
    const snap = await getFirestore().doc('settings/globalSettings').get();
    return ringtoneKey(snap.get('order_ringtone_url'));
  } catch (e) {
    logger.warn('notifications: could not read the ringtone setting', { error: String(e) });
    return '';
  }
}

/**
 * Title and body from the admin's dynamic_notification template, or null.
 * No text is written in code: the admin owns the wording.
 */
async function templateText(type) {
  try {
    const snap = await getFirestore().collection('dynamic_notification').where('type', '==', type).limit(1).get();
    if (snap.empty) return null;
    const d = snap.docs[0].data();
    const title = String(d.subject ?? '').trim();
    const body = String(d.message ?? '').trim();
    return title || body ? { title, body } : null;
  } catch (e) {
    logger.error('notifications: reading the template failed', { type, error: String(e) });
    return null;
  }
}

/** FCM errors meaning the token is dead (the app saves a new one on its next start). */
function isDeadToken(code) {
  return code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token';
}

/** Sends one message; never throws, never logs the token. */
async function send(message, context) {
  try {
    await getMessaging().send(message);
    logger.info('notification sent', context);
    return true;
  } catch (e) {
    const code = e && e.code;
    if (isDeadToken(code)) logger.warn('notification: recipient token no longer registered', { ...context, code });
    else logger.error('notification failed', { ...context, code, error: String(e && e.message).replace(/[A-Za-z0-9_\-:]{60,}/g, '<redacted>') });
    return false;
  }
}

module.exports = { usableToken, ringtoneKey, currentRingtoneKey, templateText, send };
```

---

## 2. Scheduled order → Store

### What the apps already do

- **Customer app:** an order placed for a later time is saved in
  `vendor_orders` with `status: "Order Placed"`, `scheduleTime` and
  `scheduledNotificationSent: false`, and **no push** is sent to the store
  when it is placed. An order for "now" keeps today's immediate push.
- **Store app:** while open, it shows the order in its **Scheduled** tab and
  moves it to **New** (ringing) when it is due. When the Store app is in the
  background or closed, only this function's push tells the store.
- **Lead time:** `settings/scheduleOrderNotification` — `notifyTime` (number)
  and `timeUnit` (`minute` / `hour` / `day`). The order is due at
  `scheduleTime − lead`. A missing document means a lead of 0. Any other unit
  means one minute.

### The function — `scheduledOrderNotifier.js`

It runs every minute, finds due orders, claims each one in a transaction (so
it is sent **once**, even if two runs overlap), then pushes the store owner.
The only fields it writes are the notification flags
`scheduledNotificationSent`, `scheduledNotificationAt` and, for an order that
was already accepted or cancelled, `scheduledNotificationSkipped`. It never
changes the order's status.

```js
// scheduledOrderNotifier.js
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');
const { usableToken, currentRingtoneKey, templateText, send } = require('./notifications');

const ORDER_PLACED = 'Order Placed';
const SENT = 'scheduledNotificationSent';
const SENT_AT = 'scheduledNotificationAt';
const SKIPPED = 'scheduledNotificationSkipped';
const PUSH_TYPE = 'scheduled_order_due';   // the Store app routes this to New
const TEMPLATE = 'schedule_order';

/** Lead time in ms, read exactly like the Store app. */
function leadMs(notifyTime, timeUnit) {
  const n = Number.parseInt(String(notifyTime ?? '').trim(), 10);
  const value = Number.isFinite(n) ? n : 0;
  const unit = String(timeUnit ?? '').trim();
  const ms = unit === 'minute' ? value * 60e3 : unit === 'hour' ? value * 3600e3 : unit === 'day' ? value * 86400e3 : 60e3;
  return ms < 0 ? 0 : ms;
}

function toMillis(v) {
  if (v == null) return null;
  if (typeof v === 'number') return v;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v instanceof Date) return v.getTime();
  return null;
}

/** done | skip | wait | notify — run on the query result AND again inside the transaction. */
function decide(order, now, lead) {
  if (!order || order[SENT] === true) return { kind: 'done' };
  if (order.status !== ORDER_PLACED) return { kind: 'skip', status: String(order.status ?? '') };
  const at = toMillis(order.scheduleTime);
  if (at !== null && at - lead > now) return { kind: 'wait' };
  return { kind: 'notify' };
}

/** The push to the store owner. */
function storeMessage(token, orderId, text, key) {
  const data = { type: PUSH_TYPE, orderId };
  if (!text) {
    // No template text: data-only, nothing empty is shown; the Store app
    // still moves the order to New when it runs.
    return {
      token,
      data,
      android: { priority: 'high' },
      apns: { headers: { 'apns-priority': '5', 'apns-push-type': 'background' }, payload: { aps: { 'content-available': 1 } } },
    };
  }
  return {
    token,
    notification: { title: text.title, body: text.body },
    data,
    android: {
      priority: 'high',
      notification: { channelId: key ? `new_order_rt_${key}` : 'new_order', sound: 'order_alert' },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: { sound: key ? `order_ringtone_${key}.caf` : 'order_alert.caf' } },
    },
  };
}

/** The store owner's uid: order.vendor.author, else vendors/{vendorID}.author. */
async function ownerOf(db, order) {
  const author = String(order?.vendor?.author ?? '').trim();
  if (author) return author;
  const vendorId = String(order?.vendorID ?? '').trim();
  if (!vendorId) return null;
  const store = await db.collection('vendors').doc(vendorId).get();
  const a = String(store.get('author') ?? '').trim();
  return a || null;
}

exports.scheduledOrderNotifier = onSchedule(
  // Use the same region as the project's other functions.
  { schedule: 'every 1 minutes', region: 'us-central1', timeZone: 'Etc/UTC', retryCount: 0, maxInstances: 1, timeoutSeconds: 120, memory: '256MiB' },
  async () => {
    const db = getFirestore();
    const now = Date.now();
    const settings = await db.doc('settings/scheduleOrderNotification').get();
    const lead = settings.exists ? leadMs(settings.get('notifyTime'), settings.get('timeUnit')) : 0;

    // One equality filter: covered by Firestore's automatic index.
    const pending = await db.collection('vendor_orders').where(SENT, '==', false).get();
    if (pending.empty) return;

    let text;   // template, read once per run when first needed
    let key;    // ringtone key, read once per run when first needed
    for (const doc of pending.docs) {
      const first = decide(doc.data(), now, lead);
      if (first.kind === 'wait' || first.kind === 'done') continue;
      try {
        // Claim: only one run can mark the order, so it is pushed at most once.
        const claim = await db.runTransaction(async (tx) => {
          const snap = await tx.get(doc.ref);
          const d = decide(snap.data(), now, lead);
          if (d.kind === 'notify') {
            tx.update(doc.ref, { [SENT]: true, [SENT_AT]: FieldValue.serverTimestamp() });
            return { kind: 'notify', order: snap.data() };
          }
          if (d.kind === 'skip') {
            // Accepted / cancelled before it was due: mark it, never push.
            tx.update(doc.ref, { [SENT]: true, [SENT_AT]: FieldValue.serverTimestamp(), [SKIPPED]: d.status || 'unknown' });
          }
          return { kind: d.kind };
        });
        if (claim.kind !== 'notify') continue;

        const owner = await ownerOf(db, claim.order);
        if (!owner) { logger.warn('scheduled order: no store owner', { orderId: doc.id }); continue; }
        const token = (await db.collection('users').doc(owner).get()).get('fcmToken');
        if (!usableToken(token)) { logger.warn('scheduled order: store owner has no FCM token', { orderId: doc.id, owner }); continue; }

        if (text === undefined) text = await templateText(TEMPLATE);
        if (key === undefined) key = await currentRingtoneKey();
        await send(storeMessage(token.trim(), doc.id, text, key), { kind: PUSH_TYPE, orderId: doc.id, owner });
      } catch (e) {
        logger.error('scheduled order: handling failed', { orderId: doc.id, error: String(e) });
      }
    }
  },
);
```

### Export it — `index.js`

```js
// add next to the existing exports; nothing else in index.js changes
exports.scheduledOrderNotifier = require('./scheduledOrderNotifier').scheduledOrderNotifier;
```

If the project already has a scheduled-order function, keep its
scheduling and query logic, and replace only its push call with
`storeMessage(...)` + `send(...)` above, so the `data`, channel and sound match
what the Store app expects.

---

## 3. Order accepted → assigned Driver

### Where it goes

The store accepting a delivery order sets `vendor_orders/{id}.status` to
`Order Accepted`. The existing `deliveryDispatch` function reacts to that (and
to `Driver Rejected`), picks the driver and writes the assignment:
`status: "Driver Pending"`, `driverId` / `driverID`, and the order id in
`users/{driverId}.orderRequestData`. **That logic stays as it is.**

Add one call **after** the assignment has been written successfully. If
`deliveryDispatch` already sends a push to the driver, **replace** that send
with this call, so the driver does not get two notifications.

### The helper — add to `notifications.js` (or a new `driverNotifications.js`)

```js
// driverNotifications.js
const { getFirestore } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');
const { usableToken, currentRingtoneKey, templateText, send } = require('./notifications');

const TEMPLATE = 'new_delivery_order';   // dynamic_notification type for the text

/**
 * Notifies the driver just assigned to [orderId].
 * [type] is the service: 'order' (food / e-commerce delivery), and — if the
 * same helper is used by the other dispatch functions — 'parcel', 'cab', 'rental'.
 */
async function notifyAssignedDriver(orderId, driverId, type = 'order') {
  if (!orderId || !driverId) return false;
  const driver = await getFirestore().collection('users').doc(driverId).get();
  const token = driver.get('fcmToken');
  if (!usableToken(token)) {
    // The Driver app still finds the offer from orderRequestData / "Driver Pending" when it opens.
    logger.warn('order accepted: assigned driver has no FCM token', { orderId, driverId });
    return false;
  }
  const text = await templateText(TEMPLATE);
  const key = await currentRingtoneKey();
  return send(
    {
      token: token.trim(),
      ...(text ? { notification: { title: text.title, body: text.body } } : {}),
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        type,                      // the Driver app opens its incoming-order popup for this type
        id: orderId,
        orderId,
        status: 'Driver Pending',
      },
      android: {
        priority: 'high',
        notification: { channelId: key ? `driver_jobs_rt_${key}` : 'spideli', sound: 'default' },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { sound: key ? `order_ringtone_${key}.caf` : 'default', 'content-available': 1 } },
      },
    },
    { kind: 'order_accepted_driver', orderId, driverId },
  );
}

module.exports = { notifyAssignedDriver };
```

### The one-line change inside `deliveryDispatch`

```js
const { notifyAssignedDriver } = require('./driverNotifications');

// ... existing deliveryDispatch code, unchanged ...
//     it chooses `driverId` and writes:
//       vendor_orders/{orderId}: status "Driver Pending", driverId, driverID
//       users/{driverId}.orderRequestData: arrayUnion(orderId)

// NEW — after that write has succeeded (and instead of any existing push to the driver):
await notifyAssignedDriver(orderId, driverId, 'order');
```

The same call works in `parcelDispatch`, `cabDispatch` and `rentalDispatch`
with `'parcel'`, `'cab'` and `'rental'` if those functions should send the same
payload; that is optional and not part of this change.

---

## 4. Final payloads (for checking)

**Scheduled order → Store** (admin ringtone set, key `955470e2`):

```json
{
  "token": "<store owner fcmToken>",
  "notification": { "title": "<schedule_order subject>", "body": "<schedule_order message>" },
  "data": { "type": "scheduled_order_due", "orderId": "<orderId>" },
  "android": { "priority": "high", "notification": { "channelId": "new_order_rt_955470e2", "sound": "order_alert" } },
  "apns": { "headers": { "apns-priority": "10" }, "payload": { "aps": { "sound": "order_ringtone_955470e2.caf" } } }
}
```

Without a ringtone: `channelId: "new_order"`, iOS `sound: "order_alert.caf"`.

**Order accepted → Driver** (admin ringtone set):

```json
{
  "token": "<driver fcmToken>",
  "notification": { "title": "<new_delivery_order subject>", "body": "<new_delivery_order message>" },
  "data": { "click_action": "FLUTTER_NOTIFICATION_CLICK", "type": "order", "id": "<orderId>", "orderId": "<orderId>", "status": "Driver Pending" },
  "android": { "priority": "high", "notification": { "channelId": "driver_jobs_rt_955470e2", "sound": "default" } },
  "apns": { "headers": { "apns-priority": "10" }, "payload": { "aps": { "sound": "order_ringtone_955470e2.caf", "content-available": 1 } } }
}
```

Without a ringtone: `channelId: "spideli"`, iOS `sound: "default"`.

All `data` values must be strings (FCM rejects the message otherwise).

---

## 5. Templates the admin must have in `dynamic_notification`

| `type` | Used for | Example `subject` / `message` (the admin writes the real wording) |
|---|---|---|
| `schedule_order` | Scheduled order → Store | "Scheduled order due" / "A scheduled order is ready to be prepared." |
| `new_delivery_order` | Order accepted → Driver | "New delivery order" / "You have a new delivery order. Please accept it in time." |

- **Store, no template:** the store gets a silent data push. The Store app
  still moves the order to New when it runs.
- **Driver, no template:** the push has no visible title or text. Create the
  template before deploying.

---

## 6. Deploy and test

```bash
firebase deploy --only functions:scheduledOrderNotifier,functions:deliveryDispatch --project spideli-870b0
```

`onSchedule` needs the Blaze plan, plus Cloud Scheduler enabled on the project.

**Scheduled order → Store**

1. In the Customer app, place an order for about 10 minutes ahead.
   `vendor_orders/{id}.scheduledNotificationSent` should be `false`, and the
   store gets no push now.
2. Close the Store app. At `scheduleTime − lead`, the store owner's phone
   rings with the order sound. The order now has
   `scheduledNotificationSent: true`.
3. Tap the notification: the Store app opens on New with that order.
4. Accept or cancel a scheduled order before it is due. It is marked with
   `scheduledNotificationSkipped` and no push is sent.
5. Logs: `firebase functions:log --only scheduledOrderNotifier`.

**Order accepted → Driver**

1. With a driver online and the Driver app closed, place a delivery order and
   accept it in the Store app.
2. `deliveryDispatch` assigns the driver: the order is `Driver Pending`. The
   driver's phone rings with the order sound. Tapping it opens the
   incoming-order popup with Accept / Reject.
3. Reject it: the existing dispatch assigns the next driver, who gets the
   same notification.
4. Logs: `firebase functions:log --only deliveryDispatch`. Look for
   `notification sent` with `kind: order_accepted_driver`.

---

## 7. Rules for this change

- **Text:** only from `dynamic_notification` templates, never written in code.
- **One notification per event:**
  - scheduled orders are claimed in a transaction;
  - the driver push replaces any push `deliveryDispatch` already sends.
- **Fields written:** the scheduled-order notification flags only. Never
  `status`, `isActive`, wallet, driver or sign-in fields.
- **Logging:** tokens are never logged.
- **Ringtone key:** must stay identical to the apps' (`OrderRingtone.keyFor`).
  Check it with the test vector in §1.
