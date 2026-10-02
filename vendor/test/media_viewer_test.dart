import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:vendor/app/chat_screens/full_screen_image_viewer.dart';
import 'package:vendor/app/chat_screens/full_screen_video_viewer.dart';
import 'package:vendor/controller/dash_board_controller.dart';
import 'package:vendor/widget/video_widget.dart';

Widget _host(Widget child) => GetMaterialApp(home: child);

void main() {
  // Report 02#7: tapping an employee's photo in the home header opened the
  // Profile tab by a fixed position (3, or 4 with dine-in) that an employee's
  // role-filtered tab bar does not have, and the dashboard blanked.
  group('dashboard tabs', () {
    const List<NavigationItem> owner = [
      NavigationItem(label: DashBoardController.homeTab, iconPath: '', page: SizedBox()),
      NavigationItem(label: DashBoardController.dineInTab, iconPath: '', page: SizedBox()),
      NavigationItem(label: DashBoardController.productsTab, iconPath: '', page: SizedBox()),
      NavigationItem(label: DashBoardController.walletTab, iconPath: '', page: SizedBox()),
      NavigationItem(label: DashBoardController.profileTab, iconPath: '', page: SizedBox()),
    ];
    const List<NavigationItem> employee = [
      NavigationItem(label: DashBoardController.homeTab, iconPath: '', page: SizedBox()),
      NavigationItem(label: DashBoardController.profileTab, iconPath: '', page: SizedBox()),
    ];

    test('the profile tab is found wherever it sits', () {
      expect(DashBoardController.tabIndexIn(owner, DashBoardController.profileTab), 4);
      expect(DashBoardController.tabIndexIn(employee, DashBoardController.profileTab), 1);
    });

    test('a tab the role leaves out is reported missing, not guessed', () {
      expect(DashBoardController.tabIndexIn(employee, DashBoardController.productsTab), -1);
      expect(DashBoardController.tabIndexIn(employee, DashBoardController.dineInTab), -1);
    });

    test('a position past the end falls back to the first tab', () {
      expect(DashBoardController.safeTabIndex(4, employee.length), 0);
      expect(DashBoardController.safeTabIndex(-1, employee.length), 0);
      expect(DashBoardController.safeTabIndex(1, employee.length), 1);
      expect(DashBoardController.safeTabIndex(0, 0), 0);
    });
  });

  group('FullScreenImageViewer', () {
    test('only an http(s) address counts as a photo', () {
      expect(FullScreenImageViewer.canShow(null), isFalse);
      expect(FullScreenImageViewer.canShow(''), isFalse);
      expect(FullScreenImageViewer.canShow('   '), isFalse);
      expect(FullScreenImageViewer.canShow('null'), isFalse);
      expect(FullScreenImageViewer.canShow('assets/images/user_placeholder.png'), isFalse);
      expect(FullScreenImageViewer.canShow('https://example.com/a.png'), isTrue);
    });

    test('open() does nothing without a photo', () {
      expect(FullScreenImageViewer.open(null), isFalse);
      expect(FullScreenImageViewer.open(''), isFalse);
    });

    for (final String? url in <String?>[null, '', 'not a url']) {
      testWidgets('a missing photo ("$url") says so instead of opening blank', (tester) async {
        await tester.pumpWidget(_host(FullScreenImageViewer(imageUrl: url)));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(PhotoView), findsNothing);
        expect(find.text('Photo not available'), findsOneWidget);
        expect(find.byType(Hero), findsNothing);
      });
    }

    testWidgets('a valid photo opens the zoomable viewer', (tester) async {
      await tester.pumpWidget(_host(const FullScreenImageViewer(imageUrl: 'https://example.com/a.png', heroTag: 'chat-image-1')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(PhotoView), findsOneWidget);
      final Hero hero = tester.widget(find.byType(Hero));
      expect(hero.tag, 'chat-image-1');
    });
  });

  group('FullScreenVideoViewer', () {
    for (final String url in <String>['', '  ', 'not a url']) {
      testWidgets('a missing video ("$url") says so instead of spinning on black', (tester) async {
        await tester.pumpWidget(_host(FullScreenVideoViewer(videoUrl: url, heroTag: 'v')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Video not available'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    }
  });

  group('video previews', () {
    test('only a file or a non-empty address is playable', () {
      expect(hasPlayableVideoSource(null), isFalse);
      expect(hasPlayableVideoSource(''), isFalse);
      expect(hasPlayableVideoSource(42), isFalse);
      expect(hasPlayableVideoSource('https://example.com/v.mp4'), isTrue);
    });

    testWidgets('an ad without a video shows a stand-in instead of throwing', (tester) async {
      await tester.pumpWidget(_host(const Scaffold(body: VideoAdvWidget(url: null, width: 200, height: 120))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(VideoUnavailableBox), findsOneWidget);
    });
  });
}
