# Spideli Cloud Functions (`push` codebase)

One function: **`scheduledOrderNotifier`**. It tells a store about an order
placed for a later time when that order becomes due, exactly once. It replaces
the Store app's phone alarms (removed), so the store needs no "Alarms &
reminders" permission and is notified even when its app is closed.

Source: `src/index.ts` (trigger), `src/notifier.ts` (one run), `src/rules.ts`
(pure rules, unit tested in `test/rules.test.js`).

## What it does

Runs **every minute** (Cloud Scheduler, region `us-central1`, the region of the
project's other functions). Each run:

1. Reads the admin lead time from `settings/scheduleOrderNotification`
   (`notifyTime` + `timeUnit`), exactly like the Store app's
   `ScheduledOrderRule.leadTime` (`vendor/lib/utils/scheduled_order.dart`):
   `notifyTime` is a number or a numeric string (unreadable = 0); `timeUnit`
   `minute` / `hour` / `day`; **any other or missing unit counts as 1 minute**;
   never negative. No document = 0 (the scheduled time itself).
2. Queries `vendor_orders` **where `scheduledNotificationSent == false`** (one
   equality filter, so Firestore's automatic single-field index is enough: **no
   composite index**). Everything else is filtered in code.
3. For each order: **due** when `scheduleTime - lead <= now` (an order with no
   readable `scheduleTime` is due at once, as the Store app lists it under New).
   A due order is claimed in a **transaction** that re-reads it and only if it
   is still `status == "Order Placed"` and `scheduledNotificationSent != true`
   sets `scheduledNotificationSent: true` and `scheduledNotificationAt:
   serverTimestamp()`. Only the run that claimed it sends the push, so
   overlapping runs notify once (checked on the Firestore emulator with three
   concurrent runs).
4. An order that is **no longer `Order Placed`** (cancelled, rejected, ...) is
   never pushed: the transaction marks it `scheduledNotificationSent: true`,
   `scheduledNotificationAt`, `scheduledNotificationSkipped: "<its status>"`,
   so it leaves the query.
5. The push goes to the store owner's **current** token
   `users/{order.vendor.author}.fcmToken` (when the order has no
   `vendor.author`: `vendors/{vendorID}.author`). No token: logged, nothing
   sent. Message:
   - `notification`: `subject` / `message` of the `dynamic_notification`
     document with `type == "schedule_order"` (the existing template; no text
     in code);
   - `data`: `{type: "scheduled_order_due", orderId}` (strings);
   - `android`: `priority: high`, `notification.channel_id: new_order`,
     `sound: order_alert` (the Store app's loud order channel);
   - `apns`: `apns-priority: 10`, `aps.sound: order_alert.caf`.

   **Template missing or empty:** a warning is logged and the push is sent
   **data-only** (same `data`, Android high priority, APNs background push:
   `apns-priority: 5`, `apns-push-type: background`, `content-available: 1`).
   Nothing is shown, but a Store app in the foreground still moves the order to
   New and rings in-app. Add the template text to get a visible notification.
6. A failed push is logged (FCM error code, order id, owner uid; never the
   token) and **not retried**: the order is already claimed (at most once). An
   `UNREGISTERED` token is logged; the owner's app writes a fresh token on its
   next start.

In the Store app, the push shows on the `new_order` channel (system in the
background; the app's own foreground display otherwise). In the foreground it
also moves the order from Scheduled to New at once; a tap opens the orders
(New) tab.

### Orders placed before this change

Orders written without `scheduledNotificationSent` (every order placed before
this customer-app build) are **not picked up**: the query only matches
`== false`. They still move from Scheduled to New in the Store app at their due
time while the app is open, as before, but get no push. If some are still
waiting when this goes live, set `scheduledNotificationSent: false` on those
`vendor_orders` documents (status `Order Placed`, `scheduleTime` in the
future) in the console, and the next run handles them. Older customer builds
(before the scheduled-order change) still send the `schedule_order` push when
the order is PLACED and write no field.

Only the default Firestore database is read (not the `staging` named database).

## Deploy (not done yet)

Requirements:

- The **Blaze** (pay-as-you-go) plan on `spideli-870b0`: scheduled functions
  need Cloud Scheduler, and 2nd-gen functions need Cloud Build / Artifact
  Registry / Cloud Run (the first deploy enables these APIs).
- The Firebase CLI signed in with an account that has access to
  `spideli-870b0` (Owner, or Editor + Cloud Functions Admin). The CLI on the
  development Mac is currently signed in with an account that has **no
  access** to this project:

  ```sh
  firebase logout
  firebase login            # an account with access to spideli-870b0
  firebase projects:list    # spideli-870b0 must be listed
  ```

Steps, from the repository root:

```sh
npm --prefix functions install
npm --prefix functions test        # builds and runs the unit tests
firebase deploy --only functions:push:scheduledOrderNotifier --project spideli-870b0
```

(or `npm --prefix functions run deploy`). `firebase.json` declares this folder
as the **`push` codebase**, so the filter must name the codebase:
`functions:push:scheduledOrderNotifier`. A plain
`--only functions:scheduledOrderNotifier` looks in the `default` codebase and
deploys nothing. Do not run a bare `firebase deploy --only functions`: it would
offer to delete functions of the `push` codebase that are not in this folder.
`firebase.json` has no `firestore` section, so no deploy from this repo touches
the live rules or indexes. The runtime is Node.js 22, as `firebase.json`
already sets (`runtime: nodejs22`; Node.js 20 reached end of life in April
2026).

Check it runs: `npm --prefix functions run logs`, or Cloud Console > Cloud
Scheduler (job `firebase-schedule-scheduledOrderNotifier-us-central1`). Every
run logs `scheduled orders run` with `pending` / `waiting` / `notified` /
`skipped` counts. Remove: `firebase functions:delete scheduledOrderNotifier
--region us-central1 --project spideli-870b0`.

## Admin: the lead time

`settings/scheduleOrderNotification`:

| Field | Value | Meaning |
|---|---|---|
| `notifyTime` | e.g. `"15"` or `15` | how long before the scheduled time the store is notified |
| `timeUnit` | `"minute"`, `"hour"` or `"day"` | unit of `notifyTime` (anything else = 1 minute) |

`notifyTime: "0"`, `timeUnit: "minute"` (or no document) notifies at the
scheduled time. The Store app uses the same setting to move the order from
Scheduled to New. Changes apply on the next run (within a minute).

The text is the `dynamic_notification` template with `type: "schedule_order"`
(`subject` = title, `message` = body), edited in the admin panel like the other
templates.

## Cost

One run per minute: about 43,200 invocations a month (inside the free 2M), one
Cloud Scheduler job (3 free per billing account, then about $0.10 a month).
Firestore reads per run: 1 (settings) + 1 per order still waiting (at least 1
for an empty query) + the claim / template / token reads for due orders. Idle,
that is about 2,900 reads a day; each waiting scheduled order adds 1,440 reads
a day until it is due. Writes: one per notified or skipped order.

## Develop

```sh
npm install
npm run build      # TypeScript -> lib/
npm test           # build + node --test test/
```
