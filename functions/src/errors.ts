/**
 * Maps firebase-admin errors to the HTTP responses of the sendPush contract.
 * Pure, so it is unit tested directly.
 */

export interface HttpFailure {
  status: number;
  error: string;
  message: string;
  /** Seconds, sent as the Retry-After header when present. */
  retryAfter?: number;
}

/** A failed FCM send, with what the app needs to act on it. */
export interface PushFailure extends HttpFailure {
  /**
   * FCM HTTP v1 error code as FCM returned it (`UNREGISTERED`,
   * `INVALID_ARGUMENT`, `SENDER_ID_MISMATCH`, `QUOTA_EXCEEDED`, `UNAVAILABLE`,
   * `INTERNAL`, `THIRD_PARTY_AUTH_ERROR`, ...), or "" when the send never
   * reached FCM. The same names the apps' legacy-path error parsers read.
   */
  fcmErrorCode: string;
  /**
   * The recipient token can never receive again (uninstalled, rotated,
   * malformed, or from another Firebase project). The function clears it
   * from users / providers_workers / vendors; the app must not retry and
   * should drop any copy it holds.
   */
  deadToken: boolean;
}

function errorCode(err: unknown): string {
  if (typeof err === "object" && err !== null) {
    const code = (err as { code?: unknown }).code;
    if (typeof code === "string") return code;
    // FirebaseMessagingError keeps the code under errorInfo as well.
    const info = (err as { errorInfo?: { code?: unknown } }).errorInfo;
    if (info && typeof info.code === "string") return info.code;
  }
  return "";
}

function errorMessage(err: unknown): string {
  if (typeof err === "object" && err !== null) {
    const m = (err as { message?: unknown }).message;
    if (typeof m === "string") return m;
  }
  return "";
}

/**
 * The FCM v1 error code from the raw response firebase-admin keeps on the
 * error (`httpResponse.data`): `error.details[].errorCode` of the FcmError
 * detail, else `error.status`. firebase-admin folds several of these into one
 * client code (PERMISSION_DENIED and SENDER_ID_MISMATCH both become
 * messaging/mismatched-credential), and they need different handling.
 */
export function rawFcmErrorCode(err: unknown): { code: string; message: string } {
  if (typeof err !== "object" || err === null) return { code: "", message: "" };
  const http = (err as { httpResponse?: { data?: unknown } }).httpResponse;
  let data: unknown = http?.data;
  if (typeof data === "string") {
    try {
      data = JSON.parse(data);
    } catch {
      return { code: "", message: "" };
    }
  }
  if (typeof data !== "object" || data === null) return { code: "", message: "" };
  const e = (data as { error?: unknown }).error;
  if (typeof e !== "object" || e === null) return { code: typeof e === "string" ? e : "", message: "" };
  const error = e as { status?: unknown; message?: unknown; details?: unknown };
  const message = typeof error.message === "string" ? error.message : "";
  if (Array.isArray(error.details)) {
    for (const d of error.details) {
      if (typeof d === "object" && d !== null) {
        const c = (d as { errorCode?: unknown }).errorCode;
        if (typeof c === "string" && c !== "") return { code: c, message };
      }
    }
  }
  return { code: typeof error.status === "string" ? error.status : "", message };
}

const TOKEN_TEXT_RE = /registration[ -]token/i;

function failure(f: HttpFailure, fcmErrorCode: string, deadToken = false): PushFailure {
  return { ...f, fcmErrorCode, deadToken };
}

/** admin.messaging().send() failures. */
export function mapMessagingError(err: unknown): PushFailure {
  const raw = rawFcmErrorCode(err);
  const text = raw.message || errorMessage(err);

  // 1. What FCM itself said, when it answered.
  switch (raw.code) {
    case "UNREGISTERED":
    case "NOT_FOUND":
      return failure(
        { status: 404, error: "unregistered", message: "The FCM token is no longer registered (app uninstalled or token rotated)." },
        "UNREGISTERED",
        true,
      );
    case "SENDER_ID_MISMATCH":
      return failure({ status: 403, error: "sender_mismatch", message: "The FCM token belongs to a different Firebase project." }, raw.code, true);
    case "INVALID_ARGUMENT":
      return TOKEN_TEXT_RE.test(text)
        ? failure({ status: 400, error: "invalid_token", message: "FCM rejected the registration token." }, raw.code, true)
        : failure({ status: 400, error: "invalid_argument", message: "FCM rejected the message as invalid." }, raw.code);
    case "QUOTA_EXCEEDED":
      return failure(
        { status: 429, error: "fcm_rate_limited", message: "FCM is throttling sends to this target; retry later.", retryAfter: 60 },
        raw.code,
      );
    case "UNAVAILABLE":
      return failure({ status: 503, error: "fcm_unavailable", message: "FCM is unavailable; retry later.", retryAfter: 10 }, raw.code);
    case "INTERNAL":
      return failure({ status: 502, error: "fcm_error", message: "FCM returned an internal error; retry later." }, raw.code);
    case "THIRD_PARTY_AUTH_ERROR":
      return failure(
        {
          status: 502,
          error: "apns_auth_error",
          message: "APNs rejected the project's credentials (check the APNs key in the Firebase console > Cloud Messaging).",
        },
        raw.code,
      );
    // No FcmError detail: the function's own credentials or permissions.
    case "PERMISSION_DENIED":
    case "UNAUTHENTICATED":
      return failure({ status: 500, error: "server_misconfigured", message: "The function is not allowed to send with FCM." }, raw.code);
  }

  // 2. No usable FCM answer (network error, or the SDK refused the message
  //    before sending): fall back to firebase-admin's client code.
  switch (errorCode(err)) {
    case "messaging/registration-token-not-registered":
      return failure(
        { status: 404, error: "unregistered", message: "The FCM token is no longer registered (app uninstalled or token rotated)." },
        "UNREGISTERED",
        true,
      );
    case "messaging/invalid-registration-token":
      return failure({ status: 400, error: "invalid_token", message: "FCM rejected the registration token." }, "INVALID_ARGUMENT", true);
    case "messaging/mismatched-credential":
      // Without the raw answer SENDER_ID_MISMATCH and PERMISSION_DENIED look
      // the same here; never clear a token on a guess.
      return failure({ status: 403, error: "sender_mismatch", message: "FCM refused this sender for the token." }, "");
    case "messaging/payload-size-limit-exceeded":
      return failure({ status: 413, error: "payload_too_large", message: "The message exceeds FCM's 4 KB limit." }, "");
    case "messaging/invalid-argument":
      return TOKEN_TEXT_RE.test(text)
        ? failure({ status: 400, error: "invalid_token", message: "FCM rejected the registration token." }, "INVALID_ARGUMENT", true)
        : failure({ status: 400, error: "invalid_argument", message: "FCM rejected the message as invalid." }, "");
    case "messaging/invalid-recipient":
    case "messaging/invalid-payload":
    case "messaging/invalid-data-payload-key":
    case "messaging/invalid-options":
    case "messaging/invalid-package-name":
    case "messaging/too-many-topics":
      return failure({ status: 400, error: "invalid_argument", message: "FCM rejected the message as invalid." }, "");
    case "messaging/message-rate-exceeded":
    case "messaging/device-message-rate-exceeded":
    case "messaging/topics-message-rate-exceeded":
      return failure(
        { status: 429, error: "fcm_rate_limited", message: "FCM is throttling sends to this target; retry later.", retryAfter: 60 },
        "",
      );
    case "messaging/third-party-auth-error":
      return failure(
        {
          status: 502,
          error: "apns_auth_error",
          message: "APNs rejected the project's credentials (check the APNs key in the Firebase console > Cloud Messaging).",
        },
        "",
      );
    case "messaging/server-unavailable":
      return failure({ status: 503, error: "fcm_unavailable", message: "FCM is unavailable; retry later.", retryAfter: 10 }, "");
    case "messaging/internal-error":
    case "messaging/unknown-error":
      return failure({ status: 502, error: "fcm_error", message: "FCM returned an internal error; retry later." }, "");
    case "messaging/authentication-error":
      return failure({ status: 500, error: "server_misconfigured", message: "The function could not authenticate to FCM." }, "");
    default:
      return failure({ status: 500, error: "internal", message: "Could not send the push." }, "");
  }
}

/** admin.auth().verifyIdToken() failures. */
export function mapAuthError(err: unknown): HttpFailure {
  const code = errorCode(err);
  switch (code) {
    case "auth/id-token-expired":
      return {
        status: 401,
        error: "id_token_expired",
        message: "The Firebase ID token has expired; call getIdToken(true) and retry.",
      };
    case "auth/id-token-revoked":
    case "auth/user-disabled":
      return { status: 403, error: "user_disabled", message: "This account can no longer send notifications." };
    case "auth/argument-error":
    case "auth/invalid-id-token":
      return { status: 401, error: "invalid_id_token", message: "The Firebase ID token is not valid." };
    case "app/network-error":
    case "auth/internal-error":
      return { status: 503, error: "unavailable", message: "Could not verify the ID token; retry later.", retryAfter: 5 };
    default:
      return { status: 401, error: "invalid_id_token", message: "The Firebase ID token is not valid." };
  }
}
