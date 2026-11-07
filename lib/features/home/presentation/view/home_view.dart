import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../auth/presentation/viewmodel/auth_view_model.dart';
import '../viewmodel/home_view_model.dart';

/// ANA SAYFA — referans `home()` ekranı.
///
///   .hero        lig hapı, 🛡️, "ARENA SENİ BEKLİYOR", kupa + seri, MAÇA BAŞLA
///   .tilegrid    KADROM · KARTLARIM · PAKETLER
///   GÜNLÜK GÖREVLER  (sunucuda yok → "YAKINDA"; kart görevlerine yönlendirir)
///   LİG İLERLEMESİ   (referanstaki "SEZON ÖDÜLÜ" bloğu; sezon sistemi yok,
///                     yerine GERÇEK lig ilerlemesi)
///
/// Bütün sayılar sunucudan: puan (MMR), lig, seri, kadro ve kart sayısı.
/// Referanstaki örnek sayılar (1.825, 4 galibiyet, 2/3 görev) KULLANILMAZ.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (_) => getIt<HomeViewModel>()..load(),
      child: const AppShell(currentRoute: AppRoutes.home, child: _HomeBody()),
    );
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  @override
  void initState() {
    super.initState();
    // Coin, puan ve devam eden maç bilgisi maç sonrası değişmiş olabilir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<AuthViewModel>().refreshProfile();
      } on ProviderNotFoundException {
        // Testlerde oturum modeli olmayabilir
      }
    });
  }

  Future<void> _yenile() async {
    final isler = <Future<void>>[context.read<HomeViewModel>().load()];
    try {
      isler.add(context.read<AuthViewModel>().refreshProfile());
    } on ProviderNotFoundException {
      // test
    }
    await Future.wait(isler);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, k) {
      final genis = k.maxWidth >= 900;
      final icerik = genis ? const _GenisYerlesim() : const _DarYerlesim();
      return RefreshIndicator(
        color: Ref.accent,
        backgroundColor: Ref.panel,
        onRefresh: _yenile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: Ref.pagePadding,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: genis ? 1180 : 620),
                child: RefPageEnter(child: icerik),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Telefon ve tablet: referansla aynı tek sütun (.page gap:13px)
class _DarYerlesim extends StatelessWidget {
  const _DarYerlesim();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DevamEdenMac(),
          _ArenaHero(),
          SizedBox(height: Ref.pageGap),
          _Karolar(),
          SizedBox(height: Ref.pageGap),
          _Gorevler(),
          SizedBox(height: Ref.pageGap),
          _LigIlerlemesi(),
        ],
      );
}

/// Masaüstü: aynı bileşenler iki sütunda (boş alan bırakmadan)
class _GenisYerlesim extends StatelessWidget {
  const _GenisYerlesim();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DevamEdenMac(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(children: [_ArenaHero(), SizedBox(height: Ref.pageGap), _Karolar()]),
              ),
              SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: Column(children: [_Gorevler(), SizedBox(height: Ref.pageGap), _LigIlerlemesi()]),
              ),
            ],
          ),
        ],
      );
}

UserModel? _kullanici(BuildContext c) {
  try {
    return Provider.of<SessionManager>(c).user;
  } on ProviderNotFoundException {
    return null;
  }
}

// ====================================================================
// .hero
// ====================================================================
class _ArenaHero extends StatelessWidget {
  const _ArenaHero();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final kullanici = _kullanici(context);
    final rutbe = vm.rank;
    final seri = vm.winStreak;

    return RefHero(
      crest: '🛡️',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // <span class="pill">🏆 ALTIN LİG III</span> — gerçek lig
          RefPill(rutbe == null ? 'LİG YÜKLENİYOR' : rutbe.label.toUpperTr(), emoji: '🏆'),
          // h2 { font-size:36px; line-height:.94; margin:13px 0 5px;
          //   text-shadow:0 3px 18px #0009 }
          const SizedBox(height: 13),
          Text(
            'ARENA\nSENİ BEKLİYOR',
            style: Ref.heading(RefHero.isNarrow(context) ? 32 : 36, height: 0.94).copyWith(
              shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 3), blurRadius: 18)],
            ),
          ),
          const SizedBox(height: 5),
          Text('Kartlarını hazırla. Taktiklerini konuştur.', style: Ref.bodyText(12, color: Ref.muted)),
          // .row { margin:18px 0 14px }
          const SizedBox(height: 18),
          Wrap(
            spacing: 9,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text.rich(
                TextSpan(children: [
                  const WidgetSpan(alignment: PlaceholderAlignment.middle, child: Em('🏆', size: 27)),
                  TextSpan(text: ' ${trThousands(kullanici?.mmr ?? 0)}'),
                ]),
                style: Ref.heading(27, color: Ref.gold, height: 1.2),
                semanticsLabel: '${kullanici?.mmr ?? 0} puan',
              ),
              if (seri > 0)
                RefPill('${vm.isStreakCapped ? '$seri+' : '$seri'} galibiyet serisi', emoji: '🔥'),
            ],
          ),
          const SizedBox(height: 14),
          RefCta(
            'MAÇA BAŞLA',
            leading: RefGlyph.swords,
            trailing: RefGlyph.play,
            onTap: () => context.go(AppRoutes.matchmaking),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// .tilegrid { grid-template-columns:repeat(3,1fr); gap:8px }
// ====================================================================
class _Karolar extends StatelessWidget {
  const _Karolar();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final kadro = vm.activeDeckCardCount;
    final kart = vm.inventoryCount;
    final karolar = [
      RefTile(
        emoji: '♟️',
        title: 'KADROM',
        subtitle: kadro == null ? '4-4-2' : '$kadro / ${GameRules.squadSize}',
        onTap: () => context.go(AppRoutes.deck),
      ),
      RefTile(
        emoji: '🃏',
        title: 'KARTLARIM',
        subtitle: kart == null ? 'Koleksiyon' : '$kart kart',
        onTap: () => context.go(AppRoutes.collection),
      ),
      RefTile(
        emoji: '🎁',
        title: 'PAKETLER',
        subtitle: 'Mağaza',
        onTap: () => context.go(AppRoutes.store),
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < karolar.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: karolar[i]),
          ],
        ],
      ),
    );
  }
}

// ====================================================================
// GÜNLÜK GÖREVLER — sunucuda günlük görev YOK
// ====================================================================
class _Gorevler extends StatelessWidget {
  const _Gorevler();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RefSectionHead('GÜNLÜK GÖREVLER', trailing: Text('YAKINDA', style: Ref.tiny(Ref.accent))),
          const SizedBox(height: Ref.pageGap),
          RefCardPanel(children: [
            // .task { gap:10px } .em 23px, strong 11px, small muted
            Row(
              children: [
                const Em('🎯', size: 23),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Günlük görevler yakında', style: Ref.bodyText(11, weight: FontWeight.w700)),
                      Text('Şimdilik kart görevleri açık: kartlarını birleştir, ödül kazan.',
                          style: Ref.bodyText(10, color: Ref.muted)),
                    ],
                  ),
                ),
              ],
            ),
            RefSecondaryButton('KART GÖREVLERİNE GİT', trailing: RefGlyph.arrowRight, onTap: () => context.go(AppRoutes.sbc)),
          ]),
        ],
      );
}

// ====================================================================
// LİG İLERLEMESİ — referans "SEZON ÖDÜLÜ" bloğu, gerçek lig verisiyle
// ====================================================================
class _LigIlerlemesi extends StatelessWidget {
  const _LigIlerlemesi();

  @override
  Widget build(BuildContext context) {
    final r = context.watch<HomeViewModel>().rank;
    final String alt;
    if (r == null) {
      alt = 'Yükleniyor';
    } else if (r.isTopTier || r.nextLabel == null) {
      alt = 'En üst ligdesin';
    } else {
      alt = '${r.pointsToNext} puan sonra ${r.nextLabel}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefSectionHead('LİG İLERLEMESİ', trailing: r == null ? null : RefPill(r.label.toUpperTr())),
        const SizedBox(height: Ref.pageGap),
        RefCardPanel(children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r == null ? 'LİG' : '${r.leagueName.toUpperTr()} LİGİ',
                        style: Ref.bodyText(14, color: Ref.gold, weight: FontWeight.w700)),
                    Text(alt, style: Ref.tiny(Ref.muted)),
                  ],
                ),
              ),
              const Em('🏆', size: 31),
            ],
          ),
          RefBar(r == null ? 0 : (r.isTopTier ? 1 : r.progress)),
          RefSecondaryButton('LİG YOLUNU GÖR', trailing: RefGlyph.arrowRight, onTap: () => context.go(AppRoutes.leagueTiers)),
        ]),
      ],
    );
  }
}

// ====================================================================
// Devam eden maç (oyunda gerçek; referansta yok)
// ====================================================================
class _DevamEdenMac extends StatelessWidget {
  const _DevamEdenMac();

  @override
  Widget build(BuildContext context) {
    String? macId;
    try {
      macId = context.watch<AuthViewModel>().activeMatchId;
    } on ProviderNotFoundException {
      macId = null;
    }
    if (macId == null) return const SizedBox.shrink();
    final id = macId;
    return Padding(
      padding: const EdgeInsets.only(bottom: Ref.pageGap),
      child: RefCardPanel(
        onTap: () => context.push(AppRoutes.matchWithId(id)),
        children: [
          Row(
            children: [
              const Em('⚽', size: 23),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Devam eden maçın var', style: Ref.bodyText(11, weight: FontWeight.w700)),
                    Text('Sıra sende olabilir. Süren dolarsa hükmen yenik sayılırsın.',
                        style: Ref.bodyText(10, color: Ref.muted)),
                  ],
                ),
              ),
            ],
          ),
          RefSecondaryButton('MAÇA DÖN', trailing: RefGlyph.arrowRight, onTap: () => context.push(AppRoutes.matchWithId(id))),
        ],
      ),
    );
  }
}
