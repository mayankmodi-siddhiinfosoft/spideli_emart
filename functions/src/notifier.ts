/**
 * The work of one `scheduledOrderNotifier` run (see index.ts and README.md).
 */
import { FieldValue, type DocumentReference, type Firestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

import {
  ORDER_PLACED,
  SENT_AT_FIELD,
  SENT_FIELD,
  SKIPPED_FIELD,
  TEMPLATE_TYPE,
  buildDueMessage,
  decide,
  isDeadTokenError,
  leadTimeMs,
  templateText,
  usableToken,
  type Template,
} from "./rules";

const ORDERS = "vendor_orders";
const USERS = "users";
const VENDORS = "vendors";
const SETTINGS = "settings";
const LEAD_DOC = "scheduleOrderNotification";
const TEMPLATES = "dynamic_notification";

/** One run of `scheduledOrderNotifier` at [nowMs] (epoch ms). */
export async function runOnce(db: Firestore, nowMs: number): Promise<void> {
  // Lead time first: when it cannot be read, nothing is sent this run
  // (better a minute late than early).
  const settings = await db.collection(SETTINGS).doc(LEAD_DOC).get();
  const lead = settings.exists ? leadTimeMs(settings.get("notifyTime"), settings.get("timeUnit")) : 0;

  const pending = await db
    .collection(ORDERS)
    .where(SENT_FIELD, "==", false)
    .select("status", "scheduleTime", "vendorID", "vendor.author", SENT_FIELD)
    .get();
  if (pending.empty) return;

  let template: Template | null | undefined;
  let notified = 0;
  let skipped = 0;
  let waiting = 0;
  for (const doc of pending.docs) {
    const first = decide(doc.data(), nowMs, lead);
    if (first.kind === "wait") {
      waiting++;
      continue;
    }
    if (first.kind === "done") continue;
    try {
      const claim = await claimOrder(db, doc.ref, nowMs, lead);
      if (claim.kind === "skip") {
        skipped++;
        continue;
      }
      if (claim.kind !== "notify") continue;
      if (template === undefined) template = await readTemplate(db);
      if (await notifyStore(db, doc.id, claim.data, template)) notified++;
    } catch (e) {
      logger.error("scheduled order: handling failed", { orderId: doc.id, error: errorText(e) });
    }
  }
  logger.info("scheduled orders run", { pending: pending.size, waiting, notified, skipped, leadMs: lead });
}

type Claim = { kind: "notify"; data: Record<string, unknown> } | { kind: "skip" } | { kind: "none" };

/**
 * Re-reads the order in a transaction and marks it, so it is notified at most
 * once even when two runs overlap: only an order that is still `Order
 * Placed`, not yet sent and due is claimed (`scheduledNotificationSent: true`,
 * `scheduledNotificationAt`). An order that left `Order Placed` is marked too
 * (with `scheduledNotificationSkipped`: its status), and never pushed.
 */
async function claimOrder(db: Firestore, ref: DocumentReference, nowMs: number, lead: number): Promise<Claim> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const decision = decide(data, nowMs, lead);
    switch (decision.kind) {
      case "notify":
        tx.update(ref, { [SENT_FIELD]: true, [SENT_AT_FIELD]: FieldValue.serverTimestamp() });
        return { kind: "notify", data: data ?? {} } as Claim;
      case "skip":
        tx.update(ref, {
          [SENT_FIELD]: true,
          [SENT_AT_FIELD]: FieldValue.serverTimestamp(),
          [SKIPPED_FIELD]: decision.status || "unknown",
        });
        return { kind: "skip" } as Claim;
      default:
        return { kind: "none" } as Claim;
    }
  });
}

/** The `schedule_order` template's text, or null (logged) when it has none. */
async function readTemplate(db: Firestore): Promise<Template | null> {
  try {
    const snap = await db.collection(TEMPLATES).where("type", "==", TEMPLATE_TYPE).limit(1).get();
    const text = snap.empty ? null : templateText(snap.docs[0].data());
    if (!text) {
      logger.warn(`scheduled order: no text in the ${TEMPLATES} template "${TEMPLATE_TYPE}"; sending a data-only push`);
    }
    return text;
  } catch (e) {
    logger.error("scheduled order: reading the template failed; sending a data-only push", { error: errorText(e) });
    return null;
  }
}

/** The store owner's uid: the order's `vendor.author`, else `vendors/{vendorID}.author`. */
async function ownerOf(db: Firestore, order: Record<string, unknown>): Promise<string | null> {
  const vendor = order.vendor as Record<string, unknown> | undefined;
  const author = typeof vendor?.author === "string" ? vendor.author.trim() : "";
  if (author) return author;
  const vendorId = typeof order.vendorID === "string" ? order.vendorID.trim() : "";
  if (!vendorId) return null;
  const store = await db.collection(VENDORS).doc(vendorId).get();
  const storeAuthor = store.get("author");
  return typeof storeAuthor === "string" && storeAuthor.trim() ? storeAuthor.trim() : null;
}

/**
 * Pushes the store owner's CURRENT token. The order is already claimed, so a
 * failure is logged and not retried (the order is in the Store app's New list
 * anyway once due). Tokens are never logged.
 */
async function notifyStore(db: Firestore, orderId: string, order: Record<string, unknown>, text: Template | null): Promise<boolean> {
  const owner = await ownerOf(db, order);
  if (!owner) {
    logger.warn("scheduled order: no store owner on the order or its store", { orderId });
    return false;
  }
  const user = await db.collection(USERS).doc(owner).get();
  const token = user.get("fcmToken");
  if (!usableToken(token)) {
    logger.warn("scheduled order: the store owner has no FCM token", { orderId, owner });
    return false;
  }
  try {
    await getMessaging().send(buildDueMessage(token, orderId, text));
    logger.info("scheduled order: store notified", { orderId, owner, status: ORDER_PLACED });
    return true;
  } catch (e) {
    const code = (e as { code?: unknown })?.code;
    if (isDeadTokenError(code)) {
      // UNREGISTERED: the owner's app writes a fresh token on its next start.
      logger.warn("scheduled order: the store owner's token is no longer registered (UNREGISTERED)", { orderId, owner, code });
    } else {
      logger.error("scheduled order: push failed", { orderId, owner, code: typeof code === "string" ? code : undefined, error: errorText(e) });
    }
    return false;
  }
}

/** An error's message without anything that could carry a token. */
function errorText(e: unknown): string {
  const message = e instanceof Error ? e.message : String(e);
  // FCM error messages can quote the registration token: mask long token-like runs.
  return message.replace(/[A-Za-z0-9_\-:]{60,}/g, "<redacted>");
}
