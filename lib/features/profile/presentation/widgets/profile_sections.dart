import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';
import '../../../items/cosmetics/equipped_cosmetics.dart';
import '../../domain/achievements.dart';
import '../viewmodel/profile_view_model.dart';

/// Başarım → referans .tile emojisi
String achievementEmoji(Achievement a) => switch (a.id) {
      'ilk_mac' => '⚽',
      'ilk_galibiyet' => '🏆',
      'on_galibiyet' => '🔥',
      'elli_mac' => '🏟️',
      'usta_ligi' => '🛡️',
      'master_ligi' => '👑',
      _ => '🎖️',
    };

/// BAŞARIMLAR — referans .tilegrid (3 sütun). Başarımlar GERÇEK
/// sayaçlardan hesaplanır ve ödülsüzdür (bkz. [Achievement]).
class AchievementsSection extends StatelessWidget {
  final ProfileViewModel viewModel;
  final int columns;

  const AchievementsSection({super.key, required this.viewModel, this.columns = 3});

  @override
  Widget build(BuildContext context) {
    final liste = viewModel.achievements;
    final satirlar = <List<Achievement>>[];
    for (var i = 0; i < liste.length; i += columns) {
      satirlar.add(liste.sublist(i, i + columns > liste.length ? liste.length : i + columns));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefSectionHead('BAŞARIMLAR',
            trailing: Text('${viewModel.unlockedAchievementCount} / ${liste.length} AÇIK', style: Ref.tiny(Ref.accent))),
        const SizedBox(height: Ref.pageGap),
        for (var r = 0; r < satirlar.length; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: i < satirlar[r].length
                      ? AchievementTile(achievement: satirlar[r][i])
                      : const SizedBox.shrink(),
                ),
              ],
            ]),
          ),
        ],
      ],
    );
  }
}

/// Referans .tile: emoji 27px, strong 11px, small #9eb0c8.
/// Kilitli başarım soluk görünür; sağ üstte kilit / onay işareti.
class AchievementTile extends StatelessWidget {
  final Achievement achievement;

  const AchievementTile({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final acik = a.isUnlocked;
    return Semantics(
      label: '${a.title}: ${a.description}. ${acik ? 'Açıldı' : 'Kilitli, ${a.progressText}'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          gradient: Ref.tileGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: acik ? Ref.accent.withValues(alpha: 0.6) : Ref.tileBorder),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -6,
              right: -1,
              child: Icon(
                acik ? Icons.check_circle_rounded : Icons.lock_rounded,
                size: 13,
                color: acik ? Ref.accent : Ref.tileSmall,
              ),
            ),
            Opacity(
              opacity: acik ? 1 : 0.55,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Center(child: Em(achievementEmoji(a), size: 27, height: 1.36)),
                  ),
                  Text(a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Ref.bodyText(11, color: Ref.tileText, weight: FontWeight.w700)),
                  Text(
                    acik ? a.description : a.progressText,
                    // .tile small: tek satır (tam metin Semantics etiketinde)
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Ref.bodyText(10, color: Ref.tileSmall),
                  ),
                  // Çok adımlı hedeflerde ilerleme çubuğu
                  if (!acik && a.target > 1) ...[
                    const SizedBox(height: 6),
                    RefBar(a.progress, height: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Favori kartlar — referans "★ Favori futbolcu" paneli; oyunda birden
/// fazla favori olabildiği için kart şeridi.
class FavoriteCardsSection extends StatelessWidget {
  final ProfileViewModel viewModel;

  const FavoriteCardsSection({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (!viewModel.supportsFavorites) return const SizedBox.shrink();
    final kartlar = viewModel.favoriteCards;
    const genislik = 92.0;

    return RefCardPanel(children: [
      Row(children: [
        const Icon(Icons.star_rounded, size: 16, color: Ref.gold),
        const SizedBox(width: 6),
        Expanded(child: Text('Favori kartlar', style: Ref.bodyText(14, weight: FontWeight.w700))),
        GestureDetector(
          onTap: () => context.go(AppRoutes.collection),
          child: Text('KOLEKSİYON', style: Ref.caps(Ref.accent)),
        ),
      ]),
      if (kartlar.isEmpty)
        Text('Koleksiyonda bir karta dokunup "Favorilere ekle"ye basarak favorilerine ekleyebilirsin.',
            style: Ref.bodyText(11, color: Ref.muted))
      else
        SizedBox(
          height: genislik / RefCardLayout.grid.aspectRatio,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kartlar.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final InventoryCard k = kartlar[i];
              return RefPlayerCard(
                key: ValueKey('favori-${k.cardId}'),
                skin: EquippedCosmetics.current?.cardSkin,
                name: k.fullName,
                position: k.position,
                tier: k.tier,
                power: k.power,
                seed: k.cardId,
                kitSeed: k.club ?? k.nationality,
                imageUrl: k.imageUrl,
                width: genislik,
                isFavorite: true,
              );
            },
          ),
        ),
    ]);
  }
}
