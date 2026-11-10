import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/avatar2d/avatar_painter.dart';
import '../../../../shared/widgets/avatar2d/avatar_spec.dart';
import '../../../../shared/widgets/cosmetics/cosmetic_art.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../items/cosmetics/equipped_cosmetics.dart';
import '../viewmodel/profile_view_model.dart';
import '../../../items/domain/items_repository.dart';
import '../widgets/profile_sections.dart';

/// PROFİL — referans `profile()` ekranı.
///
///   .hero (ortalı)  avatar, ad, lig hapı, alt satır
///   .statrow        KAZANILAN MAÇ · KAZANMA ORANI · PUAN
///   BAŞARIMLAR      .tilegrid
///   .card-panel     ★ Favori kartlar
///   .secondary-button  LİG SIRALAMASINI GÖR
///
/// Referansta olmayan ama oyunda gerçek olanlar aynı dilde altta:
/// altın / koruma / maç sayısı satırı, son maçlar, ayarlar.
/// Avatar: oyuncuya özel 2D yüz (kullanıcı kimliğinden deterministik).
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileViewModel>(
      create: (_) => getIt<ProfileViewModel>()..initialize(),
      child: const AppShell(currentRoute: AppRoutes.profile, child: _Govde()),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final k = vm.user;
    final oran = vm.totalMatches > 0 ? '%${(vm.winRate * 100).round()}' : '—';

    return LayoutBuilder(builder: (context, kk) {
      final genis = kk.maxWidth >= 900;
      final sol = <Widget>[
        _Kimlik(viewModel: vm),
        const SizedBox(height: Ref.pageGap),
        RefStatRow([
          RefStat('${k?.wins ?? 0}', 'KAZANILAN MAÇ'),
          RefStat(oran, 'KAZANMA ORANI'),
          RefStat(trThousands(k?.mmr ?? 0), 'PUAN'),
        ]),
        const SizedBox(height: 7),
        RefStatRow([
          RefStat(trThousands(k?.coins ?? 0), 'ALTIN', valueSize: 20),
          RefStat('${vm.protectionSlots}/${GameRules.maxProtectionSlots}', 'KORUMA', valueSize: 20),
          RefStat('${vm.totalMatches}', 'MAÇ', valueSize: 20),
        ]),
        const SizedBox(height: Ref.pageGap),
        AchievementsSection(viewModel: vm),
      ];
      final sag = <Widget>[
        FavoriteCardsSection(viewModel: vm),
        if (vm.supportsFavorites) const SizedBox(height: Ref.pageGap),
        _Gecmis(viewModel: vm),
        const SizedBox(height: Ref.pageGap),
        RefSecondaryButton('LİG SIRALAMASINI GÖR', onTap: () => context.go(AppRoutes.leaderboard)),
        const SizedBox(height: 8),
        RefNeutralButton(
          onTap: () => context.push(AppRoutes.settings),
          semanticLabel: 'Ayarlar',
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.settings_rounded, size: 14, color: Ref.neutralText),
            const SizedBox(width: 6),
            Text('AYARLAR', style: Ref.bodyText(11, color: Ref.neutralText, weight: FontWeight.w800)),
          ]),
        ),
        // Ekonomi V2 (FAZ 3): envanter (servis kayıtlıysa)
        if (getIt.isRegistered<ItemsRepository>()) ...[
          const SizedBox(height: 8),
          RefNeutralButton(
            onTap: () => context.push(AppRoutes.inventory),
            semanticLabel: 'Envanter',
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.inventory_2_rounded, size: 14, color: Ref.neutralText),
              const SizedBox(width: 6),
              Text('ENVANTER', style: Ref.bodyText(11, color: Ref.neutralText, weight: FontWeight.w800)),
            ]),
          ),
        ],
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

/// .hero { text-align:center } avatar 72px · h2 ad · .pill lig · muted alt satır
class _Kimlik extends StatelessWidget {
  final ProfileViewModel viewModel;
  const _Kimlik({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final k = viewModel.user;
    final r = viewModel.rank;
    return RefHero(
      child: Column(
        children: [
          _ProfilAvatari(seed: 'oyuncu-${k?.id ?? k?.username ?? '?'}'),
          const SizedBox(height: 10),
          Text(
            (k?.username ?? 'Oyuncu').toUpperTr(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ref.heading(36, height: 0.94),
          ),
          const SizedBox(height: 8),
          RefPill(r == null ? 'LİG YÜKLENİYOR' : '${r.label.toUpperTr()} LİGİ'),
          const _SezonRozeti(),
          const SizedBox(height: 10),
          Text(
            k == null || k.totalMatches == 0
                ? 'Henüz maç oynamadın'
                : '${k.wins} galibiyet · ${k.losses} mağlubiyet · ${k.draws} beraberlik',
            textAlign: TextAlign.center,
            style: Ref.bodyText(11, color: Ref.muted),
          ),
        ],
      ),
    );
  }
}

/// FAZ 6: profil karakteri + giyilen kozmetikler (çerçeve, forma, kaptan
/// bandı). Yüz kimliği aynı kalır; yalnız forma renkleri değişir.
class _ProfilAvatari extends StatelessWidget {
  final String seed;
  const _ProfilAvatari({required this.seed});

  @override
  Widget build(BuildContext context) {
    final servis = EquippedCosmetics.current;
    Widget ciz() {
      var spec = AvatarSpec.generate(seed);
      final forma = cosmeticKitColors(servis?.kit);
      if (forma != null) spec = spec.copyWith(jersey: forma.$1, jerseyTrim: forma.$2);
      return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        CosmeticFrame(slug: servis?.frame, size: 84, child: AvatarPortrait(spec: spec, size: 84, headshot: true)),
        if (servis?.character == 'captain_band') const Positioned(right: -4, bottom: 14, child: CaptainBandBadge()),
      ]);
    }

    return servis == null ? ciz() : ListenableBuilder(listenable: servis, builder: (_, _) => ciz());
  }
}

class _SezonRozeti extends StatelessWidget {
  const _SezonRozeti();

  @override
  Widget build(BuildContext context) {
    final servis = EquippedCosmetics.current;
    if (servis == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: servis,
      builder: (_, _) => servis.badge == null
          ? const SizedBox.shrink()
          : Padding(padding: const EdgeInsets.only(top: 6), child: SeasonBadgeChip(servis.badge!)),
    );
  }
}

/// SON MAÇLAR (oyunda gerçek; referansta yok) — .card-panel satırları
class _Gecmis extends StatelessWidget {
  final ProfileViewModel viewModel;
  const _Gecmis({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final liste = viewModel.history;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RefSectionHead('SON MAÇLAR', trailing: Text('${liste.length} MAÇ', style: Ref.tiny(Ref.muted))),
      const SizedBox(height: Ref.pageGap),
      if (liste.isEmpty)
        RefCardPanel(children: [
          Text('Henüz bitmiş maçın yok.', style: Ref.bodyText(12, weight: FontWeight.w700)),
          Text('İlk maçını oyna; sonuçların burada görünür.', style: Ref.tiny(Ref.muted)),
          RefSecondaryButton('MAÇA BAŞLA', leadingGlyph: RefGlyph.swords, onTap: () => context.go(AppRoutes.matchmaking)),
        ])
      else
        for (final m in liste.take(10)) ...[
          _MacSatiri(entry: m),
          const SizedBox(height: 8),
        ],
    ]);
  }
}

class _MacSatiri extends StatelessWidget {
  final MatchHistoryEntry entry;
  const _MacSatiri({required this.entry});

  @override
  Widget build(BuildContext context) {
    final renk = switch (entry.outcome) {
      MatchOutcome.win => Ref.accent,
      MatchOutcome.loss => Ref.red,
      MatchOutcome.draw => Ref.gold,
    };
    final transfer = entry.transferText;
    final zaman = _zaman(entry.finishedAt);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: Ref.cardPanelGradient,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Ref.cardPanelBorder),
      ),
      child: Row(children: [
        Container(width: 5, height: 32, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.opponentUsername,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Ref.bodyText(13, weight: FontWeight.w700)),
            Text(transfer == null ? zaman : '$zaman · $transfer',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Ref.tiny(Ref.muted)),
          ]),
        ),
        Text(entry.scoreText, style: Ref.heading(18, weight: FontWeight.w900)),
        const SizedBox(width: 10),
        SizedBox(
          width: 58,
          child: Text(entry.outcome.shortLabel,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ref.bodyText(11, color: renk, weight: FontWeight.w900)),
        ),
      ]),
    );
  }

  /// "12 dakika önce", "Dün", "3 Eylül"
  static String _zaman(DateTime? tarih) {
    if (tarih == null) return 'Bitti';
    final fark = DateTime.now().difference(tarih.toLocal());
    if (fark.inMinutes < 1) return 'Az önce';
    if (fark.inMinutes < 60) return '${fark.inMinutes} dakika önce';
    if (fark.inHours < 24) return '${fark.inHours} saat önce';
    if (fark.inDays == 1) return 'Dün';
    if (fark.inDays < 7) return '${fark.inDays} gün önce';
    return DateFormat('d MMMM', 'tr').format(tarih.toLocal());
  }
}
