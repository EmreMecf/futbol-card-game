import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/auth/session_manager.dart';
import '../../core/di/injection.dart';
import '../../core/router/app_routes.dart';
import '../../features/auth/presentation/viewmodel/auth_view_model.dart';
import '../../features/chests/presentation/viewmodel/chests_view_model.dart';
import '../../features/chests/domain/chest_texts.dart';
import '../../ui_v21/screens/deck/v21_emergency_banner.dart';
import '../../features/collection/presentation/viewmodel/collection_view_model.dart';
import '../../features/daily/data/daily_service.dart';
import '../../features/deck/presentation/viewmodel/deck_view_model.dart';
import '../../features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import '../../features/progress/presentation/viewmodel/progress_view_model.dart';
import '../../features/season/presentation/viewmodel/season_view_model.dart';
import '../../features/store/presentation/viewmodel/store_view_model.dart';
import '../../shared/widgets/error_snackbar.dart';
import '../ui_v21.dart';
import 'web_kit.dart';
import '../../core/l10n/app_language.dart';

// GENİŞ EKRAN (WEB) TASARIM EKRANLARI
//
// Her ekran kendi dosyasında (`part`): ortak yardımcılar ve özel (_) sınıflar
// tek kütüphane içinde kaldığı için ekranlar birbirinin parçalarını
// kullanmaya devam eder.
part 'web_home.dart';
part 'web_collection.dart';
part 'web_deck.dart';
part 'web_chests.dart';
part 'web_store.dart';
part 'web_progress.dart';
part 'web_ready.dart';
part 'web_friends.dart';
