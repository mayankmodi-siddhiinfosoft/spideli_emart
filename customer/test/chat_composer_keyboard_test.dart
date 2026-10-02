import 'package:customer/screen_ui/multi_vendor_service/chat_screens/widgets/chat_widgets.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bug #13 — the chat keyboard covered the text field.
///
/// The composer lives in the Scaffold's `bottomNavigationBar` slot, which is
/// laid out at the bottom of the **screen**: `resizeToAvoidBottomInset` shrinks
/// the body only. `DsStickyBar(avoidKeyboard: true)` is what lifts it, and it
/// must apply the inset exactly once.
void main() {
  const double keyboard = 300;
  const Size screen = Size(400, 800);

  Widget host({required bool avoidKeyboard, double inset = keyboard}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: screen, viewInsets: EdgeInsets.only(bottom: inset)),
      child: DsScaffold(
        body: const SizedBox.expand(),
        bottomBar: DsStickyBar(
          avoidKeyboard: avoidKeyboard,
          child: const SizedBox(key: Key('composer'), height: 48),
        ),
      ),
    ),
  );

  testWidgets('without the flag the bar sits under the keyboard', (tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(avoidKeyboard: false));
    await tester.pumpAndSettle();

    final Rect bar = tester.getRect(find.byKey(const Key('composer')));
    expect(bar.bottom, greaterThan(screen.height - keyboard));
  });

  testWidgets('with the flag the bar clears the keyboard, exactly once', (tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(avoidKeyboard: true));
    await tester.pumpAndSettle();

    final Rect bar = tester.getRect(find.byKey(const Key('composer')));
    // Above the keyboard...
    expect(bar.bottom, lessThanOrEqualTo(screen.height - keyboard));
    // ...and not pushed up by two keyboards' worth of inset.
    expect(bar.bottom, greaterThan(screen.height - keyboard * 2));
  });

  testWidgets('with no keyboard the bar is laid out exactly as before', (tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(avoidKeyboard: false, inset: 0));
    await tester.pumpAndSettle();
    final Rect before = tester.getRect(find.byKey(const Key('composer')));

    await tester.pumpWidget(host(avoidKeyboard: true, inset: 0));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(const Key('composer'))), before);
  });

  // The client's 2 October report: in Help & Support (and every other chat)
  // the keyboard hid the whole input row. The chat screens now put the
  // composer in the Scaffold BODY via ChatThreadLayout, exactly as below.
  group('chat screen composer (ChatThreadLayout + ChatComposer)', () {
    const Key list = Key('messages');

    Widget chat({
      required MediaQueryData media,
      ScrollController? scroll,
      TextEditingController? text,
    }) {
      final TextEditingController field = text ?? TextEditingController();
      final Widget screen = DsScaffold(
        maxContentWidth: null,
        resizeToAvoidBottomInset: true,
        appBar: const DsAppBar(title: 'Help & Support'),
        body: ChatThreadLayout(
          scrollController: scroll,
          textController: field,
          messages: ListView.builder(
            key: list,
            reverse: true,
            controller: scroll,
            itemCount: 60,
            itemBuilder: (context, i) => SizedBox(height: 56, child: Text('message $i')),
          ),
          composer: ChatComposer(controller: field, hint: 'Start typing with admin...', onAttach: () {}, onSend: () {}, onSubmitted: (_) {}),
        ),
      );
      return MaterialApp(home: MediaQuery(data: media, child: screen));
    }

    Finder field() => find.byType(TextField);
    Finder button(IconData icon) => find.ancestor(of: find.byIcon(icon), matching: find.byType(DsIconButton));
    Finder send() => button(Icons.send_rounded);
    Finder attach() => button(Icons.add_photo_alternate_outlined);
    Finder bar() => find.byType(DsStickyBar);

    void setScreen(WidgetTester tester) {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('keyboard open: text field, attach and send sit fully above the keyboard, inset applied once', (tester) async {
      setScreen(tester);
      await tester.pumpWidget(chat(media: const MediaQueryData(size: screen)));
      await tester.pumpAndSettle();
      final double gapClosed = screen.height - tester.getRect(send()).bottom;

      // An iPhone-style keyboard: 300 inset, home-indicator viewPadding that the
      // keyboard covers, so `padding.bottom` is 0 while it is up.
      await tester.pumpWidget(
        chat(
          media: const MediaQueryData(
            size: screen,
            viewInsets: EdgeInsets.only(bottom: keyboard),
            viewPadding: EdgeInsets.only(bottom: 34),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const double keyboardTop = 800 - keyboard;
      for (final Finder f in [field(), send(), attach()]) {
        final Rect r = tester.getRect(f);
        expect(r.bottom, lessThanOrEqualTo(keyboardTop), reason: '$f must be fully above the keyboard');
        expect(r.top, greaterThanOrEqualTo(0));
      }
      // The bar's bottom edge is flush with the keyboard: not left under it,
      // and not lifted by a second inset or a stale safe-area padding.
      expect(tester.getRect(bar()).bottom, keyboardTop);
      // Same breathing room above the keyboard as above the screen edge.
      expect(keyboardTop - tester.getRect(send()).bottom, moreOrLessEquals(gapClosed));
      // Messages end where the composer starts (newest message stays visible).
      expect(tester.getRect(find.byKey(list)).bottom, tester.getRect(bar()).top);
    });

    testWidgets('keyboard closed: no extra bottom gap; only the safe area when there is one', (tester) async {
      setScreen(tester);
      await tester.pumpWidget(chat(media: const MediaQueryData(size: screen)));
      await tester.pumpAndSettle();
      expect(tester.getRect(bar()).bottom, screen.height);
      final double gap = screen.height - tester.getRect(send()).bottom;
      // The bar's own vertical padding only (DsSpace.md), nothing more.
      expect(gap, moreOrLessEquals(DsSpace.md));

      await tester.pumpWidget(
        chat(
          media: const MediaQueryData(size: screen, padding: EdgeInsets.only(bottom: 34), viewPadding: EdgeInsets.only(bottom: 34)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(bar()).bottom, screen.height);
      expect(screen.height - tester.getRect(send()).bottom, moreOrLessEquals(gap + 34));
    });

    testWidgets('the newest message comes back into view when the keyboard opens', (tester) async {
      setScreen(tester);
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      // No MediaQuery override: the keyboard arrives through the view, as on
      // a device.
      await tester.pumpWidget(
        MaterialApp(
          home: DsScaffold(
            maxContentWidth: null,
            resizeToAvoidBottomInset: true,
            body: ChatThreadLayout(
              scrollController: scroll,
              textController: TextEditingController(),
              messages: ListView.builder(reverse: true, controller: scroll, itemCount: 60, itemBuilder: (context, i) => SizedBox(height: 56, child: Text('message $i'))),
              composer: ChatComposer(controller: TextEditingController(), hint: '', onAttach: () {}, onSend: () {}, onSubmitted: (_) {}),
            ),
          ),
        ),
      );
      scroll.jumpTo(1200); // reading older messages
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      await tester.pumpAndSettle();

      expect(scroll.offset, scroll.position.minScrollExtent);
      expect(find.text('message 0'), findsOneWidget);
      expect(tester.getRect(find.byIcon(Icons.send_rounded)).bottom, lessThanOrEqualTo(screen.height - keyboard));
    });

    testWidgets('typing brings the newest message back into view', (tester) async {
      setScreen(tester);
      final ScrollController scroll = ScrollController();
      final TextEditingController text = TextEditingController();
      addTearDown(scroll.dispose);
      addTearDown(text.dispose);
      await tester.pumpWidget(chat(media: const MediaQueryData(size: screen), scroll: scroll, text: text));
      scroll.jumpTo(1200);
      await tester.pump();

      await tester.enterText(field(), 'hello');
      await tester.pumpAndSettle();

      expect(scroll.offset, scroll.position.minScrollExtent);
      expect(find.text('message 0'), findsOneWidget);
    });

    testWidgets('no list attached yet: keyboard and typing do not throw', (tester) async {
      setScreen(tester);
      final ScrollController scroll = ScrollController();
      final TextEditingController text = TextEditingController();
      addTearDown(scroll.dispose);
      addTearDown(text.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DsScaffold(
            maxContentWidth: null,
            resizeToAvoidBottomInset: true,
            body: ChatThreadLayout(
              scrollController: scroll,
              textController: text,
              messages: const SizedBox.expand(), // e.g. the initial loader
              composer: ChatComposer(controller: text, hint: '', onAttach: () {}, onSend: () {}, onSubmitted: (_) {}),
            ),
          ),
        ),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
