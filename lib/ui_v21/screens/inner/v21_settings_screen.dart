import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/auth/presentation/viewmodel/auth_view_model.dart';
import '../../../features/settings/presentation/viewmodel/settings_view_model.dart';
import '../../ui_v21.dart';

/// V2.1 AYARLAR (referans `assets/v21/screens/settings.png`; alt menü yok).
///
///   SES:   Ses efektleri (YAKINDA) · Müzik (YAKINDA) · Titreşim
///   OYUN:  Kart parıltısı · Süre uyarısı
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
      title: 'AYARLAR',
      route: AppRoutes.settings,
      fallbackRoute: AppRoutes.profile,
      showNavigation: false,
      children: (context, k) => [
        V21SectionTitle('SES', scale: k),
        _Group(
          scale: k,
          rows: [
            _ToggleRow(
              color: const Color(0xFF5FB4FF),
              title: 'Ses efektleri',
              soon: true,
              value: false,
              onChanged: null,
              scale: k,
            ),
            _ToggleRow(
              color: const Color(0xFFE3A9FA),
              title: 'Müzik',
              soon: true,
              value: false,
              onChanged: null,
              scale: k,
            ),
            _ToggleRow(
              color: const Color(0xFFFFC832),
              title: 'Titreşim',
              subtitle: 'Nadir kart çıkınca telefon titrer',
              value: vm.vibration,
              onChanged: vm.setVibration,
              scale: k,
            ),
          ],
        ),
        SizedBox(height: 14 * k),
        V21SectionTitle('OYUN', scale: k),
        _Group(
          scale: k,
          rows: [
            _ToggleRow(
              color: const Color(0xFF8BE38A),
              title: 'Kart parıltısı',
              subtitle: 'Efsane kart parıltısı ve kart gölgeleri',
              value: vm.cardAnimations,
              onChanged: vm.setCardAnimations,
              scale: k,
            ),
            _ToggleRow(
              color: const Color(0xFFFF5A6E),
              title: 'Süre uyarısı',
              subtitle: 'Son 10 saniyede sayaç kırmızıya döner',
              value: vm.turnWarning,
              onChanged: vm.setTurnWarning,
              scale: k,
            ),
          ],
        ),
        SizedBox(height: 14 * k),
        V21SectionTitle('HESAP', scale: k),
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
                    semanticsLabel: 'Avatar',
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
                          'Kullanıcı adı',
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
              Text(
                'Ad ve şifre değiştirme yakında eklenecek.',
                style: V21Type.label(13 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
              ),
            ],
          ),
        ),
        // Geliştirici araçları: yayın sürümünde derlenmez (kDebugMode sabit)
        if (kDebugMode) ...[
          SizedBox(height: 14 * k),
          V21SectionTitle('GELİŞTİRİCİ', scale: k),
          Wrap(
            spacing: 8 * k,
            runSpacing: 8 * k,
            children: [
              for (final (label, route) in const [
                ('TASARIM', AppRoutes.designSystem),
                ('KARAKTER', AppRoutes.characterPreview),
                ('2D STİL', AppRoutes.stylePrototype),
              ])
                SizedBox(
                  width: 110 * k,
                  child: V21GameButton(
                    label: label,
                    tone: V21ButtonTone.purple,
                    size: V21ButtonSize.small,
                    scale: k,
                    onPressed: () => context.push(route),
                  ),
                ),
            ],
          ),
        ],
        SizedBox(height: 20 * k),
        V21GameButton(
          label: 'ÇIKIŞ YAP',
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
      subtitle: 'HESAP',
      title: 'ÇIKIŞ YAPILSIN MI?',
      message: 'Bu cihazdaki oturumun kapanacak. Kartların ve ilerlemen hesabında kalır.',
      actions: const [
        V21DialogAction('ÇIKIŞ YAP', tone: V21ButtonTone.red, result: true),
        V21DialogAction('VAZGEÇ', tone: V21ButtonTone.blue, result: false),
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
                  V21Tag(text: 'YAKINDA', background: const Color(0xFFFF9500), foreground: Colors.white, scale: k),
                ] else if (subtitle != null)
                  Text(
                    subtitle!,
                    style: V21Type.label(11 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
                  ),
              ],
            ),
          ),
          V21Toggle(value: value, onChanged: onChanged, semanticsLabel: soon ? '$title, yakında' : title, scale: k),
        ],
      ),
    );
  }
}
