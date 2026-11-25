import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/auth/presentation/viewmodel/auth_view_model.dart';
import '../../../features/settings/presentation/viewmodel/settings_view_model.dart';
import '../../ui_v21.dart';
import '../../../features/auth/presentation/widgets/social_links_panel.dart';
import '../../../core/l10n/app_language.dart';

/// V2.1 AYARLAR (referans `assets/v21/screens/settings.png`; alt menü yok).
///
///   SES:   Ses efektleri (YAKINDA) · Müzik (YAKINDA) · Titreşim
///   OYUN:  Kart parıltısı · Süre uyarısı
///   DİL:   Türkçe · English (hemen uygulanır, cihazda saklanır)
///   HESAP: avatar + kullanıcı adı, e-posta; değiştirme yakında
///   [ ÇIKIŞ YAP ]  (onaylı)
///
/// VERİ: `SettingsViewModel` (uygulama genelinde TEK örnek, cihazda
/// saklanır; `.value` ile verilir). Ses ve müzik oyunda henüz yok: anahtar
/// çalışıyormuş gibi gösterilmez, pasif "YAKINDA".
class V21SettingsScreen extends StatelessWidget {
  const V21SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<SettingsViewModel>.value(value: getIt<SettingsViewModel>(), child: const _Body());
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    SessionManager? session;
    try {
      session = context.watch<SessionManager>();
    } on ProviderNotFoundException {
      session = null;
    }
    final user = session?.user;
    return V21InnerPage(
      title: 'AYARLAR'.tr,
      route: AppRoutes.settings,
      fallbackRoute: AppRoutes.profile,
      showNavigation: false,
      children: (context, k) => [
        V21SectionTitle('SES'.tr, scale: k),
        _Group(
          scale: k,
          rows: [
            _ToggleRow(
              color: const Color(0xFF5FB4FF),
              title: 'Ses efektleri'.tr,
              soon: true,
              value: false,
              onChanged: null,
              scale: k,
            ),
            _ToggleRow(
              color: const Color(0xFFE3A9FA),
              title: 'Müzik'.tr,
              soon: true,
              value: false,
              onChanged: null,
              scale: k,
            ),
            _ToggleRow(
              color: const Color(0xFFFFC832),
              title: 'Titreşim'.tr,
              subtitle: 'Nadir kart çıkınca telefon titrer'.tr,
              value: vm.vibration,
              onChanged: vm.setVibration,
              scale: k,
            ),
          ],
        ),
        SizedBox(height: 14 * k),
        V21SectionTitle('OYUN'.tr, scale: k),
        _Group(
          scale: k,
          rows: [
            _ToggleRow(
              color: const Color(0xFF8BE38A),
              title: 'Kart parıltısı'.tr,
              subtitle: 'Efsane kart parıltısı ve kart gölgeleri'.tr,
              value: vm.cardAnimations,
              onChanged: vm.setCardAnimations,
              scale: k,
            ),
            _ToggleRow(
              color: const Color(0xFFFF5A6E),
              title: 'Süre uyarısı'.tr,
              subtitle: 'Son 10 saniyede sayaç kırmızıya döner'.tr,
              value: vm.turnWarning,
              onChanged: vm.setTurnWarning,
              scale: k,
            ),
          ],
        ),
        SizedBox(height: 14 * k),
        V21SectionTitle('DİL'.tr, scale: k),
        _Group(scale: k, rows: [_LanguageRow(scale: k)]),
        SizedBox(height: 14 * k),
        V21SectionTitle('HESAP'.tr, scale: k),
        V21GamePanel(
          scale: k,
          radius: 16,
          padding: EdgeInsets.all(14 * k),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  V21PlayerAvatar(
                    seed: 'oyuncu-${user?.id ?? user?.username ?? '?'}',
                    semanticsLabel: 'Avatar'.tr,
                    name: user?.username,
                    size: 56 * k,
                    ringColor: const Color(0xFFFFC832),
                    background: const Color(0xFFFF9F5A),
                  ),
                  SizedBox(width: 12 * k),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.username ?? '—', style: V21Type.title(22 * k, shadows: V21Type.inkShadow(k))),
                        Text(
                          'Kullanıcı adı'.tr,
                          style: V21Type.label(11 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                        ),
                        if (user != null && user.email.isNotEmpty)
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14 * k),
              SocialLinksPanel(scale: k),
              Text(
                'Ad ve şifre değiştirme yakında eklenecek.'.tr,
                style: V21Type.label(13 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
              ),
            ],
          ),
        ),
        SizedBox(height: 20 * k),
        V21GameButton(
          label: 'ÇIKIŞ YAP'.tr,
          tone: V21ButtonTone.blue,
          size: V21ButtonSize.large,
          scale: k,
          onPressed: () => _signOut(context),
        ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await V21GameDialog.show<bool>(
      context,
      subtitle: 'HESAP'.tr,
      title: 'ÇIKIŞ YAPILSIN MI?'.tr,
      message: 'Bu cihazdaki oturumun kapanacak. Kartların ve ilerlemen hesabında kalır.'.tr,
      actions: [
        V21DialogAction('ÇIKIŞ YAP'.tr, tone: V21ButtonTone.red, result: true),
        V21DialogAction('VAZGEÇ'.tr, tone: V21ButtonTone.blue, result: false),
      ],
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<AuthViewModel>().signOut();
    } on ProviderNotFoundException {
      return;
    }
    if (context.mounted) context.go(AppRoutes.login);
  }
}

class _Group extends StatelessWidget {
  final List<Widget> rows;
  final double scale;
  const _Group({required this.rows, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return V21GamePanel(
      scale: k,
      radius: 16,
      padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 4 * k),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Container(height: 2 * k, color: const Color(0x337B56C9)),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// Oyun dili: Türkçe / English. Seçim hemen uygulanır ve cihazda saklanır.
/// Dil adları her zaman kendi dilinde yazılır (oyuncu bilmediği dilde
/// kalsa bile kendi dilini bulabilsin).
class _LanguageRow extends StatelessWidget {
  final double scale;
  const _LanguageRow({required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLanguageController.instance,
      builder: (context, secili, _) => Padding(
        padding: EdgeInsets.symmetric(vertical: 10 * k),
        child: Row(
          children: [
            V21OrbIcon(size: 40 * k, color: const Color(0xFF6FE4FF)),
            SizedBox(width: 14 * k),
            Expanded(
              child: Wrap(
                spacing: 8 * k,
                runSpacing: 8 * k,
                children: [
                  for (final dil in AppLanguage.values)
                    V21GameButton(
                      key: ValueKey('dil-${dil.code}'),
                      label: dil.nativeName,
                      tone: dil == secili ? V21ButtonTone.green : V21ButtonTone.purple,
                      size: V21ButtonSize.small,
                      scale: k,
                      semanticsLabel: dil == secili ? '${dil.nativeName}, ${'seçili'.tr}' : dil.nativeName,
                      onPressed: dil == secili ? () {} : () => AppLanguageController.instance.select(dil),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final Color color;
  final String title;
  final String? subtitle;
  final bool soon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double scale;

  const _ToggleRow({
    required this.color,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.scale,
    this.subtitle,
    this.soon = false,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10 * k),
      child: Row(
        children: [
          V21OrbIcon(size: 40 * k, color: color),
          SizedBox(width: 14 * k),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: V21Type.title(18 * k, color: soon ? const Color(0xFFB9ADD8) : Colors.white)),
                if (soon) ...[
                  SizedBox(height: 4 * k),
                  V21Tag(text: 'YAKINDA'.tr, background: const Color(0xFFFF9500), foreground: Colors.white, scale: k),
                ] else if (subtitle != null)
                  Text(
                    subtitle!,
                    style: V21Type.label(11 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
                  ),
              ],
            ),
          ),
          V21Toggle(value: value, onChanged: onChanged, semanticsLabel: soon ? '{title}, yakında'.trArgs({'title': title}) : title, scale: k),
        ],
      ),
    );
  }
}
