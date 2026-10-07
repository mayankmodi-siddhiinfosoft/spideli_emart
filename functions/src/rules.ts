/**
 * Pure rules of the scheduled-order notifier: no Firebase here, so every rule
 * is unit tested (`test/rules.test.js`).
 *
 * They mirror the Store app (`vendor/lib/utils/scheduled_order.dart`,
 * `ScheduledOrderRule`): an `Order Placed` order with a `scheduleTime` is due
 * at `scheduleTime - lead`, where the lead comes from
 * `settings/scheduleOrderNotification` (`notifyTime` + `timeUnit`).
 */

/** The only status a scheduled order waits in (`Constant.orderPlaced`). */
export const ORDER_PLACED = "Order Placed";

/** Order field the customer app writes `false` for an order placed for later. */
export const SENT_FIELD = "scheduledNotificationSent";

/** Server time at which the store was notified (or the order was skipped). */
export const SENT_AT_FIELD = "scheduledNotificationAt";

/** Why an order was marked without a push (e.g. it was cancelled first). */
export const SKIPPED_FIELD = "scheduledNotificationSkipped";

/** `data.type` of the push; the Store app routes it to its orders (New). */
export const PUSH_TYPE = "scheduled_order_due";

/** `dynamic_notification` template whose `subject` / `message` is the text. */
export const TEMPLATE_TYPE = "schedule_order";

/** The Store app's loud new-order channel and tone (`.claude/PUSH-CHANNELS.md`). */
export const STORE_ORDER_CHANNEL = "new_order";
export const STORE_ORDER_ANDROID_SOUND = "order_alert";
export const STORE_ORDER_APNS_SOUND = "order_alert.caf";

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;

/**
 * Dart's `'${value ?? ''}'`: how the Store app turns a Firestore value into a
 * string before parsing it.
 */
function dartString(value: unknown): string {
  if (value === null || value === undefined) return "";
  return String(value);
}

/**
 * Dart's `int.tryParse` (radix 10): optional sign, then decimal digits, or
 * `0x` + hex digits. Anything else is null. Whitespace is trimmed first.
 */
export function dartIntTryParse(raw: string): number | null {
  const s = raw.trim();
  let value: number;
  if (/^[+-]?\d+$/.test(s)) {
    value = Number.parseInt(s, 10);
  } else if (/^[+-]?0x[0-9a-f]+$/i.test(s)) {
    const negative = s.startsWith("-");
    value = Number.parseInt(s.replace(/^[+-]/, "").slice(2), 16);
    if (negative) value = -value;
  } else {
    return null;
  }
  return Number.isSafeInteger(value) ? value : null;
}

/**
 * The admin's lead time in milliseconds, read exactly like
 * `ScheduledOrderRule.leadTime`: [notifyTime] (number or string; unreadable =
 * 0) in [timeUnit] `minute` / `hour` / `day`; any other unit (also a missing
 * one) is ONE minute whatever the number; never negative.
 *
 * A missing `settings/scheduleOrderNotification` document is the app's
 * default (`'0'` `'minute'`): 0.
 */
export function leadTimeMs(notifyTime: unknown, timeUnit: unknown): number {
  const value = dartIntTryParse(dartString(notifyTime)) ?? 0;
  let lead: number;
  switch (dartString(timeUnit).trim()) {
    case "minute":
      lead = value * MINUTE_MS;
      break;
    case "hour":
      lead = value * HOUR_MS;
      break;
    case "day":
      lead = value * DAY_MS;
      break;
    default:
      lead = MINUTE_MS;
  }
  return lead < 0 ? 0 : lead;
}

/** A Firestore `Timestamp` (or anything with `toMillis()`), a `Date`, or epoch ms. */
export function toMillis(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (value instanceof Date) {
    const ms = value.getTime();
    return Number.isFinite(ms) ? ms : null;
  }
  if (typeof value === "object" && typeof (value as { toMillis?: unknown }).toMillis === "function") {
    const ms = (value as { toMillis: () => number }).toMillis();
    return Number.isFinite(ms) ? ms : null;
  }
  return null;
}

/** When the store can act on an order: `scheduleTime - lead` (ms), or null. */
export function dueAtMs(scheduleTime: unknown, leadMs: number): number | null {
  const at = toMillis(scheduleTime);
  return at === null ? null : at - leadMs;
}

export type Decision =
  /** Already notified (or marked): nothing to do. */
  | { kind: "done" }
  /** No longer `Order Placed` (accepted, cancelled, ...): mark, never push. */
  | { kind: "skip"; status: string }
  /** Still waiting for its due time. */
  | { kind: "wait"; dueAtMs: number }
  /** Due now: claim it and push the store. */
  | { kind: "notify"; dueAtMs: number | null };

/**
 * What to do with one order whose `scheduledNotificationSent` was false, at
 * [nowMs]. Used for the query result AND again inside the transaction, on the
 * fresh read, so overlapping runs notify at most once.
 *
 * An order with no readable `scheduleTime` is due at once (the Store app
 * lists it under New as well).
 */
export function decide(order: Record<string, unknown> | undefined, nowMs: number, leadMs: number): Decision {
  if (!order) return { kind: "done" };
  if (order[SENT_FIELD] === true) return { kind: "done" };
  const status = dartString(order.status);
  if (status !== ORDER_PLACED) return { kind: "skip", status };
  const due = dueAtMs(order.scheduleTime, leadMs);
  if (due !== null && due > nowMs) return { kind: "wait", dueAtMs: due };
  return { kind: "notify", dueAtMs: due };
}

/** A usable FCM token: not empty, not the string "null" the apps used to write. */
export function usableToken(token: unknown): token is string {
  if (typeof token !== "string") return false;
  const t = token.trim();
  return t.length > 0 && t !== "null" && t !== "undefined";
}

export interface Template {
  title: string;
  body: string;
}

/**
 * The template's text (`subject` / `message`), or null when there is none.
 * No text is invented here: the admin owns the wording.
 */
export function templateText(doc: Record<string, unknown> | undefined): Template | null {
  if (!doc) return null;
  const title = dartString(doc.subject).trim();
  const body = dartString(doc.message).trim();
  if (title.length === 0 && body.length === 0) return null;
  return { title, body };
}

/** The FCM message (Admin SDK shape) for one due order. Values are strings. */
export interface DueMessage {
  token: string;
  notification?: { title: string; body: string };
  data: { type: string; orderId: string };
  android: {
    priority: "high";
    notification?: { channelId: string; sound: string };
  };
  apns: {
    headers: Record<string, string>;
    payload: { aps: { sound?: string; "content-available"?: number } };
  };
}

/**
 * The push to the store owner. With template text: a normal notification on
 * the Store app's loud `new_order` channel with the order tone (iOS
 * `order_alert.caf`). Without (template missing or empty): a DATA-ONLY push,
 * nothing shown, so the app (in the foreground) still moves the order to New
 * and rings in-app; an empty visible notification is never sent.
 */
export function buildDueMessage(token: string, orderId: string, text: Template | null): DueMessage {
  const data = { type: PUSH_TYPE, orderId };
  if (text) {
    return {
      token: token.trim(),
      notification: { title: text.title, body: text.body },
      data,
      android: {
        priority: "high",
        notification: { channelId: STORE_ORDER_CHANNEL, sound: STORE_ORDER_ANDROID_SOUND },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: STORE_ORDER_APNS_SOUND } },
      },
    };
  }
  return {
    token: token.trim(),
    data,
    android: { priority: "high" },
    apns: {
      // Apple requires priority 5 and push type `background` for a push that
      // only has `content-available`.
      headers: { "apns-priority": "5", "apns-push-type": "background" },
      payload: { aps: { "content-available": 1 } },
    },
  };
}

/** FCM error codes meaning the token is dead (the owner's app replaces it). */
export function isDeadTokenError(code: unknown): boolean {
  return code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token";
}
