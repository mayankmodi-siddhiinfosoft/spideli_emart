/**
 * Request validation and FCM message building for sendPush.
 *
 * Pure: no Firebase calls, so it is unit tested directly (test/payload.test.js).
 *
 * The message is the one the five apps build for FCM HTTP v1 themselves on the
 * legacy path (`PushPayload.fcmV1Message` and its twins, see
 * .claude/PUSH-CHANNELS.md):
 *
 *   { token,
 *     notification: { title, body },
 *     data: { ...string values },
 *     android: { priority: "high", notification: { channel_id, sound } },
 *     apns: { headers: { "apns-priority": "10" },
 *             payload: { aps: { sound, "content-available": 1 } } } }
 *
 * The sender picks the RECEIVING app's channel and sounds and passes them as
 * `android.channelId`, `android.sound` and `apns.sound`. When a caller leaves
 * them out (an older build), `kind` selects the same defaults the apps use for
 * a new store order or a driver job; otherwise the receiving app's manifest
 * default channel and the default sound apply.
 *
 * Leniency, on purpose: a push that is refused is a push nobody sees, and the
 * apps do not retry. So input the apps would have converted is converted here
 * the same way (data values to strings, over-long text clipped, FCM-reserved
 * data keys dropped, unknown fields and malformed channel/sound overrides
 * ignored), and the response lists what was changed. Only what cannot be sent
 * at all is refused: no or malformed target, wrong types for title/body,
 * nothing to send, data over FCM's size limit.
 */
import type { Message } from "firebase-admin/messaging";

export const LIMITS = {
  /** Characters (Unicode code points); longer text is clipped. */
  titleChars: 200,
  bodyChars: 1000,
  /** UTF-8 bytes of all data keys plus values (FCM's own data limit is 4 KB). */
  dataBytes: 4096,
  dataKeyChars: 256,
  kindChars: 64,
  tokenMinChars: 32,
  tokenMaxChars: 4096,
} as const;

export type Profile = "order_alert" | "driver_job" | "default";

interface ProfileDefaults {
  channelId?: string;
  androidSound: string;
  apnsSound: string;
}

/**
 * Store app: a new order or booking request. Channel `new_order` and
 * `res/raw/order_alert.wav` are created by vendor/lib/utils/notification_service.dart;
 * `new_order` is also the store's manifest default_notification_channel_id.
 * Same set as the apps' `PushChannels.storeOrderKinds`.
 */
export const ORDER_ALERT_KINDS: ReadonlySet<string> = new Set(["order_placed", "schedule_order", "dinein_placed", "new_order"]);

/**
 * Driver app: a new or assigned delivery / ride / parcel / rental job. Channel
 * `driver_jobs` ("New jobs", loud; driver/lib/utils/notification_service.dart,
 * .claude/PUSH-CHANNELS.md driver section). An older driver build without that
 * channel posts it on its manifest default `driver_notifications_channel`,
 * still heads-up and audible. Matched on `kind` only: `data.type` values such
 * as `parcel_order` are also sent to customers.
 */
export const DRIVER_JOB_KINDS: ReadonlySet<string> = new Set([
  "new_delivery_order",
  "assign_order",
  "driver_job",
  "order_available",
  "job_assigned",
  "job_queue",
  "new_ride",
  "new_parcel",
  "new_rental",
]);

export const PROFILE_DEFAULTS: Readonly<Record<Profile, ProfileDefaults>> = {
  order_alert: { channelId: "new_order", androidSound: "order_alert", apnsSound: "order_alert.caf" },
  driver_job: { channelId: "driver_jobs", androidSound: "default", apnsSound: "default" },
  // No channel: the receiving app's manifest default channel shows it.
  default: { androidSound: "default", apnsSound: "default" },
};

export interface PushRequest {
  token?: string;
  topic?: string;
  title?: string;
  body?: string;
  data?: Record<string, string>;
  kind?: string;
  android?: { channelId?: string; sound?: string };
  apns?: { sound?: string };
}

/** What the server changed or ignored in a request it still sent. */
export interface Adjustments {
  /** Top-level / nested fields that are not part of the contract, or malformed overrides. */
  ignored: string[];
  /** Data keys left out: null values, empty keys, keys FCM reserves. */
  droppedDataKeys: string[];
  /** Data keys whose value was not a string and was converted. */
  convertedDataKeys: string[];
  /** "title" / "body" when clipped to the limit. */
  truncated: string[];
}

export interface ValidationError {
  ok: false;
  status: 400 | 413;
  error: "invalid_argument" | "payload_too_large";
  field: string;
  message: string;
}

export type Validation = { ok: true; value: PushRequest; adjustments: Adjustments } | ValidationError;

const TOP_LEVEL_KEYS = new Set(["token", "topic", "title", "body", "data", "kind", "android", "apns"]);

const TOKEN_RE = /^[A-Za-z0-9_\-:.]+$/;
const TOPIC_RE = /^[A-Za-z0-9\-_.~%]{1,900}$/;
const KIND_RE = /^[A-Za-z0-9_.:\-]+$/;
const CHANNEL_RE = /^[A-Za-z0-9_.\-]{1,64}$/;
const ANDROID_SOUND_RE = /^[A-Za-z0-9_.\-]{1,64}$/;
const APNS_SOUND_RE = /^[A-Za-z0-9_.\- ]{1,64}$/;

/** FCM rejects these data keys (and any starting with google / gcm). */
const RESERVED_DATA_KEYS = new Set(["from", "notification", "message_type", "collapse_key"]);

function invalid(field: string, message: string): ValidationError {
  return { ok: false, status: 400, error: "invalid_argument", field, message };
}

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

export function codePointLength(s: string): number {
  let n = 0;
  for (const _ of s) n++;
  return n;
}

function clip(s: string, max: number): string {
  return codePointLength(s) <= max ? s : Array.from(s).slice(0, max).join("");
}

function optionalString(v: unknown): { ok: true; value: string | undefined } | { ok: false } {
  if (v === undefined || v === null) return { ok: true, value: undefined };
  if (typeof v === "string") return { ok: true, value: v };
  return { ok: false };
}

/**
 * A data value as the apps convert it (`PushPayload.stringData`): strings as
 * they are, objects and arrays as JSON, everything else with its string form.
 * (A Dart double such as 1.0 arrives in JSON as 1 and becomes "1" here, where
 * Dart would have written "1.0"; send it as a string to keep the ".0".)
 */
export function dataValueToString(value: unknown): string {
  if (typeof value === "string") return value;
  if (typeof value === "object" && value !== null) {
    try {
      return JSON.stringify(value);
    } catch {
      return String(value);
    }
  }
  return String(value);
}

/** Validates a sendPush request body and normalises it the way the apps do. */
export function parsePushRequest(input: unknown): Validation {
  if (!isPlainObject(input)) return invalid("", "Request body must be a JSON object.");

  const adj: Adjustments = { ignored: [], droppedDataKeys: [], convertedDataKeys: [], truncated: [] };
  for (const key of Object.keys(input)) {
    if (!TOP_LEVEL_KEYS.has(key)) adj.ignored.push(key);
  }

  const out: PushRequest = {};

  // Target: exactly one of token / topic.
  const token = optionalString(input.token);
  if (!token.ok) return invalid("token", "token must be a string.");
  const topic = optionalString(input.topic);
  if (!topic.ok) return invalid("topic", "topic must be a string.");
  const tokenValue = token.value?.trim();
  const topicValue = topic.value?.trim();
  if ((tokenValue === undefined) === (topicValue === undefined)) {
    return invalid("token", "Send exactly one of 'token' or 'topic'.");
  }
  if (tokenValue !== undefined) {
    const t = tokenValue;
    if (
      t.length < LIMITS.tokenMinChars ||
      t.length > LIMITS.tokenMaxChars ||
      !TOKEN_RE.test(t) ||
      t.toLowerCase() === "null" ||
      t.toLowerCase() === "undefined"
    ) {
      return invalid("token", "token is not an FCM registration token.");
    }
    out.token = t;
  } else {
    const raw = topicValue!;
    const t = raw.startsWith("/topics/") ? raw.slice("/topics/".length) : raw;
    if (!TOPIC_RE.test(t)) return invalid("topic", "topic must match [a-zA-Z0-9-_.~%]{1,900}.");
    out.topic = t;
  }

  // Notification text: clipped, like the apps clip before sending.
  const title = optionalString(input.title);
  if (!title.ok) return invalid("title", "title must be a string.");
  if (title.value !== undefined) {
    out.title = clip(title.value, LIMITS.titleChars);
    if (out.title !== title.value) adj.truncated.push("title");
  }
  const body = optionalString(input.body);
  if (!body.ok) return invalid("body", "body must be a string.");
  if (body.value !== undefined) {
    out.body = clip(body.value, LIMITS.bodyChars);
    if (out.body !== body.value) adj.truncated.push("body");
  }

  // Data: a map of string to string, converted like the apps' stringData().
  if (input.data !== undefined && input.data !== null) {
    if (!isPlainObject(input.data)) return invalid("data", "data must be an object.");
    const data: Record<string, string> = {};
    let bytes = 0;
    for (const [rawKey, value] of Object.entries(input.data)) {
      const key = rawKey.trim();
      const lower = key.toLowerCase();
      if (
        value === null ||
        value === undefined ||
        key.length === 0 ||
        key.length > LIMITS.dataKeyChars ||
        RESERVED_DATA_KEYS.has(lower) ||
        lower.startsWith("google") ||
        lower.startsWith("gcm")
      ) {
        adj.droppedDataKeys.push(rawKey);
        continue;
      }
      const s = dataValueToString(value);
      if (typeof value !== "string") adj.convertedDataKeys.push(key);
      bytes += Buffer.byteLength(key, "utf8") + Buffer.byteLength(s, "utf8");
      if (bytes > LIMITS.dataBytes) {
        return {
          ok: false,
          status: 413,
          error: "payload_too_large",
          field: "data",
          message: `data must be at most ${LIMITS.dataBytes} bytes (keys plus values, UTF-8).`,
        };
      }
      data[key] = s;
    }
    if (Object.keys(data).length > 0) out.data = data;
  }

  // kind: the notification template type (e.g. 'order_placed') or 'chat'.
  const kind = optionalString(input.kind);
  if (!kind.ok) {
    adj.ignored.push("kind");
  } else if (kind.value !== undefined && kind.value.trim() !== "") {
    const k = kind.value.trim();
    if (k.length > LIMITS.kindChars || !KIND_RE.test(k)) adj.ignored.push("kind");
    else out.kind = k;
  }

  // Channel / sound chosen by the sender for the receiving app. A malformed
  // value is ignored (the defaults still deliver the push) rather than refused.
  if (input.android !== undefined && input.android !== null) {
    if (!isPlainObject(input.android)) {
      adj.ignored.push("android");
    } else {
      const android: { channelId?: string; sound?: string } = {};
      for (const [key, value] of Object.entries(input.android)) {
        if (key === "channelId" || key === "channel_id") {
          if (value === null || value === undefined || value === "") continue;
          if (typeof value === "string" && CHANNEL_RE.test(value.trim())) android.channelId = value.trim();
          else adj.ignored.push(`android.${key}`);
        } else if (key === "sound") {
          if (value === null || value === undefined || value === "") continue;
          if (typeof value === "string" && ANDROID_SOUND_RE.test(value.trim())) android.sound = value.trim();
          else adj.ignored.push("android.sound");
        } else {
          adj.ignored.push(`android.${key}`);
        }
      }
      if (Object.keys(android).length > 0) out.android = android;
    }
  }
  if (input.apns !== undefined && input.apns !== null) {
    if (!isPlainObject(input.apns)) {
      adj.ignored.push("apns");
    } else {
      for (const [key, value] of Object.entries(input.apns)) {
        if (key === "sound") {
          if (value === null || value === undefined || value === "") continue;
          if (typeof value === "string" && APNS_SOUND_RE.test(value.trim())) out.apns = { sound: value.trim() };
          else adj.ignored.push("apns.sound");
        } else {
          adj.ignored.push(`apns.${key}`);
        }
      }
    }
  }

  if (out.title === undefined && out.body === undefined && out.data === undefined) {
    return invalid("title", "Nothing to send: give a title, a body or data.");
  }

  return { ok: true, value: out, adjustments: adj };
}

/** Which defaults apply when the caller gave no channel. `kind` wins; `data.type` can only select an order alert. */
export function resolveProfile(req: PushRequest): Profile {
  const kind = (req.kind ?? "").toLowerCase();
  if (ORDER_ALERT_KINDS.has(kind)) return "order_alert";
  if (DRIVER_JOB_KINDS.has(kind)) return "driver_job";
  const dataType = (req.data?.type ?? "").toLowerCase();
  if (ORDER_ALERT_KINDS.has(dataType)) return "order_alert";
  return "default";
}

export interface BuiltMessage {
  message: Message;
  profile: Profile;
  /** The Android channel the message names, or "" for the manifest default. */
  channelId: string;
}

/** Builds the FCM message for a validated request. */
export function buildMessage(req: PushRequest): BuiltMessage {
  const profile = resolveProfile(req);
  const defaults = PROFILE_DEFAULTS[profile];
  const hasNotification = req.title !== undefined || req.body !== undefined;

  const message: Record<string, unknown> = req.token !== undefined ? { token: req.token } : { topic: req.topic };

  if (hasNotification) {
    const notification: { title?: string; body?: string } = {};
    if (req.title !== undefined) notification.title = req.title;
    if (req.body !== undefined) notification.body = req.body;
    message.notification = notification;
  }
  if (req.data !== undefined) message.data = { ...req.data };

  const channelId = req.android?.channelId ?? defaults.channelId;
  const androidSound = req.android?.sound ?? defaults.androidSound;
  const apnsSound = req.apns?.sound ?? defaults.apnsSound;

  if (hasNotification) {
    // Exactly the apps' legacy blocks: high priority, the receiving app's
    // channel and sound, APNs alert priority with a sound (without aps.sound
    // iOS shows the alert silently) and a background wake-up.
    const androidNotification: Record<string, string> = { sound: androidSound };
    if (channelId !== undefined) androidNotification.channelId = channelId;
    message.android = { priority: "high", notification: androidNotification };
    message.apns = {
      headers: { "apns-priority": "10" },
      payload: { aps: { sound: apnsSound, contentAvailable: true } },
    };
  } else {
    // Data only: no android.notification (it would post an empty one). APNs
    // requires priority 5 and push type "background" for a silent push.
    message.android = { priority: "high" };
    message.apns = {
      headers: { "apns-priority": "5", "apns-push-type": "background" },
      payload: { aps: { contentAvailable: true } },
    };
  }

  return { message: message as unknown as Message, profile, channelId: hasNotification ? (channelId ?? "") : "" };
}
