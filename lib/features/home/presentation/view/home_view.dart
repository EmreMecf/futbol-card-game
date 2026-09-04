import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/stat_chip.dart';
import '../../../auth/presentation/viewmodel/auth_view_model.dart';
import '../widgets/home_widgets.dart';

/// Ana sayfa — oyunun giriş noktası.
///
/// ===================================================================
/// İKİ YERLEŞİM, TEK VERİ
/// ===================================================================
/// Telefonda tek sütun ve alt sekme çubuğu; masaüstünde kenar çubuğu
/// ve iki sütunlu ızgara. İkisi de aynı [AuthViewModel] ve
/// [SessionManager] verisini okuyor, tekrarlanan mantık yok.
///
/// Ekranın tamamı tek bir karara hizmetçi: "maça gir". Bu yüzden
/// hızlı maç alanı en büyük, en parlak ve en üstteki öğe; kalan her
/// şey ondan görünür biçimde daha sönük.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    // Coin, MMR ve koruma hakkı maç sonrası değişmiş olabilir;
    // ayrıca devam eden maç varsa oraya dönebilmek için tazeliyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRoutes.home,
      child: ResponsiveBuilder(
        builder: (context, boyut) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () => context.read<AuthViewModel>().refreshProfile(),
          child: boyut.usesSidebar
              ? _GenisYerlesim(size: boyut)
              : _DarYerlesim(size: boyut),
        ),
      ),
    );
  }
}

// ====================================================================
// TELEFON / TABLET
// ====================================================================
class _DarYerlesim extends StatelessWidget {
  final ScreenSize size;

  const _DarYerlesim({required this.size});

  @override
  Widget build(BuildContext context) {
    final kenar = AppBreakpoints.pagePadding(size);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(kenar, 16, kenar, 110),
        children: [
          const _OyuncuSeridi(),
          const SizedBox(height: 18),
          const _DevamEdenMac(),
          const HizliMacKarti(compact: true),
          const SizedBox(height: 14),
          const _KaroIzgarasi(columns: 2),
          const SizedBox(height: 14),
          const IstatistikKarti(),
        ],
      ),
    );
  }
}

// ====================================================================
// MASAÜSTÜ
// ====================================================================
class _GenisYerlesim extends StatelessWidget {
  final ScreenSize size;

  const _GenisYerlesim({required this.size});

  @override
  Widget build(BuildContext context) {
    final kenar = AppBreakpoints.pagePadding(size);

    return SafeArea(
      child: ContentWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(kenar, 32, kenar, 40),
          children: [
            const _MasaustuBasligi(),
            const SizedBox(height: 24),
            const _DevamEdenMac(),

            // Hızlı maç solda geniş, sezon kartı sağda dar.
            // 2:1 oranı hangi öğenin asıl olduğunu tek bakışta anlatıyor.
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: HizliMacKarti(compact: false)),
                  SizedBox(width: 20),
                  Expanded(flex: 1, child: IstatistikKarti()),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _KaroIzgarasi(columns: AppBreakpoints.gridColumns(size)),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// ÜST ŞERİTLER
// ====================================================================

/// Telefon üst şeridi: avatar, ad, seviye çubuğu, sayaç hapları.
class _OyuncuSeridi extends StatelessWidget {
  const _OyuncuSeridi();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionManager>();
    final kullanici = session.user;

    return Row(
      children: [
        _Avatar(username: kullanici?.username),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kullanici?.username ?? 'Oyuncu',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.name,
              ),
              const SizedBox(height: 3),
              _MacOzeti(user: kullanici),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StatChip.coins(
          kullanici?.coins ?? 0,
          onTap: () => context.go(AppRoutes.store),
        ),
        const SizedBox(width: 8),
        StatChip.rating(kullanici?.mmr ?? 0),
      ],
    );
  }
}

/// Masaüstü başlığı: karşılama ve sayaç hapları.
class _MasaustuBasligi extends StatelessWidget {
  const _MasaustuBasligi();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionManager>();
    final kullanici = session.user;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoş geldin, ${kullanici?.username ?? 'Oyuncu'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(
                  size: 36,
                  weight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              _MacOzeti(user: kullanici, dense: false),
            ],
          ),
        ),
        StatChip.coins(
          kullanici?.coins ?? 0,
          onTap: () => context.go(AppRoutes.store),
        ),
        const SizedBox(width: 10),
        StatChip.rating(kullanici?.mmr ?? 0),
        const SizedBox(width: 10),
        StatChip.protection(session.protectionSlots, GameRules.maxProtectionSlots),
      ],
    );
  }
}

/// "12G 4M 2B · Seviye 12" özeti.
class _MacOzeti extends StatelessWidget {
  final UserModel? user;
  final bool dense;

  const _MacOzeti({required this.user, this.dense = true});

  @override
  Widget build(BuildContext context) {
    final g = user?.wins ?? 0;
    final m = user?.losses ?? 0;
    final b = user?.draws ?? 0;
    final toplam = g + m + b;

    final metin = toplam == 0
        ? 'Henüz maç oynamadın'
        : '$g galibiyet · $m mağlubiyet · $b beraberlik';

    return Text(
      metin,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body(
        size: dense ? 12 : 14,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? username;

  const _Avatar({this.username});

  @override
  Widget build(BuildContext context) {
    final harf = (username?.trim().isNotEmpty ?? false)
        ? username!.trim()[0].toUpperCase()
        : '?';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          harf,
          style: AppTypography.display(size: 20, weight: FontWeight.w900),
        ),
      ),
    );
  }
}

// ====================================================================
// DEVAM EDEN MAÇ UYARISI
// ====================================================================
class _DevamEdenMac extends StatelessWidget {
  const _DevamEdenMac();

  @override
  Widget build(BuildContext context) {
    final macId = context.watch<AuthViewModel>().activeMatchId;
    if (macId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(AppRoutes.matchWithId(macId)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_soccer,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Devam eden maçın var',
                        style: AppTypography.body(
                          size: 13.5,
                          weight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Sıra sende olabilir. Süren dolarsa hükmen '
                        'yenik sayılırsın.',
                        style: AppTypography.bodyXS,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// KARO IZGARASI
// ====================================================================
class _KaroIzgarasi extends StatelessWidget {
  final int columns;

  const _KaroIzgarasi({required this.columns});

  @override
  Widget build(BuildContext context) {
    final karolar = <Widget>[
      MenuKarosu(
        title: 'MAĞAZA',
        subtitle: 'Paketleri gör',
        icon: Icons.storefront_rounded,
        iconColor: AppColors.accent,
        onTap: () => context.go(AppRoutes.store),
      ),
      MenuKarosu(
        title: 'GÖREVLER',
        subtitle: 'Kart erit, ödül kazan',
        icon: Icons.checklist_rounded,
        iconColor: AppColors.success,
        onTap: () => context.go(AppRoutes.sbc),
      ),
      MenuKarosu(
        title: 'KADROM',
        subtitle: 'Diziliş ve kimya',
        icon: Icons.grid_view_rounded,
        iconColor: AppColors.tierDiamond,
        onTap: () => context.go(AppRoutes.deck),
      ),
      MenuKarosu(
        title: 'KOLEKSİYON',
        subtitle: 'Kartlarını incele',
        icon: Icons.style_rounded,
        iconColor: AppColors.tierLegend,
        onTap: () => context.go(AppRoutes.collection),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // SABİT YÜKSEKLİK, en/boy oranı DEĞİL.
        //
        // childAspectRatio kullanılırsa karo yüksekliği ekran
        // genişliğiyle birlikte büyür: 390px telefonda doğru duran
        // oran, 540px'lik bir pencerede karoyu 170px'e çıkarıp ikon
        // ile yazı arasını uçuruma çeviriyordu. İçerik hep aynı
        // olduğu için yükseklik de sabit olmalı.
        mainAxisExtent: 118,
      ),
      itemCount: karolar.length,
      itemBuilder: (context, i) => karolar[i],
    );
  }
}
