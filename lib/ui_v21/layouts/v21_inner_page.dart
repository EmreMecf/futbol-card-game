import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/v21_feedback.dart';
import '../components/v21_filters.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import '../screens/home/v21_home_nav.dart';
import '../theme/v21_theme.dart';
import '../utilities/v21_scale.dart';
import 'v21_screen_layout.dart';

/// Yüklenme durumu: veri yok + yükleniyor / hata / kapalı / hazır
enum V21PageState { loading, error, disabled, ready }

/// V2.1 İÇ SAYFA iskeleti (referans: Sandıklar, Gelişim, Envanter, Lig
/// Yolu, Profil, Ayarlar, Kart Takası).
///
///   [‹] BAŞLIK                         (kaynak hapı)
///   kaydırılan içerik (aşağı çekince yenilenir)
///   alt menü (üst sekme vurgulu) — Ayarlar'da yok
///
/// Durumlar tek yerde: yükleniyor göstergesi, hata (TEKRAR DENE), sistem
/// kapalı ("YAKINDA"). Sayı uydurulmaz.
class V21InnerPage extends StatelessWidget {
  final String title;

  /// Bu sayfanın rotası (alt menüde aynı sekmeye tekrar basınca bir şey yapmaz)
  final String route;

  /// Alt menüde vurgulanacak üst sekme; null: vurgu yok
  final String? highlightRoute;

  /// Geri gidilecek yer (yığında önceki sayfa yoksa)
  final String fallbackRoute;
  final bool showNavigation;
  final Widget Function(BuildContext context, double scale)? trailing;
  final V21PageState state;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;

  /// Sistem kapalıyken gösterilecek metin
  final String disabledTitle;
  final String disabledMessage;
  final List<Widget> Function(BuildContext context, double scale) children;

  /// Zemin (varsayılan sekme sayfası moru)
  final Widget background;

  /// Geri basılınca önce sorulacak soru (ör. kaydedilmemiş değişiklik)
  final Future<bool> Function()? confirmBack;

  const V21InnerPage({
    super.key,
    required this.title,
    required this.route,
    required this.fallbackRoute,
    required this.children,
    this.highlightRoute,
    this.showNavigation = true,
    this.trailing,
    this.state = V21PageState.ready,
    this.errorMessage,
    this.onRetry,
    this.onRefresh,
    this.disabledTitle = 'YAKINDA',
    this.disabledMessage = 'Bu bölüm henüz açık değil.',
    this.background = V21Background.page,
    this.confirmBack,
  });

  Future<void> _back(BuildContext context) async {
    if (confirmBack != null && !await confirmBack!()) return;
    if (!context.mounted) return;
    context.canPop() ? context.pop() : context.go(fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V21Theme.data(context),
      child: V21ScreenLayout(
        background: background,
        // Geniş ekranda yan menü her iç sayfada kalır
        bottomNavigation: showNavigation || V21Scale.of(context).isExpanded
            ? (context, sc) => V21HomeNav(currentRoute: route, highlightRoute: highlightRoute, scale: sc.s)
            : null,
        body: (context, sc) {
          final k = sc.s;
          final List<Widget> content = switch (state) {
            V21PageState.loading => [
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: V21Colors.goldTop)),
              ),
            ],
            V21PageState.error => [
              V21EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'BAĞLANTI SORUNU',
                message: errorMessage ?? 'Bilgi yüklenemedi. Bağlantını kontrol edip tekrar dene.',
                actionLabel: onRetry == null ? null : 'TEKRAR DENE',
                onAction: onRetry,
                scale: k,
              ),
            ],
            V21PageState.disabled => [
              V21EmptyState(
                icon: Icons.hourglass_top_rounded,
                title: disabledTitle,
                message: disabledMessage,
                scale: k,
              ),
            ],
            V21PageState.ready => children(context, k),
          };
          final list = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12 * k, 0, 12 * k, 24 * k),
            children: content,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(12 * k, 12 * k, 8 * k, 0),
                child: V21PageTitle(
                  title: title,
                  scale: k,
                  onBack: () => _back(context),
                  trailing: trailing?.call(context, k),
                ),
              ),
              SizedBox(height: 14 * k),
              Expanded(
                child: onRefresh == null
                    ? list
                    : RefreshIndicator(
                        color: V21Colors.goldTop,
                        backgroundColor: V21Colors.panel,
                        onRefresh: onRefresh!,
                        child: list,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bölüm başlığı ("YUVALAR", "BAŞARIMLAR 5/6") + sağda soluk açıklama
class V21SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final double scale;
  const V21SectionTitle(this.title, {super.key, this.trailing, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Padding(
      padding: EdgeInsets.only(top: 6 * k, bottom: 10 * k),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: V21Type.title(25 * k, shadows: V21Type.inkShadow(k))),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: V21Type.label(11 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
            ),
        ],
      ),
    );
  }
}

/// Ekran ölçeğini hesaplamak için kısa yol (iç sayfa parçaları)
double v21ScaleOf(BuildContext context) => V21Scale.of(context).s;
