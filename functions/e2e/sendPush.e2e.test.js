// End-to-end smoke test of the deployed shape of sendPush, on the emulators.
//
//   cd functions && npm run test:e2e
//
// Starts the Auth, Firestore and Functions emulators under the demo-spideli
// project id (a "demo-" project never reaches real Google services), creates
// accounts in the Auth emulator, and calls the function over HTTP exactly as
// the apps do. Everything up to the FCM call is real; FCM itself cannot be
// emulated, so the final send fails without credentials and the test checks
// that the failure comes back in the contract's shape.
const { before, describe, test } = require("node:test");
const assert = require("node:assert/strict");

const PROJECT = "demo-spideli";
const AUTH = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099"}`;
const FIRESTORE = `http://${process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080"}`;
const URL = `http://127.0.0.1:5001/${PROJECT}/us-central1/sendPush`;
const TOKEN = "fGx1cZ3kT0mH0vbH8ZQwq1:APA91bH" + "x".repeat(120);

async function signUp(body) {
  const r = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...body, returnSecureToken: true }),
  });
  const j = await r.json();
  assert.ok(j.idToken, JSON.stringify(j));
  return { uid: j.localId, idToken: j.idToken };
}

function fsValue(v) {
  if (typeof v === "string") return { stringValue: v };
  if (typeof v === "number") return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(fsValue) } };
  return { nullValue: null };
}

/** Writes a document with rules bypassed ("Bearer owner" is the emulator's admin token). */
async function putDoc(path, data) {
  const fields = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, fsValue(v)]));
  const r = await fetch(`${FIRESTORE}/v1/projects/${PROJECT}/databases/(default)/documents/${path}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json", Authorization: "Bearer owner" },
    body: JSON.stringify({ fields }),
  });
  assert.equal(r.status, 200, await r.text());
}

async function getDoc(path) {
  const r = await fetch(`${FIRESTORE}/v1/projects/${PROJECT}/databases/(default)/documents/${path}`, { headers: { Authorization: "Bearer owner" } });
  return r.status === 200 ? r.json() : null;
}

async function call(idToken, body, init = {}) {
  const headers = { "Content-Type": "application/json", ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}), ...(init.headers ?? {}) };
  const r = await fetch(URL, { method: init.method ?? "POST", headers, body: init.method === "GET" ? undefined : JSON.stringify(body) });
  const text = await r.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    // framework error pages are not JSON
  }
  return { status: r.status, json, text, headers: r.headers };
}

let customer;
let stranger;
let anon;

before(async () => {
  customer = await signUp({ email: "customer@spideli.test", password: "secret123" });
  stranger = await signUp({ email: "noprofile@spideli.test", password: "secret123" });
  anon = await signUp({});
  await putDoc(`users/${customer.uid}`, { id: customer.uid, role: "customer", fcmToken: "x" });
});

describe("sendPush over HTTP", () => {
  test("only POST, only JSON", async () => {
    const get = await call(customer.idToken, null, { method: "GET" });
    assert.equal(get.status, 405);
    assert.equal(get.headers.get("allow"), "POST");
    const form = await call(customer.idToken, {}, { headers: { "Content-Type": "text/plain" } });
    assert.equal(form.status, 415);
  });

  test("authentication: missing, garbage, anonymous, no profile", async () => {
    const none = await call(null, { token: TOKEN, title: "t" });
    assert.deepEqual([none.status, none.json.error], [401, "unauthenticated"]);
    const bad = await call("not-a-token", { token: TOKEN, title: "t" });
    assert.deepEqual([bad.status, bad.json.error], [401, "invalid_id_token"]);
    const a = await call(anon.idToken, { token: TOKEN, title: "t" });
    assert.deepEqual([a.status, a.json.error], [403, "anonymous_not_allowed"]);
    const s = await call(stranger.idToken, { token: TOKEN, title: "t" });
    assert.deepEqual([s.status, s.json.error], [403, "user_not_found"]);
  });

  test("validation happens before anything is sent", async () => {
    const r = await call(customer.idToken, { token: "null", title: "t" });
    assert.deepEqual([r.status, r.json.error, r.json.field], [400, "invalid_argument", "token"]);
    const big = await call(customer.idToken, { token: TOKEN, data: { k: "v".repeat(4096) } });
    assert.deepEqual([big.status, big.json.error], [413, "payload_too_large"]);
    const topic = await call(customer.idToken, { topic: "customer", title: "t" });
    assert.deepEqual([topic.status, topic.json.error], [403, "topic_forbidden"]);
  });

  test("a valid app request reaches FCM; its failure comes back in the contract's shape", async () => {
    const r = await call(customer.idToken, {
      token: TOKEN,
      title: "Order placed",
      body: "#1",
      data: { type: "order_placed", orderId: "o1", amount: 12 },
      kind: "order_placed",
      android: { channelId: "new_order", sound: "order_alert" },
      apns: { sound: "order_alert.caf" },
    });
    // No FCM credentials on the emulator: a 5xx with the failure fields.
    assert.ok(r.status >= 500, `${r.status} ${r.text}`);
    assert.equal(r.json.ok, false);
    assert.equal(typeof r.json.fcmErrorCode, "string");
    assert.equal(r.json.deadToken, false);
    // The attempt was counted.
    const limit = await getDoc(`push_rate_limits/${customer.uid}`);
    assert.ok(limit, "push_rate_limits doc written");
    assert.equal(limit.fields.dayCount.integerValue, "1");
  });

  test("per-account daily limit", async () => {
    const today = new Date().toISOString().slice(0, 10);
    await putDoc(`push_rate_limits/${customer.uid}`, { hits: [], dayKey: today, dayCount: 3000 });
    const r = await call(customer.idToken, { token: TOKEN, title: "t" });
    assert.deepEqual([r.status, r.json.error, r.json.limit], [429, "rate_limited", "day"]);
    assert.ok(Number(r.headers.get("retry-after")) > 0);
  });
});
