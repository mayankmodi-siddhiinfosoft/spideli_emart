/**
 * Runtime configuration for sendPush.
 *
 * Every value has a safe default, so a plain `firebase deploy` needs no setup.
 * To change one, put it in `functions/.env` (deployed with the function) or
 * `functions/.env.spideli-870b0`, e.g. `PUSH_LIMIT_PER_MINUTE=90`.
 */

function intFromEnv(name: string, fallback: number, min: number, max: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw.trim() === "") return fallback;
  const value = Number.parseInt(raw, 10);
  if (!Number.isFinite(value) || value < min || value > max) return fallback;
  return value;
}

function listFromEnv(name: string, fallback: string[]): string[] {
  const raw = process.env[name];
  if (raw === undefined) return fallback;
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

export const CONFIG = {
  /** Same region as the project's existing `deleteUser` function. */
  region: "us-central1",

  /** Sliding window: at most this many sends per signed-in user per 60 s. */
  perMinute: intFromEnv("PUSH_LIMIT_PER_MINUTE", 60, 1, 10_000),

  /** Fixed UTC-day cap per signed-in user (a store on a busy day sends a few per order). */
  perDay: intFromEnv("PUSH_LIMIT_PER_DAY", 3000, 1, 1_000_000),

  /**
   * `users/{uid}.role` values allowed to send to a topic. The apps subscribe to
   * broadcast topics ("customer", "vendor", "provider", "worker", driver zone
   * topics) and never send to one, so by default only an admin account can.
   */
  topicRoles: listFromEnv("PUSH_TOPIC_ROLES", ["admin"]),

  /** Hard cap on the raw request; a maximal valid request is well under 8 KB. */
  maxRequestBytes: 16 * 1024,

  /** A caller must have a profile in one of these collections (doc id = auth uid). */
  profileCollections: ["users", "providers_workers"],

  /** Server-only; Firestore rules must deny clients (see SERVER-PUSH-CONTRACT.md). */
  rateLimitCollection: "push_rate_limits",

  /**
   * On UNREGISTERED / SENDER_ID_MISMATCH / a malformed token, set
   * `fcmToken: ""` on the users / providers_workers / vendors documents that
   * still hold it (src/tokens.ts). `PUSH_CLEAR_DEAD_TOKENS=false` turns it off.
   */
  clearDeadTokens: (process.env.PUSH_CLEAR_DEAD_TOKENS ?? "true").trim().toLowerCase() !== "false",
} as const;
