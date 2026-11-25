import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/audio/game_audio.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'package:shared_models/shared_models.dart' show displayText;
import 'core/platform/orientation_policy.dart';
import 'core/utils/logger.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/settings/presentation/viewmodel/settings_view_model.dart';
import 'core/l10n/app_language.dart';

/// Uygulamanin giris noktasi.
///
/// ACILIS SIRASI (sirasi onemlidir):
///   1. Flutter motorunu hazirla
///   2. .env dosyasini oku (backend adresi icin)
///   3. Bagimliliklari (Get_It) kaydet
///   4. Cihazdaki oturumu geri yukle (varsa WebSocket'i de acar)
///   5. Uygulamayi baslat
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _ekranYonunuAyarla();

  try {
    await dotenv.load(fileName: '.env');

    // Yayin paketi yanlis adrese (http / localhost) bagliysa sessizce
    // "baglanilamadi" demek yerine acilista acik bir mesaj goster.
    if (kReleaseMode) {
      final sorun = AppConfig.releaseConfigProblem(AppConfig.apiBaseUrl);
      if (sorun != null) throw StateError(sorun);
    }
    await configureDependencies();

    // Cihaz tercihleri (titreşim, animasyon, süre uyarısı) İLK ekrandan
    // önce okunmalı. Aksi halde ayarlar ekranı açılana kadar her yer
    // varsayılanlarla çalışır ve oyuncunun kapattığı titreşim gelir.
    await getIt<SettingsViewModel>().load();

    // Dil: kayıtlı seçim, yoksa cihaz dili. Modellerdeki etiketler
    // (mevki, taktik, görev şartı) de aynı çeviriden geçer.
    await AppLanguageController.instance.load();
    displayText = (s) => s.tr;

    // Ses: hangi müzik/efekt dosyalarının eklendiğini öğrenir. Başarısız
    // olursa oyun sessiz açılır; açılışı engellemez.
    await getIt<GameAudio>().init();

    AppLogger.info('Backend adresi: ${AppConfig.apiBaseUrl}');

    // Kayitli oturumu yukle. Basarisiz olsa bile uygulama acilmali;
    // kullanici giris ekranini gorur.
    await getIt<AuthRepository>().restoreSession();
  } catch (e, s) {
    AppLogger.error('Uygulama baslatilamadi', error: e, stackTrace: s);
    runApp(_BaslatmaHatasiEkrani(mesaj: e.toString()));
    return;
  }

  runApp(const FutbolCardApp());
}

/// Telefon dikey kalir; tablet ve web her yonde calisir.
///
/// Ekran olcusu acilista henuz gelmediyse once dikey kilitlenir (telefon
/// yan acilmasin), ilk kare cizilince gercek olcuyle karar verilir.
Future<void> _ekranYonunuAyarla() async {
  const dikey = [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
  final binding = WidgetsBinding.instance;
  OrientationPolicy kural() {
    final ekran = binding.platformDispatcher.views.first;
    return orientationPolicyFor(ekran.physicalSize, ekran.devicePixelRatio, isWeb: kIsWeb);
  }

  final ilk = kural();
  if (ilk == OrientationPolicy.free) return;
  await SystemChrome.setPreferredOrientations(dikey);
  if (ilk == OrientationPolicy.unknown) {
    binding.addPostFrameCallback((_) {
      if (kural() == OrientationPolicy.free) SystemChrome.setPreferredOrientations(const []);
    });
  }
}

/// Acilista bir sey ters giderse (ornek: .env eksik) bos beyaz ekran
/// yerine anlasilir bir mesaj gosterelim.
class _BaslatmaHatasiEkrani extends StatelessWidget {
  final String mesaj;

  const _BaslatmaHatasiEkrani({required this.mesaj});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Color(0xFFE5484D)),
                const SizedBox(height: 16),
                Text(
                  'Uygulama baslatilamadi'.tr,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  mesaj,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF9AA5B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
