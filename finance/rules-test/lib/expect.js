import assert from 'node:assert/strict';

/** The request went through. */
export function allowed(r, what = '') {
  assert.ok(r.ok, `expected ALLOWED ${what}: ${r.status} ${typeof r.body === 'string' ? r.body : JSON.stringify(r.body)}`.slice(0, 1500));
}

/** The rules refused it (403), not some other failure. */
export function denied(r, what = '') {
  assert.equal(r.status, 403, `expected DENIED (403) ${what}, got ${r.status} ${typeof r.body === 'string' ? r.body : JSON.stringify(r.body)}`.slice(0, 1500));
}

export { assert };
