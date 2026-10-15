#!/usr/bin/env python3
"""Simulates the admin panel's steps in the QA emulator, as
docs/SPIDELI_FINANCE_ADMIN_WEB_SPEC.md describes them (owner access, like the
panel's Admin SDK: the rules are bypassed, so every check is made here).

    python3 admin.py withdrawal-complete OP_ID
    python3 admin.py withdrawal-fail OP_ID "reason"
    python3 admin.py reverse TX_ID "reason"
    ... (see the commands at the end)

Each money step is a balanced posting: platform and customer accounts move by
the same amount, and a wallet never goes below zero.
"""

import datetime
import json
import os
import random
import string
import sys
import urllib.error
import urllib.request

PROJECT = 'spideli-870b0'
FS = f'http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents'
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from seed import enc  # noqa: E402
from verify import dec  # noqa: E402

ADMIN = 'admin:qa'


def now():
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)


def call(method, url, body=None):
    req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(), headers={'Content-Type': 'application/json', 'Authorization': 'Bearer owner'}, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise SystemExit(f'{method} {url} -> {e.code}: {e.read().decode()[:300]}')


def get(path):
    d = call('GET', f'{FS}/{path}')
    return None if d is None else {k: dec(v) for k, v in d.get('fields', {}).items()}


def patch(path, fields):
    """Updates only the given fields (like the panel's update())."""
    mask = '&'.join(f'updateMask.fieldPaths={k}' for k in fields)
    call('PATCH', f'{FS}/{path}?{mask}', {'fields': {k: enc(v) for k, v in fields.items()}})


def put(path, data):
    call('PATCH', f'{FS}/{path}', {'fields': {k: enc(v) for k, v in data.items()}})


def rid(n=8):
    return ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(n))


def reference():
    a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    return 'SPF-' + now().strftime('%y%m%d') + '-' + ''.join(random.choice(a) for _ in range(6))


def post(type_, cur, frm, to, amount, user_ids, source, description, fee=0, reversal_of=None):
    """The panel's posting helper (admin spec 5.2): plan (reads, checks), then write."""
    assert amount > 0 and fee >= 0 and frm != to
    platform = f'platform_{cur}'
    lines = [{'accountId': frm, 'direction': 'debit', 'amount': amount + fee}, {'accountId': to, 'direction': 'credit', 'amount': amount}]
    if fee > 0 and platform not in (frm, to):
        lines.append({'accountId': platform, 'direction': 'credit', 'amount': fee})
    accounts = {}
    for l in lines:
        a = get(f'financial_accounts/{l["accountId"]}')
        if a is None:
            if l['direction'] == 'debit' or not l['accountId'].startswith('wallet_'):
                raise SystemExit(f'missing account {l["accountId"]}')
            uid = l['accountId'][len('wallet_'):].rsplit('_', 1)[0]
            a = {'id': l['accountId'], 'kind': 'wallet', 'userId': uid, 'currency': cur, 'balance': 0, 'normalSide': 'credit', 'status': 'active', '_new': True}
        if a.get('status') != 'active':
            raise SystemExit(f'account {l["accountId"]} is {a.get("status")}')
        delta = -l['amount'] if l['direction'] == 'debit' else l['amount']
        if a['balance'] + delta < 0 and a.get('kind') != 'platform':
            raise SystemExit(f'insufficient funds on {l["accountId"]}: {a["balance"]} < {l["amount"]}')
        accounts[l['accountId']] = (a, delta)
    tx = f'tx_{int(now().timestamp() * 1000)}_{rid()}'
    t = now()
    doc = {'id': tx, 'type': type_, 'status': 'posted', 'reference': reference(), 'currency': cur, 'lines': lines, 'userIds': sorted(set(user_ids)),
           'accountIds': [l['accountId'] for l in lines], 'source': source, 'funding': 'wallet', 'description': description, 'createdBy': ADMIN, 'createdAt': t}
    if reversal_of:
        doc['reversalOf'] = reversal_of
    put(f'ledger_transactions/{tx}', doc)
    for acc_id, (a, delta) in accounts.items():
        if a.get('_new'):
            put(f'financial_accounts/{acc_id}', {'id': acc_id, 'kind': 'wallet', 'userId': a['userId'], 'currency': cur, 'balance': delta, 'normalSide': 'credit', 'status': 'active', 'lastTxId': tx, 'createdAt': t, 'updatedAt': t})
        else:
            patch(f'financial_accounts/{acc_id}', {'balance': a['balance'] + delta, 'lastTxId': tx, 'updatedAt': t})
    return tx, doc['reference']


def reverse(tx_id, reason):
    o = get(f'ledger_transactions/{tx_id}')
    if o is None or o['status'] == 'reversed':
        raise SystemExit('nothing to reverse')
    debit, credit = o['lines'][0], o['lines'][1]
    ids = [post('reversal', o['currency'], credit['accountId'], debit['accountId'], credit['amount'], o['userIds'], o['source'], reason, reversal_of=tx_id)[0]]
    if len(o['lines']) > 2:
        ids.append(post('reversal', o['currency'], o['lines'][2]['accountId'], debit['accountId'], o['lines'][2]['amount'], o['userIds'], o['source'], reason, reversal_of=tx_id)[0])
    patch(f'ledger_transactions/{tx_id}', {'status': 'reversed', 'reversedBy': ids, 'reversedAt': now()})
    return ids


# ---------------------------------------------------------------- queues
def withdrawal_complete(op_id):
    op = get(f'wallet_operations/{op_id}')
    assert op and op['type'] == 'withdrawal' and op['status'] == 'pending', op
    patch(f'wallet_operations/{op_id}', {'status': 'completed', 'payoutReference': 'OM-QA-' + rid(6).upper(), 'completedAt': now(), 'processedBy': ADMIN})


def withdrawal_fail(op_id, reason):
    op = get(f'wallet_operations/{op_id}')
    assert op and op['type'] == 'withdrawal' and op['status'] == 'pending', op
    reverse(op['txId'], reason)
    patch(f'wallet_operations/{op_id}', {'status': 'reversed', 'reason': reason, 'completedAt': now(), 'processedBy': ADMIN})


def transfer_lock(tid):
    patch(f'money_transfers/{tid}', {'adminLockedAt': now()})


def transfer_complete(tid):
    t = get(f'money_transfers/{tid}')
    assert t and t['status'] == 'processing' and not t.get('cancelRequested'), t
    patch(f'money_transfers/{tid}', {'status': 'completed', 'providerReference': 'MM-QA-' + rid(6).upper(), 'completedAt': now(), 'recipientVerified': True})


def transfer_cancel(tid):
    """A cancel request not yet paid: refund, then cancelled."""
    t = get(f'money_transfers/{tid}')
    assert t and t['status'] == 'processing' and t.get('cancelRequested') is True, t
    reverse(t['txId'], 'Cancelled at your request')
    patch(f'money_transfers/{tid}', {'status': 'cancelled', 'reason': 'cancelled_by_sender', 'completedAt': now()})


def transfer_reverse(tid, reason):
    t = get(f'money_transfers/{tid}')
    assert t and t['status'] == 'processing', t
    reverse(t['txId'], reason)
    patch(f'money_transfers/{tid}', {'status': 'reversed', 'reason': reason, 'completedAt': now()})


if __name__ == '__main__':
    cmd, args = sys.argv[1], sys.argv[2:]
    {
        'withdrawal-complete': lambda: withdrawal_complete(args[0]),
        'withdrawal-fail': lambda: withdrawal_fail(args[0], args[1]),
        'reverse': lambda: print(reverse(args[0], args[1])),
        'transfer-lock': lambda: transfer_lock(args[0]),
        'transfer-complete': lambda: transfer_complete(args[0]),
        'transfer-cancel': lambda: transfer_cancel(args[0]),
        'transfer-reverse': lambda: transfer_reverse(args[0], args[1]),
    }[cmd]()
    print('done')
