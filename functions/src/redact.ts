import { createHash } from "node:crypto";

/**
 * A short, stable fingerprint of an FCM token or ID token for logs. The token
 * itself is a bearer credential for that device and is never logged.
 */
export function fingerprint(secret: string): string {
  return createHash("sha256").update(secret, "utf8").digest("hex").slice(0, 12);
}
