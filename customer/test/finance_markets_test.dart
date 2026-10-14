import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:customer/utils/finance_intel_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Markets (published by the admin from licensed feeds) and the customer's
/// own intelligence writes (.claude/FINANCE-DIRECT-FIRESTORE.md 3.11).
void main() {
  DateTime? d(dynamic v) => v is DateTime ? v : null;
  final now = DateTime(2026, 10, 14, 15);

  group('configuration', () {
    test('markets: each part only when enabled and true', () {
      final c = IntelligenceConfig.parse({
        'markets': {'enabled': true, 'stocks': true, 'bonds': false, 'ipos': true, 'news': 'yes'},
      })!;
      expect(c.markets!.stocks, isTrue);
      expect(c.markets!.ipos, isTrue);
      expect(c.markets!.bonds, isFalse);
      expect(c.markets!.collections, isFalse);
      expect(c.markets!.news, isFalse);
      expect(c.indicators, isNull);
      expect(IntelligenceConfig.parse({'markets': {'enabled': false, 'stocks': true}}), isNull, reason: 'nothing else is offered');
      expect(IntelligenceConfig.parse({'markets': {'enabled': true}}), isNull, reason: 'no part is on');
      expect(MarketsConfig.parse(null), isNull);
      final withIndicators = IntelligenceConfig.parse({
        'indicators': {'enabled': true, 'countries': ['CM']},
      })!;
      expect(withIndicators.markets, isNull);
    });
  });

  group('securities', () {
    Map<String, dynamic> raw([Map<String, dynamic> extra = const {}]) => {
          'id': 's1',
          'published': true,
          'type': 'stock',
          'symbol': 'SNTS',
          'name': 'Sonatel',
          'exchange': 'BRVM',
          'country': 'SN',
          'currency': 'XOF',
          'price': 25000.5,
          'change': 250,
          'changePercent': 1.01,
          'source': 'BRVM feed',
          'updatedAt': DateTime(2026, 10, 14, 14, 50),
          ...extra,
        };

    test('shown only published, with a source, an update time and a price', () {
      final s = MarketSecurity.fromMap(raw(), d)!;
      expect(s.title, 'Sonatel');
      expect(s.direction, 'up');
      expect(s.priceDisplay, '25 000.5 XOF');
      expect(s.changeDisplay, '+1.01 %');
      expect(MarketSecurity.fromMap(raw({'published': false}), d), isNull);
      expect(MarketSecurity.fromMap(raw({'source': ''}), d), isNull);
      expect(MarketSecurity.fromMap(raw({'updatedAt': null}), d), isNull);
      expect(MarketSecurity.fromMap(raw({'price': null}), d), isNull);
      expect(MarketSecurity.fromMap(raw({'type': 'crypto'}), d), isNull);
    });

    test('a bond may show its yield without a price; an index has no currency', () {
      final b = MarketSecurity.fromMap(raw({'type': 'bond', 'price': null, 'yieldPercent': 6.25, 'couponPercent': 5.5, 'maturityDate': DateTime(2031, 3, 1)}), d)!;
      expect(b.isBond, isTrue);
      expect(b.yieldPercent, 6.25);
      expect(b.maturityDate, DateTime(2031, 3, 1));
      final i = MarketSecurity.fromMap(raw({'type': 'index', 'name': 'BRVM Composite', 'price': 245.31, 'changePercent': -0.4}), d)!;
      expect(i.priceDisplay, '245.31');
      expect(i.direction, 'down');
    });

    test('live: recent and not delayed; delayed is said', () {
      expect(MarketSecurity.fromMap(raw(), d)!.isLive(now), isTrue);
      expect(MarketSecurity.fromMap(raw({'delayed': true}), d)!.isLive(now), isFalse);
      expect(MarketSecurity.fromMap(raw({'updatedAt': DateTime(2026, 10, 13)}), d)!.isLive(now), isFalse);
    });

    test('price history: dated closes, oldest first', () {
      final h = closingPrices([
        {'securityId': 's1', 'date': DateTime(2026, 10, 13), 'close': 101},
        {'securityId': 's1', 'date': DateTime(2026, 10, 11), 'close': 99.5},
        {'securityId': 's1', 'close': 100},
      ], d);
      expect(h, [(DateTime(2026, 10, 11), 99.5), (DateTime(2026, 10, 13), 101.0)]);
    });
  });

  group('IPOs', () {
    Map<String, dynamic> raw(String id, String status, [Map<String, dynamic> extra = const {}]) => {
          'id': id,
          'published': true,
          'company': 'Orange CI',
          'symbol': 'ORAC',
          'exchange': 'BRVM',
          'currency': 'XOF',
          'priceLow': 9000,
          'priceHigh': 10000,
          'status': status,
          'source': 'BRVM',
          'updatedAt': DateTime(2026, 10, 1),
          ...extra,
        };

    test('complete, known status, https prospectus only', () {
      final i = IpoListing.fromMap(raw('i1', 'open', {'prospectusUrl': 'http://x.example/p.pdf'}), d)!;
      expect(i.prospectusUrl, isEmpty);
      expect(i.priceDisplay, '9 000 - 10 000 XOF');
      expect(IpoListing.fromMap(raw('i1', 'open', {'offerPrice': 9500}), d)!.priceDisplay, '9 500 XOF');
      expect(IpoListing.fromMap(raw('i1', 'open', {'prospectusUrl': 'https://x.example/p.pdf'}), d)!.prospectusUrl, 'https://x.example/p.pdf');
      expect(IpoListing.fromMap(raw('i1', 'rumoured'), d), isNull);
      expect(IpoListing.fromMap(raw('i1', 'open', {'source': ''}), d), isNull);
      expect(IpoListing.fromMap(raw('i1', 'open', {'published': false}), d), isNull);
    });

    test('order: open, upcoming (soonest first), then the most recent', () {
      final list = [
        IpoListing.fromMap(raw('listed-old', 'listed', {'listingDate': DateTime(2026, 1, 1)}), d)!,
        IpoListing.fromMap(raw('up-late', 'upcoming', {'openDate': DateTime(2026, 12, 1)}), d)!,
        IpoListing.fromMap(raw('open', 'open', {'closeDate': DateTime(2026, 10, 30)}), d)!,
        IpoListing.fromMap(raw('up-soon', 'upcoming', {'openDate': DateTime(2026, 11, 1)}), d)!,
        IpoListing.fromMap(raw('listed-new', 'listed', {'listingDate': DateTime(2026, 9, 1)}), d)!,
      ]..sort(IpoListing.compare);
      expect(list.map((i) => i.id), ['open', 'up-soon', 'up-late', 'listed-new', 'listed-old']);
    });
  });

  test('collections: published with securities, in their order, unpublished ones left out', () {
    final c = StockCollection.fromMap({
      'id': 'c1',
      'published': true,
      'title': 'Telecoms',
      'securityIds': ['s2', 's1', 's2', 'gone'],
      'riskLevel': 9,
      'order': 2,
    })!;
    expect(c.securityIds, ['s2', 's1', 'gone']);
    expect(c.riskLevel, 7);
    MarketSecurity sec(String id) => MarketSecurity.fromMap({
          'id': id,
          'published': true,
          'type': 'stock',
          'name': id,
          'price': 1,
          'source': 'feed',
          'updatedAt': DateTime(2026),
        }, d)!;
    expect(c.of([sec('s1'), sec('s2')]).map((s) => s.id), ['s2', 's1']);
    expect(StockCollection.fromMap({'id': 'c2', 'published': true, 'title': 'Empty', 'securityIds': []}), isNull);
    expect(StockCollection.fromMap({'id': 'c3', 'published': false, 'title': 'Draft', 'securityIds': ['s1']}), isNull);
  });

  test('news: title, source and date; https links only; news by default', () {
    final n = FinanceNews.fromMap({
      'id': 'n1',
      'published': true,
      'title': 'BEAC keeps its rate',
      'source': 'BEAC',
      'url': 'javascript:alert(1)',
      'publishedAt': DateTime(2026, 10, 14),
    }, d)!;
    expect(n.url, isEmpty);
    expect(n.category, 'news');
    expect(FinanceNews.fromMap({'id': 'n2', 'published': true, 'title': 'x', 'source': 'y', 'url': 'https://a.example', 'category': 'analysis', 'publishedAt': DateTime(2026)}, d)!.url, 'https://a.example');
    expect(FinanceNews.fromMap({'id': 'n3', 'published': true, 'title': 'x', 'publishedAt': DateTime(2026)}, d), isNull);
  });

  group('watchlist', () {
    test('at most 50 securities, added once, removed', () {
      final full = [for (int i = 0; i < 50; i++) 's$i'];
      expect(MarketPlans.watchProblem(full, 'new', true), 'watchlist_full');
      expect(MarketPlans.watchProblem(full, 's3', true), isNull, reason: 'already in it');
      expect(MarketPlans.watchProblem(full, 's3', false), isNull);
      expect(MarketPlans.toggled(['a', 'b'], 'a', true), ['b', 'a']);
      expect(MarketPlans.toggled(['a', 'b'], 'a', false), ['b']);
      expect(MarketPlans.watchlist({'securityIds': [...full, 'x', 's1']}), hasLength(50));
    });

    test('the owner\'s document: the whole list and the time', () {
      final w = MarketPlans.save('u1', ['a', 'b', 'a']).single;
      expect(w.path, 'investor_watchlists/u1');
      expect(w.data['securityIds'], ['a', 'b']);
      expect(w.data['updatedAt'], isA<FieldValue>());
      expect(w.data.keys.toSet(), {'securityIds', 'updatedAt'});
    });
  });

  group('matching writes', () {
    const cfg = MatchingConfig(
      currencies: ['XAF'],
      sectors: ['agriculture', 'energy'],
      types: ['equity', 'loan'],
      countries: ['CM'],
      weights: {'sector': 1, 'country': 1, 'type': 1, 'ticket': 1, 'horizon': 1},
      minScore: 60,
      eligibility: '',
    );

    test('investor profile: the owner\'s document with the offered values only', () {
      final w = IntelPlans.investorProfile(
        'u1',
        cfg,
        currency: 'XAF',
        sectors: ['agriculture', 'astrology'],
        countries: ['CM', 'FR'],
        types: ['loan'],
        minTicket: 100000,
        maxTicket: 1000000,
        maxRisk: 9,
        maxHorizonMonths: -3,
      ).single;
      expect(w.path, 'investor_profiles/u1');
      expect(w.data['sectors'], ['agriculture']);
      expect(w.data['countries'], ['CM']);
      expect(w.data['maxRisk'], 7);
      expect(w.data['maxHorizonMonths'], 0);
      expect(InvestorProfile.fromMap(Map<String, dynamic>.from(w.data)..remove('updatedAt')), isNotNull, reason: 'readable by the matching rules');
      expect(IntelPlans.profileProblem(cfg, currency: 'XAF', minTicket: 0, maxTicket: 1), isNull);
      expect(IntelPlans.profileProblem(cfg, currency: 'XAF', minTicket: 5, maxTicket: 1), 'amount_out_of_range');
      expect(IntelPlans.profileProblem(cfg, currency: 'EUR', minTicket: 0, maxTicket: 1), 'state_changed');
    });

    test('opportunity response: name and email only when interested', () {
      final yes = IntelPlans.respond(opportunityId: 'o1', uid: 'u1', interested: true, message: '  Call me  ', name: 'Ada N', email: 'ada@example.com').single;
      expect(yes.path, 'opportunity_interests/o1_u1');
      expect(yes.data['interested'], isTrue);
      expect(yes.data['name'], 'Ada N');
      expect(yes.data['email'], 'ada@example.com');
      expect(yes.data['message'], 'Call me');
      expect(yes.data['userId'], 'u1');
      final no = IntelPlans.respond(opportunityId: 'o1', uid: 'u1', interested: false, name: 'Ada N', email: 'ada@example.com').single;
      expect(no.data['interested'], isFalse);
      expect(no.data['name'], isA<FieldValue>(), reason: 'removed: not shared');
      expect(no.data['email'], isA<FieldValue>());
      final long = IntelPlans.respond(opportunityId: 'o1', uid: 'u1', interested: true, message: 'x' * 900).single;
      expect((long.data['message'] as String).length, IntelPlans.maxMessage);
    });
  });
}
