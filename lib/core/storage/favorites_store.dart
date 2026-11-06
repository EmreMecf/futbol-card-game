import 'package:shared_preferences/shared_preferences.dart';

/// Favori kartlar — BU CİHAZDA saklanır.
///
/// ===================================================================
/// NEDEN SUNUCUDA DEĞİL?
/// ===================================================================
/// Favori, oyunun hiçbir kuralını etkilemeyen kişisel bir işaret
/// (ayarlardaki titreşim tercihi gibi). Sunucuya taşımak veritabanında
/// yeni bir tablo ve yeni bir uç nokta demekti; MD "gereksiz değişiklik
/// yapma" diyor. Bedeli: favoriler başka bir cihaza taşınmaz. Koleksiyon
/// ekranında bu açıkça yazıyor.
///
/// Sunucuya taşımak istenirse değişecek tek yer bu sınıf; ekranlar
/// sadece [isFavorite] / [toggle] kullanıyor.
///
/// ===================================================================
/// NEDEN `cardId`, NEDEN `userCardId` DEĞİL?
/// ===================================================================
/// `userCardId` elindeki o FİZİKSEL kopyanın kimliği. Maç kaybedip
/// kartı kaptırırsan ya da görevde eritirsen o kimlik yok olur; aynı
/// oyuncuyu tekrar kazandığında favori işareti gitmiş olurdu.
/// `cardId` ise katalogdaki oyuncunun kimliği ve hiç değişmez.
class FavoritesStore {
  static const _anahtar = 'favori_kartlar';

  /// Bir oyuncu en fazla bu kadar favori tutabilir. Sınırsız liste
  /// hem "favori" kavramını anlamsızlaştırır hem de cihaz deposunu
  /// gereksiz büyütür.
  static const int maxFavorites = 50;

  SharedPreferences? _depo;
  Set<String> _favoriler = {};

  Set<String> get ids => Set.unmodifiable(_favoriler);

  /// Disk bir kez okunur. Koleksiyon ekranı her açıldığında tekrar
  /// okumaya gerek yok: bu nesne tek örnek ve bütün değişiklikler
  /// zaten bellekte.
  Future<void>? _yukleme;

  Future<void> load() => _yukleme ??= _diskOku();

  Future<void> _diskOku() async {
    try {
      _depo ??= await SharedPreferences.getInstance();
      _favoriler = (_depo?.getStringList(_anahtar) ?? const []).toSet();
    } catch (_) {
      // Depo açılamadıysa favorisiz devam: koleksiyon yine çalışmalı
      _favoriler = {};
    }
  }

  bool isFavorite(String cardId) => _favoriler.contains(cardId);

  /// Favoriyi açar/kapatır. Yeni durumu döner.
  ///
  /// Sınıra ulaşıldıysa yeni favori EKLENMEZ ve `false` döner;
  /// çağıran taraf oyuncuya nedenini söylemeli.
  Future<bool> toggle(String cardId) async {
    // YARIŞ DURUMU: Disk okuması bitmeden değişiklik yapılırsa, okuma
    // bitince diskteki ESKİ liste yeni favorinin üstüne yazılır ve
    // favori kaybolurdu. Önce yüklemenin bitmesini bekliyoruz.
    await load();

    if (_favoriler.contains(cardId)) {
      _favoriler.remove(cardId);
    } else {
      if (_favoriler.length >= maxFavorites) return false;
      _favoriler.add(cardId);
    }
    try {
      await _depo?.setStringList(_anahtar, _favoriler.toList());
    } catch (_) {
      // Diske yazılamadı; oturum boyunca yine geçerli
    }
    return _favoriler.contains(cardId);
  }

  bool get isFull => _favoriler.length >= maxFavorites;
}
