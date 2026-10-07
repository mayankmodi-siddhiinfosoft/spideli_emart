import 'package:customer/utils/review_totals.dart';
import 'package:flutter_test/flutter_test.dart';

/// A customer's rating of a driver (cab, parcel, rental) writes only
/// `reviewsCount` / `reviewsSum` of `users/{driverId}`, re-read in a
/// transaction - never the driver's whole document, whose
/// `orderRequestData` / `inProgressOrderID` the dispatch and the driver own.
void main() {
  group('the change a rating makes', () {
    test('a new review: one more review, its stars', () {
      final d = UserReviewTotals.delta(rating: 4);
      expect(d.countDelta, 1);
      expect(d.sumDelta, 4);
    });

    test('an edited review: the same count, the difference in stars', () {
      final d = UserReviewTotals.delta(rating: 2, previousRating: 5);
      expect(d.countDelta, 0);
      expect(d.sumDelta, -3);
    });
  });

  group('the totals written back', () {
    test('only the two rating fields', () {
      final Map<String, dynamic> out = UserReviewTotals.applied({
        'reviewsCount': '3',
        'reviewsSum': '12',
        'orderRequestData': ['p2'],
        'inProgressOrderID': ['r1'],
        'location': {'latitude': 1, 'longitude': 2},
      }, countDelta: 1, sumDelta: 4);
      expect(out.keys, unorderedEquals(['reviewsCount', 'reviewsSum']));
    });

    test('stored strings stay strings (an increment would reset them)', () {
      expect(UserReviewTotals.applied({'reviewsCount': '3', 'reviewsSum': '12'}, countDelta: 1, sumDelta: 4), {'reviewsCount': '4', 'reviewsSum': '16'});
      expect(UserReviewTotals.applied({'reviewsCount': '3', 'reviewsSum': '12.0'}, countDelta: 0, sumDelta: -2), {'reviewsCount': '3', 'reviewsSum': '10'});
    });

    test('stored numbers stay numbers', () {
      expect(UserReviewTotals.applied({'reviewsCount': 3, 'reviewsSum': 12.5}, countDelta: 1, sumDelta: 4), {'reviewsCount': 4, 'reviewsSum': 16.5});
    });

    test('missing or unreadable totals start from zero, never below it', () {
      expect(UserReviewTotals.applied(null, countDelta: 1, sumDelta: 5), {'reviewsCount': '1', 'reviewsSum': '5'});
      expect(UserReviewTotals.applied({'reviewsCount': 'x', 'reviewsSum': ''}, countDelta: 1, sumDelta: 5), {'reviewsCount': '1', 'reviewsSum': '5'});
      expect(UserReviewTotals.applied({'reviewsCount': '0', 'reviewsSum': '1'}, countDelta: 0, sumDelta: -3), {'reviewsCount': '0', 'reviewsSum': '0'});
    });
  });
}
