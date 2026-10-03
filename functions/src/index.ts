/**
 * sendPush: the server half of push notifications for the five Spideli apps.
 *
 * The apps used to download a Firebase Admin service-account key from
 * `settings/notification_setting.serviceJson` and call FCM HTTP v1 themselves,
 * which hands full admin access to project spideli-870b0 to anyone who opens
 * an APK. With this function deployed and `settings/notification_setting.serverPushUrl`
 * set, an app sends its signed-in user's Firebase ID token here instead, and
 * only this function holds FCM credentials (its own runtime service account).
 *
 * Contract: .claude/SERVER-PUSH-CONTRACT.md
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import { onRequest } from "firebase-functions/v2/https";

import { CONFIG } from "./config";
import { HttpFailure, mapAuthError, mapMessagingError } from "./errors";
import { Adjustments, buildMessage, parsePushRequest } from "./payload";
import { consumeRateLimit } from "./rateLimit";
import { fingerprint } from "./redact";
import { clearDeadToken } from "./tokens";

initializeApp();

interface JsonResponse {
  status(code: number): JsonResponse;
  set(field: string, value: string): JsonResponse;
  json(body: unknown): void;
}

function reply(res: JsonResponse, status: number, body: Record<string, unknown>, retryAfter?: number): void {
  if (retryAfter !== undefined) res.set("Retry-After", String(retryAfter));
  res.status(status).json(body);
}

function replyFailure(res: JsonResponse, f: HttpFailure, extra: Record<string, unknown> = {}): void {
  const { status, error, message, retryAfter } = f;
  const body: Record<string, unknown> = { ok: false, error, message, ...extra };
  if (retryAfter !== undefined) body.retryAfterSeconds = retryAfter;
  reply(res, status, body, retryAfter);
}

/** Only the non-empty lists, so a clean request gets a clean response. */
function adjustmentsBody(a: Adjustments): Record<string, string[]> {
  const out: Record<string, string[]> = {};
  for (const [k, v] of Object.entries(a)) if (v.length > 0) out[k] = v;
  return out;
}

const BEARER_RE = /^Bearer\s+([A-Za-z0-9\-_.=]+)$/i;

export const sendPush = onRequest(
  {
    region: CONFIG.region,
    // The function authenticates every call itself (Firebase ID token), so it
    // must be reachable without Google IAM credentials.
    invoker: "public",
    cors: false,
    memory: "256MiB",
    timeoutSeconds: 30,
    maxInstances: 20,
    concurrency: 80,
  },
  async (req, res) => {
    res.set("Cache-Control", "no-store");

    if (req.method !== "POST") {
      res.set("Allow", "POST");
      reply(res, 405, { ok: false, error: "method_not_allowed", message: "Use POST." });
      return;
    }
    if (!req.is("application/json")) {
      reply(res, 415, {
        ok: false,
        error: "unsupported_media_type",
        message: "Content-Type must be application/json.",
      });
      return;
    }
    if (req.rawBody !== undefined && req.rawBody.length > CONFIG.maxRequestBytes) {
      reply(res, 413, {
        ok: false,
        error: "payload_too_large",
        message: `The request must be at most ${CONFIG.maxRequestBytes} bytes.`,
      });
      return;
    }

    // 1. Who is calling: a signed-in, non-anonymous Firebase account.
    const match = BEARER_RE.exec((req.get("authorization") ?? "").trim());
    if (!match) {
      res.set("WWW-Authenticate", 'Bearer realm="sendPush"');
      reply(res, 401, {
        ok: false,
        error: "unauthenticated",
        message: "Send 'Authorization: Bearer <Firebase ID token>'.",
      });
      return;
    }
    let uid: string;
    try {
      const decoded = await getAuth().verifyIdToken(match[1]);
      uid = decoded.uid;
      if (decoded.firebase?.sign_in_provider === "anonymous") {
        logger.warn("sendPush: anonymous caller refused", { uid });
        reply(res, 403, {
          ok: false,
          error: "anonymous_not_allowed",
          message: "Sign in with a real account to send notifications.",
        });
        return;
      }
    } catch (err) {
      const f = mapAuthError(err);
      logger.warn("sendPush: ID token rejected", { code: errCode(err), status: f.status });
      if (f.status === 401) res.set("WWW-Authenticate", 'Bearer realm="sendPush", error="invalid_token"');
      replyFailure(res, f);
      return;
    }

    // 2. What to send (validated before any Firestore read).
    const parsed = parsePushRequest(req.body);
    if (!parsed.ok) {
      logger.info("sendPush: invalid request", { uid, field: parsed.field, status: parsed.status });
      reply(res, parsed.status, { ok: false, error: parsed.error, field: parsed.field, message: parsed.message });
      return;
    }
    const request = parsed.value;
    const adjustments = adjustmentsBody(parsed.adjustments);

    // 3. Must be a platform user: customers, drivers, stores and providers live
    //    in users/{uid}; provider workers in providers_workers/{uid}.
    const db = getFirestore();
    let role = "";
    try {
      let found = false;
      for (const collection of CONFIG.profileCollections) {
        const snap = await db.collection(collection).doc(uid).get();
        if (snap.exists) {
          found = true;
          const r = snap.get("role");
          role = typeof r === "string" ? r : "";
          break;
        }
      }
      if (!found) {
        logger.warn("sendPush: no profile for caller", { uid });
        reply(res, 403, {
          ok: false,
          error: "user_not_found",
          message: "The signed-in account has no user profile.",
        });
        return;
      }
    } catch (err) {
      logger.error("sendPush: profile lookup failed", { uid, code: errCode(err) });
      replyFailure(res, { status: 503, error: "unavailable", message: "Try again shortly.", retryAfter: 5 });
      return;
    }

    // Topics are the apps' broadcast channels: admin only by default.
    if (request.topic !== undefined && !CONFIG.topicRoles.includes(role)) {
      logger.warn("sendPush: topic send refused", { uid, role, topic: request.topic });
      reply(res, 403, {
        ok: false,
        error: "topic_forbidden",
        message: "This account may not send to a topic; send to a device token.",
      });
      return;
    }

    // 4. Abuse limit.
    try {
      const decision = await consumeRateLimit(db, CONFIG.rateLimitCollection, uid, {
        perMinute: CONFIG.perMinute,
        perDay: CONFIG.perDay,
      });
      if (!decision.allowed) {
        logger.warn("sendPush: rate limited", { uid, reason: decision.reason });
        replyFailure(
          res,
          {
            status: 429,
            error: "rate_limited",
            message:
              decision.reason === "minute"
                ? `At most ${CONFIG.perMinute} notifications per minute per account.`
                : `At most ${CONFIG.perDay} notifications per day per account.`,
            retryAfter: decision.retryAfterSeconds,
          },
          { limit: decision.reason },
        );
        return;
      }
    } catch (err) {
      logger.error("sendPush: rate-limit store failed", { uid, code: errCode(err) });
      replyFailure(res, { status: 503, error: "unavailable", message: "Try again shortly.", retryAfter: 5 });
      return;
    }

    // 5. Send. Logs carry lengths, data KEYS and a token fingerprint only:
    //    never a token, a title, a body or a data value.
    const { message, profile, channelId } = buildMessage(request);
    const target =
      request.token !== undefined ? { target: "token", tokenFp: fingerprint(request.token) } : { target: "topic", topic: request.topic };
    const summary = {
      uid,
      kind: request.kind ?? "",
      profile,
      channelId,
      ...target,
      titleLength: request.title?.length ?? 0,
      bodyLength: request.body?.length ?? 0,
      dataKeys: Object.keys(request.data ?? {}),
      ...adjustments,
    };
    try {
      const messageId = await getMessaging().send(message);
      logger.info("sendPush: sent", summary);
      reply(res, 200, { ok: true, messageId, profile, channelId, ...adjustments });
    } catch (err) {
      const f = mapMessagingError(err);
      let tokensCleared = 0;
      if (f.deadToken && request.token !== undefined && CONFIG.clearDeadTokens) {
        try {
          tokensCleared = await clearDeadToken(db, request.token);
        } catch (clearErr) {
          logger.warn("sendPush: dead-token clean-up failed", { uid, tokenFp: summary.tokenFp, code: errCode(clearErr) });
        }
      }
      const log = f.status >= 500 ? logger.error : logger.warn;
      log("sendPush: FCM refused", { ...summary, code: errCode(err), fcmErrorCode: f.fcmErrorCode, status: f.status, tokensCleared });
      replyFailure(res, f, { fcmErrorCode: f.fcmErrorCode, deadToken: f.deadToken, tokensCleared });
    }
  },
);

function errCode(err: unknown): string {
  if (typeof err === "object" && err !== null) {
    const code = (err as { code?: unknown }).code;
    if (typeof code === "string" || typeof code === "number") return String(code);
  }
  return "unknown";
}
