// Chat composer vs. on-screen keyboard (client bug: in Help & Support the
// text field, attach and send buttons disappeared behind the keyboard).
//
// The real chat screens need Firebase and GetX controllers, so these tests
// pump the same layouts the screens use, built from the same DS widgets:
//
// * composer in the Scaffold's bottom bar (`DsStickyBar(avoidKeyboard: true)`),
//   pushed as its own route or nested in a dashboard Scaffold's body;
// * composer as the last child of the body (`Column` + `Expanded` list),
//   pushed or nested in a dashboard Scaffold's body;
//
// and check that with a 300 px keyboard the text field and send button sit
// fully above it with the normal bar padding (inset applied exactly once, no
// safe area), and that without a keyboard there is no extra bottom gap.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideliprovider/themes/ds/ds.dart';

const Size _screen = Size(390, 844);
const double _keyboard = 300;
const double _safeArea = 34;

/// What Flutter reports on a phone with a home indicator: while the keyboard
/// is up it covers the safe area, so `padding.bottom` is 0.
MediaQueryData _mq({required bool keyboard}) => MediaQueryData(
      size: _screen,
      viewInsets: EdgeInsets.only(bottom: keyboard ? _keyboard : 0),
      viewPadding: const EdgeInsets.only(bottom: _safeArea),
      padding: EdgeInsets.only(bottom: keyboard ? 0 : _safeArea),
    );

const Key _field = Key('composer-field');
const Key _send = Key('composer-send');
const Key _attach = Key('composer-attach');

Widget _composerRow() => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        DsIconButton(key: _attach, icon: Icons.camera_alt_outlined, semanticLabel: 'Send Media', variant: DsIconButtonVariant.tonal, onPressed: () {}),
        const DsGap(DsSpace.sm),
        const Flexible(child: TextField(key: _field, minLines: 1, maxLines: 4)),
        const DsGap(DsSpace.sm),
        DsIconButton(key: _send, icon: Icons.send_rounded, semanticLabel: 'Send', variant: DsIconButtonVariant.tonal, size: 52, onPressed: () {}),
      ],
    );

Widget _messages() => ListView.builder(reverse: true, itemCount: 40, itemBuilder: (_, i) => SizedBox(height: 56, child: Text('message $i')));

/// Driver order chat / help & support, worker chat / help & support.
Widget _bottomBarChat() => DsScaffold(body: _messages(), bottomBar: DsStickyBar(avoidKeyboard: true, child: _composerRow()));

/// Provider chat / help & support.
Widget _bodyComposerChat() => Scaffold(
      body: Column(children: [Expanded(child: _messages()), DsStickyBar(child: _composerRow())]),
    );

/// A dashboard Scaffold (app bar + drawer) that shows the chat page as its
/// body, as the driver and provider dashboards do for Help & Support.
Widget _inDashboard(Widget page) => Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      drawer: const Drawer(),
      body: page,
    );

Future<void> _pump(WidgetTester tester, Widget page, {required bool keyboard}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    home: MediaQuery(data: _mq(keyboard: keyboard), child: page),
  ));
  await tester.pumpAndSettle();
}

/// The composer row (the bar's content, without its padding).
Rect _row(WidgetTester tester) => tester.getRect(find.ancestor(of: find.byKey(_field), matching: find.byType(Row)).first);

void _expectAboveKeyboard(WidgetTester tester) {
  final keyboardTop = _screen.height - _keyboard;
  for (final key in [_field, _send, _attach]) {
    final r = tester.getRect(find.byKey(key));
    expect(r.top, greaterThanOrEqualTo(0), reason: '$key is pushed off the top');
    expect(r.bottom, lessThanOrEqualTo(keyboardTop), reason: '$key is behind the keyboard');
  }
  // Directly above the keyboard with the bar's normal padding: the inset is
  // applied once (not twice) and the safe area is not added on top of it.
  expect(_row(tester).bottom, moreOrLessEquals(keyboardTop - DsSpace.md));
}

void _expectNoExtraGapWithoutKeyboard(WidgetTester tester) {
  // Only the safe area and the bar's own padding below the composer.
  expect(_row(tester).bottom, moreOrLessEquals(_screen.height - _safeArea - DsSpace.md));
}

void main() {
  final layouts = <String, Widget Function()>{
    'composer in the bottom bar (own route)': _bottomBarChat,
    'composer in the bottom bar (inside a dashboard Scaffold)': () => _inDashboard(_bottomBarChat()),
    'composer in the body (own route)': _bodyComposerChat,
    'composer in the body (inside a dashboard Scaffold)': () => _inDashboard(_bodyComposerChat()),
  };

  for (final entry in layouts.entries) {
    group(entry.key, () {
      testWidgets('keyboard open: text field, attach and send sit fully above the keyboard', (tester) async {
        await _pump(tester, entry.value(), keyboard: true);
        _expectAboveKeyboard(tester);
      });

      testWidgets('keyboard closed: no extra bottom gap', (tester) async {
        await _pump(tester, entry.value(), keyboard: false);
        _expectNoExtraGapWithoutKeyboard(tester);
      });
    });
  }

  testWidgets('a plain sticky bar (not a composer) keeps its old behaviour', (tester) async {
    await _pump(tester, DsScaffold(body: _messages(), bottomBar: DsStickyBar(child: _composerRow())), keyboard: true);
    expect(_row(tester).bottom, moreOrLessEquals(_screen.height - DsSpace.md));
  });

  group('DsChatAutoScroll', () {
    late ScrollController scroll;
    late TextEditingController text;

    Widget chat() => DsScaffold(
          body: DsChatAutoScroll(controller: scroll, textController: text, child: ListView.builder(controller: scroll, reverse: true, itemCount: 60, itemBuilder: (_, i) => SizedBox(height: 56, child: Text('message $i')))),
          bottomBar: DsStickyBar(avoidKeyboard: true, child: TextField(key: _field, controller: text)),
        );

    setUp(() {
      scroll = ScrollController();
      text = TextEditingController();
    });
    tearDown(() {
      scroll.dispose();
      text.dispose();
    });

    Future<void> pumpChat(WidgetTester tester) async {
      tester.view.physicalSize = _screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: ThemeData.light(), home: chat()));
      await tester.pumpAndSettle();
    }

    testWidgets('scrolls to the newest message when the keyboard appears', (tester) async {
      await pumpChat(tester);
      scroll.jumpTo(800); // the user scrolled up to older messages
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pumpAndSettle();
      expect(scroll.offset, scroll.position.minScrollExtent);
      // The composer moved up with the keyboard.
      expect(tester.getRect(find.byKey(_field)).bottom, lessThanOrEqualTo(_screen.height - _keyboard));
    });

    testWidgets('scrolls to the newest message when the user types', (tester) async {
      await pumpChat(tester);
      scroll.jumpTo(800);
      await tester.pump();
      await tester.enterText(find.byKey(_field), 'Hello');
      await tester.pumpAndSettle();
      expect(scroll.offset, scroll.position.minScrollExtent);
    });

    testWidgets('does nothing (and does not throw) before the list is attached', (tester) async {
      final detached = ScrollController();
      addTearDown(detached.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DsChatAutoScroll(controller: detached, textController: text, child: TextField(key: _field, controller: text))),
      ));
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      addTearDown(tester.view.reset);
      await tester.enterText(find.byKey(_field), 'Hi');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
