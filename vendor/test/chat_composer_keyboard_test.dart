import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/app/chat_screens/widgets/chat_widgets.dart';
import 'package:vendor/themes/ds/ds.dart';

/// The client's 2 October report: in Help & Support (and every other chat)
/// the open keyboard hid the whole input row — text field, attach and send.
///
/// Both store chat screens (Help & Support, and the order / admin chat) build
/// their body exactly like [chat] below: a Scaffold that resizes for the
/// keyboard, and a [ChatThreadLayout] with the message list above the
/// screen's composer.
void main() {
  const double keyboard = 300;
  const Size screen = Size(400, 800);

  const Key list = Key('messages');

  Widget composerFor(String kind, TextEditingController text) => kind == 'help'
      ? HelpSupportComposer(controller: text, onAttach: () {}, onSend: () {}, onSubmitted: (_) {})
      : ChatComposer(controller: text, onAttach: () {}, onSend: () {});

  Widget chat(String kind, {MediaQueryData? media, ScrollController? scroll, TextEditingController? text}) {
    final TextEditingController field = text ?? TextEditingController();
    final Widget page = Scaffold(
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
        composer: composerFor(kind, field),
      ),
    );
    return MaterialApp(home: media == null ? page : MediaQuery(data: media, child: page));
  }

  Finder button(IconData icon) => find.ancestor(of: find.byIcon(icon), matching: find.byType(DsIconButton));
  Finder field() => find.byType(TextField);
  Finder send() => button(Icons.send_rounded);
  Finder attach() => button(Icons.add_photo_alternate_outlined);
  Finder bar() => find.byType(DsStickyBar);

  void setScreen(WidgetTester tester) {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  for (final String kind in ['help', 'order']) {
    group('$kind chat composer', () {
      testWidgets('keyboard open: text field, attach and send sit fully above the keyboard, inset applied once', (tester) async {
        setScreen(tester);
        await tester.pumpWidget(chat(kind, media: const MediaQueryData(size: screen)));
        await tester.pumpAndSettle();
        final double gapClosed = screen.height - tester.getRect(send()).bottom;

        // An iPhone-style keyboard: 300 inset, home-indicator viewPadding that
        // the keyboard covers, so `padding.bottom` is 0 while it is up.
        await tester.pumpWidget(
          chat(
            kind,
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
        // Flush with the keyboard: not under it, not lifted twice.
        expect(tester.getRect(bar()).bottom, keyboardTop);
        // Same breathing room above the keyboard as above the screen edge.
        expect(keyboardTop - tester.getRect(send()).bottom, moreOrLessEquals(gapClosed));
        // The messages end where the composer starts.
        expect(tester.getRect(find.byKey(list)).bottom, tester.getRect(bar()).top);
      });

      testWidgets('keyboard closed: no extra bottom gap; only the safe area when there is one', (tester) async {
        setScreen(tester);
        await tester.pumpWidget(chat(kind, media: const MediaQueryData(size: screen)));
        await tester.pumpAndSettle();
        expect(tester.getRect(bar()).bottom, screen.height);
        final double gap = screen.height - tester.getRect(send()).bottom;
        // The bar's own vertical padding only (DsSpace.md) — the send button
        // is the tallest thing in the row in both composers.
        expect(gap, moreOrLessEquals(DsSpace.md, epsilon: 6));

        await tester.pumpWidget(
          chat(kind, media: const MediaQueryData(size: screen, padding: EdgeInsets.only(bottom: 34), viewPadding: EdgeInsets.only(bottom: 34))),
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
        await tester.pumpWidget(chat(kind, scroll: scroll));
        scroll.jumpTo(1200); // reading older messages
        await tester.pump();

        tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();

        expect(scroll.offset, scroll.position.minScrollExtent);
        expect(find.text('message 0'), findsOneWidget);
        expect(tester.getRect(send()).bottom, lessThanOrEqualTo(screen.height - keyboard));
      });

      testWidgets('typing brings the newest message back into view', (tester) async {
        setScreen(tester);
        final ScrollController scroll = ScrollController();
        final TextEditingController text = TextEditingController();
        addTearDown(scroll.dispose);
        addTearDown(text.dispose);
        await tester.pumpWidget(chat(kind, scroll: scroll, text: text));
        scroll.jumpTo(1200);
        await tester.pump();

        await tester.enterText(field(), 'hello');
        await tester.pumpAndSettle();

        expect(scroll.offset, scroll.position.minScrollExtent);
        expect(find.text('message 0'), findsOneWidget);
      });
    });
  }

  testWidgets('no list attached yet: keyboard and typing do not throw', (tester) async {
    setScreen(tester);
    final ScrollController scroll = ScrollController();
    final TextEditingController text = TextEditingController();
    addTearDown(scroll.dispose);
    addTearDown(text.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: true,
          body: ChatThreadLayout(
            scrollController: scroll,
            textController: text,
            messages: const SizedBox.expand(), // e.g. the initial loader
            composer: composerFor('help', text),
          ),
        ),
      ),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();
    await tester.enterText(field(), 'hi');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('DsStickyBar(avoidKeyboard) in a bottom bar clears the keyboard exactly once', (tester) async {
    setScreen(tester);
    Widget host(bool avoid, double inset) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: screen, viewInsets: EdgeInsets.only(bottom: inset)),
        child: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: DsStickyBar(avoidKeyboard: avoid, child: const SizedBox(key: Key('bar'), height: 48)),
        ),
      ),
    );
    await tester.pumpWidget(host(false, keyboard));
    expect(tester.getRect(find.byKey(const Key('bar'))).bottom, greaterThan(screen.height - keyboard));

    await tester.pumpWidget(host(true, keyboard));
    final double bottom = tester.getRect(find.byKey(const Key('bar'))).bottom;
    expect(bottom, lessThanOrEqualTo(screen.height - keyboard));
    expect(bottom, greaterThan(screen.height - keyboard * 2));

    await tester.pumpWidget(host(false, 0));
    final Rect before = tester.getRect(find.byKey(const Key('bar')));
    await tester.pumpWidget(host(true, 0));
    expect(tester.getRect(find.byKey(const Key('bar'))), before);
  });
}
