import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/storage/favorites_store.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/collection/domain/repositories/collection_repository.dart';
import 'package:futbol_card/features/collection/presentation/viewmodel/collection_view_model.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FAZ 3 — Koleksiyonda favori sistemi (MD bölüm 4-F).
///
/// Favoriler BU CİHAZDA saklanıyor ve katalog kimliğine (cardId)
/// bağlı. Bu testler özellikle şunu kilitliyor: kartı kaptırıp aynı
/// oyuncuyu tekrar kazandığında favori işareti GİTMEMELİ.
void main() {
  InventoryCard kart(String userCardId, String cardId, String ad,
          {CardPosition p = CardPosition.forward, int guc = 70}) =>
      InventoryCard(
        userCardId: userCardId,
        cardId: cardId,
        fullName: ad,
        position: p,
        tier: CardTier.gold,
        power: guc,
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FavoritesStore', () {
    test('favori diske yazılır ve yeni açılışta geri okunur', () async {
      final ilk = FavoritesStore();
      await ilk.load();
      await ilk.toggle('c-messi');

      final ikinci = FavoritesStore();
      await ikinci.load();
      expect(ikinci.isFavorite('c-messi'), isTrue);
    });

    test('YARIŞ: yükleme bitmeden basılan favori KAYBOLMAZ', () async {
      // Disk okuması bitmeden kalbe basılırsa, okuma bitince eski liste
      // yeni favorinin üstüne yazılıyordu.
      SharedPreferences.setMockInitialValues({
        'favori_kartlar': ['c-eski'],
      });
      final d = FavoritesStore();
      final yukleme = d.load(); // beklenmiyor
      await d.toggle('c-yeni');
      await yukleme;

      expect(d.isFavorite('c-yeni'), isTrue);
      expect(d.isFavorite('c-eski'), isTrue);
    });

    test('ikinci basış favoriden çıkarır', () async {
      final d = FavoritesStore();
      await d.load();
      expect(await d.toggle('c1'), isTrue);
      expect(await d.toggle('c1'), isFalse);
      expect(d.isFavorite('c1'), isFalse);
    });

    test('sınırda yeni favori EKLENMEZ, mevcut çıkarılabilir', () async {
      SharedPreferences.setMockInitialValues({
        'favori_kartlar': [
          for (var i = 0; i < FavoritesStore.maxFavorites; i++) 'c$i',
        ],
      });
      final d = FavoritesStore();
      await d.load();

      expect(d.isFull, isTrue);
      expect(await d.toggle('yeni'), isFalse);
      expect(d.isFavorite('yeni'), isFalse);

      // Çıkarmak sınırdayken de çalışmalı
      await d.toggle('c0');
      expect(d.isFavorite('c0'), isFalse);
    });
  });

  group('CollectionViewModel favorileri', () {
    late _SahteRepo repo;
    late FavoritesStore depo;
    late CollectionViewModel vm;

    setUp(() async {
      repo = _SahteRepo([
        kart('u1', 'c-yildiz', 'Kuzey Yıldızı', guc: 96),
        kart('u2', 'c-genc', 'Genç Yetenek', guc: 60),
        kart('u3', 'c-ismail', 'İsmail Kaya', p: CardPosition.defender),
      ]);
      depo = FavoritesStore();
      vm = CollectionViewModel(repo, depo);
      await vm.load();
    });

    test('favori ekle ve "sadece favoriler" filtresi', () async {
      await vm.toggleFavorite(repo.kartlar[0]);

      expect(vm.isFavorite(repo.kartlar[0]), isTrue);
      expect(vm.favoriteCount, 1);

      vm.setFavoritesOnly(true);
      expect(vm.filteredCards.map((k) => k.fullName), ['Kuzey Yıldızı']);
      expect(vm.hasActiveFilter, isTrue);

      vm.clearFilters();
      expect(vm.favoritesOnly, isFalse);
      expect(vm.filteredCards, hasLength(3));
    });

    test('KAPTIRILIP TEKRAR KAZANILAN kart favori kalır (cardId bağlı)',
        () async {
      await vm.toggleFavorite(repo.kartlar[0]);

      // Maçta kaptırıldı: koleksiyondan çıktı
      repo.kartlar = [repo.kartlar[1], repo.kartlar[2]];
      await vm.load(showLoading: false);
      expect(vm.favoriteCount, 0, reason: 'Elde yoksa sayılmaz');

      // Aynı oyuncu başka bir maçta YENİ bir kopya olarak geri geldi:
      // userCardId farklı, cardId aynı
      repo.kartlar = [...repo.kartlar, kart('u99', 'c-yildiz', 'Kuzey Yıldızı')];
      await vm.load(showLoading: false);

      expect(vm.isFavorite(repo.kartlar.last), isTrue);
      expect(vm.favoriteCount, 1);
    });

    test('sınıra takılınca toggleFavorite false döner', () async {
      SharedPreferences.setMockInitialValues({
        'favori_kartlar': [
          for (var i = 0; i < FavoritesStore.maxFavorites; i++) 'x$i',
        ],
      });
      final dolu = FavoritesStore();
      final vm2 = CollectionViewModel(repo, dolu);
      await vm2.load();

      expect(await vm2.toggleFavorite(repo.kartlar[0]), isFalse);
      expect(vm2.isFavorite(repo.kartlar[0]), isFalse);
    });
  });

  group('Türkçe düzeltmeler', () {
    test('"İsmail" araması Türkçe büyük İ ile eşleşir', () async {
      final vm = CollectionViewModel(
        _SahteRepo([kart('u3', 'c3', 'İsmail Kaya')]),
        FavoritesStore(),
      );
      await vm.load();

      vm.setSearch('ismail');
      expect(vm.filteredCards, hasLength(1),
          reason: "toLowerCase() 'İ'yi 'i̇' (birleşik nokta) yapıyordu");

      vm.setSearch('İSMAİL');
      expect(vm.filteredCards, hasLength(1));
    });

    test('sıralama etiketleri Türkçe karakterli', () {
      expect(CollectionSort.powerDesc.label, contains('Güce göre'));
      expect(CollectionSort.nameAsc.label, 'İsme göre');
    });
  });
}

class _SahteRepo implements CollectionRepository {
  List<InventoryCard> kartlar;

  _SahteRepo(this.kartlar);

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async =>
      Success(kartlar);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Bu test için gerekmiyor');
}
