import 'package:customer/lang/app_ar.dart';
import 'package:customer/lang/app_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// The delivery code / proof of delivery, store location and cancellation
/// reason strings are translated in every language map, and a translation
/// keeps the key's `@placeholders` (trParams fills them in).
void main() {
  const keys = <String>[
    'This store has not set its location yet',
    'Your order has arrived',
    'Open the app for your delivery code',
    'Your delivery code',
    'Code expired — ask your delivery partner for a new one',
    'Expires in @time',
    'Share this code with your delivery partner only when you receive your order',
    'Proof of delivery',
    'Delivery status',
    'POD status',
    'OTP Verified',
    'Verified on',
    'Delivery man',
    'Delivery partner',
    'Delivery type',
    'Why are you cancelling?',
    'Why are you cancelling this booking?',
    'Why are you cancelling this parcel?',
    'Why are you cancelling this subscription?',
    'A reason is required.',
    'Please select a reason',
    'Please describe the reason',
    'Please describe the reason in at least 3 characters',
    'Reason',
    'Describe the reason',
    'Driver is taking too long',
    'Changed my plans',
    'Booked by mistake',
    'Price too high',
    'Other',
    'Cancelled by @party',
    'Rejected by @party',
    'No reason recorded',
    'Customer',
    'Driver',
    'Restaurant',
    'Store',
    'Service provider',
    'Worker',
    'Admin',
    'Cancelling order...',
    'This parcel has already been handed over and can no longer be cancelled.',
    'Your driver cancelled — finding another driver',
    'Please wait',
  ];
  const maps = <String, Map<String, String>>{'en_US': enUS, 'ar_AR': arAR};
  final placeholder = RegExp(r'@\w+');

  for (final entry in maps.entries) {
    test('${entry.key} translates every delivery code and cancellation string', () {
      final missing = keys.where((k) => (entry.value[k] ?? '').trim().isEmpty).toList();
      expect(missing, isEmpty);
      for (final k in keys) {
        final want = placeholder.allMatches(k).map((m) => m.group(0)).toSet();
        final got = placeholder.allMatches(entry.value[k]!).map((m) => m.group(0)).toSet();
        expect(got, want, reason: k);
      }
    });
  }
}
