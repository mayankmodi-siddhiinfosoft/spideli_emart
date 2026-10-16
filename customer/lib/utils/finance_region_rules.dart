/// Spideli Finance per region (the admin panel's
/// APP-SPEC-FINANCE-REGION-SETTINGS, 15 Oct 2026), as data: which region's
/// settings the customer uses, where they are, and which documents carry the
/// region. Unit tested in test/finance_region_test.dart; Firestore is read by
/// FinanceRegion (lib/service/finance_region_service.dart).
///
/// * A region offers Finance only when `regions/{id}.financeEnabled == true`.
/// * Its settings are `finance_settings/{regionId}_{module}`, with exactly the
///   fields `platform_settings/{module}` had, plus `regionId`, `module`,
///   `currencies` (the region's currency; the wallet adds its convertible
///   ones) and the admin's timestamps. A missing document means "not
///   available yet": the app never falls back to `platform_settings`.
/// * Every Finance request the customer creates carries the `regionId` it was
///   made in, and so do the postings that pay it.
library;

import 'package:customer/service/finance_ledger.dart';

/// The modules of `finance_settings/{regionId}_{module}`.
abstract final class FinanceModules {
  static const String wallet = 'wallet';
  static const String kyc = 'kyc';
  static const String transfers = 'transfers';
  static const String bills = 'bills';
  static const String cards = 'cards';
  static const String savings = 'savings';
  static const String tontines = 'tontines';
  static const String lending = 'lending';
  static const String investments = 'investments';
  static const String insurance = 'insurance';
  static const String financing = 'financing';
  static const String intelligence = 'intelligence';

  static const List<String> all = [wallet, kyc, transfers, bills, cards, savings, tontines, lending, investments, insurance, financing, intelligence];
}

/// Whether Finance is offered where the customer is.
enum FinanceRegionStatus {
  /// A region offering Finance: its settings apply.
  ready,

  /// The customer's region is known, but none of its regions offers Finance.
  notOffered,

  /// The app cannot tell which region the customer is in.
  unresolved,
}

/// The customer's Finance region: [regionId] when [status] is ready, and the
/// regions offering Finance the customer may switch between ([choices], more
/// than one only where several regions serve the same place).
class FinanceRegionPick {
  final FinanceRegionStatus status;
  final String? regionId;
  final List<String> choices;

  const FinanceRegionPick._(this.status, this.regionId, this.choices);

  const FinanceRegionPick.ready(String id, List<String> choices) : this._(FinanceRegionStatus.ready, id, choices);
  const FinanceRegionPick.notOffered() : this._(FinanceRegionStatus.notOffered, null, const []);
  const FinanceRegionPick.unresolved() : this._(FinanceRegionStatus.unresolved, null, const []);

  bool get isReady => status == FinanceRegionStatus.ready;

  @override
  bool operator ==(Object other) =>
      other is FinanceRegionPick && other.status == status && other.regionId == regionId && other.choices.length == choices.length && other.choices.every(choices.contains);

  @override
  int get hashCode => Object.hash(status, regionId, choices.length);

  @override
  String toString() => 'FinanceRegionPick($status, $regionId, $choices)';
}

abstract final class FinanceRegionRules {
  static const String settingsCollection = 'finance_settings';

  /// `finance_settings/{regionId}_{module}`.
  static String settingsId(String regionId, String module) => '${regionId}_$module';

  /// The documents the customer creates that carry `regionId` (spec 3.4),
  /// the postings that pay them (3.5, so the admin filters the ledger by
  /// region), and the financing project an application belongs to (its
  /// sectors and stages are the region's settings).
  static const Set<String> regionCollections = {
    'wallet_operations',
    'money_transfers',
    'utility_payment_requests',
    'virtual_cards',
    'card_funding_requests',
    'savings_goals',
    'tontines',
    'loan_applications',
    'investment_subscriptions',
    'insurance_quotes',
    'financing_projects',
    'financing_applications',
    'kyc_applications',
    'ledger_transactions',
  };

  static String _collectionOf(String path) {
    final int slash = path.indexOf('/');
    return slash < 0 ? path : path.substring(0, slash);
  }

  /// [writes] with `regionId` added to every document of
  /// [regionCollections] they create. A document that already names its
  /// region keeps it; nothing changes without a region.
  static List<FinanceWrite> stamp(Iterable<FinanceWrite> writes, String? regionId) {
    if (regionId == null || regionId.isEmpty) return writes.toList();
    return [
      for (final w in writes)
        w.op == 'create' && regionCollections.contains(_collectionOf(w.path)) && (w.data['regionId'] ?? '').toString().isEmpty
            ? FinanceWrite(w.path, w.op, {...w.data, 'regionId': regionId})
            : w,
    ];
  }

  /// The region of a stored record (`regionId`), else [fallback]: a record
  /// keeps the settings of the region it was made in.
  static String? regionOf(Map<String, dynamic>? record, String? fallback) {
    final String own = (record?['regionId'] ?? '').toString();
    return own.isNotEmpty ? own : fallback;
  }

  /// The customer's Finance region among [candidates] (the regions the app
  /// resolved for the customer, most precise rung first, never widened to the
  /// rest of the country): those offering Finance ([offersFinance]); a
  /// remembered choice among them ([remembered]); else the most specific,
  /// i.e. the one the fewest delivery zones serve ([zoneCount], a region in
  /// no zone last), then by [name].
  static FinanceRegionPick pick({
    required List<String> candidates,
    required bool Function(String id) offersFinance,
    int Function(String id)? zoneCount,
    String Function(String id)? name,
    String? remembered,
  }) {
    if (candidates.isEmpty) return const FinanceRegionPick.unresolved();
    final offering = candidates.toSet().where(offersFinance).toList();
    if (offering.isEmpty) return const FinanceRegionPick.notOffered();
    int zones(String id) {
      final int n = zoneCount?.call(id) ?? 0;
      return n > 0 ? n : 1 << 30;
    }

    offering.sort((a, b) {
      final int z = zones(a).compareTo(zones(b));
      if (z != 0) return z;
      final String na = (name?.call(a) ?? a).toLowerCase();
      final String nb = (name?.call(b) ?? b).toLowerCase();
      return na.compareTo(nb);
    });
    final String chosen = remembered != null && offering.contains(remembered) ? remembered : offering.first;
    return FinanceRegionPick.ready(chosen, offering);
  }

  /// The settings document [data] of [module] for [regionId], as the
  /// parsers read it; null when there is none, or it names another region or
  /// module (never used for the wrong place).
  static Map<String, dynamic>? settingsOf(Map<String, dynamic>? data, String regionId, String module) {
    if (data == null) return null;
    final String region = (data['regionId'] ?? '').toString();
    final String mod = (data['module'] ?? '').toString();
    if (region.isNotEmpty && region != regionId) return null;
    if (mod.isNotEmpty && mod != module) return null;
    return data;
  }

  /// Whether two reads of a settings document hold the same values (maps
  /// and lists compared by content): an unchanged document never reloads
  /// the screens.
  static bool same(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length && a.keys.every((k) => b.containsKey(k) && same(a[k], b[k]));
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!same(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
