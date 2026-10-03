/**
 * Dead-token clean-up for sendPush.
 *
 * When FCM says a registration token can never receive again (UNREGISTERED,
 * SENDER_ID_MISMATCH, or a malformed token), every profile still holding it
 * gets `fcmToken: ""`, so senders stop wasting pushes (and rate limit) on it
 * and the receiving app writes a fresh one on its next start or token refresh.
 *
 * The apps cannot do this themselves without being allowed to write other
 * users' fcmToken, which the Firestore rules draft forbids (redirecting
 * someone's pushes to your own device is the attack there).
 */
import type { Firestore } from "firebase-admin/firestore";

/** Where the apps keep a recipient token (users / providers_workers: the account; vendors: the store). */
export const TOKEN_COLLECTIONS = ["users", "providers_workers", "vendors"] as const;

/** At most this many documents per collection are cleared for one token. */
const MAX_DOCS_PER_COLLECTION = 10;

/**
 * Sets `fcmToken: ""` on documents whose fcmToken is exactly [token]. Each
 * update is conditional on the document not having changed since it was
 * read, so a new token the app wrote meanwhile is never overwritten. Returns
 * how many documents were cleared. Throws only if a query fails.
 */
export async function clearDeadToken(db: Firestore, token: string): Promise<number> {
  let cleared = 0;
  for (const collection of TOKEN_COLLECTIONS) {
    const snap = await db.collection(collection).where("fcmToken", "==", token).limit(MAX_DOCS_PER_COLLECTION).get();
    for (const doc of snap.docs) {
      try {
        await doc.ref.update({ fcmToken: "" }, { lastUpdateTime: doc.updateTime });
        cleared++;
      } catch {
        // Changed or deleted since the read: leave it to the app.
      }
    }
  }
  return cleared;
}
