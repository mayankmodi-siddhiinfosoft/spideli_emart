/**
 * Per-user abuse limit for sendPush, kept in Firestore so it holds across
 * function instances.
 *
 * Document `push_rate_limits/{uid}`:
 *   hits      number[]   send times (ms since epoch) inside the last 60 s, oldest first
 *   dayKey    string     UTC day the counter below belongs to, 'YYYY-MM-DD'
 *   dayCount  number     sends on dayKey
 *   updatedAt Timestamp
 *   expireAt  Timestamp  now + 2 days; set a Firestore TTL policy on it to clean up
 *
 * A refused request is not recorded, so retrying while limited does not extend
 * the wait.
 */
import { FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";

export const WINDOW_MS = 60_000;
const DAY_MS = 86_400_000;
const EXPIRE_AFTER_MS = 2 * DAY_MS;

export interface RateLimits {
  perMinute: number;
  perDay: number;
}

export interface WindowState {
  hits: number[];
  dayKey: string;
  dayCount: number;
}

export type RateDecision =
  | { allowed: true; next: WindowState }
  | { allowed: false; reason: "minute" | "day"; retryAfterSeconds: number };

export function utcDayKey(nowMs: number): string {
  return new Date(nowMs).toISOString().slice(0, 10);
}

/** Pure decision for one more send at `nowMs`, given the stored state. */
export function evaluateRateLimit(stored: unknown, nowMs: number, limits: RateLimits): RateDecision {
  const s = (typeof stored === "object" && stored !== null ? stored : {}) as Record<string, unknown>;
  const windowStart = nowMs - WINDOW_MS;
  const hits = (Array.isArray(s.hits) ? s.hits : [])
    .filter((h): h is number => typeof h === "number" && Number.isFinite(h) && h > windowStart && h <= nowMs + WINDOW_MS)
    .sort((a, b) => a - b);

  const today = utcDayKey(nowMs);
  const dayCount = s.dayKey === today && typeof s.dayCount === "number" && s.dayCount > 0 ? s.dayCount : 0;

  if (dayCount >= limits.perDay) {
    const nextMidnight = Date.UTC(
      new Date(nowMs).getUTCFullYear(),
      new Date(nowMs).getUTCMonth(),
      new Date(nowMs).getUTCDate() + 1,
    );
    return { allowed: false, reason: "day", retryAfterSeconds: Math.max(1, Math.ceil((nextMidnight - nowMs) / 1000)) };
  }

  if (hits.length >= limits.perMinute) {
    // The oldest hit that has to leave the window before one more fits.
    const blocking = hits[hits.length - limits.perMinute];
    return {
      allowed: false,
      reason: "minute",
      retryAfterSeconds: Math.max(1, Math.ceil((blocking + WINDOW_MS - nowMs) / 1000)),
    };
  }

  hits.push(nowMs);
  return { allowed: true, next: { hits: hits.slice(-limits.perMinute), dayKey: today, dayCount: dayCount + 1 } };
}

/** Records one send for `uid` if it is within the limits. Throws if Firestore fails. */
export async function consumeRateLimit(
  db: Firestore,
  collection: string,
  uid: string,
  limits: RateLimits,
): Promise<RateDecision> {
  const ref = db.collection(collection).doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const nowMs = Date.now();
    const decision = evaluateRateLimit(snap.data(), nowMs, limits);
    if (decision.allowed) {
      tx.set(ref, {
        ...decision.next,
        updatedAt: FieldValue.serverTimestamp(),
        expireAt: Timestamp.fromMillis(nowMs + EXPIRE_AFTER_MS),
      });
    }
    return decision;
  });
}
