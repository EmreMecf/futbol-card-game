import 'package:get_it/get_it.dart';
import 'package:shared_models/shared_models.dart';

import '../../features/monetization/cosmetics/cosmetic_shop.dart';
import '../../features/monetization/purchase/purchase_controller.dart';
import '../../features/monetization/purchase/store_client.dart';
import '../../features/monetization/monetization_api.dart';
import '../../features/monetization/rewarded_ad_controller.dart';
import '../../features/monetization/rewarded_ad_provider.dart';
import '../../features/social/social_api.dart';
import '../../features/social/friend_challenge.dart';
import '../../features/chests/data/chest_repository_impl.dart';
import '../../features/chests/domain/chest_repository.dart';
import '../../features/chests/presentation/viewmodel/chests_view_model.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/social_auth_repository.dart';
import '../../features/auth/data/repositories/social_auth_repository_impl.dart';
import '../../features/auth/presentation/viewmodel/auth_view_model.dart';
import '../../features/collection/data/datasources/collection_remote_datasource.dart';
import '../../features/collection/data/repositories/collection_repository_impl.dart';
import '../../features/collection/domain/repositories/collection_repository.dart';
import '../../features/collection/presentation/viewmodel/collection_view_model.dart';
import '../../features/deck/data/datasources/deck_remote_datasource.dart';
import '../../features/deck/data/repositories/deck_repository_impl.dart';
import '../../features/deck/domain/repositories/deck_repository.dart';
import '../../features/deck/presentation/viewmodel/deck_view_model.dart';
import '../../features/items/cosmetics/equipped_cosmetics.dart';
import '../../features/match/data/datasources/match_remote_datasource.dart';
import '../../features/match/data/repositories/match_repository_impl.dart';
import '../../features/match/domain/repositories/match_repository.dart';
import '../../features/match/presentation/viewmodel/match_view_model.dart';
import '../../features/matchmaking/data/ranked_rules.dart';
import '../../features/matchmaking/data/datasources/matchmaking_remote_datasource.dart';
import '../../features/matchmaking/data/repositories/matchmaking_repository_impl.dart';
import '../../features/matchmaking/domain/repositories/matchmaking_repository.dart';
import '../../features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import '../../features/sbc/data/datasources/sbc_remote_datasource.dart';
import '../../features/sbc/data/repositories/sbc_repository_impl.dart';
import '../../features/sbc/domain/repositories/sbc_repository.dart';
import '../../features/sbc/presentation/viewmodel/sbc_builder_view_model.dart';
import '../../features/season/data/season_repository_impl.dart';
import '../../features/season/domain/season_repository.dart';
import '../../features/season/presentation/viewmodel/season_view_model.dart';
import '../../features/sbc/presentation/viewmodel/sbc_list_view_model.dart';
import '../../features/store/data/datasources/store_remote_datasource.dart';
import '../../features/store/data/repositories/store_repository_impl.dart';
import '../../features/store/domain/repositories/store_repository.dart';
import '../../features/store/presentation/viewmodel/store_view_model.dart';
import '../audio/game_audio.dart';
import '../auth/session_manager.dart';
import '../network/api_client.dart';
import '../network/websocket_service.dart';
import '../router/app_router.dart';
import '../storage/favorites_store.dart';
import '../storage/token_storage.dart';
import '../utils/logger.dart';
import '../../features/home/presentation/viewmodel/home_view_model.dart';
import '../../features/progress/data/progress_repository_impl.dart';
import '../../features/progress/domain/progress_repository.dart';
import '../../features/progress/presentation/viewmodel/progress_view_model.dart';
import '../../features/profile/presentation/viewmodel/profile_view_model.dart';
import '../../features/settings/presentation/viewmodel/settings_view_model.dart';
import '../../features/items/data/items_repository_impl.dart';
import '../../features/items/domain/items_repository.dart';
import '../../features/items/presentation/viewmodel/items_view_model.dart';
import '../../features/leaderboard/data/datasources/leaderboard_remote_datasource.dart';
import '../../features/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import '../../features/leaderboard/domain/repositories/leaderboard_repository.dart';
import '../../features/leaderboard/presentation/viewmodel/leaderboard_view_model.dart';
import '../../features/daily/data/daily_service.dart';
import '../../features/leaderboard/data/trophy_road.dart';
import '../../features/leaderboard/presentation/viewmodel/league_tiers_view_model.dart';

/// Uygulamanin servis konteyneri (Service Locator).
final GetIt getIt = GetIt.instance;

/// KAYIT TURLERI:
///   registerLazySingleton -> ilk istendiginde uretilir, sonra hep ayni ornek
///                            (servisler, repository'ler icin)
///   registerFactory       -> her istendiginde YENI ornek
///                            (ViewModel'ler icin; ekran kapaninca temizlensin)
///
/// SIRA ONEMLI: Bir servis baska bir servise bagimliysa, once bagimli
/// oldugu servis kaydedilmeli. Asagidaki sira bu kurala gore dizildi.
Future<void> configureDependencies() async {
  // ---------------- 1. DEPOLAMA VE OTURUM ----------------
  getIt
    ..registerLazySingleton<TokenStorage>(TokenStorage.new)
    // Favoriler tek örnek: koleksiyon ekranı her açıldığında diskten
    // yeniden okunmasın, ekranlar arası tutarlı kalsın.
    ..registerLazySingleton<FavoritesStore>(FavoritesStore.new)
    ..registerLazySingleton<SessionManager>(
      () => SessionManager(getIt<TokenStorage>()),
    );

  // ---------------- 2. AG ----------------
  getIt
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        getIt<SessionManager>(),
        onSessionExpired: () {
          AppLogger.warning('Oturum gecersiz, kullanici cikis yapiyor.');
          // SessionManager.clear() zaten dinleyicileri uyariyor;
          // AppRouter bunu gorup giris ekranina yonlendiriyor.
        },
      ),
    )
    ..registerLazySingleton<WebSocketService>(
      () => WebSocketService(
        getIt<SessionManager>(),
        // Suresi dolmus jetonla WebSocket 401 alir; once REST ile yenilenir
        refreshToken: () => getIt<ApiClient>().refreshSession(),
      ),
    );

  // ---------------- 3. YONLENDIRME ----------------
  getIt.registerLazySingleton<AppRouter>(
    () => AppRouter(getIt<SessionManager>()),
  );

  // ---------------- 4. VERI KAYNAKLARI ----------------
  getIt
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(getIt<ApiClient>()),
    )
    ..registerLazySingleton<CollectionRemoteDataSource>(
      () => CollectionRemoteDataSource(getIt<ApiClient>()),
    )
    ..registerLazySingleton<MatchmakingRemoteDataSource>(
      () => MatchmakingRemoteDataSource(getIt<ApiClient>()),
    )
    ..registerLazySingleton<MatchRemoteDataSource>(
      () => MatchRemoteDataSource(getIt<ApiClient>()),
    )
    ..registerLazySingleton<DeckRemoteDataSource>(
      () => DeckRemoteDataSource(getIt<ApiClient>()),
    )
    ..registerLazySingleton<StoreRemoteDataSource>(
      () => StoreRemoteDataSource(getIt<ApiClient>()),
    )
    ..registerLazySingleton<SbcRemoteDataSource>(
      () => SbcRemoteDataSource(getIt<ApiClient>()),
    );

  // ---------------- 5. REPOSITORY'LER ----------------
  getIt
    ..registerLazySingleton<SocialAuthRepository>(
      () => SocialAuthRepositoryImpl(
        getIt<AuthRemoteDataSource>(),
        getIt<SessionManager>(),
        getIt<WebSocketService>(),
      ),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        getIt<AuthRemoteDataSource>(),
        getIt<SessionManager>(),
        getIt<WebSocketService>(),
      ),
    )
    ..registerLazySingleton<CollectionRepository>(
      () => CollectionRepositoryImpl(getIt<CollectionRemoteDataSource>()),
    )
    ..registerLazySingleton<MatchmakingRepository>(
      () => MatchmakingRepositoryImpl(getIt<MatchmakingRemoteDataSource>()),
    )
    ..registerLazySingleton<MatchRepository>(
      () => MatchRepositoryImpl(getIt<MatchRemoteDataSource>()),
    )
    ..registerLazySingleton<DeckRepository>(
      () => DeckRepositoryImpl(getIt<DeckRemoteDataSource>()),
    )
    ..registerLazySingleton<StoreRepository>(
      () => StoreRepositoryImpl(getIt<StoreRemoteDataSource>()),
    )
    ..registerLazySingleton<LeaderboardRepository>(
      () => LeaderboardRepositoryImpl(
        LeaderboardRemoteDataSource(getIt<ApiClient>()),
      ),
    )
    ..registerLazySingleton<SbcRepository>(
      () => SbcRepositoryImpl(getIt<SbcRemoteDataSource>()),
    );

  // ---------------- 6. VIEWMODEL'LER ----------------
  getIt
    ..registerFactory<AuthViewModel>(
      () => AuthViewModel(getIt<AuthRepository>(), social: getIt<SocialAuthRepository>()),
    )
    ..registerFactory<CollectionViewModel>(
      () => CollectionViewModel(
        getIt<CollectionRepository>(),
        getIt<FavoritesStore>(),
      ),
    )
    ..registerFactory<DeckViewModel>(
      () => DeckViewModel(getIt<DeckRepository>()),
    )
    // 044: günlük döngü + günün teklifi (anahtarlar kapalıysa görünmez)
    ..registerLazySingleton<DailyLoopService>(() => DailyLoopService(getIt<ApiClient>()))
    ..registerFactory<StoreViewModel>(
      () => StoreViewModel(
        getIt<StoreRepository>(),
        getIt<SessionManager>(),
        dailyOffer: () => getIt<DailyLoopService>().shop(),
        buyDailyOffer: () => getIt<DailyLoopService>().buyOffer(),
      ),
    )
    ..registerFactory<SbcListViewModel>(
      () => SbcListViewModel(getIt<SbcRepository>()),
    )
    // Ekonomi V2 (FAZ 1): sandıklar, ödül enerjisi, acil kadro
    ..registerLazySingleton<ChestRepository>(
      () => ChestRepositoryImpl(getIt<ApiClient>()),
    )
    // Ekonomi V2 (FAZ 4): Battle Pass + görevler
    ..registerLazySingleton<SeasonRepository>(
      () => SeasonRepositoryImpl(getIt<ApiClient>()),
    )
    ..registerFactory<SeasonViewModel>(
      () => SeasonViewModel(getIt<SeasonRepository>()),
    )
    // Ekonomi V2 (FAZ 3): item envanteri
    ..registerLazySingleton<ItemsRepository>(
      () => ItemsRepositoryImpl(getIt<ApiClient>()),
    )
    ..registerFactory<ItemsViewModel>(
      () => ItemsViewModel(getIt<ItemsRepository>()),
    )
    // Ekonomi V2 (FAZ 6): giyilen kozmetikler (yalnız görsel)
    ..registerLazySingleton<EquippedCosmetics>(
      () => EquippedCosmetics(getIt<ItemsRepository>()),
    )
    // Ekonomi V2 (FAZ 2): futbolcu seviyesi
    ..registerLazySingleton<ProgressRepository>(
      () => ProgressRepositoryImpl(getIt<ApiClient>()),
    )
    ..registerFactory<ProgressViewModel>(
      () => ProgressViewModel(getIt<ProgressRepository>(),
          session: getIt<SessionManager>(), items: getIt<ItemsRepository>()),
    )
    ..registerFactory<ChestsViewModel>(
      () => ChestsViewModel(
        getIt<ChestRepository>(),
        socket: getIt<WebSocketService>(),
        session: getIt<SessionManager>(),
        items: getIt<ItemsRepository>(),
        gemApi: getIt<SocialApi>(),
      ),
    )
    // 056: arkadaşlık, açık profil, elmas, rakip kadrosu
    ..registerLazySingleton<SocialApi>(() => SocialApi(getIt<ApiClient>()))
    // 060: ödüllü reklam (sunucu ayarı kapalıyken hiçbir şey gösterilmez)
    ..registerLazySingleton<MonetizationApi>(() => MonetizationApi(getIt<ApiClient>()))
    // 061: satın alma (sunucu bayrağı + mağaza fiyatı yoksa görünmez)
    // 062: elmasla kozmetik mağaza (bayrak kapalıyken görünmez)
    ..registerLazySingleton<CosmeticShopApi>(() => CosmeticShopApi(getIt<ApiClient>()))
    ..registerFactory<CosmeticShopController>(
      () => CosmeticShopController(
        getIt<CosmeticShopApi>(),
        session: getIt<SessionManager>(),
        items: getIt<ItemsRepository>(),
      ),
    )
    ..registerLazySingleton<PurchaseApi>(() => PurchaseApi(getIt<ApiClient>()))
    ..registerFactory<PurchaseController>(
      () => PurchaseController(getIt<PurchaseApi>(), StoreClient.create(), session: getIt<SessionManager>()),
    )
    ..registerFactory<RewardedAdController>(
      () => RewardedAdController(getIt<MonetizationApi>(), RewardedAdProvider.create(), session: getIt<SessionManager>()),
    )
    // 058: arkadaşı dostluk maçına çağırma (ekranın üstündeki davet kutucuğu)
    ..registerLazySingleton<FriendChallengeController>(
      () => FriendChallengeController(
        getIt<SocialApi>(),
        events: getIt<WebSocketService>().events,
        connection: getIt<WebSocketService>().connectionState,
        isSignedIn: () => getIt<SessionManager>().isSignedIn,
        sessionChanges: getIt<SessionManager>(),
      ),
    )
    // Gorev kadrosu kurma ekrani hangi gorev icin acildigini bilmeli
    ..registerFactoryParam<SbcBuilderViewModel, SbcChallenge, void>(
      (gorev, _) => SbcBuilderViewModel(getIt<SbcRepository>(), challenge: gorev),
    )
    ..registerFactory<LeagueTiersViewModel>(
      () => LeagueTiersViewModel(
        getIt<LeaderboardRepository>(),
        // 043: kupa yolu (anahtar kapalıysa görünmez)
        trophyRoad: () => fetchTrophyRoad(getIt<ApiClient>()),
      ),
    )
    ..registerFactory<LeaderboardViewModel>(
      () => LeaderboardViewModel(
        getIt<LeaderboardRepository>(),
        getIt<SessionManager>(),
      ),
    )
    ..registerFactory<HomeViewModel>(
      () => HomeViewModel(
        getIt<LeaderboardRepository>(),
        getIt<MatchRepository>(),
        getIt<DeckRepository>(),
      ),
    )
    ..registerFactory<ProfileViewModel>(
      () => ProfileViewModel(
        getIt<MatchRepository>(),
        getIt<AuthRepository>(),
        getIt<LeaderboardRepository>(),
        getIt<SessionManager>(),
        collectionRepository: getIt<CollectionRepository>(),
        favorites: getIt<FavoritesStore>(),
      ),
    )
    // Ayarlar cihazda saklandigi icin repository'ye ihtiyaci yok.
    // Tek ornek yeterli: ayni tercihleri her ekran ayni anda gormeli.
    ..registerLazySingleton<SettingsViewModel>(() => SettingsViewModel())
    // Ses: ayarları okur; main() içinde init() ile dosyaları öğrenir
    ..registerLazySingleton<GameAudio>(() => GameAudio(getIt<SettingsViewModel>()))
    ..registerFactory<MatchmakingViewModel>(
      () => MatchmakingViewModel(
        getIt<MatchmakingRepository>(),
        getIt<WebSocketService>(),
        getIt<SessionManager>(),
        // Ekonomi V2 (037): yeni kurallarda koruma bölümü gizlenir
        cardLossEnabled: () => fetchRankedCardLossEnabled(getIt<ApiClient>()),
        // 041: antrenman düğmesi yalnız anahtar açıkken
        trainingEnabled: () => fetchTrainingEnabled(getIt<ApiClient>()),
        // 042: öğretici durumu (kapalıysa kart görünmez)
        tutorialStatus: () => fetchTutorialStatus(getIt<ApiClient>()),
      ),
    )
    // MatchViewModel mac kimligini parametre olarak alir.
    // registerFactoryParam sayesinde her mac icin ayri bir ornek
    // uretiliyor: getIt<MatchViewModel>(param1: macId)
    ..registerFactoryParam<MatchViewModel, String, void>(
      (macId, _) => MatchViewModel(
        getIt<MatchRepository>(),
        getIt<WebSocketService>(),
        getIt<SessionManager>(),
        matchId: macId,
      ),
    );

  AppLogger.info('Bagimliliklar kaydedildi.');
}
