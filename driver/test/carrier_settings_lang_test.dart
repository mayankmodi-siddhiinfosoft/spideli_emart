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
    'Carrier settings are for parcel delivery companies only.',
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
    // "Set up your carrier" (13 Oct 2026).
    'Set up your carrier',
    'You have not set up your carrier yet.',
    "Enter your carrier's details to receive parcel orders from customers.",
    "Enter your carrier's details. Customers can choose your carrier once the administrator has verified and published it.",
    'Carrier Logo',
    'Regions served',
    'Select the regions where your carrier delivers (at least one).',
    'No region is available yet. Please contact Spideli.',
    'Checked by the administrator before your carrier is verified.',
    'Document photo',
    'Create carrier',
    'Add photo',
    'Remove',
    'Your carrier could not be created. Please try again.',
    "Carrier created. It will be offered to customers once the administrator has verified it.",
    'Please enter this price',
    'Select a region to enter its prices.',
    'Please enter the prices for @region.',
    'Prices for @region',
    'Please enter the phone number',
    'Please enter a valid email address',
    'Select at least one region',
    'Could not pick the image.',
    'Phone Number',
    'Email Address',
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

}
