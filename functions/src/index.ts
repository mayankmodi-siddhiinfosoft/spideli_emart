/**
 * scheduledOrderNotifier: tells a store about an order placed for a later
 * time when it becomes due, once.
 *
 * The customer app writes `scheduledNotificationSent: false` on such an order
 * and sends no push. Every minute this function:
 *  1. reads the admin lead time (`settings/scheduleOrderNotification`);
 *  2. queries `vendor_orders` where `scheduledNotificationSent == false`
 *     (one equality filter: the automatic single-field index, no composite
 *     index) and filters in code;
 *  3. for an order that is due (`scheduleTime - lead <= now`), claims it in a
 *     transaction (re-read: still `Order Placed` and not yet sent ->
 *     `scheduledNotificationSent: true`, `scheduledNotificationAt`), then
 *     pushes the store owner (`users/{vendor.author}.fcmToken`);
 *  4. marks an order that is no longer `Order Placed` as handled, without a
 *     push.
 * See README.md.
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { runOnce } from "./notifier";

initializeApp();

/** Same region as the project's other functions (`deleteUser`). */
const REGION = "us-central1";

export const scheduledOrderNotifier = onSchedule(
  {
    schedule: "every 1 minutes",
    region: REGION,
    timeZone: "Etc/UTC",
    // A failed run is not retried: the next run, a minute later, picks the
    // orders up again (nothing is claimed by a run that failed before it).
    retryCount: 0,
    maxInstances: 1,
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    await runOnce(getFirestore(), Date.now());
  },
);
