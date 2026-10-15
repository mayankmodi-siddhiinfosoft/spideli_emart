#!/usr/bin/env python3
"""Seeds the Spideli Finance QA environment (local emulators only).

Run ./start.sh first, then:

    python3 seed.py            # reset the emulators and seed everything

Every request goes to 127.0.0.1 (the Auth, Firestore and Storage emulators
started by start.sh, project spideli-870b0 inside the emulator). Nothing is
sent to the live project. Firestore writes use the emulator's `owner` token,
which bypasses the security rules exactly like the admin panel's Admin SDK.

Sample customers (fictional people; the password is for this local
environment only):
    Amina Diallo   amina.diallo@spideli.test   verified (basic), 500 000 XAF
    Jean Mbarga    jean.mbarga@spideli.test    verified (basic), 300 000 XAF
    Fatou Ndiaye   fatou.ndiaye@spideli.test   not verified yet,  150 000 XAF
"""

import datetime
import json
import os
import random
import string
import urllib.error
import urllib.parse
import urllib.request

PROJECT = 'spideli-870b0'
FS = f'http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents'
AUTH = 'http://127.0.0.1:9099'
PASSWORD = 'SpideliQA#2026'  # local emulator accounts only

HERE = os.path.dirname(os.path.abspath(__file__))
NOW = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)


# ---------------------------------------------------------------- config
def finance_config():
    """The finance settings of .claude/seed_finance_config.py (the same values
    the live seed uses), read without running that script's network code."""
    src = open(os.path.join(HERE, '..', '..', '.claude', 'seed_finance_config.py')).read()
    src = src[: src.index('SERVICE_TYPE = ')]
    ns = {'datetime': datetime}
    exec(compile(src, 'seed_finance_config', 'exec'), ns)
    return ns['SETTINGS'], ns['RESOURCES'], ns['TEMPLATES']


# ---------------------------------------------------------------- encoding
class Geo:
    def __init__(self, lat, lng):
        self.lat, self.lng = lat, lng


def enc(v):
    if v is None:
        return {'nullValue': None}
    if isinstance(v, bool):
        return {'booleanValue': v}
    if isinstance(v, int):
        return {'integerValue': str(v)}
    if isinstance(v, float):
        return {'doubleValue': v}
    if isinstance(v, str):
        return {'stringValue': v}
    if isinstance(v, datetime.datetime):
        return {'timestampValue': v.strftime('%Y-%m-%dT%H:%M:%S.%fZ')}
    if isinstance(v, Geo):
        return {'geoPointValue': {'latitude': v.lat, 'longitude': v.lng}}
    if isinstance(v, (list, tuple)):
        return {'arrayValue': {'values': [enc(x) for x in v]}}
    if isinstance(v, dict):
        return {'mapValue': {'fields': {k: enc(x) for k, x in v.items()}}}
    raise TypeError(repr(v))


def call(method, url, body=None, owner=True):
    headers = {'Content-Type': 'application/json'}
    if owner:
        headers['Authorization'] = 'Bearer owner'
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f'{method} {url} -> {e.code}: {e.read().decode()[:400]}')


def put(path, data):
    """Creates or replaces the document at path (owner: rules bypassed)."""
    call('PATCH', f'{FS}/{path}', {'fields': {k: enc(v) for k, v in data.items()}})


def rid(n=20):
    return ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(n))


def reference():
    alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    return 'SPF-' + NOW.strftime('%y%m%d') + '-' + ''.join(random.choice(alphabet) for _ in range(6))


# ---------------------------------------------------------------- reset
def reset():
    call('DELETE', f'http://127.0.0.1:8080/emulator/v1/projects/{PROJECT}/databases/(default)/documents')
    call('DELETE', f'{AUTH}/emulator/v1/projects/{PROJECT}/accounts')


# ---------------------------------------------------------------- people
DOUALA = Geo(4.0483, 9.7043)  # Bonanjo, Douala
PEOPLE = [
    # key, first, last, email, phone, kycLevel, opening XAF
    ('amina', 'Amina', 'Diallo', 'amina.diallo@spideli.test', '650000101', 'basic', 500000),
    ('jean', 'Jean', 'Mbarga', 'jean.mbarga@spideli.test', '650000202', 'basic', 300000),
    ('fatou', 'Fatou', 'Ndiaye', 'fatou.ndiaye@spideli.test', '650000303', '', 150000),
]


def sign_up(email, name):
    r = call('POST', f'{AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=qa', {'email': email, 'password': PASSWORD, 'returnSecureToken': True}, owner=False)
    call('POST', f'{AUTH}/identitytoolkit.googleapis.com/v1/accounts:update?key=qa', {'idToken': r['idToken'], 'displayName': name, 'returnSecureToken': False}, owner=False)
    return r['localId']


def seed_people():
    uids = {}
    for key, first, last, email, phone, kyc, _ in PEOPLE:
        uid = sign_up(email, f'{first} {last}')
        uids[key] = uid
        address = {
            'id': rid(),
            'address': 'Rue Joss, Bonanjo',
            'addressAs': 'Home',
            'landmark': 'Near the Akwa roundabout',
            'locality': 'Douala, Cameroon',
            'isDefault': True,
            'location': {'latitude': DOUALA.lat, 'longitude': DOUALA.lng},
        }
        doc = {
            'id': uid,
            'email': email,
            'firstName': first,
            'lastName': last,
            'profilePictureURL': '',
            'fcmToken': '',
            'countryCode': '+237',
            'phoneNumber': phone,
            'wallet_amount': 0,
            'createdAt': NOW,
            'active': True,
            'isActive': True,
            'role': 'customer',
            'shippingAddress': [address],
        }
        if kyc:
            doc.update({'kycLevel': kyc, 'kycStatus': 'approved'})
        put(f'users/{uid}', doc)
    return uids


# ---------------------------------------------------------------- places
def seed_zone():
    zid = 'qa_douala'
    d = 0.35
    put(f'zone/{zid}', {
        'id': zid,
        'name': 'Douala',
        'publish': True,
        'latitude': DOUALA.lat,
        'longitude': DOUALA.lng,
        'area': [Geo(DOUALA.lat - d, DOUALA.lng - d), Geo(DOUALA.lat - d, DOUALA.lng + d), Geo(DOUALA.lat + d, DOUALA.lng + d), Geo(DOUALA.lat + d, DOUALA.lng - d)],
    })


# ---------------------------------------------------------------- finance
WALLET = {
    'currencies': ['XAF', 'EUR', 'USD'],
    # Gateways need sandbox credentials (settings/*); without them the app
    # shows that no payment method is available for the region.
    'deposit': {'enabled': True, 'methods': ['mobile_money', 'card'], 'min': {'XAF': 500}, 'max': {'XAF': 2000000}},
    'withdraw': {
        'enabled': True,
        'methods': ['mobile_money', 'bank'],
        'min': {'XAF': 1000},
        'max': {'XAF': 1000000},
        'feePercent': 1,
        'feeFixed': {'XAF': 100},
        'feeMax': {'XAF': 5000},
        'delay': 'Within 24 hours',
    },
    'convert': {'enabled': True, 'currencies': ['XAF', 'EUR', 'USD'], 'feePercent': 1, 'maxRateAgeHours': 48},
    'security': {'reauthAbove': {'XAF': 100000, 'EUR': 15000}},
}


def seed_settings(settings):
    cards = dict(settings['cards'])
    cards.update({
        'issuerName': 'Test card issuer (QA)',
        'issuanceFee': {'XAF': 1000},
        'monthlyFee': {'XAF': 0},
        'terms': 'QA environment cardholder agreement. Test cards are simulated: no real card is issued and no payment network is reached.',
        'termsVersion': 1,
        'capabilities': {'withdraw': True, 'renew': True, 'cardTransfer': True, 'onlineToggle': True, 'internationalToggle': True, 'secureDetails': 'none'},
        'limits': {'maxPerTransaction': {'XAF': 500000}, 'maxDaily': {'XAF': 1000000}, 'maxMonthly': {'XAF': 3000000}},
    })
    all_settings = dict(settings)
    all_settings['cards'] = cards
    all_settings['wallet'] = WALLET
    for doc_id, data in all_settings.items():
        put(f'platform_settings/{doc_id}', {**data, 'createdAt': NOW})


def seed_templates(templates):
    for type_, subject, message in templates:
        i = rid()
        put(f'dynamic_notification/{i}', {'id': i, 'type': type_, 'subject': subject, 'message': message, 'service_type': 'Multivendor Delivery Service', 'createdAt': NOW})


def seed_rates():
    # Indicative sample rates for the QA environment (EUR/XAF is the fixed CFA peg).
    for frm, to, rate in [('EUR', 'XAF', 655.957), ('USD', 'XAF', 603.5), ('XAF', 'XOF', 1.0)]:
        i = f'{frm}_{to}_{NOW.strftime("%Y%m%d")}'
        put(f'exchange_rate_snapshots/{i}', {'from': frm, 'to': to, 'pair': f'{frm}_{to}', 'rate': rate, 'source': 'QA sample rates', 'kind': 'official' if frm == 'EUR' else 'indicative', 'observedAt': NOW})


def seed_accounts(uids):
    """platform_{CUR} accounts and each customer's opening balance, booked as
    the admin panel books a manual adjustment (a balanced two-line posting)."""
    total = 0
    for key, first, last, *_rest, opening in PEOPLE:
        uid = uids[key]
        tx = f'tx_{int(NOW.timestamp() * 1000)}_{rid(8)}'
        wallet = f'wallet_{uid}_XAF'
        put(f'ledger_transactions/{tx}', {
            'id': tx,
            'type': 'manual_adjustment',
            'status': 'posted',
            'reference': reference(),
            'currency': 'XAF',
            'lines': [{'accountId': 'platform_XAF', 'direction': 'debit', 'amount': opening}, {'accountId': wallet, 'direction': 'credit', 'amount': opening}],
            'userIds': [uid],
            'accountIds': ['platform_XAF', wallet],
            'source': {'kind': 'admin_adjustments', 'id': f'qa_opening_{key}'},
            'funding': 'wallet',
            'description': 'Opening balance (test funds)',
            'createdBy': 'admin:qa',
            'createdAt': NOW,
        })
        put(f'financial_accounts/{wallet}', {'id': wallet, 'kind': 'wallet', 'userId': uid, 'currency': 'XAF', 'balance': opening, 'normalSide': 'credit', 'status': 'active', 'lastTxId': tx, 'createdAt': NOW, 'updatedAt': NOW})
        total += opening
    for cur, balance in [('XAF', -total), ('EUR', 0), ('USD', 0)]:
        put(f'financial_accounts/platform_{cur}', {'id': f'platform_{cur}', 'kind': 'platform', 'currency': cur, 'balance': balance, 'normalSide': 'credit', 'status': 'active', 'lastTxId': '', 'createdAt': NOW, 'updatedAt': NOW})


def seed_catalogs(resources):
    """Sample catalog entries the admin would publish, each marked as test data."""
    days = lambda n: NOW + datetime.timedelta(days=n)
    # Utility billers: one per amount type (open, packages, due).
    put('utility_billers/qa_power', {
        'name': 'City Power (test biller)', 'category': 'electricity', 'country': 'CM', 'currency': 'XAF', 'published': True, 'order': 1,
        'amountType': 'open', 'min': 1000, 'max': 500000, 'feePercent': 1, 'feeFixed': 0, 'feeMax': 2000,
        'accountLabel': 'Meter number', 'accountHint': '11 digits on your meter', 'accountPattern': '[0-9]{11}',
    })
    put('utility_billers/qa_tv', {
        'name': 'Vision TV packages (test biller)', 'category': 'tv', 'country': 'CM', 'currency': 'XAF', 'published': True, 'order': 2,
        'amountType': 'packages', 'feePercent': 0, 'accountLabel': 'Smart card number', 'accountPattern': '[0-9]{10}',
        'packages': [{'code': 'basic', 'name': 'Basic - 1 month', 'amount': 5000}, {'code': 'family', 'name': 'Family - 1 month', 'amount': 12000}],
    })
    put('utility_billers/qa_water', {
        'name': 'City Water (test biller)', 'category': 'water', 'country': 'CM', 'currency': 'XAF', 'published': True, 'order': 3,
        'amountType': 'due', 'max': 300000, 'feeFixed': 100, 'accountLabel': 'Contract number', 'accountPattern': '[0-9]{8}',
    })
    # Investment fund with a price history.
    put('investment_funds/qa_money_market', {
        'name': 'Spideli Demo Money Market Fund', 'manager': 'Demo Asset Management (test)', 'published': True, 'status': 'open', 'order': 1,
        'description': 'A sample fund for the QA environment. It invests in short-term deposits and treasury bills.',
        'objective': 'Preserve capital and earn a regular return above savings accounts.',
        'assetClass': 'money_market', 'riskLevel': 2, 'currency': 'XAF', 'minInvestment': 10000, 'minAdditional': 5000,
        'fees': {'subscriptionPercent': 1, 'managementPercent': 0.8, 'redemptionPercent': 0.5, 'performancePercent': 0},
        'navPerUnit': 1052.4, 'navDate': days(-1), 'lockUpDays': 0, 'settlementDays': 2,
        'redemption': {'allowed': True, 'partial': True}, 'terms': 'QA sample fund terms. Not a real offer.', 'termsVersion': 1,
        'performance': {'ytd': 4.1, 'oneYear': 5.3}, 'eligibility': 'Verified Spideli customers (test).',
    })
    for i, nav in enumerate([1028.0, 1031.2, 1035.9, 1040.3, 1044.8, 1048.1, 1052.4]):
        put(f'investment_valuations/qa_mm_{i}', {'fundId': 'qa_money_market', 'date': days(-30 * (6 - i)), 'navPerUnit': nav})
    # Insurance product with a rating table.
    put('insurance_products/qa_health', {
        'name': 'Family Health Cover (sample)', 'partnerName': 'Demo Insurer (test)', 'category': 'health', 'published': True, 'status': 'open', 'order': 1,
        'summary': 'Hospital and outpatient care for you and your family.', 'description': 'A sample product for the QA environment.',
        'currency': 'XAF', 'deductible': 10000, 'waitingPeriodDays': 30, 'termMonths': 12,
        'coverages': [{'name': 'Hospital stay', 'description': 'Room and treatment', 'limit': 2000000}, {'name': 'Outpatient visits', 'description': 'Doctor visits and tests', 'limit': 300000}],
        'exclusions': ['Cosmetic surgery', 'Treatment outside Cameroon'],
        'rating': {
            'basePremium': 60000,
            'frequencies': {'annual': 0, 'quarterly': 3, 'monthly': 5},
            'factors': [
                {'key': 'age', 'label': 'Age of the oldest person covered', 'type': 'number', 'unit': 'years', 'min': 18, 'max': 70, 'bands': [{'upTo': 35, 'multiplier': 1.0}, {'upTo': 50, 'multiplier': 1.3}, {'upTo': 70, 'multiplier': 1.8}]},
                {'key': 'members', 'label': 'People covered', 'type': 'select', 'options': [{'value': '1', 'label': 'Just me', 'multiplier': 1.0}, {'value': '2-4', 'label': '2 to 4 people', 'multiplier': 2.2}, {'value': '5+', 'label': '5 or more', 'multiplier': 3.0}]},
            ],
        },
        'terms': 'QA sample insurance terms. Not a real offer.', 'termsVersion': 1,
    })
    # Financing guides (published here; unpublished in the live seed).
    for doc_id, data in resources.items():
        put(f'financial_resources/{doc_id}', {**data, 'published': True, 'updatedAt': NOW})
    # Sample market information, labelled as such.
    for code, name, value, prev, unit in [('inflation', 'Inflation (sample)', 4.2, 4.6, '%'), ('policy_rate', 'Central bank policy rate (sample)', 4.5, 5.0, '%'), ('gdp_growth', 'GDP growth (sample)', 3.9, 3.7, '%')]:
        put(f'economic_indicators/qa_cm_{code}', {'published': True, 'country': 'CM', 'code': code, 'name': name, 'value': value, 'previousValue': prev, 'unit': unit, 'period': '2026 Q2', 'source': 'QA sample data (not real figures)', 'updatedAt': NOW, 'order': 1})
    put('investment_opportunities/qa_solar', {
        'published': True, 'status': 'open', 'title': 'Solar kiosks for Douala markets (sample)', 'summary': 'A sample project: 20 solar charging kiosks in local markets.',
        'sector': 'energy', 'country': 'CM', 'type': 'equity', 'currency': 'XAF', 'minTicket': 50000, 'targetAmount': 25000000, 'raisedAmount': 9500000,
        'horizonMonths': 36, 'riskLevel': 5, 'targetReturnPercent': 12.0, 'ownerName': 'Demo Energy SARL (test)', 'closingDate': days(60),
    })
    put('finance_news/qa_news_1', {'published': True, 'title': 'Sample news item for the QA environment', 'summary': 'This entry shows how published finance news appears in the app.', 'source': 'QA sample', 'url': 'https://www.example.com/', 'category': 'economy', 'country': 'CM', 'publishedAt': NOW})


def main():
    settings, resources, templates = finance_config()
    reset()
    uids = seed_people()
    seed_zone()
    seed_settings(settings)
    seed_templates(templates)
    seed_rates()
    seed_accounts(uids)
    seed_catalogs(resources)
    for key, *_ in PEOPLE:
        print(f'{key}: {uids[key]}')
    json.dump(uids, open(os.path.join(HERE, 'uids.json'), 'w'), indent=2)


if __name__ == '__main__':
    main()
