// Ayarlar → BAĞLI HESAPLAR: Google/Apple yalnız giriş yapmış oyuncunun
// hesabına, oyuncunun kendi isteğiyle bağlanır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/auth/domain/repositories/social_auth_repository.dart';
import 'package:futbol_card/features/auth/presentation/widgets/social_links_panel.dart';

class _Baglayici implements SocialAuthRepository {
  final bagli = <SocialProvider>{};
  final baglananlar = <SocialCredential>[];
  Result<void> baglamaSonucu = const Success(null);

  @override
  bool googleAvailable = true;
  @override
  bool appleAvailable = false;
  @override
  bool get usesWebGoogleButton => false;
  @override
  Future<void> prepareGoogle() async {}
  @override
  Stream<SocialCredential> get webGoogleCredentials => const Stream.empty();
  @override
  Future<Result<SocialCredential?>> obtainCredential(SocialProvider provider) async =>
      Success(SocialCredential(provider: provider, idToken: 'jeton'));
  @override
  Future<Result<bool>> exchange(SocialCredential credential, {String? username}) async => const Success(true);
  @override
  Future<Result<Set<SocialProvider>>> linkedProviders() async => Success({...bagli});
  @override
  Future<Result<void>> link(SocialCredential credential) async {
    baglananlar.add(credential);
    if (baglamaSonucu.isSuccess) bagli.add(credential.provider);
    return baglamaSonucu;
  }
}

void main() {
  late _Baglayici repo;

  setUp(() async {
    await getIt.reset();
    repo = _Baglayici();
    getIt.registerSingleton<SocialAuthRepository>(repo);
  });

  Future<void> ac(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const Scaffold(body: SocialLinksPanel())));
    await t.pump();
  }

  testWidgets('bağlı değilse BAĞLA; basınca bağlanır ve BAĞLI yazar', (t) async {
    await ac(t);
    expect(find.text('BAĞLI HESAPLAR'), findsOneWidget);
    await t.tap(find.text('BAĞLA'));
    await t.pump();
    await t.pump();
    expect(repo.baglananlar.single.provider, SocialProvider.google);
    expect(find.text('BAĞLI'), findsOneWidget);
    expect(find.text('Hesap bağlandı.'), findsOneWidget);
  });

  testWidgets('sunucu reddederse mesajı gösterilir', (t) async {
    repo.baglamaSonucu = const Failure(AppException(message: 'Bu hesap başka bir oyuncuya bağlı.'));
    await ac(t);
    await t.tap(find.text('BAĞLA'));
    await t.pump();
    await t.pump();
    expect(find.text('Bu hesap başka bir oyuncuya bağlı.'), findsOneWidget);
    expect(find.text('BAĞLI'), findsNothing);
  });

  testWidgets('hiçbir sağlayıcı ayarlı değilse yer kaplamaz', (t) async {
    repo
      ..googleAvailable = false
      ..appleAvailable = false;
    await ac(t);
    expect(find.text('BAĞLI HESAPLAR'), findsNothing);
  });
}
