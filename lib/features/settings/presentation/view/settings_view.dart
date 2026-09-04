import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../auth/presentation/viewmodel/auth_view_model.dart';
import '../viewmodel/settings_view_model.dart';

/// Ayarlar.
///
/// Buradaki tercihler cihazda saklanıyor, sunucuya gitmiyor.
/// Gerekçe [SettingsViewModel] içinde açıklandı.
///
/// Hesap bölümünde sadece OKUNAN bilgiler var: kullanıcı adı ve
/// e-posta. Değiştirme uçları sunucuda henüz yok; olmayan bir şeye
/// giden buton koymak yerine bölüm o alanları bilgi olarak gösteriyor.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SettingsViewModel>(
      create: (_) => getIt<SettingsViewModel>()..load(),
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final kullanici = context.watch<SessionManager>().user;

    return AppShell(
      // Ayarlar bir iç ekran: alt çubukta kendi maddesi yok, profilden
      // açılıyor. Gezinme gizlenirse geri dönüş yolu kalmaz, o yüzden
      // çubuk duruyor ve Profil vurgulu kalıyor.
      currentRoute: AppRoutes.profile,
      child: ResponsiveBuilder(
        builder: (context, boyut) {
          final kenar = AppBreakpoints.pagePadding(boyut);

          return SafeArea(
            bottom: false,
            child: ContentWidth(
              maxWidth: 720,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  kenar,
                  boyut.usesSidebar ? 32 : 16,
                  kenar,
                  boyut.usesSidebar ? 40 : 110,
                ),
                children: [
                  const ScreenHeader(
                    title: 'Ayarlar',
                    showBack: true,
                    breadcrumb: 'Profil',
                  ),
                  const SizedBox(height: 24),

                  const SectionTitle('Ses ve titreşim'),
                  const SizedBox(height: 10),
                  _AnahtarSatiri(
                    icon: Icons.volume_up_rounded,
                    title: 'Ses efektleri',
                    subtitle: 'Kart, buton ve paket sesleri',
                    value: vm.soundEffects,
                    onChanged: vm.setSoundEffects,
                  ),
                  _AnahtarSatiri(
                    icon: Icons.music_note_rounded,
                    title: 'Müzik',
                    subtitle: 'Menü ve maç müziği',
                    value: vm.music,
                    onChanged: vm.setMusic,
                  ),
                  _AnahtarSatiri(
                    icon: Icons.vibration_rounded,
                    title: 'Titreşim',
                    subtitle: 'Nadir kart çıkınca telefon titrer',
                    value: vm.vibration,
                    onChanged: vm.setVibration,
                  ),

                  const SizedBox(height: 22),
                  const SectionTitle('Oyun'),
                  const SizedBox(height: 10),
                  _AnahtarSatiri(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Kart animasyonları',
                    subtitle: '3B eğilme ve holografik parlama',
                    value: vm.cardAnimations,
                    onChanged: vm.setCardAnimations,
                  ),
                  _AnahtarSatiri(
                    icon: Icons.timer_rounded,
                    title: 'Süre uyarısı',
                    subtitle: 'Son 10 saniyede sayaç kırmızıya döner',
                    value: vm.turnWarning,
                    onChanged: vm.setTurnWarning,
                  ),

                  const SizedBox(height: 22),
                  const SectionTitle('Hesap'),
                  const SizedBox(height: 10),
                  _BilgiSatiri(
                    icon: Icons.person_rounded,
                    title: 'Kullanıcı adı',
                    value: kullanici?.username ?? '—',
                  ),
                  _BilgiSatiri(
                    icon: Icons.mail_rounded,
                    title: 'E-posta',
                    value: kullanici?.email.isNotEmpty == true
                        ? kullanici!.email
                        : '—',
                  ),

                  const SizedBox(height: 14),
                  NoticeBar.info(
                    'Kullanıcı adı ve şifre değiştirme sunucuya henüz '
                    'eklenmedi. Eklendiğinde bu bölümden yapılabilecek.',
                  ),

                  const SizedBox(height: 26),
                  const _CikisButonu(),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Futbol Kart · sürüm 1.0.0',
                      style: AppTypography.bodyXS,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ====================================================================
// AÇ / KAPA SATIRI
// ====================================================================
class _AnahtarSatiri extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AnahtarSatiri({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: SurfaceCard(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(15, 10, 10, 10),
        // Satırın tamamı dokunma hedefi: küçük anahtarı isabet
        // ettirmeye çalışmak telefonda sinir bozucu.
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.textSecondary),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(
                      size: 13.5,
                      weight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyXS,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.textPrimary,
              activeTrackColor: AppColors.primary,
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.surfaceLight,
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// BİLGİ SATIRI (değiştirilemez)
// ====================================================================
class _BilgiSatiri extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _BilgiSatiri({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: SurfaceCard(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.textSecondary),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: AppTypography.body(
                  size: 13.5,
                  weight: FontWeight.w800,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTypography.bodyS,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// ÇIKIŞ
// ====================================================================
class _CikisButonu extends StatelessWidget {
  const _CikisButonu();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _onayla(context),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.danger.withValues(alpha: 0.42)),
      ),
      icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
      label: const Text(
        'ÇIKIŞ YAP',
        style: TextStyle(color: AppColors.danger),
      ),
    );
  }

  Future<void> _onayla(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Çıkış yapılsın mı?'),
        content: Text(
          'Kartların ve kadron hesabında kalır. Tekrar giriş yaptığında '
          'kaldığın yerden devam edersin.',
          style: AppTypography.bodyS,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Çıkış yap',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (onay != true || !context.mounted) return;

    await context.read<AuthViewModel>().signOut();
    if (context.mounted) context.go(AppRoutes.login);
  }
}
