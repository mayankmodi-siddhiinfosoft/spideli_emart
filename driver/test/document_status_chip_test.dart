import 'package:driver/app/verification_screen/document_status_widgets.dart';
import 'package:driver/lang/app_fr.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Fr extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {'fr_FR': trFR};
}

/// The status chips of the documents screens: one per overall status, the
/// translated label and the right tone.
void main() {
  Widget host(Widget child, {Locale? locale}) => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DsTheme.light(),
        translations: _Fr(),
        locale: locale ?? const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: Center(child: child)),
      );

  for (final status in DocumentOverallStatus.values) {
    testWidgets('overall chip: ${status.key}', (tester) async {
      await tester.pumpWidget(host(DocumentOverallStatusChip(status: status)));
      expect(find.byKey(ValueKey('document-overall-${status.key}')), findsOneWidget);
      expect(find.text(status.label), findsOneWidget);
      final DsBadge badge = tester.widget(find.byType(DsBadge));
      expect(badge.tone, overallStatusTone(status));
    });
  }

  test('tones: verified green, action required red, pending amber, not submitted neutral', () {
    expect(overallStatusTone(DocumentOverallStatus.verified), DsTone.success);
    expect(overallStatusTone(DocumentOverallStatus.actionRequired), DsTone.danger);
    expect(overallStatusTone(DocumentOverallStatus.pending), DsTone.warning);
    expect(overallStatusTone(DocumentOverallStatus.notSubmitted), DsTone.neutral);
    expect(entryStatusTone('rejected'), DsTone.danger);
    expect(entryStatusTone('expired'), DsTone.danger);
    expect(entryStatusTone('approved'), DsTone.success);
  });

  testWidgets('labels are translated', (tester) async {
    await tester.pumpWidget(host(const DocumentOverallStatusChip(status: DocumentOverallStatus.actionRequired), locale: const Locale('fr', 'FR')));
    expect(find.text(trFR['Action required']!), findsOneWidget);
  });

  testWidgets('entry chip and type badge', (tester) async {
    await tester.pumpWidget(host(const Column(mainAxisSize: MainAxisSize.min, children: [
      DocumentEntryStatusChip(status: 'rejected'),
      DocumentTypeBadge(type: 'vehicle'),
      DocumentTypeBadge(type: 'driver'),
    ])));
    expect(find.byKey(const ValueKey('document-entry-rejected')), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Vehicle'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
  });
}
