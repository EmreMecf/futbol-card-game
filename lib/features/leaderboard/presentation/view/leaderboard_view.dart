import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../viewmodel/leaderboard_view_model.dart';

/// LİGLER / SIRALAMA — referans `leagues()` ekranı.
///
///   .hero         ŞAMPİYONLUK YOLU, 🏆, lig + puan, ilerleme çubuğu
///   LİG KADEMELERİ  rozet paneli
///   LİDERLİK TABLOSU  .card-panel satırları (🥇🥈🥉 + ad + 🏆 puan)
///   .secondary-button  ⚔ DERECELİ MAÇ OYNA
///
/// GERÇEK VERİ: sıralama ve puanlar /api/leaderboard'dan, lig ve
/// ilerleme /api/leaderboard/rank'tan. Oyunda 4 lig var (Amatör, Usta,
/// Master, Master Class; her biri 3 basamak); referanstaki 5 örnek
/// rozet yerine bu 4 gerçek lig gösterilir. Sezon sistemi olmadığı için
/// "SEZON 01" yerine "LİG YOLU" yazar. Liste haftalık değil, genel.
class LeaderboardView extends StatelessWidget {
  const LeaderboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LeaderboardViewModel>(
      create: (_) => getIt<LeaderboardViewModel>()..initialize(),
      child: const AppShell(currentRoute: AppRoutes.leaderboard, child: _Govde()),
    );
  }
}

/// Gerçek liglerin rozetleri (sırayla)
const kLigRozetleri = <(String, String, String)>[
  ('amateur', '🛡️', 'Amatör'),
  ('usta', '🥈', 'Usta'),
  ('master', '🥇', 'Master'),
  ('master_class', '👑', 'Master Class'),
];

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeaderboardViewModel>();
    return LayoutBuilder(builder: (context, k) {
      final genis = k.maxWidth >= 900;
      final sol = [
        _LigHero(rank: vm.myRank),
        const SizedBox(height: Ref.pageGap),
        RefSectionHead('LİG KADEMELERİ',
            trailing: RefNeutralButton(label: 'Tüm basamaklar', onTap: () => context.push(AppRoutes.leagueTiers))),
        const SizedBox(height: Ref.pageGap),
        _Rozetler(aktifKod: vm.myRank?.leagueCode),
      ];
      final sag = [
        const RefSectionHead('LİDERLİK TABLOSU', trailing: RefPill('GENEL')),
        const SizedBox(height: Ref.pageGap),
        _Tablo(viewModel: vm),
        const SizedBox(height: Ref.pageGap),
        RefSecondaryButton('DERECELİ MAÇ OYNA',
            leadingGlyph: RefGlyph.swords, onTap: () => context.go(AppRoutes.matchmaking)),
      ];
      return RefreshIndicator(
        color: Ref.accent,
        backgroundColor: Ref.panel,
        onRefresh: vm.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: Ref.pagePadding,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: genis ? 1100 : 620),
                child: RefPageEnter(
                  child: genis
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sol)),
                          const SizedBox(width: 20),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sag)),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          ...sol,
                          const SizedBox(height: Ref.pageGap),
                          ...sag,
                        ]),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// .hero — caps "LİG YOLU", h2 "ŞAMPİYONLUK YOLU", 🏆 60px,
/// satır: lig + puan, .bar, tiny "N puan sonra ..."
class _LigHero extends StatelessWidget {
  final PlayerRank? rank;
  const _LigHero({required this.rank});

  @override
  Widget build(BuildContext context) {
    final r = rank;
    final String alt;
    if (r == null) {
      alt = 'Lig bilgisi yükleniyor';
    } else if (r.isTopTier || r.nextLabel == null) {
      alt = 'En üst basamaktasın';
    } else {
      alt = '${r.pointsToNext} puan sonra ${r.nextLabel} (${r.winsToNext} galibiyet)';
    }
    return RefHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('LİG YOLU', style: Ref.caps(Ref.accent)),
          const SizedBox(height: 13),
          Text('ŞAMPİYONLUK YOLU',
              style: Ref.heading(36, height: 0.94).copyWith(
                shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 3), blurRadius: 18)],
              )),
          const Padding(padding: EdgeInsets.all(7), child: Center(child: Em('🏆', size: 60))),
          Row(children: [
            Expanded(
              child: Text(r == null ? '—' : r.label.toUpperTr(),
                  style: Ref.bodyText(14, weight: FontWeight.w700)),
            ),
            Text('${trThousands(r?.mmr ?? 0)} PUAN', style: Ref.bodyText(14, color: Ref.gold, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          RefBar(r == null ? 0 : (r.isTopTier ? 1 : r.progress)),
          const SizedBox(height: 6),
          Text(alt, style: Ref.tiny(Ref.muted)),
        ],
      ),
    );
  }
}

/// .league-badges { justify-content:space-between } span 35px · small 9px 900
class _Rozetler extends StatelessWidget {
  final String? aktifKod;
  const _Rozetler({required this.aktifKod});

  @override
  Widget build(BuildContext context) => RefCardPanel(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final (kod, emoji, ad) in kLigRozetleri)
              Expanded(
                child: Semantics(
                  label: aktifKod == kod ? '$ad ligi, şu an buradasın' : '$ad ligi',
                  excludeSemantics: true,
                  child: Opacity(
                    opacity: aktifKod == null || aktifKod == kod ? 1 : 0.55,
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: aktifKod == kod
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: const [BoxShadow(color: Color(0x5521DFAA), blurRadius: 18)],
                                border: Border.all(color: Ref.accent, width: 1.5),
                              )
                            : null,
                        // filter: drop-shadow(0 4px 8px #000)
                        child: RefDropShadow(
                          color: const Color(0xFF000000),
                          offset: const Offset(0, 4),
                          blur: 8,
                          child: Em(emoji, size: 35, height: 1.1),
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(ad,
                            maxLines: 1,
                            style: Ref.bodyText(9, weight: FontWeight.w900, color: aktifKod == kod ? Ref.accent : Ref.text)),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ]);
}

/// Liderlik satırları: referans .card-panel (flex, space-between):
/// madalya / sıra · ad · 🏆 puan
class _Tablo extends StatelessWidget {
  final LeaderboardViewModel viewModel;
  const _Tablo({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    if (vm.isLoading && vm.entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: Ref.accent)),
      );
    }
    if (vm.entries.isEmpty) {
      return RefCardPanel(children: [
        Text(vm.errorMessage ?? 'Henüz sıralamada oyuncu yok.', style: Ref.bodyText(12, color: Ref.muted)),
        if (vm.hasError) RefNeutralButton(label: 'TEKRAR DENE', onTap: vm.refresh),
      ]);
    }
    final ben = vm.myUserId;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final e in vm.entries) ...[
        _Satir(sira: e.rankPosition, ad: e.username, puan: e.mmr, lig: e.rankLabel, benim: e.userId == ben),
        const SizedBox(height: 8),
      ],
      // Oyuncu listede değilse altta kendi satırı
      if (!vm.amIInList && vm.myPosition != null && vm.myRank != null)
        _Satir(sira: vm.myPosition!, ad: 'Sen', puan: vm.myRank!.mmr, lig: vm.myRank!.label, benim: true),
    ]);
  }
}

class _Satir extends StatelessWidget {
  final int sira;
  final String ad;
  final int puan;
  final String lig;
  final bool benim;

  const _Satir({required this.sira, required this.ad, required this.puan, required this.lig, required this.benim});

  @override
  Widget build(BuildContext context) {
    final madalya = switch (sira) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Semantics(
      label: '$sira. sıra, $ad, $puan puan${benim ? ', sen' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: Ref.cardPanelGradient,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: benim ? Ref.accent : Ref.cardPanelBorder),
          boxShadow: benim ? const [BoxShadow(color: Color(0x3321DFAA), blurRadius: 14)] : null,
        ),
        child: Row(children: [
          SizedBox(
            width: 38,
            child: madalya != null
                ? Em(madalya, size: 22)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('$sira', style: Ref.bodyText(22, color: benim ? Ref.accent : Ref.text)),
                  ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(benim && ad != 'Sen' ? '$ad (sen)' : ad,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Ref.bodyText(14, weight: FontWeight.w700)),
              Text(lig, style: Ref.tiny(Ref.muted)),
            ]),
          ),
          const Em('🏆', size: 13),
          const SizedBox(width: 4),
          Text(trThousands(puan), style: Ref.bodyText(14, color: Ref.gold, weight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
