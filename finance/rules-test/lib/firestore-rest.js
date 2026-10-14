// A tiny client for the Firestore EMULATOR's REST API, so the rules tests
// need no npm package (Node 20+: global fetch, node:test).
//
// - user requests carry an unsigned ID token (the emulator accepts them, as
//   @firebase/rules-unit-testing does): rules see request.auth.uid / token;
// - admin seeding uses "Bearer owner", which bypasses the rules (emulator only).
//
// Writes mirror the Flutter SDK: batch.set = whole-document update (no mask),
// batch.update = masked update with an exists precondition, set(merge) =
// masked update without precondition. Sentinels: SERVER_TIME, inc(n),
// union(...values), dbl(x) for a double that looks like an integer.

const HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8181';
export const PROJECT = process.env.GCLOUD_PROJECT || 'demo-spideli';
const BASE = `http://${HOST}/v1/projects/${PROJECT}/databases/(default)/documents`;
const ROOT = `projects/${PROJECT}/databases/(default)/documents`;

export const SERVER_TIME = Symbol('serverTime');
export const DELETE = Symbol('delete');
export const inc = (n) => ({ __inc: n });
export const union = (...values) => ({ __union: values });
export const dbl = (x) => ({ __double: x });
export const ts = (date) => ({ __ts: date instanceof Date ? date : new Date(date) });

function b64url(obj) {
  return Buffer.from(JSON.stringify(obj)).toString('base64url');
}

/** An unsigned ID token for [uid] (auth_time defaults to now). */
export function token(uid, claims = {}) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: `https://securetoken.google.com/${PROJECT}`,
    aud: PROJECT,
    iat: now,
    exp: now + 3600,
    auth_time: now,
    sub: uid,
    user_id: uid,
    firebase: { sign_in_provider: 'password', identities: {} },
    ...claims,
  };
  return `${b64url({ alg: 'none', typ: 'JWT' })}.${b64url(payload)}.`;
}

export function encode(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (v && v.__double !== undefined) return { doubleValue: v.__double };
  if (v && v.__ts !== undefined) return { timestampValue: v.__ts.toISOString() };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(encode) } };
  if (typeof v === 'object') return { mapValue: { fields: encodeFields(v) } };
  throw new Error(`cannot encode ${String(v)}`);
}

function isSentinel(v) {
  return v === SERVER_TIME || v === DELETE || (v && typeof v === 'object' && (v.__inc !== undefined || v.__union !== undefined));
}

function isPlainMap(v) {
  return v && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Date) && v.__ts === undefined && v.__double === undefined && !isSentinel(v);
}

// set(merge: true) as the SDKs send it: every leaf field path in the mask
// (nested maps merged, not replaced), sentinels as transforms / deletes.
function mergeParts(obj, prefix, fields, mask, transforms) {
  for (const [k, v] of Object.entries(obj)) {
    const path = prefix ? `${prefix}.${fieldPath(k)}` : fieldPath(k);
    if (v === SERVER_TIME) transforms.push({ fieldPath: path, setToServerValue: 'REQUEST_TIME' });
    else if (v === DELETE) mask.push(path);
    else if (v && typeof v === 'object' && v.__inc !== undefined) transforms.push({ fieldPath: path, increment: encode(v.__inc) });
    else if (v && typeof v === 'object' && v.__union !== undefined) transforms.push({ fieldPath: path, appendMissingElements: { values: v.__union.map(encode) } });
    else if (isPlainMap(v) && Object.keys(v).length > 0) {
      fields[k] = fields[k] || { mapValue: { fields: {} } };
      mergeParts(v, path, fields[k].mapValue.fields, mask, transforms);
    } else {
      mask.push(path);
      fields[k] = encode(v);
    }
  }
}

function encodeFields(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) if (!isSentinel(v)) out[k] = encode(v);
  return out;
}

function fieldPath(k) {
  return /^[A-Za-z_][A-Za-z_0-9]*$/.test(k) ? k : '`' + k.replace(/`/g, '\\`') + '`';
}

// The field transforms of a set() / merge (top-level sentinels only).
function transformsOf(obj) {
  const out = [];
  for (const [k, v] of Object.entries(obj)) {
    const path = fieldPath(k);
    if (v === SERVER_TIME) out.push({ fieldPath: path, setToServerValue: 'REQUEST_TIME' });
    else if (v && typeof v === 'object' && v.__inc !== undefined) out.push({ fieldPath: path, increment: encode(v.__inc) });
    else if (v && typeof v === 'object' && v.__union !== undefined) out.push({ fieldPath: path, appendMissingElements: { values: v.__union.map(encode) } });
  }
  return out;
}

// For update(): 'a.b' keys address nested fields, like the SDKs.
function nestedFromDotted(data) {
  const fields = {};
  const mask = [];
  const transforms = [];
  for (const [k, v] of Object.entries(data)) {
    const parts = k.split('.');
    const path = parts.map(fieldPath).join('.');
    if (v === SERVER_TIME) { transforms.push({ fieldPath: path, setToServerValue: 'REQUEST_TIME' }); continue; }
    if (v && typeof v === 'object' && v.__inc !== undefined) { transforms.push({ fieldPath: path, increment: encode(v.__inc) }); continue; }
    if (v && typeof v === 'object' && v.__union !== undefined) { transforms.push({ fieldPath: path, appendMissingElements: { values: v.__union.map(encode) } }); continue; }
    if (v === DELETE) { mask.push(path); continue; }
    mask.push(path);
    let cur = fields;
    for (let i = 0; i < parts.length - 1; i++) {
      cur[parts[i]] = cur[parts[i]] || { mapValue: { fields: {} } };
      cur = cur[parts[i]].mapValue.fields;
    }
    cur[parts[parts.length - 1]] = encode(v);
  }
  return { fields, mask, transforms };
}

export function decode(v) {
  if ('nullValue' in v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decode);
  if ('mapValue' in v) return decodeFields(v.mapValue.fields || {});
  if ('referenceValue' in v) return v.referenceValue;
  return v;
}

function decodeFields(f) {
  const out = {};
  for (const [k, v] of Object.entries(f)) out[k] = decode(v);
  return out;
}

/** A batch of writes, committed atomically (one request: rules see every write). */
export class Batch {
  constructor() { this.writes = []; }
  /** batch.set(ref, data): replaces the document (creates it when missing). */
  set(path, data) {
    const w = { update: { name: `${ROOT}/${path}`, fields: encodeFields(data) } };
    const t = transformsOf(data);
    if (t.length) w.updateTransforms = t;
    this.writes.push(w);
    return this;
  }
  /** batch.set(ref, data, SetOptions(merge: true)): leaf paths merged. */
  merge(path, data) {
    const fields = {};
    const mask = [];
    const transforms = [];
    mergeParts(data, '', fields, mask, transforms);
    const w = { update: { name: `${ROOT}/${path}`, fields }, updateMask: { fieldPaths: mask } };
    if (transforms.length) w.updateTransforms = transforms;
    this.writes.push(w);
    return this;
  }
  /** batch.update(ref, data): only the given fields ('a.b' = nested); the document must exist. */
  update(path, data) {
    const { fields, mask, transforms } = nestedFromDotted(data);
    const w = { update: { name: `${ROOT}/${path}`, fields }, updateMask: { fieldPaths: mask }, currentDocument: { exists: true } };
    if (transforms.length) w.updateTransforms = transforms;
    this.writes.push(w);
    return this;
  }
  delete(path) {
    this.writes.push({ delete: `${ROOT}/${path}` });
    return this;
  }
}

async function call(method, url, auth, body) {
  const res = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${auth}` },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = { raw: text }; }
  return { status: res.status, json };
}

/** A client acting as a signed-in user ([uid] null = signed out, 'owner' = admin bypass). */
export class Client {
  constructor(uid, claims = {}) {
    this.auth = uid === 'owner' ? 'owner' : uid === null ? null : token(uid, claims);
  }
  async commit(batch) {
    const r = await fetch(`${BASE}:commit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(this.auth ? { Authorization: `Bearer ${this.auth}` } : {}) },
      body: JSON.stringify({ writes: batch.writes }),
    });
    const text = await r.text();
    return { ok: r.ok, status: r.status, body: text };
  }
  async get(path) {
    const r = await fetch(`${BASE}/${path}`, { headers: this.auth ? { Authorization: `Bearer ${this.auth}` } : {} });
    const json = await r.json().catch(() => null);
    return { ok: r.ok, status: r.status, data: r.ok && json && json.fields ? decodeFields(json.fields) : null, body: json };
  }
  /** where: [[field, op, value]] with op in == array-contains < <= > >= ; orderBy: [[field, 'desc'|'asc']] */
  async query(collection, { where = [], orderBy = [], limit } = {}, parent = '') {
    const ops = { '==': 'EQUAL', 'array-contains': 'ARRAY_CONTAINS', '<': 'LESS_THAN', '<=': 'LESS_THAN_OR_EQUAL', '>': 'GREATER_THAN', '>=': 'GREATER_THAN_OR_EQUAL', in: 'IN' };
    const filters = where.map(([f, op, v]) => ({ fieldFilter: { field: { fieldPath: f }, op: ops[op], value: encode(v) } }));
    const sq = { from: [{ collectionId: collection }] };
    if (filters.length === 1) sq.where = filters[0];
    if (filters.length > 1) sq.where = { compositeFilter: { op: 'AND', filters } };
    if (orderBy.length) sq.orderBy = orderBy.map(([f, d]) => ({ field: { fieldPath: f }, direction: d === 'desc' ? 'DESCENDING' : 'ASCENDING' }));
    if (limit) sq.limit = limit;
    const url = parent ? `${BASE}/${parent}:runQuery` : `${BASE}:runQuery`;
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(this.auth ? { Authorization: `Bearer ${this.auth}` } : {}) },
      body: JSON.stringify({ structuredQuery: sq }),
    });
    const json = await r.json().catch(() => null);
    const docs = r.ok && Array.isArray(json) ? json.filter((x) => x.document).map((x) => ({ id: x.document.name.split('/').pop(), ...decodeFields(x.document.fields || {}) })) : [];
    return { ok: r.ok, status: r.status, docs, body: json };
  }
}

export const admin = new Client('owner');

/** Seeds documents as the admin (rules bypassed): { 'coll/id': data }. */
export async function seed(docs) {
  const b = new Batch();
  for (const [path, data] of Object.entries(docs)) b.set(path, data);
  const r = await admin.commit(b);
  if (!r.ok) throw new Error(`seed failed: ${r.status} ${r.body}`);
}

export async function clear() {
  const r = await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
  if (!r.ok) throw new Error(`clear failed: ${r.status}`);
}

/** Loads [source] as the emulator's rules for this project. */
export async function loadRules(source) {
  const r = await fetch(`http://${HOST}/emulator/v1/projects/${PROJECT}:securityRules`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ rules: { files: [{ name: 'firestore.rules', content: source }] } }),
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`rules did not load: ${r.status} ${text}`);
  return text;
}
