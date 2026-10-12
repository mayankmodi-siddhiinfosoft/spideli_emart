import 'package:driver/lang/app_ar.dart';
import 'package:driver/lang/app_de.dart';
import 'package:driver/lang/app_en.dart';
import 'package:driver/lang/app_fr.dart';
import 'package:driver/lang/app_hi.dart';
import 'package:driver/lang/app_ja.dart';
import 'package:driver/lang/app_pt.dart';
import 'package:driver/lang/app_ru.dart';
import 'package:driver/lang/app_zh.dart';
import 'package:flutter_test/flutter_test.dart';

/// The owner's "Carrier settings" (parcel pricing brief, 12 Oct 2026) is
/// translated in every language map, placeholders kept.
void main() {
  const keys = <String>[
    'Carrier settings',
    'Carrier Management for Parcel Delivery',
    'Carrier settings are for company owners only.',
    'Your carrier has not been set up yet — please contact Spideli.',
    'Verified carrier',
    'Verification pending',
    'Published',
    'Not published',
    'Only the administrator can change this.',
    'Carrier Identity',
    'Carrier Name',
    'Enter carrier name',
    'Enter phone number',
    'Enter carrier email address',
    'Delivery Scopes',
    'Select the operational scopes this carrier handles (at least one required).',
    'Within City',
    'Local deliveries inside the same city',
    'Between Cities',
    'Intercity deliveries across different cities',
    'Between Countries',
    'Cross-border deliveries between countries',
    'Pricing',
    'Base Charge',
    'Charge per km',
    'Charge per kg',
    'Minimum Charge',
    'Each region you serve has its own prices, in that region\'s currency. Leave a door / pickup-point value empty to use the region\'s default; 0 means free.',
    'Volumetric Divisor',
    'Home Pickup Charge',
    'Point Drop-off Charge',
    'Home Delivery Charge',
    'Point Collection Charge',
    'Service Parameters',
    'Maximum Weight (kg)',
    'Minimum Delivery Time',
    'Maximum Delivery Time',
    'Delivery Time Unit',
    'Select',
    'Conditions',
    'Conditions of carriage or special delivery terms',
    'Company Registration',
    'Verified by the administrator from your company profile.',
    'Carrier Code',
    'Regions',
    'Unique ID Number',
    'Carrier reference',
    'Save Changes',
    'Hours',
    'Days',
    'No document',
    'Region default: @value',
    'Region default: size not used',
    'Nothing to save',
    'Your carrier settings could not be saved. Please try again.',
    'Carrier settings saved',
    'Pickup and delivery options',
    'Please enter the carrier name',
    'Enter a valid number',
    'This value cannot be negative',
    'The maximum delivery time must not be less than the minimum',
    'At least one delivery scope must be selected',
  ];
  const maps = <String, Map<String, String>>{'en': enUS, 'ar': lnAr, 'de': deGR, 'fr': trFR, 'hi': hiIN, 'ja': jaJP, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH};
  final placeholder = RegExp(r'@\w+');
  for (final entry in maps.entries) {
    test('${entry.key} translates every carrier settings string', () {
      expect(keys.where((k) => (entry.value[k] ?? '').trim().isEmpty).toList(), isEmpty);
      for (final k in keys) {
        expect(placeholder.allMatches(entry.value[k]!).map((m) => m.group(0)).toSet(), placeholder.allMatches(k).map((m) => m.group(0)).toSet(), reason: k);
      }
    });
  }

  test('the carrier is never created in the app: its creation strings are gone', () {
    for (final k in const ['Create Carrier', 'Create Carrier for Parcel Delivery', 'Please create a carrier first to enable parcel delivery service.']) {
      expect(enUS.containsKey(k), isFalse, reason: k);
    }
  });
}
