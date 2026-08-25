import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';

import '../../domain/reveal_style.dart';

/// Paket açılış SIRASININ beyni.
///
/// -------------------------------------------------------------------
/// NE YAPAR, NE YAPMAZ?
/// -------------------------------------------------------------------
/// YAPAR : Hangi kartın sırada olduğunu, o kartın hangi kademede
///         açılacağını ve walkout hakkının kullanılıp kullanılmadığını
///         bilir.
/// YAPMAZ: Hiçbir animasyon çalıştırmaz, hiçbir Widget tanımaz.
///
/// Bu ayrım kasıtlı: "hangi animasyon oynayacak?" kararı SAF MANTIK
/// olduğu için widget kurmadan test edilebiliyor. Animasyonu test
/// etmek zordur; kararı test etmek kolaydır ve asıl hata yapılacak
/// yer de karar tarafıdır.
///
/// -------------------------------------------------------------------
/// SIRALAMA: NEDEN TERSTEN?
/// -------------------------------------------------------------------
/// Sunucu kartları EN İYİDEN kötüye sıralı gönderiyor. Biz tersine
/// çevirip açıyoruz; böylece paketin en iyi kartı EN SONA kalıyor.
/// Gerilim sona doğru artıyor — iyi kartı ilk saniyede görüp geri
/// kalan 14 kartı sıkılarak geçmek yerine.
class PackOpeningViewModel extends ChangeNotifier {
  final PackOpenResult result;

  /// Kartlar açılış sırasında (kötüden iyiye)
  late final List<InventoryCard> _sira = result.cards.reversed.toList();

  int _acilan = 0;

  /// Walkout paket başına SADECE BİR KEZ oynar.
  ///
  /// Pakette iki Legend çıkarsa ikisi için de 4.5 saniyelik sahneyi
  /// oynatmak, ikinci seferde heyecan değil sabırsızlık üretir.
  /// Hak, listedeki en iyi karta ayrılmıştır; diğer nadir kartlar
  /// "altın" kademesinde ama nadir rozetiyle açılır.
  bool _walkoutKullanildi = false;

  PackOpeningViewModel(this.result);

  // ------------------------------------------------------------------
  // DURUM
  // ------------------------------------------------------------------
  List<InventoryCard> get queue => List.unmodifiable(_sira);

  int get revealedCount => _acilan;
  int get totalCount => _sira.length;

  bool get isFinished => _acilan >= _sira.length;

  /// Şu an ekranda olan kart (hepsi açıldıysa null)
  InventoryCard? get currentCard =>
      _acilan < _sira.length ? _sira[_acilan] : null;

  /// "3 / 15" gibi ilerleme metni
  String get progressText => '${_acilan + 1} / ${_sira.length}';

  /// Paketin EN İYİ kartı (walkout hakkı bunun)
  InventoryCard? get bestCard => result.bestCard;

  /// Paketin genel kademesi — mağaza ekranında "bu pakette ne çıktı?"
  /// özetini renklendirmek için.
  RevealStyle get packStyle {
    final enIyi = bestCard;
    if (enIyi == null) return RevealStyle.simple;
    return RevealStyle.forTier(enIyi.tier);
  }

  // ------------------------------------------------------------------
  // KARAR: BU KART NASIL AÇILACAK?
  // ------------------------------------------------------------------
  /// [kart] için açılış kademesini döner.
  ///
  /// Walkout iki şartı birden ister:
  ///   1. Kart Diamond ya da Legend olmalı,
  ///   2. Paketin EN İYİ kartı olmalı (hak henüz kullanılmamış olmalı).
  ///
  /// İkinci şart olmasaydı 5 Diamond'lık bir pakette oyuncu 22 saniye
  /// aynı sahneyi izlerdi.
  RevealStyle styleFor(InventoryCard kart) {
    final ham = RevealStyle.forTier(kart.tier);

    if (ham.isWalkout) {
      final hakSahibi = bestCard?.userCardId == kart.userCardId;
      if (hakSahibi && !_walkoutKullanildi) return RevealStyle.walkout;

      // Nadir ama walkout hakkı yok -> güçlü ama kısa açılış
      return RevealStyle.golden;
    }

    return ham;
  }

  /// Sıradaki kartın kademesi
  RevealStyle get currentStyle {
    final kart = currentCard;
    return kart == null ? RevealStyle.simple : styleFor(kart);
  }

  // ------------------------------------------------------------------
  // İLERLEME
  // ------------------------------------------------------------------
  /// Walkout sahnesi başladığında çağrılır; hakkı harcar.
  ///
  /// Neden [next] içinde değil? Oyuncu sahneyi atlarsa bile hak
  /// harcanmış olmalı; yoksa aynı kart için sahne tekrar tetiklenebilir.
  void markWalkoutPlayed() {
    if (_walkoutKullanildi) return;
    _walkoutKullanildi = true;
    // Görsel bir değişiklik olmadığı için notifyListeners YOK:
    // sahne devam ederken gereksiz bir yeniden çizim maliyeti olurdu.
  }

  bool get walkoutUsed => _walkoutKullanildi;

  /// Bir sonraki karta geç
  void next() {
    if (isFinished) return;
    _acilan++;
    notifyListeners();
  }

  /// Kalanları atla, doğrudan özet ekranına git
  void revealAll() {
    if (isFinished) return;
    _acilan = _sira.length;
    notifyListeners();
  }
}
