// Unit tests for the pure parts of sendPush. Run with `npm test` (builds first).
const test = require("node:test");
const assert = require("node:assert/strict");

const { parsePushRequest, buildMessage, resolveProfile, dataValueToString, LIMITS } = require("../lib/payload");
const { mapMessagingError, mapAuthError, rawFcmErrorCode } = require("../lib/errors");
const { evaluateRateLimit, utcDayKey } = require("../lib/rateLimit");
const { fingerprint } = require("../lib/redact");
const { clearDeadToken, TOKEN_COLLECTIONS } = require("../lib/tokens");

const TOKEN = "fGx1cZ3kT0mH0vbH8ZQwq1:APA91bH" + "x".repeat(120);

function parseOk(body) {
  const r = parsePushRequest(body);
  assert.equal(r.ok, true, JSON.stringify(r));
  return r;
}
function valueOf(body) {
  return parseOk(body).value;
}
function parseErr(body) {
  const r = parsePushRequest(body);
  assert.equal(r.ok, false, "expected a validation error");
  return r;
}

/** The apps' legacy FCM v1 platform blocks, in firebase-admin's field names. */
function appBlocks(channelId, androidSound = "default", apnsSound = "default") {
  return {
    android: { priority: "high", notification: { ...(channelId ? { channelId } : {}), sound: androidSound } },
    apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: apnsSound, contentAvailable: true } } },
  };
}

// ---------------------------------------------------------------------------
// What the apps send (customer/driver/provider/worker push_message.dart serverRequest)

test("an app request becomes exactly the app's own legacy FCM v1 message", () => {
  const { message, profile, channelId } = buildMessage(
    valueOf({
      token: TOKEN,
      title: "Order Accepted",
      body: "Your order is accepted",
      data: { type: "restaurant_accepted", orderId: "o1", channelId: "high_importance_channel" },
      kind: "restaurant_accepted",
      android: { channelId: "high_importance_channel", sound: "default" },
      apns: { sound: "default" },
    }),
  );
  assert.equal(profile, "default");
  assert.equal(channelId, "high_importance_channel");
  assert.deepEqual(message, {
    token: TOKEN,
    notification: { title: "Order Accepted", body: "Your order is accepted" },
    data: { type: "restaurant_accepted", orderId: "o1", channelId: "high_importance_channel" },
    ...appBlocks("high_importance_channel"),
  });
});

test("on the wire it is byte-for-byte the apps' PushPayload.fcmV1Message", (t) => {
  // firebase-admin's own validator turns the message into the FCM v1 JSON it
  // sends (channelId -> channel_id, contentAvailable -> content-available: 1).
  let validateMessage;
  try {
    ({ validateMessage } = require(require("node:path").join(__dirname, "..", "node_modules", "firebase-admin", "lib", "messaging", "messaging-internal.js")));
  } catch {
    t.skip("firebase-admin internals moved; the shape tests above still hold");
    return;
  }
  const wire = JSON.parse(
    JSON.stringify(
      buildMessage(valueOf({ token: TOKEN, title: "T", body: "B", data: { type: "order_placed", orderId: "o1" }, kind: "order_placed", android: { channelId: "new_order", sound: "order_alert" }, apns: { sound: "order_alert.caf" } }))
        .message,
    ),
  );
  validateMessage(wire);
  // customer/lib/service/push_message.dart PushPayload.fcmV1Message(...)
  assert.deepEqual(wire, {
    token: TOKEN,
    notification: { title: "T", body: "B" },
    data: { type: "order_placed", orderId: "o1" },
    android: { priority: "high", notification: { channel_id: "new_order", sound: "order_alert" } },
    apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "order_alert.caf", "content-available": 1 } } },
  });
});

test("store order alert from the customer: new_order channel, order_alert sounds", () => {
  const { message } = buildMessage(
    valueOf({ token: TOKEN, title: "New order", body: "#1", kind: "order_placed", android: { channelId: "new_order", sound: "order_alert" }, apns: { sound: "order_alert.caf" } }),
  );
  assert.deepEqual(message.android, appBlocks("new_order", "order_alert").android);
  assert.deepEqual(message.apns, appBlocks(null, "default", "order_alert.caf").apns);
});

test("android.channel_id (FCM's own spelling) is accepted too", () => {
  assert.equal(valueOf({ token: TOKEN, title: "t", android: { channel_id: "01" } }).android.channelId, "01");
});

test("no channel given: receiving app's manifest default, default sounds, still high priority", () => {
  const { message, channelId } = buildMessage(valueOf({ token: TOKEN, title: "t", body: "b", kind: "booking_placed" }));
  assert.equal(channelId, "");
  assert.deepEqual(message, { token: TOKEN, notification: { title: "t", body: "b" }, ...appBlocks(null) });
});

test("older builds without a channel: kind selects the store / driver defaults", () => {
  const order = buildMessage(valueOf({ token: TOKEN, title: "New order", kind: "order_placed" }));
  assert.equal(order.profile, "order_alert");
  assert.deepEqual(order.message.android, appBlocks("new_order", "order_alert").android);
  assert.deepEqual(order.message.apns, appBlocks(null, "default", "order_alert.caf").apns);
  for (const k of ["schedule_order", "dinein_placed", "new_order"]) {
    assert.equal(resolveProfile(valueOf({ token: TOKEN, title: "t", kind: k })), "order_alert", k);
  }
  const job = buildMessage(valueOf({ token: TOKEN, title: "New delivery", kind: "new_delivery_order" }));
  assert.equal(job.profile, "driver_job");
  assert.equal(job.channelId, "driver_jobs");
  assert.equal(resolveProfile(valueOf({ token: TOKEN, title: "t", kind: "assign_order" })), "driver_job");
  // data.type can pick the order alert, never the driver channel.
  assert.equal(resolveProfile(valueOf({ token: TOKEN, title: "t", data: { type: "NEW_ORDER" } })), "order_alert");
  assert.equal(resolveProfile(valueOf({ token: TOKEN, title: "t", data: { type: "parcel_order" } })), "default");
  assert.equal(resolveProfile(valueOf({ token: TOKEN, title: "t", kind: "new_delivery_order", data: { type: "new_order" } })), "driver_job");
});

test("the caller's channel and sounds win over the kind defaults", () => {
  const { message } = buildMessage(
    valueOf({ token: TOKEN, title: "t", kind: "order_placed", android: { channelId: "general", sound: "ding" }, apns: { sound: "default" } }),
  );
  assert.deepEqual(message.android, appBlocks("general", "ding").android);
  assert.deepEqual(message.apns.payload.aps.sound, "default");
});

test("data-only push: high priority, no android.notification, silent background APNs", () => {
  const { message } = buildMessage(valueOf({ token: TOKEN, kind: "order_placed", data: { orderId: "o1" } }));
  assert.deepEqual(message, {
    token: TOKEN,
    data: { orderId: "o1" },
    android: { priority: "high" },
    apns: { headers: { "apns-priority": "5", "apns-push-type": "background" }, payload: { aps: { contentAvailable: true } } },
  });
});

test("empty title/body are kept (sendFcmMessage with a missing template)", () => {
  const { message } = buildMessage(valueOf({ token: TOKEN, title: "", body: "" }));
  assert.deepEqual(message.notification, { title: "", body: "" });
});

// ---------------------------------------------------------------------------
// Converted like the apps' stringData(), never refused for it

test("data values are converted like the apps do", () => {
  const r = parseOk({ token: TOKEN, title: "t", data: { s: "x", n: 5, f: 1.5, b: true, m: { a: 1 }, l: [1, "2"], z: null } });
  assert.deepEqual(r.value.data, { s: "x", n: "5", f: "1.5", b: "true", m: '{"a":1}', l: '[1,"2"]' });
  assert.deepEqual(r.adjustments.convertedDataKeys.sort(), ["b", "f", "l", "m", "n"]);
  assert.deepEqual(r.adjustments.droppedDataKeys, ["z"]);
  assert.equal(dataValueToString(false), "false");
});

test("FCM-reserved and empty data keys are dropped (as the apps drop them), keys trimmed", () => {
  const r = parseOk({ token: TOKEN, title: "t", data: { from: "x", "google.x": "y", gcm_x: "z", "": "e", " id ": "1", message_type: "m" } });
  assert.deepEqual(r.value.data, { id: "1" });
  assert.deepEqual(r.adjustments.droppedDataKeys.sort(), ["", "from", "gcm_x", "google.x", "message_type"]);
  assert.equal(valueOf({ token: TOKEN, title: "t", data: { b: null } }).data, undefined);
});

test("over-long title and body are clipped by code point, not refused", () => {
  const r = parseOk({ token: TOKEN, title: "a".repeat(LIMITS.titleChars + 5), body: "\u{1F600}".repeat(LIMITS.bodyChars + 1) });
  assert.equal(r.value.title.length, LIMITS.titleChars);
  assert.equal(Array.from(r.value.body).length, LIMITS.bodyChars);
  assert.deepEqual(r.adjustments.truncated, ["title", "body"]);
  assert.deepEqual(parseOk({ token: TOKEN, title: "\u{1F600}".repeat(LIMITS.titleChars) }).adjustments.truncated, []);
});

test("unknown fields and malformed overrides are ignored and reported, the push still goes", () => {
  const r = parseOk({
    token: TOKEN,
    title: "t",
    type: "x",
    kind: "bad kind",
    android: { priority: "high", channelId: "a b", sound: 5 },
    apns: { badge: "1", sound: "ok sound" },
  });
  assert.deepEqual(r.adjustments.ignored.sort(), ["android.channelId", "android.priority", "android.sound", "apns.badge", "kind", "type"]);
  assert.equal(r.value.kind, undefined);
  assert.equal(r.value.android, undefined);
  assert.deepEqual(r.value.apns, { sound: "ok sound" });
  assert.deepEqual(parseOk({ token: TOKEN, title: "t", android: "x", apns: [] }).adjustments.ignored, ["android", "apns"]);
});

test("null / empty optional fields are absent", () => {
  const r = parseOk({ token: TOKEN, topic: null, title: "t", body: null, data: null, kind: "", android: { channelId: "", sound: null }, apns: null });
  assert.deepEqual(r.value, { token: TOKEN, title: "t" });
  assert.deepEqual(r.adjustments, { ignored: [], droppedDataKeys: [], convertedDataKeys: [], truncated: [] });
});

// ---------------------------------------------------------------------------
// Refused: nothing sensible could be sent

test("exactly one usable token or topic", () => {
  assert.equal(parseErr({ title: "t" }).field, "token");
  assert.equal(parseErr({ token: TOKEN, topic: "x", title: "t" }).field, "token");
  assert.equal(parseErr({ token: "", title: "t" }).field, "token");
  assert.equal(parseErr({ token: "null", title: "t" }).field, "token");
  assert.equal(parseErr({ token: "NULL", title: "t" }).field, "token");
  assert.equal(parseErr({ token: "abc", title: "t" }).field, "token");
  assert.equal(parseErr({ token: 5, title: "t" }).field, "token");
  assert.equal(valueOf({ token: ` ${TOKEN} `, title: "t" }).token, TOKEN);
});

test("topic: /topics/ prefix stripped, charset enforced", () => {
  assert.equal(valueOf({ topic: "/topics/customer", title: "t" }).topic, "customer");
  assert.equal(buildMessage(valueOf({ topic: "zone_abc", title: "t" })).message.topic, "zone_abc");
  assert.equal(parseErr({ topic: "bad topic!", title: "t" }).field, "topic");
});

test("wrong types for title/body, nothing to send, not an object", () => {
  assert.equal(parseErr({ token: TOKEN, title: 5 }).field, "title");
  assert.equal(parseErr({ token: TOKEN, title: "t", body: {} }).field, "body");
  assert.equal(parseErr({ token: TOKEN }).field, "title");
  assert.equal(parseErr({ token: TOKEN, data: {} }).field, "title");
  assert.equal(parseErr({ token: TOKEN, title: "t", data: ["x"] }).field, "data");
  for (const bad of [null, [], "x", 1]) assert.equal(parseErr(bad).status, 400);
});

test("data over FCM's 4 KB is refused with 413", () => {
  parseOk({ token: TOKEN, data: { k: "v".repeat(LIMITS.dataBytes - 1) } });
  const r = parseErr({ token: TOKEN, data: { k: "v".repeat(LIMITS.dataBytes) } });
  assert.deepEqual([r.status, r.error, r.field], [413, "payload_too_large", "data"]);
});

// ---------------------------------------------------------------------------
// FCM errors

/** A FirebaseMessagingError as firebase-admin builds it from an FCM v1 answer. */
function fcmError(adminCode, status, errorCode, message = "x") {
  const details = errorCode ? [{ "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError", errorCode }] : [];
  return { code: adminCode, message, httpResponse: { status: 400, data: { error: { code: 400, message, status, details } } } };
}

test("FCM v1 answers map to status, error, fcmErrorCode and deadToken", () => {
  const cases = [
    [fcmError("messaging/registration-token-not-registered", "NOT_FOUND", "UNREGISTERED"), "404 unregistered UNREGISTERED true"],
    [fcmError("messaging/mismatched-credential", "PERMISSION_DENIED", "SENDER_ID_MISMATCH"), "403 sender_mismatch SENDER_ID_MISMATCH true"],
    [fcmError("messaging/invalid-argument", "INVALID_ARGUMENT", "INVALID_ARGUMENT", "The registration token is not a valid FCM registration token"), "400 invalid_token INVALID_ARGUMENT true"],
    [fcmError("messaging/invalid-argument", "INVALID_ARGUMENT", "INVALID_ARGUMENT", "Invalid value at 'message.data[0].value'"), "400 invalid_argument INVALID_ARGUMENT false"],
    [fcmError("messaging/message-rate-exceeded", "RESOURCE_EXHAUSTED", "QUOTA_EXCEEDED"), "429 fcm_rate_limited QUOTA_EXCEEDED false"],
    [fcmError("messaging/server-unavailable", "UNAVAILABLE", "UNAVAILABLE"), "503 fcm_unavailable UNAVAILABLE false"],
    [fcmError("messaging/internal-error", "INTERNAL", "INTERNAL"), "502 fcm_error INTERNAL false"],
    [fcmError("messaging/third-party-auth-error", "UNAUTHENTICATED", "THIRD_PARTY_AUTH_ERROR"), "502 apns_auth_error THIRD_PARTY_AUTH_ERROR false"],
    // The function's own permission, not the token: never clear it.
    [fcmError("messaging/mismatched-credential", "PERMISSION_DENIED", null), "500 server_misconfigured PERMISSION_DENIED false"],
    [fcmError("messaging/third-party-auth-error", "UNAUTHENTICATED", null), "500 server_misconfigured UNAUTHENTICATED false"],
  ];
  for (const [err, want] of cases) {
    const f = mapMessagingError(err);
    assert.equal(`${f.status} ${f.error} ${f.fcmErrorCode} ${f.deadToken}`, want);
  }
});

test("without a raw FCM answer the firebase-admin code is used, and tokens are cleared only when sure", () => {
  const f = (code, message) => mapMessagingError({ code, message });
  assert.deepEqual([f("messaging/registration-token-not-registered").status, f("messaging/registration-token-not-registered").deadToken], [404, true]);
  assert.equal(mapMessagingError({ errorInfo: { code: "messaging/registration-token-not-registered" } }).fcmErrorCode, "UNREGISTERED");
  assert.equal(f("messaging/invalid-argument", "registration token is invalid").deadToken, true);
  assert.equal(f("messaging/invalid-argument", "bad payload").deadToken, false);
  assert.deepEqual([f("messaging/mismatched-credential").status, f("messaging/mismatched-credential").deadToken], [403, false]);
  assert.equal(f("messaging/payload-size-limit-exceeded").status, 413);
  assert.equal(f("messaging/authentication-error").error, "server_misconfigured");
  assert.equal(f("app/invalid-credential").error, "internal");
  assert.equal(f("something/else").status, 500);
  assert.deepEqual(rawFcmErrorCode({ httpResponse: { data: '{"error":{"status":"UNAVAILABLE"}}' } }), { code: "UNAVAILABLE", message: "" });
  assert.deepEqual(rawFcmErrorCode(null), { code: "", message: "" });
});

test("auth errors", () => {
  assert.equal(mapAuthError({ code: "auth/id-token-expired" }).error, "id_token_expired");
  assert.equal(mapAuthError({ code: "auth/id-token-revoked" }).status, 403);
  assert.equal(mapAuthError({ code: "auth/argument-error" }).status, 401);
  assert.equal(mapAuthError({ code: "app/network-error" }).status, 503);
  assert.equal(mapAuthError(new Error("x")).status, 401);
});

// ---------------------------------------------------------------------------
// Dead-token clean-up

test("clearDeadToken blanks every profile holding the token, conditionally", async () => {
  const updates = [];
  const db = {
    collection(name) {
      return {
        where(field, op, value) {
          assert.deepEqual([field, op, value], ["fcmToken", "==", TOKEN]);
          return {
            limit() {
              return {
                async get() {
                  const docs = name === "users" ? ["u1", "u2"] : name === "vendors" ? ["v1"] : [];
                  return {
                    docs: docs.map((id) => ({
                      updateTime: `t-${id}`,
                      ref: {
                        async update(data, precondition) {
                          if (id === "u2") throw new Error("FAILED_PRECONDITION");
                          updates.push([name, id, data, precondition]);
                        },
                      },
                    })),
                  };
                },
              };
            },
          };
        },
      };
    },
  };
  assert.deepEqual([...TOKEN_COLLECTIONS], ["users", "providers_workers", "vendors"]);
  assert.equal(await clearDeadToken(db, TOKEN), 2);
  assert.deepEqual(updates, [
    ["users", "u1", { fcmToken: "" }, { lastUpdateTime: "t-u1" }],
    ["vendors", "v1", { fcmToken: "" }, { lastUpdateTime: "t-v1" }],
  ]);
});

// ---------------------------------------------------------------------------
// Rate limit and redaction

test("sliding window: refusals are not recorded", () => {
  const limits = { perMinute: 3, perDay: 100 };
  const t0 = Date.UTC(2026, 9, 2, 12, 0, 0);
  let state;
  for (let i = 0; i < 3; i++) {
    const d = evaluateRateLimit(state, t0 + i * 1000, limits);
    assert.equal(d.allowed, true);
    state = d.next;
  }
  assert.deepEqual(evaluateRateLimit(state, t0 + 3000, limits), { allowed: false, reason: "minute", retryAfterSeconds: 57 });
  const later = evaluateRateLimit(state, t0 + 60_001, limits);
  assert.equal(later.allowed, true);
  assert.equal(later.next.hits.length, 3);
  assert.equal(later.next.dayCount, 4);
});

test("daily cap resets at UTC midnight; garbage state is ignored", () => {
  const limits = { perMinute: 60, perDay: 2 };
  const t0 = Date.UTC(2026, 9, 2, 23, 59, 0);
  const full = { hits: [], dayKey: utcDayKey(t0), dayCount: 2 };
  assert.deepEqual(evaluateRateLimit(full, t0, limits), { allowed: false, reason: "day", retryAfterSeconds: 60 });
  assert.equal(evaluateRateLimit(full, t0 + 60_000, limits).allowed, true);
  const junk = evaluateRateLimit({ hits: ["x", null, -1, Infinity], dayKey: 5, dayCount: "9" }, t0, limits);
  assert.equal(junk.allowed, true);
  assert.deepEqual(junk.next, { hits: [t0], dayKey: "2026-10-02", dayCount: 1 });
});

test("fingerprint is short, stable and not the token", () => {
  assert.equal(fingerprint(TOKEN).length, 12);
  assert.equal(fingerprint(TOKEN), fingerprint(TOKEN));
  assert.ok(!TOKEN.includes(fingerprint(TOKEN)));
});
