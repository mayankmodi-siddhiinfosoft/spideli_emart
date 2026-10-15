#!/usr/bin/env python3
"""Reads the QA emulator's Firestore (owner access) to verify finance records.

    python3 verify.py ledger            # integrity check of every account
    python3 verify.py balances          # each sample customer's wallets
    python3 verify.py tx [N]            # the N latest postings
    python3 verify.py docs COLLECTION [N]   # the N latest documents of a collection
    python3 verify.py doc PATH          # one document

Integrity check: every posting is balanced (one debit = the credits), and
every account's balance equals its credits minus its debits in the ledger,
so the balances of all accounts sum to zero.
"""

import json
import os
import sys
import urllib.request

PROJECT = 'spideli-870b0'
FS = f'http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents'
HERE = os.path.dirname(os.path.abspath(__file__))


def dec(v):
    k, x = next(iter(v.items()))
    if k == 'integerValue':
        return int(x)
    if k == 'doubleValue':
        return float(x)
    if k == 'mapValue':
        return {a: dec(b) for a, b in x.get('fields', {}).items()}
    if k == 'arrayValue':
        return [dec(b) for b in x.get('values', [])]
    if k == 'nullValue':
        return None
    if k == 'geoPointValue':
        return (x.get('latitude'), x.get('longitude'))
    return x


def get(url):
    req = urllib.request.Request(url, headers={'Authorization': 'Bearer owner'})
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def docs(collection):
    out, token = [], ''
    while True:
        body = get(f'{FS}/{collection}?pageSize=300' + (f'&pageToken={token}' if token else ''))
        for d in body.get('documents', []):
            f = {k: dec(v) for k, v in d.get('fields', {}).items()}
            f['_id'] = d['name'].rsplit('/', 1)[1]
            f['_updated'] = d.get('updateTime', '')
            out.append(f)
        token = body.get('nextPageToken', '')
        if not token:
            return out


def names():
    uids = json.load(open(os.path.join(HERE, 'uids.json')))
    return {v: k for k, v in uids.items()}


def label(account_id, who):
    for uid, n in who.items():
        account_id = account_id.replace(uid, n)
    return account_id


def ledger():
    accounts = {a['_id']: a for a in docs('financial_accounts')}
    txs = docs('ledger_transactions')
    computed = {k: 0 for k in accounts}
    problems = []
    for t in txs:
        lines = t.get('lines', [])
        debit = sum(l['amount'] for l in lines if l['direction'] == 'debit')
        credit = sum(l['amount'] for l in lines if l['direction'] == 'credit')
        if debit != credit:
            problems.append(f'unbalanced posting {t["_id"]}: debit {debit} != credit {credit}')
        for l in lines:
            computed.setdefault(l['accountId'], 0)
            computed[l['accountId']] += l['amount'] if l['direction'] == 'credit' else -l['amount']
    who = names()
    for k, a in sorted(accounts.items()):
        if a.get('balance') != computed.get(k, 0):
            problems.append(f'{label(k, who)}: balance {a.get("balance")} but ledger says {computed.get(k, 0)}')
        if a.get('kind') != 'platform' and a.get('balance', 0) < 0:
            problems.append(f'{label(k, who)}: negative balance {a.get("balance")}')
    for k in computed:
        if k not in accounts:
            problems.append(f'{label(k, who)}: in the ledger but no account document')
    total = sum(a.get('balance', 0) for a in accounts.values() if a.get('currency') == 'XAF')
    print(f'{len(txs)} postings, {len(accounts)} accounts, XAF balances sum to {total}')
    print('OK: ledger consistent' if not problems and total == 0 else 'PROBLEMS:\n  ' + '\n  '.join(problems))


def balances():
    who = names()
    for a in sorted(docs('financial_accounts'), key=lambda a: a['_id']):
        print(f'{label(a["_id"], who):45} {a.get("kind"):12} {a.get("balance"):>12} {a.get("currency")}  {a.get("status")}')


def recent(collection, n, key='createdAt'):
    items = sorted(docs(collection), key=lambda d: str(d.get(key) or d.get('_updated')), reverse=True)[:n]
    who = names()
    for d in items:
        print(label(json.dumps(d, default=str, ensure_ascii=False), who))


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'ledger'
    if cmd == 'ledger':
        ledger()
    elif cmd == 'balances':
        balances()
    elif cmd == 'tx':
        recent('ledger_transactions', int(sys.argv[2]) if len(sys.argv) > 2 else 5)
    elif cmd == 'docs':
        recent(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 5)
    elif cmd == 'doc':
        f = get(f'{FS}/{sys.argv[2]}')
        print(label(json.dumps({k: dec(v) for k, v in f.get('fields', {}).items()}, default=str, ensure_ascii=False, indent=1), names()))
