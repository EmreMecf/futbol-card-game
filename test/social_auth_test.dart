import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/auth/domain/repositories/social_auth_repository.dart';
import 'package:futbol_card/features/auth/presentation/view/login_view.dart';
import 'package:futbol_card/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'goldens/sahte_veri.dart';

const _kimlik = SocialCredential(provider: SocialProvider.google, idToken: 'jeton');

class _Sosyal implements SocialAuthRepository {
  @override
  Future<Result<Set<SocialProvider>>> linkedProviders() async => const Success(<SocialProvider>{});

  @override
  Future<Result<void>> link(SocialCredential credential) async => const Success(null);

  @override
  bool googleAvailable = true;
  @override
  bool appleAvailable = true;
  @override
  bool get usesWebGoogleButton => false;

  Result<SocialCredential?> kimlikSonucu = const Success(_kimlik);

  /// Sırayla dönecek sunucu cevapları
  final cevaplar = <Result<bool>>[];
  final adlar = <String?>[];

  @override
  Future<void> prepareGoogle() async {}
  @override
  Stream<SocialCredential> get webGoogleCredentials => const Stream.empty();
  @override
  Future<Result<SocialCredential?>> obtainCredential(SocialProvider provider) async => kimlikSonucu;
  @override
  Future<Result<bool>> exchange(SocialCredential credential, {String? username}) async {
    adlar.add(username);
    return cevaplar.removeAt(0);
  }
}

void main() {
  late _Sosyal sosyal;
  late AuthViewModel vm;

  setUp(() {
    sosyal = _Sosyal();
    vm = AuthViewModel(GoldenAuthRepo(), social: sosyal);
  });

  group('AuthViewModel', () {
    test('kayıtlı oyuncu doğrudan girer', () async {
      sosyal.cevaplar.add(const Success(true));
      expect(await vm.continueWith(SocialProvider.google), SocialAuthOutcome.signedIn);
      expect(sosyal.adlar, [null]);
    });

    test('vazgeçen oyuncuya hata gösterilmez', () async {
      sosyal.kimlikSonucu = const Success(null);
      expect(await vm.continueWith(SocialProvider.apple), SocialAuthOutcome.cancelled);
      expect(vm.error, isNull);
      expect(vm.isBusy, isFalse);
    });

    test('sağlayıcı hatası bildirilir', () async {
      sosyal.kimlikSonucu = const Failure(AppException(message: 'olmadı'));
      expect(await vm.continueWith(SocialProvider.google), SocialAuthOutcome.failed);
      expect(vm.error?.message, 'olmadı');
    });

    test('yeni oyuncu aynı kimlikle adını gönderir, alınmış ad tekrar denenebilir', () async {
      sosyal.cevaplar.addAll([
        const Success(false),
        const Failure(AppException(message: 'alınmış')),
        const Success(true),
      ]);
      expect(await vm.continueWith(SocialProvider.google), SocialAuthOutcome.needsUsername);
      expect(await vm.finishWithUsername(' Dolu '), SocialAuthOutcome.failed);
      vm.clearError();
      expect(await vm.finishWithUsername('Bos'), SocialAuthOutcome.signedIn);
      expect(sosyal.adlar, [null, 'Dolu', 'Bos']);
    });

    test('vazgeçilen kimlik sonradan kullanılamaz', () async {
      sosyal.cevaplar.add(const Success(false));
      await vm.continueWith(SocialProvider.google);
      vm.cancelSocial();
      expect(await vm.finishWithUsername('Oyuncu'), SocialAuthOutcome.cancelled);
    });
  });

  group('Giriş ekranı', () {
    Future<void> ac(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final yonlendirici = GoRouter(
        initialLocation: '/giris',
        routes: [
          GoRoute(path: '/giris', builder: (_, _) => const LoginView()),
          GoRoute(path: '/ana-sayfa', builder: (_, _) => const Scaffold(body: Text('ANA SAYFA'))),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: vm,
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: yonlendirici),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('ayar yoksa düğmeler görünmez', (tester) async {
      sosyal
        ..googleAvailable = false
        ..appleAvailable = false;
      await ac(tester);
      expect(find.text('Google ile devam et'), findsNothing);
      expect(find.text('Apple ile devam et'), findsNothing);
      expect(find.text('VEYA'), findsNothing);
    });

    testWidgets('yeni oyuncu adını seçip ana sayfaya geçer', (tester) async {
      sosyal.cevaplar.addAll([const Success(false), const Success(true)]);
      await ac(tester);
      expect(find.text('Apple ile devam et'), findsOneWidget);

      await tester.ensureVisible(find.text('Google ile devam et'));
      await tester.tap(find.text('Google ile devam et'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ADINI SEÇ'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).last, 'Kaptan');
      await tester.tap(find.text('OYUNA BAŞLA'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(sosyal.adlar.last, 'Kaptan');
      expect(find.text('ANA SAYFA'), findsOneWidget);
    });

    testWidgets('hata formun şeridinde gösterilir', (tester) async {
      sosyal.cevaplar.add(const Failure(AppException(message: 'Giris dogrulanamadi.')));
      await ac(tester);
      await tester.ensureVisible(find.text('Google ile devam et'));
      await tester.tap(find.text('Google ile devam et'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Giris dogrulanamadi.'), findsOneWidget);
    });
  });
}
