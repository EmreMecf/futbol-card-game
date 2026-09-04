import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/storage/token_storage.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/auth/domain/repositories/auth_repository.dart';
import 'package:futbol_card/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:futbol_card/features/match/domain/repositories/match_repository.dart';
import 'package:futbol_card/features/profile/presentation/viewmodel/profile_view_model.dart';
import 'package:futbol_card/features/settings/presentation/viewmodel/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_models/shared_models.dart';

/// Profil ve Ayarlar ekranlarının mantığı.
///
/// Profilde gösterilen her sayı sunucudan geliyor; buradaki testler
/// o sayıların YANLIŞ hesaplanmadığını kilitliyor. Kazanma oranı gibi
/// tek bir bölme bile sıfıra bölme hatasıyla ekranı çökertebilir.
void main() {
  UserModel kullanici({
    int wins = 0,
    int losses = 0,
    int draws = 0,
    int coins = 0,
    int mmr = 1000,
    int protection = 3,
  }) {
    return UserModel(
      id: 'u1',
      username: 'TestOyuncu',
      wins: wins,
      losses: losses,
      draws: draws,
      coins: coins,
      mmr: mmr,
      protectionSlots: protection,
    );
  }

  MatchHistoryEntry mac({
    String rakip = 'Rakip',
    int benim = 0,
    int onun = 0,
    MatchOutcome sonuc = MatchOutcome.win,
    int alinan = 0,
    int kaptirilan = 0,
  }) {
    return MatchHistoryEntry(
      matchId: 'm-$rakip-$benim$onun',
      opponentId: 'o1',
      opponentUsername: rakip,
      myScore: benim,
      opponentScore: onun,
      outcome: sonuc,
      cardsWon: alinan,
      cardsLost: kaptirilan,
    );
  }

  // ==================================================================
  // MAÇ GEÇMİŞİ MODELİ
  // ==================================================================
  group('MatchHistoryEntry', () {
    test('skor metni iki sayıyı birleştirir', () {
      expect(mac(benim: 7, onun: 4).scoreText, '7 - 4');
    });

    test('kart alındıysa transfer metni onu söyler', () {
      expect(mac(alinan: 3).transferText, '3 kart aldın');
    });

    test('kart kaptırıldıysa transfer metni onu söyler', () {
      expect(mac(kaptirilan: 3).transferText, '3 kart kaptırdın');
    });

    test('kart el değiştirmediyse transfer metni YOK', () {
      // Beraberlikte ve korumanın tuttuğu maçlarda satırı hiç
      // çizmemek gerekiyor; boş bir metin yazmak gürültü olurdu.
      expect(mac().transferText, isNull);
      expect(mac().hadTransfers, isFalse);
    });

    test('sonuç etiketleri Türkçe', () {
      expect(MatchOutcome.win.shortLabel, 'Kazandın');
      expect(MatchOutcome.loss.shortLabel, 'Kaybettin');
      expect(MatchOutcome.draw.shortLabel, 'Berabere');
    });

    test('JSON alan adları sunucununkiyle eşleşir', () {
      // Sunucu snake_case gonderiyor. Bir alan adi tutmazsa ekran
      // sessizce sifir gosterir; bu test onu yakalar.
      final json = {
        'match_id': 'm1',
        'opponent_id': 'o1',
        'opponent_username': 'Kaan_07',
        'my_score': 7,
        'opponent_score': 4,
        'outcome': 'win',
        'cards_won': 3,
        'cards_lost': 0,
        'finished_at': '2026-09-04T08:34:37.000Z',
      };

      final e = MatchHistoryEntry.fromJson(json);

      expect(e.opponentUsername, 'Kaan_07');
      expect(e.myScore, 7);
      expect(e.outcome, MatchOutcome.win);
      expect(e.cardsWon, 3);
      expect(e.finishedAt, isNotNull);
    });
  });

  // ==================================================================
  // PROFİL VIEWMODEL
  // ==================================================================
  group('ProfileViewModel', () {
    late _SahteMatchRepo macRepo;
    late _SahteAuthRepo authRepo;
    late _SahteLigRepo ligRepo;
    late SessionManager oturum;
    late ProfileViewModel vm;

    setUp(() {
      macRepo = _SahteMatchRepo();
      authRepo = _SahteAuthRepo();
      ligRepo = _SahteLigRepo();
      // SessionManager cihaz deposunu ister; testte sahte depo yeterli.
      oturum = SessionManager(TokenStorage(_SahteGuvenliDepo()));
      vm = ProfileViewModel(macRepo, authRepo, ligRepo, oturum);
    });

    test('hiç maç yoksa kazanma oranı SIFIRA BÖLÜNMEZ', () {
      oturum.updateUser(kullanici());

      expect(vm.totalMatches, 0);
      expect(vm.winRate, 0);
      expect(vm.winRate.isNaN, isFalse);
    });

    test('kazanma oranı doğru hesaplanır', () {
      oturum.updateUser(kullanici(wins: 18, losses: 9, draws: 3));

      expect(vm.totalMatches, 30);
      expect(vm.winRate, closeTo(0.6, 0.001));
    });

    test('kullanıcı yoksa sayaçlar çökmez', () {
      expect(vm.totalMatches, 0);
      expect(vm.winRate, 0);
      expect(vm.user, isNull);
    });

    test('geçmiş yüklenir ve kart toplamları hesaplanır', () async {
      macRepo.gecmis = [
        mac(sonuc: MatchOutcome.win, alinan: 3),
        mac(sonuc: MatchOutcome.loss, kaptirilan: 3),
        mac(sonuc: MatchOutcome.win, alinan: 2),
      ];

      await vm.loadHistory();

      expect(vm.history.length, 3);
      expect(vm.cardsWonTotal, 5);
      expect(vm.cardsLostTotal, 3);
    });

    test('geçmiş hatası ekranı boşaltmaz', () async {
      macRepo.gecmis = [mac()];
      await vm.loadHistory();
      expect(vm.history.length, 1);

      // Ikinci cagri hata donsun
      macRepo.hata = 'Sunucuya ulasilamadi';
      await vm.loadHistory();

      // Eski liste KORUNUYOR: bir ag hatasi yuzunden oyuncunun
      // gecmisini silmek, ona veri kaybettigini dusundururdu.
      expect(vm.history.length, 1);
      expect(vm.hasError, isTrue);
    });

    test('boş geçmiş hata değildir', () async {
      macRepo.gecmis = const [];
      await vm.loadHistory();

      expect(vm.history, isEmpty);
      expect(vm.hasError, isFalse);
    });
  });

  // ==================================================================
  // AYARLAR VIEWMODEL
  // ==================================================================
  group('SettingsViewModel', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('varsayılanlar: ses ve titreşim açık, müzik kapalı', () async {
      final vm = SettingsViewModel();
      await vm.load();

      expect(vm.soundEffects, isTrue);
      expect(vm.vibration, isTrue);
      expect(vm.cardAnimations, isTrue);
      expect(vm.turnWarning, isTrue);
      expect(vm.music, isFalse);
    });

    test('değişiklik ANINDA yansır (diski beklemez)', () async {
      final vm = SettingsViewModel();
      await vm.load();

      // await edilmeden once bile deger degismis olmali; aksi halde
      // anahtarin hareketi disk yazimini bekliyormus gibi takilirdi.
      final future = vm.setMusic(true);
      expect(vm.music, isTrue);
      await future;
    });

    test('ayarlar diske yazılır ve geri okunur', () async {
      final vm = SettingsViewModel();
      await vm.load();
      await vm.setSoundEffects(false);
      await vm.setMusic(true);

      final yeni = SettingsViewModel();
      await yeni.load();

      expect(yeni.soundEffects, isFalse);
      expect(yeni.music, isTrue);
    });

    test('kayıtlı değerler varsayılanı ezer', () async {
      SharedPreferences.setMockInitialValues({
        'ayar_titresim': false,
        'ayar_kart_animasyonlari': false,
      });

      final vm = SettingsViewModel();
      await vm.load();

      expect(vm.vibration, isFalse);
      expect(vm.cardAnimations, isFalse);
      // Kaydedilmemis olan varsayilaninda kalir
      expect(vm.soundEffects, isTrue);
    });

    test('yükleme bittiğini bildirir', () async {
      final vm = SettingsViewModel();
      expect(vm.isLoaded, isFalse);
      await vm.load();
      expect(vm.isLoaded, isTrue);
    });

    test('dinleyiciler her değişimde uyarılır', () async {
      final vm = SettingsViewModel();
      await vm.load();

      var sayac = 0;
      vm.addListener(() => sayac++);

      await vm.setMusic(true);
      await vm.setVibration(false);

      expect(sayac, 2);
    });
  });
}

// ====================================================================
// SAHTE BAĞIMLILIKLAR
// ====================================================================

class _SahteMatchRepo implements MatchRepository {
  List<MatchHistoryEntry> gecmis = const [];
  String? hata;

  @override
  Future<Result<List<MatchHistoryEntry>>> fetchMatchHistoryList({
    int limit = 20,
    int offset = 0,
  }) async {
    final h = hata;
    if (h != null) return Failure(AppException(message: h));
    return Success(gecmis);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Bu test icin gerekmiyor');
}

class _SahteLigRepo implements LeaderboardRepository {
  PlayerRank? rutbe;

  @override
  Future<Result<PlayerRank>> fetchMyRank() async {
    final r = rutbe;
    if (r == null) return const Failure(AppException(message: 'Yok'));
    return Success(r);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Bu test icin gerekmiyor');
}

class _SahteAuthRepo implements AuthRepository {
  @override
  Future<Result<MeResponse>> fetchProfile() async =>
      const Failure(AppException(message: 'Test'));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Bu test icin gerekmiyor');
}

/// Testte gercek cihaz deposuna dokunmuyoruz: FlutterSecureStorage
/// bir platform kanali kullanir ve birim testinde calismaz.
class _SahteGuvenliDepo implements FlutterSecureStorage {
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
