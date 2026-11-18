import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/friends/friend_room_view.dart';
import 'package:futbol_card/ui_v21/theme/v21_scroll_behavior.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';

import 'v21_test_support.dart';

/// Pencere sınıfları, ölçek sınırları ve bağımsız ekranlar.
void main() {
  setUpAll(loadV21Fonts);

  group('pencere sınıfı', () {
    test('telefon, tablet ve masaüstü doğru sınıfa düşer', () {
      expect(V21Scale.classOf(const Size(280, 653)), V21WindowClass.compact);
      expect(V21Scale.classOf(const Size(390, 844)), V21WindowClass.compact);
      expect(V21Scale.classOf(const Size(768, 1024)), V21WindowClass.medium);
      expect(V21Scale.classOf(const Size(1024, 768)), V21WindowClass.expanded);
      expect(V21Scale.classOf(const Size(1920, 1080)), V21WindowClass.expanded);
      expect(V21Scale.classOf(const Size(844, 390)), V21WindowClass.expanded, reason: 'kısa yatay pencere');
    });

    for (final boyut in kV21AllSizes) {
      test('${v21SizeName(boyut)}: içerik pencereye sığar, yazı aşırı büyümez', () {
        final s = V21Scale.forSize(boyut);
        final menu = s.isExpanded ? V21Metrics.sideNavWidth : 0;
        expect(s.contentWidth, lessThanOrEqualTo(boyut.width - menu));
        expect(s.s, inInclusiveRange(0.7, 1.3));
      });
    }
  });

  test('yatay listeler fareyle sürüklenebilir', () {
    expect(const V21ScrollBehavior().dragDevices, containsAll(PointerDeviceKindSet.gerekli));
  });

  group('arkadaş odası', () {
    for (final boyut in kV21AllSizes) {
      testWidgets('${v21SizeName(boyut)} taşmaz', (t) async {
        t.view.physicalSize = boyut;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const FriendRoomView()));
        await t.pump();
        expect(t.takeException(), isNull);
        expect(find.text('DAVET OLUŞTUR'), findsOneWidget);
        if (boyut == const Size(1672, 941) && v21GoldenFor(boyut)) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/v21_friends_1672x941.png'));
        }
      });
    }
  });
}

abstract final class PointerDeviceKindSet {
  static const gerekli = [PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad];
}
