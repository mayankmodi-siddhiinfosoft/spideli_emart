import 'package:bottom_picker/bottom_picker.dart';
import 'package:customer/main.dart';
import 'package:customer/widget/schedule_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bug #8 — the schedule-time calendar never displayed.
///
/// bottom_picker 5 runs on the standalone material_ui / cupertino_ui packages,
/// whose `showModalBottomSheet` asserts on **their** `MaterialLocalizations`.
/// A `package:flutter/material.dart` MaterialApp registers only Flutter's own,
/// so `.show()` threw "No MaterialLocalizations found" inside the tap handler
/// and the sheet never appeared. `appLocalizationsDelegates` is what fixes it.
void main() {
  Widget host(void Function(BuildContext) onTap) => MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: () => onTap(context), child: const Text('open')),
        ),
      ),
    ),
  );

  testWidgets('the schedule picker opens', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(
      host(
        (context) => showSchedulePicker(
          context: context,
          title: 'Schedule Time',
          minDateTime: DateTime.now(),
          onPicked: (value) => picked = value,
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomPicker<DateTime>), findsOneWidget);
    expect(find.text('Schedule Time'), findsOneWidget);
    expect(picked, isNull);
  });

  testWidgets('a stale value below the minimum still opens the picker', (tester) async {
    // The checkout keeps the last schedule time; by the next visit it is in the
    // past, which used to put the picker outside its own bounds.
    await tester.pumpWidget(
      host(
        (context) => showSchedulePicker(
          context: context,
          title: 'Schedule Time',
          initialDateTime: DateTime.now().subtract(const Duration(days: 30)),
          minDateTime: DateTime.now(),
          onPicked: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomPicker<DateTime>), findsOneWidget);
  });

  group('clampScheduleDateTime', () {
    final min = DateTime(2026, 10, 1, 12);
    final max = DateTime(2026, 10, 8, 12);

    test('keeps a value inside the range', () {
      final value = DateTime(2026, 10, 3);
      expect(clampScheduleDateTime(value, min: min, max: max), value);
    });

    test('folds a value below the minimum onto the minimum', () {
      expect(clampScheduleDateTime(DateTime(2020), min: min, max: max), min);
    });

    test('folds a value above the maximum onto the maximum', () {
      expect(clampScheduleDateTime(DateTime(2030), min: min, max: max), max);
    });

    test('falls back to a value inside the range when none is set', () {
      final result = clampScheduleDateTime(null, min: min, max: max);
      expect(result.isBefore(min), isFalse);
      expect(result.isAfter(max), isFalse);
    });
  });
}
