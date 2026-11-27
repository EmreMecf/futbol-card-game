// UÇTAN UCA TEST — gerçek tarayıcı (Chrome) + gerçek sunucu + gerçek veritabanı
//
// Sahte hiçbir şey yok: uygulama Chrome'da açılır, istekler yerel API'ye
// gider, API geçici bir PostgreSQL veritabanına yazar. Senaryo:
//   kayıt → ana sayfa → koleksiyon → ayarlar (dil TR→EN→TR) → çıkış →
//   tekrar giriş → botla antrenman maçı (sonuna kadar) → ana sayfa
//
// Hem telefon düzeninde (dar pencere) hem geniş web düzeninde çalışır.
//
// Çalıştırma (veritabanı, sunucu ve chromedriver'ı betik kurar):
//   bash scripts/uctan-uca-test.sh
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:futbol_card/core/router/app_routes.dart';
import 'package:futbol_card/main.dart' as app;
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:futbol_card/ui_v21/web/web_kit.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final adimlar = <String>[];

  /// Ekrandaki bütün yazılar (hata olunca rapora eklenir)
  String ekran() => find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '')
      .where((s) => s.trim().isNotEmpty)
      .join(' | ');

  String rota(WidgetTester t) => GoRouter.of(t.element(find.byType(Navigator).first)).state.uri.path;

  /// Gerçek ağ isteği beklenir: koşul sağlanana kadar kare kare ilerler
  Future<void> bekleKosul(WidgetTester t, bool Function() kosul, String ne, {int saniye = 30}) async {
    final son = DateTime.now().add(Duration(seconds: saniye));
    while (DateTime.now().isBefore(son)) {
      await t.pump(const Duration(milliseconds: 200));
      if (kosul()) {
        adimlar.add('TAMAM: $ne');
        return;
      }
    }
    fail('BEKLENEN GELMEDİ: $ne\nRota: ${rota(t)}\nAdımlar: ${adimlar.join(' → ')}\nEkran: ${ekran()}');
  }

  Future<void> bekle(WidgetTester t, Finder f, String ne, {int saniye = 30}) =>
      bekleKosul(t, () => f.evaluate().isNotEmpty, ne, saniye: saniye);

  /// Gerçek kullanıcı gibi basar: hedefin üstünde başka bir şey varsa
  /// (ör. alttan çıkan bildirim) kalkmasını bekler, sonra dokunur.
  Future<void> bas(WidgetTester t, Finder f, String ne) async {
    await t.ensureVisible(f.last);
    await bekle(t, f.hitTestable(), 'basılabilir: $ne', saniye: 10);
    await t.tap(f.hitTestable().last);
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<void> yaz(WidgetTester t, String etiket, String metin) async {
    final alan = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == etiket);
    await t.enterText(alan.first, metin);
    await t.pump(const Duration(milliseconds: 100));
  }

  void git(WidgetTester t, String hedef) {
    GoRouter.of(t.element(find.byType(Navigator).first)).go(hedef);
  }

  /// Telefon düzeninde V21PlayerCard, geniş web düzeninde WCard çizilir
  final kart = find.byWidgetPredicate((w) => w is V21PlayerCard || w is WCard);
  final elKarti = find
      .byWidgetPredicate((w) => (w is V21PlayerCard && w.onTap != null) || (w is WCard && w.onTap != null))
      .hitTestable();

  /// Basılabilir oyun düğmesi (telefon: V21GameButton, geniş web: WButton)
  Finder dugme(String etiket) => find
      .byWidgetPredicate(
        (w) =>
            (w is V21GameButton && w.label == etiket && w.status == V21ButtonStatus.normal) ||
            (w is WButton && w.label == etiket && w.onTap != null && !w.busy),
      )
      .hitTestable();

  /// Maçı bitene kadar oynar: sıra bizdeyse elden basılabilir ilk kartı
  /// seçer ve OYNA! der; bot hamlesini sunucu yapar. Hamle sayısını döner.
  Future<int> macOyna(WidgetTester t) async {
    final son = DateTime.now().add(const Duration(minutes: 8));
    var hamle = 0;
    while (DateTime.now().isBefore(son)) {
      await t.pump(const Duration(milliseconds: 250));
      if (find.text('ANA MENÜ').evaluate().isNotEmpty) return hamle;
      if (dugme('PAS GEÇ · TURU KAYBET').evaluate().isNotEmpty) {
        await t.tap(dugme('PAS GEÇ · TURU KAYBET').first);
        hamle++;
        continue;
      }
      if (find.text('OYNA!').evaluate().isEmpty) continue; // sıra rakipte / sahne oynuyor
      if (dugme('OYNA!').evaluate().isEmpty) {
        if (elKarti.evaluate().isNotEmpty) await t.tap(elKarti.first);
        continue;
      }
      await t.tap(dugme('OYNA!').first);
      hamle++;
    }
    fail('MAÇ 8 DAKİKADA BİTMEDİ ($hamle hamle)\nAdımlar: ${adimlar.join(' → ')}\nEkran: ${ekran()}');
  }

  testWidgets('kayıt → koleksiyon → dil → çıkış → giriş → antrenman maçı', (t) async {
    // Her çalıştırmada yeni hesap (aynı veritabanında tekrar çalıştırılabilsin)
    final no = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final kullanici = 'e2e_$no';
    final eposta = 'e2e_$no@test.local';
    const sifre = 'UcTanUca-2026!';

    unawaited(app.main());
    await bekle(t, find.text('GİRİŞ YAP'), 'giriş ekranı açıldı');

    // 1) KAYIT
    await bas(t, find.text('KAYDOL'), 'KAYDOL');
    await bekle(t, find.text('HESAP OLUŞTUR'), 'kayıt ekranı');
    await yaz(t, 'Kullanıcı adı', kullanici);
    await yaz(t, 'E-posta', eposta);
    await yaz(t, 'Şifre', sifre);
    await bas(t, find.text('HESAP OLUŞTUR'), 'HESAP OLUŞTUR');

    // 2) ANA SAYFA: sunucu hesabı açtı, başlangıç kadrosu verildi
    await bekle(t, find.text('MAÇA BAŞLA'), 'kayıt sonrası ana sayfa', saniye: 45);

    // 3) KOLEKSİYON (menüden): başlangıç kartları sunucudan gelir
    await bas(t, find.text('KARTLAR'), 'menü KARTLAR');
    await bekleKosul(t, () => rota(t) == AppRoutes.collection, 'koleksiyon ekranı');
    await bekle(t, kart, 'başlangıç kartları sunucudan geldi');
    expect(find.text('HENÜZ KART YOK'), findsNothing);

    // 4) AYARLAR: dil İngilizce ↔ Türkçe
    git(t, AppRoutes.settings);
    await bekle(t, find.text('DİL'), 'ayarlar ekranı');
    await bas(t, find.byKey(const ValueKey('dil-en')), 'English');
    await bekle(t, find.text('LANGUAGE'), 'dil İngilizce oldu');
    await bas(t, find.byKey(const ValueKey('dil-tr')), 'Türkçe');
    await bekle(t, find.text('DİL'), 'dil Türkçeye döndü');
    // Ekranın altındaki düğmeye kaydırarak inilir (gerçek kullanıcı gibi)
    await t.scrollUntilVisible(find.text('ÇIKIŞ YAP'), 300, scrollable: find.byType(Scrollable).first);

    // 5) ÇIKIŞ (onay penceresiyle)
    await bas(t, find.text('ÇIKIŞ YAP'), 'ÇIKIŞ YAP');
    await bekle(t, find.text('ÇIKIŞ YAPILSIN MI?'), 'çıkış onayı soruldu');
    await bas(t, find.text('ÇIKIŞ YAP'), 'onay: ÇIKIŞ YAP');
    await bekle(t, find.text('GİRİŞ YAP'), 'çıkış sonrası giriş ekranı');

    // 6) AYNI HESAPLA TEKRAR GİRİŞ
    await yaz(t, 'E-posta', eposta);
    await yaz(t, 'Şifre', sifre);
    await bas(t, find.text('GİRİŞ YAP'), 'GİRİŞ YAP');
    await bekle(t, find.text('MAÇA BAŞLA'), 'giriş sonrası ana sayfa', saniye: 45);

    // 7) BOTLA ANTRENMAN MAÇI: sonuna kadar oynanır
    await bas(t, find.text('MAÇA BAŞLA'), 'MAÇA BAŞLA');
    await bekle(t, find.text('BOTLA ANTRENMAN'), 'maça hazırlık ekranı');
    await bas(t, find.text('BOTLA ANTRENMAN'), 'BOTLA ANTRENMAN');
    await bekleKosul(t, () => rota(t).startsWith('${AppRoutes.match}/'), 'antrenman maçı açıldı', saniye: 45);

    final hamle = await macOyna(t);
    adimlar.add('TAMAM: maç bitti ($hamle hamle)');
    expect(hamle, greaterThan(0));
    await bekle(t, find.text('ANA MENÜ'), 'sonuç ekranı');
    expect(find.text('ANTRENMAN · ÖDÜL VE PUAN YOK'), findsOneWidget);
    await bas(t, find.text('ANA MENÜ'), 'ANA MENÜ');
    await bekle(t, find.text('MAÇA BAŞLA'), 'maçtan sonra ana sayfa');

    binding.reportData = {'adimlar': adimlar, 'kullanici': kullanici, 'hamle': hamle};
  });
}
