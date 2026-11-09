import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
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
///
/// FAZ 8: referans dili — geri düğmesi + .sectionhead (lig basamakları
/// ekranıyla aynı), her grup bir .card-panel, bilgi notu .note.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    // `.value` ŞART, `create:` DEĞİL.
    //
    // SettingsViewModel uygulama genelinde TEK örnek (singleton) ve
    // main() içinde yükleniyor. `create:` ile verilseydi Provider bu
    // ekran kapanınca onu dispose ederdi; ekran ikinci kez açıldığında
    // "dispose edilmiş ChangeNotifier kullanıldı" hatası alınırdı ve
    // titreşim/animasyon ayarları bütün uygulamada okunamaz olurdu.
    return ChangeNotifierProvider<SettingsViewModel>.value(
      value: getIt<SettingsViewModel>(),
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
      child: ListView(
        padding: Ref.pagePadding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: RefPageEnter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      RefNeutralButton(
                        padding: const EdgeInsets.all(7),
                        semanticLabel: 'Geri',
                        onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.profile),
                        child: const Icon(Icons.arrow_back_rounded, size: 16, color: Ref.neutralText),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: RefSectionHead('AYARLAR', size: 27, kicker: 'PROFİL')),
                    ]),
                    const SizedBox(height: Ref.pageGap),

                    // SES VE MÜZİK HENÜZ YOK.
                    // Oyunda ses dosyası ve ses motoru bulunmuyor. Anahtarı
                    // çalışıyormuş gibi göstermek oyuncuyu yanıltırdı
                    // (MD kural 12: eksik kaynağı tamamlanmış gibi
                    // gösterme). Ses sistemi eklenince `enabled` açılır.
                    _Grup(baslik: 'SES VE TİTREŞİM', satirlar: [
                      _AnahtarSatiri(
                        emoji: '🔊',
                        title: 'Ses efektleri',
                        subtitle: 'Yakında — ses dosyaları henüz eklenmedi',
                        value: false,
                        onChanged: vm.setSoundEffects,
                        enabled: false,
                      ),
                      _AnahtarSatiri(
                        emoji: '🎵',
                        title: 'Müzik',
                        subtitle: 'Yakında — müzik henüz eklenmedi',
                        value: false,
                        onChanged: vm.setMusic,
                        enabled: false,
                      ),
                      _AnahtarSatiri(
                        emoji: '📳',
                        title: 'Titreşim',
                        subtitle: 'Nadir kart çıkınca telefon titrer',
                        value: vm.vibration,
                        onChanged: vm.setVibration,
                      ),
                    ]),
                    const SizedBox(height: Ref.pageGap),
                    _Grup(baslik: 'OYUN', satirlar: [
                      _AnahtarSatiri(
                        emoji: '✨',
                        title: 'Kart animasyonları',
                        subtitle: 'Efsane kart parıltısı ve kart gölgeleri',
                        value: vm.cardAnimations,
                        onChanged: vm.setCardAnimations,
                      ),
                      _AnahtarSatiri(
                        emoji: '⏱️',
                        title: 'Süre uyarısı',
                        subtitle: 'Son 10 saniyede sayaç kırmızıya döner',
                        value: vm.turnWarning,
                        onChanged: vm.setTurnWarning,
                      ),
                    ]),
                    const SizedBox(height: Ref.pageGap),
                    _Grup(baslik: 'HESAP', satirlar: [
                      _BilgiSatiri(emoji: '👤', title: 'Kullanıcı adı', value: kullanici?.username ?? '—'),
                      _BilgiSatiri(
                        emoji: '✉️',
                        title: 'E-posta',
                        value: kullanici?.email.isNotEmpty == true ? kullanici!.email : '—',
                      ),
                    ]),
                    const SizedBox(height: Ref.pageGap),
                    const RefNote(
                      'Kullanıcı adı ve şifre değiştirme sunucuya henüz eklenmedi. '
                      'Eklendiğinde bu bölümden yapılabilecek.',
                    ),

                    // Geliştirici aracı: yayın sürümünde derlenmez bile
                    // (kDebugMode sabit olduğu için ağaç silkeleme kaldırır).
                    if (kDebugMode) ...[
                      const SizedBox(height: Ref.pageGap),
                      _Grup(baslik: 'GELİŞTİRİCİ', satirlar: [
                        _GecisSatiri(
                          emoji: '🎨',
                          title: 'Tasarım sistemi',
                          onTap: () => context.push(AppRoutes.designSystem),
                        ),
                        _GecisSatiri(
                          emoji: '🧑',
                          title: 'Karakter prototipi',
                          onTap: () => context.push(AppRoutes.characterPreview),
                        ),
                        _GecisSatiri(
                          emoji: '🖌️',
                          title: '2D stil prototipi',
                          onTap: () => context.push(AppRoutes.stylePrototype),
                        ),
                      ]),
                    ],

                    const SizedBox(height: 18),
                    const _CikisButonu(),
                    const SizedBox(height: 12),
                    Center(child: Text('Futbol Kart · sürüm 1.0.0', style: Ref.tiny(Ref.muted))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bir ayar grubu: küçük başlık + .card-panel içinde ayraçlı satırlar
class _Grup extends StatelessWidget {
  final String baslik;
  final List<Widget> satirlar;
  const _Grup({required this.baslik, required this.satirlar});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(baslik, style: Ref.caps(Ref.muted)),
          const SizedBox(height: 8),
          RefCardPanel(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            gap: 0,
            children: [
              for (var i = 0; i < satirlar.length; i++) ...[
                if (i > 0) Container(height: 1, color: Ref.cardPanelBorder.withValues(alpha: 0.6)),
                satirlar[i],
              ],
            ],
          ),
        ],
      );
}

/// .task satırı dili: emoji + başlık 13px/700 + küçük açıklama
class _Satir extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Satir({required this.emoji, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final govde = ConstrainedBox(
      // Parmakla isabet: en az 48 px
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Em(emoji, size: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Ref.bodyText(13, weight: FontWeight.w700)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ref.bodyText(10.5, color: Ref.muted),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
    if (onTap == null) return govde;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: govde);
  }
}

// ====================================================================
// AÇ / KAPA SATIRI
// ====================================================================
class _AnahtarSatiri extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Kapalıysa satır soluk görünür ve dokunulamaz
  final bool enabled;

  const _AnahtarSatiri({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: _Satir(
        emoji: emoji,
        title: title,
        subtitle: subtitle,
        // Satırın tamamı dokunma hedefi: küçük anahtarı isabet
        // ettirmeye çalışmak telefonda sinir bozucu.
        onTap: enabled ? () => onChanged(!value) : null,
        // Renkler temadan (switchTheme: referans --accent)
        trailing: Switch(value: value, onChanged: enabled ? onChanged : null),
      ),
    );
  }
}

// ====================================================================
// BİLGİ SATIRI (değiştirilemez)
// ====================================================================
class _BilgiSatiri extends StatelessWidget {
  final String emoji;
  final String title;
  final String value;

  const _BilgiSatiri({required this.emoji, required this.title, required this.value});

  @override
  Widget build(BuildContext context) => _Satir(
        emoji: emoji,
        title: title,
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Ref.bodyText(12, color: Ref.muted, weight: FontWeight.w700),
          ),
        ),
      );
}

/// Başka bir ekrana giden satır (geliştirici araçları)
class _GecisSatiri extends StatelessWidget {
  final String emoji;
  final String title;
  final VoidCallback onTap;
  const _GecisSatiri({required this.emoji, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => _Satir(
        emoji: emoji,
        title: title,
        onTap: onTap,
        trailing: const RefGlyphIcon(RefGlyph.arrowRight, size: 14, color: Ref.muted),
      );
}

// ====================================================================
// ÇIKIŞ
// ====================================================================
class _CikisButonu extends StatelessWidget {
  const _CikisButonu();

  @override
  Widget build(BuildContext context) {
    return RefNeutralButton(
      semanticLabel: 'Çıkış yap',
      padding: const EdgeInsets.all(12),
      onTap: () => _onayla(context),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.logout_rounded, size: 16, color: Ref.red),
        const SizedBox(width: 6),
        Text('ÇIKIŞ YAP', style: Ref.bodyText(12, color: Ref.red, weight: FontWeight.w900)),
      ]),
    );
  }

  Future<void> _onayla(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Çıkış yapılsın mı?', style: Ref.h3()),
        content: Text(
          'Kartların ve kadron hesabında kalır. Tekrar giriş yaptığında '
          'kaldığın yerden devam edersin.',
          style: Ref.bodyText(13, color: Ref.muted),
        ),
        actions: [
          RefNeutralButton(label: 'VAZGEÇ', onTap: () => Navigator.pop(ctx, false)),
          RefNeutralButton(
            onTap: () => Navigator.pop(ctx, true),
            child: Text('ÇIKIŞ YAP', style: Ref.bodyText(11, color: Ref.red, weight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (onay != true || !context.mounted) return;

    await context.read<AuthViewModel>().signOut();
    if (context.mounted) context.go(AppRoutes.login);
  }
}
