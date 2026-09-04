import 'package:get_it/get_it.dart';
import 'package:shared_models/shared_models.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/viewmodel/auth_view_model.dart';
import '../../features/collection/data/datasources/collection_remote_datasource.dart';
import '../../features/collection/data/repositories/collection_repository_impl.dart';
import '../../features/collection/domain/repositories/collection_repository.dart';
import '../../features/collection/presentation/viewmodel/collection_view_model.dart';
import '../../features/deck/data/datasources/deck_remote_datasource.dart';
import '../../features/deck/data/repositories/deck_repository_impl.dart';
import '../../features/deck/domain/repositories/deck_repository.dart';
import '../../features/deck/presentation/viewmodel/deck_view_model.dart';
import '../../features/match/data/datasources/match_remote_datasource.dart';
import '../../features/match/data/repositories/match_repository_impl.dart';
import '../../features/match/domain/repositories/match_repository.dart';
import '../../features/match/presentation/viewmodel/match_view_model.dart';
import '../../features/matchmaking/data/datasources/matchmaking_remote_datasource.dart';
import '../../features/matchmaking/data/repositories/matchmaking_repository_impl.dart';
import '../../features/matchmaking/domain/repositories/matchmaking_repository.dart';
import '../../features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import '../../features/sbc/data/datasources/sbc_remote_datasource.dart';
import '../../features/sbc/data/repositories/sbc_repository_impl.dart';
import '../../features/sbc/domain/repositories/sbc_repository.dart';
import '../../features/sbc/presentation/viewmodel/sbc_builder_view_model.dart';
import '../../features/sbc/presentation/viewmodel/sbc_list_view_model.dart';
import '../../features/store/data/datasources/store_remote_datasource.dart';
import '../../features/store/data/repositories/store_repository_impl.dart';
import '../../features/store/domain/repositories/store_repository.dart';
import '../../features/store/presentation/viewmodel/store_view_model.dart';
import '../auth/session_manager.dart';
import '../network/api_client.dart';
import '../network/websocket_service.dart';
import '../router/app_router.dart';
import '../storage/token_storage.dart';
import '../utils/logger.dart';
import '../../features/profile/presentation/viewmodel/profile_view_model.dart';
import '../../features/settings/presentation/viewmodel/settings_view_model.dart';

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
      () => WebSocketService(getIt<SessionManager>()),
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
    ..registerLazySingleton<SbcRepository>(
      () => SbcRepositoryImpl(getIt<SbcRemoteDataSource>()),
    );

  // ---------------- 6. VIEWMODEL'LER ----------------
  getIt
    ..registerFactory<AuthViewModel>(
      () => AuthViewModel(getIt<AuthRepository>()),
    )
    ..registerFactory<CollectionViewModel>(
      () => CollectionViewModel(getIt<CollectionRepository>()),
    )
    ..registerFactory<DeckViewModel>(
      () => DeckViewModel(getIt<DeckRepository>()),
    )
    ..registerFactory<StoreViewModel>(
      () => StoreViewModel(getIt<StoreRepository>(), getIt<SessionManager>()),
    )
    ..registerFactory<SbcListViewModel>(
      () => SbcListViewModel(getIt<SbcRepository>()),
    )
    // Gorev kadrosu kurma ekrani hangi gorev icin acildigini bilmeli
    ..registerFactoryParam<SbcBuilderViewModel, SbcChallenge, void>(
      (gorev, _) => SbcBuilderViewModel(getIt<SbcRepository>(), challenge: gorev),
    )
    ..registerFactory<ProfileViewModel>(
      () => ProfileViewModel(
        getIt<MatchRepository>(),
        getIt<AuthRepository>(),
        getIt<SessionManager>(),
      ),
    )
    // Ayarlar cihazda saklandigi icin repository'ye ihtiyaci yok.
    // Tek ornek yeterli: ayni tercihleri her ekran ayni anda gormeli.
    ..registerLazySingleton<SettingsViewModel>(() => SettingsViewModel())
    ..registerFactory<MatchmakingViewModel>(
      () => MatchmakingViewModel(
        getIt<MatchmakingRepository>(),
        getIt<WebSocketService>(),
        getIt<SessionManager>(),
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
