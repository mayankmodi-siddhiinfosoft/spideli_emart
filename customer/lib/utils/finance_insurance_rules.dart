/// Spideli Finance: online insurance, the pure rules the screens use
/// (.claude/FINANCE-APP-CONTRACT.md section 13) and the writes of each step
/// (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.10). Unit tested in
/// test/finance_insurance_rules_test.dart and
/// test/finance_insurance_direct_test.dart.
///
/// The INSURER (through the Spideli admin) decides quotes, premiums,
/// activation, renewals, cancellations and claim decisions: the app writes
/// requests. The premium computed here is a SIMULATION from the product's
/// published rating; the binding premium is the insurer's quote.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:customer/service/finance_ledger.dart';

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

double? _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic v) => v is List ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];

/// `finance_settings/{regionId}_insurance` (admin). Null when missing or invalid.
class InsuranceConfig {
  final List<String> currencies;
  final List<String> categories;
  final List<String> paymentMethods;
  final int maxClaimFiles;

  const InsuranceConfig({required this.currencies, required this.categories, required this.paymentMethods, required this.maxClaimFiles});

  static InsuranceConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final currencies = _strings(raw['currencies']).where((c) => RegExp(r'^[A-Z]{3}$').hasMatch(c)).toList();
    final categories = _strings(raw['categories']);
    final methods = _strings(raw['paymentMethods']);
    if (currencies.isEmpty || categories.isEmpty || methods.isEmpty) return null;
    final int files = _int(_map(raw['claims'])['maxFiles']);
    return InsuranceConfig(currencies: currencies, categories: categories, paymentMethods: methods, maxClaimFiles: files < 1 ? 5 : math.min(files, 20));
  }
}

/// Premium payment frequencies and how many payments a year each makes.
abstract final class PremiumFrequency {
  static const Map<String, int> perYear = {'annual': 1, 'semiannual': 2, 'quarterly': 4, 'monthly': 12};

  static String label(String f) => const {'annual': 'Yearly', 'semiannual': 'Every 6 months', 'quarterly': 'Every 3 months', 'monthly': 'Monthly'}[f] ?? f;
}

class FactorOption {
  final String value;
  final String label;
  final double multiplier;

  const FactorOption(this.value, this.label, this.multiplier);
}

/// A band of a number factor: values up to [upTo] (inclusive) use [multiplier].
class FactorBand {
  final double upTo;
  final double multiplier;

  const FactorBand(this.upTo, this.multiplier);
}

/// One question of the quote form, and its effect on the simulated premium.
class RatingFactor {
  final String key;
  final String label;

  /// `select` (one of [options]) or `number` (between [min] and [max], priced by [bands]).
  final String type;
  final String unit;
  final List<FactorOption> options;
  final double? min;
  final double? max;
  final List<FactorBand> bands;

  const RatingFactor({
    required this.key,
    required this.label,
    required this.type,
    this.unit = '',
    this.options = const [],
    this.min,
    this.max,
    this.bands = const [],
  });

  static RatingFactor? fromMap(Map<String, dynamic> m) {
    final String key = m['key']?.toString() ?? '';
    final String type = m['type']?.toString() ?? '';
    if (key.isEmpty) return null;
    if (type == 'select') {
      final options = [
        for (final o in _maps(m['options']))
          if ((o['value'] ?? '').toString().isNotEmpty && (_num(o['multiplier']) ?? 0) > 0)
            FactorOption(o['value'].toString(), o['label']?.toString() ?? o['value'].toString(), _num(o['multiplier'])!),
      ];
      if (options.isEmpty) return null;
      return RatingFactor(key: key, label: m['label']?.toString() ?? key, type: type, options: options);
    }
    if (type == 'number') {
      final bands = [
        for (final b in _maps(m['bands']))
          if (_num(b['upTo']) != null && (_num(b['multiplier']) ?? 0) > 0) FactorBand(_num(b['upTo'])!, _num(b['multiplier'])!),
      ]..sort((a, b) => a.upTo.compareTo(b.upTo));
      return RatingFactor(key: key, label: m['label']?.toString() ?? key, type: type, unit: m['unit']?.toString() ?? '', min: _num(m['min']), max: _num(m['max']), bands: bands);
    }
    return null;
  }

  /// The multiplier for [answer], or null when it is missing or out of range.
  double? multiplierFor(dynamic answer) {
    if (type == 'select') {
      for (final o in options) {
        if (o.value == answer?.toString()) return o.multiplier;
      }
      return null;
    }
    final double? v = _num(answer);
    if (v == null || (min != null && v < min!) || (max != null && v > max!)) return null;
    if (bands.isEmpty) return 1;
    for (final b in bands) {
      if (v <= b.upTo) return b.multiplier;
    }
    return null;
  }
}

class Coverage {
  final String name;
  final String description;
  final int? limit;

  const Coverage(this.name, this.description, this.limit);

  static List<Coverage> list(dynamic v) => [
        for (final c in _maps(v))
          if ((c['name'] ?? '').toString().isNotEmpty) Coverage(c['name'].toString(), c['description']?.toString() ?? '', c['limit'] == null ? null : _int(c['limit'])),
      ];
}

/// A document: a Storage path or an https link.
class InsuranceDocument {
  final String name;
  final String? storagePath;
  final String? url;

  const InsuranceDocument(this.name, {this.storagePath, this.url});

  static List<InsuranceDocument> list(dynamic v) => [
        for (final d in _maps(v))
          if ((d['name'] ?? '').toString().isNotEmpty && ((d['storagePath'] ?? '').toString().isNotEmpty || '${d['url'] ?? ''}'.startsWith('https://')))
            InsuranceDocument(
              d['name'].toString(),
              storagePath: (d['storagePath'] ?? '').toString().isEmpty ? null : d['storagePath'].toString(),
              url: '${d['url'] ?? ''}'.startsWith('https://') ? d['url'].toString() : null,
            ),
      ];
}

/// `insurance_products/{productId}`, published by the admin for an authorised insurer.
class InsuranceProduct {
  final String id;
  final String name;
  final String partnerName;
  final String category;
  final String summary;
  final String description;
  final String currency;
  final List<Coverage> coverages;
  final List<String> exclusions;
  final int deductible;
  final int waitingPeriodDays;
  final int termMonths;

  /// Yearly premium before factors (minor units); null = quote only, no simulation.
  final int? basePremium;

  /// Allowed frequencies and their loading in percent.
  final Map<String, double> frequencies;
  final List<RatingFactor> factors;
  final String terms;
  final int termsVersion;
  final List<InsuranceDocument> documents;
  final String status;

  const InsuranceProduct({
    required this.id,
    required this.name,
    required this.partnerName,
    required this.category,
    required this.summary,
    required this.description,
    required this.currency,
    required this.coverages,
    required this.exclusions,
    required this.deductible,
    required this.waitingPeriodDays,
    required this.termMonths,
    required this.basePremium,
    required this.frequencies,
    required this.factors,
    required this.terms,
    required this.termsVersion,
    required this.documents,
    required this.status,
  });

  static InsuranceProduct fromMap(Map<String, dynamic> m) {
    final rating = _map(m['rating']);
    final freqRaw = _map(rating['frequencies']);
    final freqs = <String, double>{
      for (final f in PremiumFrequency.perYear.keys)
        if (freqRaw.containsKey(f) && (_num(freqRaw[f]) ?? -1) >= 0) f: _num(freqRaw[f])!,
    };
    final int base = _int(rating['basePremium']);
    return InsuranceProduct(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      partnerName: m['partnerName']?.toString() ?? '',
      category: m['category']?.toString() ?? 'other',
      summary: m['summary']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      currency: m['currency']?.toString() ?? '',
      coverages: Coverage.list(m['coverages']),
      exclusions: _strings(m['exclusions']),
      deductible: math.max(0, _int(m['deductible'])),
      waitingPeriodDays: math.max(0, _int(m['waitingPeriodDays'])),
      termMonths: _int(m['termMonths']) < 1 ? 12 : _int(m['termMonths']),
      basePremium: base > 0 ? base : null,
      frequencies: freqs.isEmpty ? const {'annual': 0} : freqs,
      factors: _maps(rating['factors']).map(RatingFactor.fromMap).whereType<RatingFactor>().toList(),
      terms: m['terms']?.toString() ?? '',
      termsVersion: _int(m['termsVersion']),
      documents: InsuranceDocument.list(m['documents']),
      status: m['status']?.toString() ?? 'closed',
    );
  }

  bool get acceptsQuotes => status == 'open' && termsVersion > 0;

  bool get canSimulate => basePremium != null;
}

class PremiumEstimate {
  final int yearly;
  final int installment;
  final int installmentsPerYear;

  const PremiumEstimate(this.yearly, this.installment, this.installmentsPerYear);

  int get yearlyTotal => installment * installmentsPerYear;
}

abstract final class RateSimulator {
  /// The simulated premium for [answers] at [frequency], or null when the
  /// product cannot be simulated or an answer is missing or out of range.
  static PremiumEstimate? estimate(InsuranceProduct p, Map<String, dynamic> answers, String frequency) {
    if (p.basePremium == null || !p.frequencies.containsKey(frequency)) return null;
    double premium = p.basePremium!.toDouble();
    for (final f in p.factors) {
      final double? m = f.multiplierFor(answers[f.key]);
      if (m == null) return null;
      premium *= m;
    }
    final int perYear = PremiumFrequency.perYear[frequency]!;
    final double loaded = premium * (1 + p.frequencies[frequency]! / 100);
    return PremiumEstimate(premium.round(), (loaded / perYear).round(), perYear);
  }
}

abstract final class InsuranceLabels {
  static String category(String? c) => const {
        'health': 'Health',
        'life': 'Life',
        'auto': 'Motor',
        'home': 'Home',
        'travel': 'Travel',
        'business': 'Business',
        'agriculture': 'Agriculture',
        'device': 'Phone and devices',
        'funeral': 'Funeral',
        'other': 'Other',
      }[c] ??
      (c ?? '-');

  static String quote(String? s) => const {
        'requested': 'Quote requested',
        'quoted': 'Quote ready',
        'accepted': 'Accepted',
        'declined': 'Declined',
        'expired': 'Expired',
        'rejected': 'Not offered',
      }[s] ??
      (s ?? '-');

  static String policy(String? s) => const {
        'pending_activation': 'Waiting for the insurer',
        'active': 'Active',
        'renewal_due': 'Renewal due',
        'lapsed': 'Lapsed',
        'cancellation_requested': 'Cancellation requested',
        'cancelled': 'Cancelled',
        'expired': 'Expired',
        'rejected': 'Not accepted',
      }[s] ??
      (s ?? '-');

  static String premium(String? s) => const {
        'upcoming': 'Upcoming',
        'due': 'Due',
        'overdue': 'Overdue',
        'paid': 'Paid',
        'failed': 'Payment failed',
        'processing': 'Processing',
      }[s] ??
      (s ?? '-');

  static String claim(String? s) => const {
        'submitted': 'Submitted',
        'under_review': 'Under review',
        'info_requested': 'More information needed',
        'approved': 'Approved',
        'paid': 'Paid',
        'rejected': 'Not approved',
        'withdrawn': 'Withdrawn',
      }[s] ??
      (s ?? '-');

  static const List<String> claimSteps = ['submitted', 'under_review', 'approved', 'paid'];
}

/// A quote (`insurance_quotes/{id}`), the fields the actions need.
class Quote {
  final String status;
  final DateTime? validUntil;
  final int premium;

  const Quote(this.status, this.validUntil, this.premium);

  static Quote fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) => Quote(m['status']?.toString() ?? '', toDate(m['validUntil']), _int(m['installmentAmount'] ?? m['premium']));

  bool canAccept(DateTime now) => status == 'quoted' && premium > 0 && (validUntil == null || now.isBefore(validUntil!));

  bool get canDecline => status == 'quoted';
}

/// What the app offers on a policy and its claims (the server re-checks each).
abstract final class PolicyActions {
  static bool covered(String? s) => s == 'active' || s == 'renewal_due';

  static bool canClaim(String? s) => covered(s);

  static bool canCancel(String? s) => covered(s);

  static bool canSetAutoRenew(String? s) => covered(s);

  /// Not again once the renewal is paid ([requested]: `renewalRequestedAt`).
  static bool canRenew(String? s, int renewalPremium, {bool requested = false}) => s == 'renewal_due' && renewalPremium > 0 && !requested;

  static bool premiumPayable(String? s) => s == 'due' || s == 'overdue' || s == 'failed';

  static bool canRespondToClaim(String? s) => s == 'info_requested';

  static bool canWithdrawClaim(String? s) => s == 'submitted' || s == 'under_review' || s == 'info_requested';
}

/// The writes of each insurance step (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 3.10), as data. Payments carry their posting to the platform
/// (`insurance_premium`) in the same batch.
abstract final class InsuranceWrites {
  static Object get _now => FieldValue.serverTimestamp();

  /// Midnight of [d] (a day without its time), as a Firestore timestamp.
  static Timestamp day(DateTime d) => Timestamp.fromDate(DateTime(d.year, d.month, d.day));

  /// A quote request, `insurance_quotes/{id}` `requested`. The admin prices
  /// it with the insurer (`quoted`: `premium`, `installmentAmount`,
  /// `validUntil`, `terms`, `termsVersion`, `coverEnd`, cover, documents) or
  /// sets `rejected` with `reason`.
  static List<FinanceWrite> requestQuote({
    required String id,
    required String uid,
    required InsuranceProduct product,
    required Map<String, dynamic> answers,
    required String frequency,
    required DateTime coverStart,
  }) =>
      [
        FinanceWrite('insurance_quotes/$id', 'create', {
          'id': id,
          'userId': uid,
          'productId': product.id,
          'productName': product.name,
          'partnerName': product.partnerName,
          'category': product.category,
          'currency': product.currency,
          'answers': answers,
          'frequency': frequency,
          'coverStart': day(coverStart),
          'termMonths': product.termMonths,
          'status': 'requested',
          'createdAt': _now,
          'updatedAt': _now,
        }),
      ];

  /// `quoted -> declined` by the user.
  static List<FinanceWrite> declineQuote(String quoteId) => [
        FinanceWrite('insurance_quotes/$quoteId', 'update', {'status': 'declined', 'declinedAt': _now, 'updatedAt': _now}),
      ];

  /// The policy of an accepted quote has the quote's id (one per quote).
  static String policyIdOf(String quoteId) => quoteId;

  /// The first premium of a policy.
  static String firstPremiumIdOf(String policyId) => '${policyId}_1';

  /// Accepting quote [quoteId] ([quote]: its fields) under its terms, signed
  /// with [signatureName], with the first premium paid by [posting]: the
  /// quote `accepted`, the policy `pending_activation` and the premium
  /// `paid`, in one batch. The admin activates the policy with the insurer
  /// (`active`, `policyNumber`, documents), or `rejected` and a reversal.
  static List<FinanceWrite> acceptQuote({
    required String quoteId,
    required Map<String, dynamic> quote,
    required String uid,
    required String signatureName,
    required FinancePosting posting,
    required Map<String, dynamic> paidWith,
  }) {
    final String policyId = policyIdOf(quoteId);
    final String premiumId = firstPremiumIdOf(policyId);
    const copied = [
      'productId', 'productName', 'partnerName', 'category', 'currency', 'premium', 'frequency', 'installmentAmount', //
      'deductible', 'coverages', 'coverStart', 'coverEnd', 'termsVersion',
    ];
    final int amount = (quote['installmentAmount'] ?? quote['premium']) is num ? ((quote['installmentAmount'] ?? quote['premium']) as num).round() : 0;
    return [
      FinanceWrite('insurance_quotes/$quoteId', 'update', {
        'status': 'accepted',
        'acceptedAt': _now,
        'signatureName': signatureName,
        'policyId': policyId,
        'updatedAt': _now,
      }),
      FinanceWrite('insurance_policies/$policyId', 'create', {
        'id': policyId,
        'userId': uid,
        'quoteId': quoteId,
        for (final k in copied)
          if (quote[k] != null) k: quote[k],
        'signatureName': signatureName,
        'acceptedAt': _now,
        'autoRenew': false,
        'status': 'pending_activation',
        'createdAt': _now,
        'updatedAt': _now,
      }),
      FinanceWrite('insurance_premiums/$premiumId', 'create', {
        'id': premiumId,
        'userId': uid,
        'policyId': policyId,
        'amount': amount,
        'currency': quote['currency'],
        'dueDate': _now,
        'status': 'paid',
        'paidAt': _now,
        'txId': posting.txId,
        'reference': posting.reference,
        'payment': paidWith,
        'createdAt': _now,
        'updatedAt': _now,
      }),
      ...posting.writes,
    ];
  }

  /// A premium `due | overdue | failed -> paid`, by [posting].
  static List<FinanceWrite> payPremium({required String premiumId, required FinancePosting posting, required Map<String, dynamic> paidWith}) => [
        FinanceWrite('insurance_premiums/$premiumId', 'update', {
          'status': 'paid',
          'paidAt': _now,
          'txId': posting.txId,
          'reference': posting.reference,
          'payment': paidWith,
          'updatedAt': _now,
        }),
        ...posting.writes,
      ];

  /// The renewal of a `renewal_due` policy, [amount] (its `renewalPremium`)
  /// paid by [posting]: `renewalRequestedAt`. The admin renews it with the
  /// insurer (`active`, new `coverEnd`), or refunds it.
  static List<FinanceWrite> renew({required String policyId, required int amount, required FinancePosting posting, required Map<String, dynamic> paidWith}) => [
        FinanceWrite('insurance_policies/$policyId', 'update', {
          'renewalRequestedAt': _now,
          'renewalPaidAmount': amount,
          'renewalTxId': posting.txId,
          'renewalReference': posting.reference,
          'renewalPayment': paidWith,
          'updatedAt': _now,
        }),
        ...posting.writes,
      ];

  static List<FinanceWrite> setAutoRenew(String policyId, bool autoRenew) => [
        FinanceWrite('insurance_policies/$policyId', 'update', {'autoRenew': autoRenew, 'updatedAt': _now}),
      ];

  /// `active | renewal_due -> cancellation_requested`; the admin cancels it
  /// with the insurer (`cancelled`, any refund) or restores [status].
  static List<FinanceWrite> requestCancellation({required String policyId, required String status, required String reason}) => [
        FinanceWrite('insurance_policies/$policyId', 'update', {
          'status': 'cancellation_requested',
          'statusBefore': status,
          if (reason.isNotEmpty) 'cancellationReason': reason,
          'cancellationRequestedAt': _now,
          'updatedAt': _now,
        }),
      ];

  /// A claim, `insurance_claims/{id}` `submitted`, its photos already in
  /// Storage (`insurance_claims/{uid}/{id}/...`, [documents]). The admin
  /// decides with the insurer (`under_review`, `info_requested` with the
  /// question in `reason`, `approved`, `paid` with a posting, `rejected`).
  static List<FinanceWrite> createClaim({
    required String id,
    required String uid,
    required Map<String, dynamic> policy,
    required DateTime incidentDate,
    required String description,
    required int amountClaimed,
    required List<Map<String, dynamic>> documents,
  }) =>
      [
        FinanceWrite('insurance_claims/$id', 'create', {
          'id': id,
          'userId': uid,
          'policyId': policy['id'],
          'policyNumber': policy['policyNumber'] ?? '',
          'productName': policy['productName'] ?? '',
          'currency': policy['currency'],
          'incidentDate': day(incidentDate),
          'description': description,
          'amountClaimed': amountClaimed,
          'documents': documents,
          'status': 'submitted',
          'createdAt': _now,
          'updatedAt': _now,
        }),
      ];

  /// The answer to the insurer's question: the claim back `under_review`
  /// with the new photos, and the message in `insurance_claims/{id}/events`.
  static List<FinanceWrite> respondToClaim({
    required String claimId,
    required String eventId,
    required String uid,
    required String message,
    required List<Map<String, dynamic>> documents,
  }) =>
      [
        FinanceWrite('insurance_claims/$claimId', 'update', {
          'status': 'under_review',
          if (documents.isNotEmpty) 'documents': FieldValue.arrayUnion(documents),
          'respondedAt': _now,
          'updatedAt': _now,
        }),
        FinanceWrite('insurance_claims/$claimId/events/$eventId', 'create', {
          'id': eventId,
          'type': 'customer_response',
          'userId': uid,
          'authorId': uid,
          'message': message,
          'documents': documents,
          'createdAt': _now,
        }),
      ];

  /// `submitted | under_review | info_requested -> withdrawn`.
  static List<FinanceWrite> withdrawClaim(String claimId) => [
        FinanceWrite('insurance_claims/$claimId', 'update', {'status': 'withdrawn', 'withdrawnAt': _now, 'updatedAt': _now}),
      ];
}
