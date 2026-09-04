import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:futbol_card/features/leaderboard/presentation/viewmodel/leaderboard_view_model.dart';
import 'package:futbol_card/features/leaderboard/presentation/widgets/rank_badge.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_models/shared_models.dart';

/// Lig sistemi ve liderlik tablosu.
///
/// Buradaki testler "güzel görünüyor mu" diye sormaz; oyuncuyu
/// YANILTACAK davranışları kilitler. Bir oyuncuya yanlış lig ya da
/// yanlış sıra göstermek, ödül olarak sunulan bir şeyi bozmak demek.
void main() {
  PlayerRank rutbe({
    int mmr = 1000,
    int tierId = 1,
    String lig = 'Amatör',
    int seviye = 1,
    int taban = 1000,
    int? tavan = 1100,
    String? sonrakiLig = 'Amatör',
    int? sonrakiSeviye = 2,
    double ilerleme = 0,
    bool enUst = false,
  }) {
    return PlayerRank(
      mmr: mmr,
      tierId: tierId,
      leagueCode: 'amateur',
      leagueName: lig,
      division: seviye,
      color: '#7C8DA6',
      tierMinMmr: taban,
      nextTierMmr: tavan,
      nextLeagueName: sonrakiLig,
      nextDivision: sonrakiSeviye,
      progress: ilerleme,
      isTopTier: enUst,
    );
  }

  LeaderboardEntry kayit({
    int sira = 1,
    String id = 'u1',
    String ad = 'Oyuncu',
    int mmr = 1000,
    int g = 0,
    int m = 0,
    int b = 0,
    String lig = 'Amatör',
    int seviye = 1,
  }) {
    return LeaderboardEntry(
      rankPosition: sira,
      userId: id,
      username: ad,
      mmr: mmr,
      wins: g,
      losses: m,
      draws: b,
      leagueName: lig,
      division: seviye,
      color: '#7C8DA6',
    );
  }

  // ==================================================================
  // RÜTBE MODELİ
  // ==================================================================
  group('PlayerRank', () {
    test('etiket lig adı ve seviyeyi birleştirir', () {
      expect(rutbe(lig: 'Usta', seviye: 2).label, 'Usta 2');
      expect(rutbe(lig: 'Master Class', seviye: 3).label, 'Master Class 3');
    });

    test('sıradaki basamağın adı yazılır', () {
      final r = rutbe(sonrakiLig: 'Usta', sonrakiSeviye: 1);
      expect(r.nextLabel, 'Usta 1');
    });

    test('EN ÜST basamakta sıradaki basamak YOK', () {
      // "Sıradaki: null 1" gibi bir metin yazılmamalı.
      final r = rutbe(enUst: true, tavan: null, sonrakiLig: null,
          sonrakiSeviye: null);

      expect(r.nextLabel, isNull);
      expect(r.pointsToNext, isNull);
      expect(r.winsToNext, isNull);
    });

    test('yükselmek için gereken puan hesaplanır', () {
      final r = rutbe(mmr: 1025, tavan: 1100);
      expect(r.pointsToNext, 75);
    });

    test('puan hedefi GEÇİLMİŞSE negatif gösterilmez', () {
      // Eşik düşürülürse oyuncunun puanı hedefin üstünde kalabilir.
      // "-50 puan kaldı" yazmak saçma olurdu.
      final r = rutbe(mmr: 1150, tavan: 1100);
      expect(r.pointsToNext, 0);
      expect(r.winsToNext, 0);
    });

    test('galibiyet hedefi YUKARI yuvarlanır', () {
      // Bir maç 25 puan. 75 puan tam 3 galibiyet.
      expect(rutbe(mmr: 1025, tavan: 1100).winsToNext, 3);

      // 76 puan 3 galibiyetle KAPANMAZ; 4 gerekir.
      // Aşağı yuvarlansaydı oyuncu 3 galibiyet alıp yükselememiş
      // olurdu ve uygulama ona yalan söylemiş olurdu.
      expect(rutbe(mmr: 1024, tavan: 1100).winsToNext, 4);
    });

    test('JSON alan adları sunucununkiyle eşleşir', () {
      final json = {
        'mmr': 1425,
        'tier_id': 5,
        'league_code': 'usta',
        'league_name': 'Usta',
        'division': 2,
        'color': '#2DD4BF',
        'tier_min_mmr': 1400,
        'next_tier_mmr': 1500,
        'next_league_name': 'Usta',
        'next_division': 3,
        'progress': 0.25,
        'is_top_tier': false,
      };

      final r = PlayerRank.fromJson(json);

      expect(r.label, 'Usta 2');
      expect(r.nextLabel, 'Usta 3');
      expect(r.pointsToNext, 75);
      expect(r.progress, closeTo(0.25, 0.001));
    });
  });

  // ==================================================================
  // LİDERLİK SATIRI
  // ==================================================================
  group('LeaderboardEntry', () {
    test('ilk üç madalya alır, dördüncü almaz', () {
      expect(kayit(sira: 1).medal, 1);
      expect(kayit(sira: 3).medal, 3);
      expect(kayit(sira: 4).medal, isNull);
      expect(kayit(sira: 250).medal, isNull);
    });

    test('kazanma oranı SIFIRA BÖLÜNMEZ', () {
      expect(kayit().winRate, 0);
      expect(kayit().winRate.isNaN, isFalse);
    });

    test('kazanma oranı doğru hesaplanır', () {
      expect(kayit(g: 6, m: 3, b: 1).winRate, closeTo(0.6, 0.001));
    });

    test('JSON alan adları sunucununkiyle eşleşir', () {
      // Sunucu 'position' yerine 'rank_position' kullaniyor
      // (position PostgreSQL'de ayrilmis kelime).
      final json = {
        'rank_position': 7,
        'user_id': 'abc',
        'username': 'Kaan_07',
        'mmr': 1240,
        'wins': 12,
        'losses': 5,
        'draws': 1,
        'league_name': 'Amatör',
        'division': 3,
        'color': '#7C8DA6',
      };

      final e = LeaderboardEntry.fromJson(json);

      expect(e.rankPosition, 7);
      expect(e.username, 'Kaan_07');
      expect(e.rankLabel, 'Amatör 3');
      expect(e.totalMatches, 18);
    });
  });

  // ==================================================================
  // RENK ÇÖZÜMLEME
  // ==================================================================
  group('leagueColor', () {
    test('altı haneli hex çözülür', () {
      expect(leagueColor('#2DD4BF'), const Color(0xFF2DD4BF));
      expect(leagueColor('2DD4BF'), const Color(0xFF2DD4BF));
    });

    test('BOZUK renk ekranı ÇÖKERTMEZ', () {
      // Renk veritabanından geliyor. Yanlış yazılmış bir değer
      // yüzünden liderlik tablosunun açılmaması kabul edilemez.
      expect(() => leagueColor('kirmizi'), returnsNormally);
      expect(() => leagueColor(''), returnsNormally);
      expect(() => leagueColor('#XYZ'), returnsNormally);
    });
  });

  // ==================================================================
  // VIEWMODEL
  // ==================================================================
  group('LeaderboardViewModel', () {
    late _SahteLigRepo repo;
    late SessionManager oturum;
    late LeaderboardViewModel vm;

    setUp(() {
      repo = _SahteLigRepo();
      oturum = SessionManager(TokenStorage(_BellektekiDepo()));
      vm = LeaderboardViewModel(repo, oturum);
    });

    test('liste ve rütbe birlikte yüklenir', () async {
      repo.tablo = Leaderboard(
        entries: [kayit(sira: 1, ad: 'A'), kayit(sira: 2, ad: 'B')],
        myPosition: 2,
        amIInList: true,
      );
      repo.rutbe = rutbe();

      await vm.initialize();

      expect(vm.entries.length, 2);
      expect(vm.myPosition, 2);
      expect(vm.myRank, isNotNull);
    });

    test('rütbe hatası LİSTEYİ engellemez', () async {
      // Rozet yüklenemedi diye sıralamayı gizlemek, oyuncuya
      // hiçbir şey göstermemek olurdu.
      repo.tablo = Leaderboard(entries: [kayit()], myPosition: 1);
      repo.rutbeHatasi = 'Rutbe alinamadi';

      await vm.initialize();

      expect(vm.entries.length, 1);
      expect(vm.myRank, isNull);
    });

    test('liste hatasında eski liste korunur', () async {
      repo.tablo = Leaderboard(entries: [kayit()]);
      await vm.loadLeaderboard();
      expect(vm.entries.length, 1);

      repo.tabloHatasi = 'Sunucuya ulasilamadi';
      await vm.loadLeaderboard();

      // Bir ag hatasi yuzunden siralamayi silmek, oyuncuya "kimse
      // yok" demek olurdu.
      expect(vm.entries.length, 1);
      expect(vm.hasError, isTrue);
    });

    test('boş sıralama hata değildir', () async {
      repo.tablo = const Leaderboard();
      await vm.loadLeaderboard();

      expect(vm.entries, isEmpty);
      expect(vm.hasError, isFalse);
    });
  });

  // ==================================================================
  // BASAMAK GRUPLAMA
  // ==================================================================
  group('LeagueGroup', () {
    LeagueTier bas(int id, String kod, String ad, int seviye, int mmr) =>
        LeagueTier(
          tierId: id,
          leagueCode: kod,
          leagueName: ad,
          division: seviye,
          minMmr: mmr,
          color: '#7C8DA6',
        );

    final hepsi = [
      bas(1, 'amateur', 'Amatör', 1, 1000),
      bas(2, 'amateur', 'Amatör', 2, 1100),
      bas(3, 'amateur', 'Amatör', 3, 1200),
      bas(4, 'usta', 'Usta', 1, 1300),
      bas(5, 'usta', 'Usta', 2, 1400),
      bas(6, 'usta', 'Usta', 3, 1500),
    ];

    test('basamaklar lige göre gruplanır', () {
      final gruplar = LeagueGroup.fromTiers(hepsi);

      expect(gruplar.length, 2);
      expect(gruplar[0].name, 'Amatör');
      expect(gruplar[1].name, 'Usta');
      expect(gruplar[0].tiers.length, 3);
    });

    test('lig SIRASI korunur', () {
      // Sunucu basamaklari id sirasinda gonderiyor. Gruplama bunu
      // bozarsa Usta, Amatör'un ustunde gorunurdu.
      final gruplar = LeagueGroup.fromTiers(hepsi);
      expect(gruplar.map((g) => g.code).toList(), ['amateur', 'usta']);
    });

    test('seviyeler kendi icinde 1-2-3 sirali', () {
      // Karisik gelirse bile duzelmeli
      final karisik = [hepsi[2], hepsi[0], hepsi[1]];
      final gruplar = LeagueGroup.fromTiers(karisik);

      expect(gruplar.single.tiers.map((t) => t.division).toList(), [1, 2, 3]);
    });

    test('ligin giris puani en dusuk seviyeninki', () {
      final gruplar = LeagueGroup.fromTiers(hepsi);
      expect(gruplar[0].minMmr, 1000);
      expect(gruplar[1].minMmr, 1300);
    });

    test('bos liste cokmez', () {
      expect(LeagueGroup.fromTiers(const []), isEmpty);
    });

    test('JSON alan adlari sunucununkiyle eslesir', () {
      final json = {
        'tier_id': 7,
        'league_code': 'master',
        'league_name': 'Master',
        'division': 1,
        'min_mmr': 1625,
        'color': '#F97316',
      };

      final t = LeagueTier.fromJson(json);

      expect(t.tierId, 7);
      expect(t.label, 'Master 1');
      expect(t.minMmr, 1625);
    });
  });

  // ==================================================================
  // ROZET ÇİZİMİ
  // ==================================================================
  group('RankBadge', () {
    Widget sar(Widget cocuk) => MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: Center(child: cocuk)),
        );

    testWidgets('seviye numarası rozetin içinde yazar', (tester) async {
      await tester.pumpWidget(sar(
        RankBadge.fromRank(rutbe(lig: 'Usta', seviye: 2)),
      ));

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('etiketli halde lig adı da yazar', (tester) async {
      await tester.pumpWidget(sar(
        RankBadge.fromRank(rutbe(lig: 'Master Class', seviye: 3),
            showLabel: true),
      ));

      expect(find.text('Master Class'), findsOneWidget);
      expect(find.text('Seviye 3'), findsOneWidget);
    });

    testWidgets('rütbe kartı hedefi GALİBİYET olarak yazar',
        (tester) async {
      await tester.pumpWidget(sar(
        RankProgressCard(rank: rutbe(mmr: 1025, tavan: 1100)),
      ));

      expect(find.text('Yükselmek için 3 galibiyet'), findsOneWidget);
    });

    testWidgets('EN ÜST basamakta ilerleme çubuğu yerine mesaj çıkar',
        (tester) async {
      await tester.pumpWidget(sar(
        RankProgressCard(
          rank: rutbe(
            lig: 'Master Class',
            seviye: 3,
            enUst: true,
            tavan: null,
            sonrakiLig: null,
            sonrakiSeviye: null,
          ),
        ),
      ));

      expect(find.textContaining('En üst basamaktasın'), findsOneWidget);
      expect(find.textContaining('Yükselmek için'), findsNothing);
    });

    testWidgets('sıra rozeti verilirse gösterilir', (tester) async {
      await tester.pumpWidget(sar(
        RankProgressCard(rank: rutbe(), position: 42),
      ));

      expect(find.text('#42'), findsOneWidget);
    });
  });
}

// ====================================================================
// SAHTE BAĞIMLILIKLAR
// ====================================================================

class _SahteLigRepo implements LeaderboardRepository {
  Leaderboard tablo = const Leaderboard();
  PlayerRank? rutbe;
  String? tabloHatasi;
  String? rutbeHatasi;

  @override
  Future<Result<Leaderboard>> fetchLeaderboard({
    int limit = 50,
    int offset = 0,
  }) async {
    final h = tabloHatasi;
    if (h != null) return Failure(AppException(message: h));
    return Success(tablo);
  }

  /// Lig basamaklarinin tanimi. Ligler tanitim ekrani kullaniyor.
  List<LeagueTier> basamaklar = const [];
  String? basamakHatasi;

  @override
  Future<Result<List<LeagueTier>>> fetchTiers() async {
    final h = basamakHatasi;
    if (h != null) return Failure(AppException(message: h));
    return Success(basamaklar);
  }

  @override
  Future<Result<PlayerRank>> fetchMyRank() async {
    final h = rutbeHatasi;
    if (h != null) return Failure(AppException(message: h));
    final r = rutbe;
    if (r == null) {
      return const Failure(AppException(message: 'Rutbe yok'));
    }
    return Success(r);
  }
}

class _BellektekiDepo implements FlutterSecureStorage {
  final Map<String, String> _veri = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _veri[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _veri.remove(key);
    } else {
      _veri[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _veri.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Bu test icin gerekmiyor');
}
