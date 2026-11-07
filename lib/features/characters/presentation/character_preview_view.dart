import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/game/game_ui.dart';
import '../../../shared/widgets/premium_card/premium_card.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../match/presentation/arena/arena_backdrop.dart';
import '../data/character_repository.dart';
import '../../match/presentation/arena/clash_scene.dart';
import 'character_preview_view_model.dart';

/// TEK KARAKTER PROTOTİPİ (Aşama A1) — geliştirici önizlemesi.
///
/// Sunucudaki gerçek kaydı gösterir (taslak katalog, oyunda görünmez).
/// Eksik olan her varlık açıkça yazılır; arena, 3B varlık olmadığı için
/// 2.5B yedekte oynar ve bunu söyler.
class CharacterPreviewView extends StatelessWidget {
  const CharacterPreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => getIt<CharacterPreviewViewModel>()..load(),
      child: const _Govde(),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CharacterPreviewViewModel>();
    final v = vm.data;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Karakter önizleme', style: AppTypography.display(size: 20, weight: FontWeight.w900)),
      ),
      body: vm.isLoading && v == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : vm.hasError && v == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: NoticeBar.warning(vm.errorMessage ?? 'Yüklenemedi',
                        title: 'Karakter alınamadı'),
                  ),
                )
              : v == null
                  ? const SizedBox.shrink()
                  : _Icerik(vm: vm, data: v),
    );
  }
}

class _Icerik extends StatelessWidget {
  final CharacterPreviewViewModel vm;
  final CharacterCardData data;

  const _Icerik({required this.vm, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = data.character;
    final p = data.proposal;
    final sunum = data.presentation;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenEdge),
      children: [
        NoticeBar.info(
          'Taslak katalog (${c.catalogVersion}) · durum: ${c.status.name} · '
          'oyunda görünmez. Güç ve özellikler Denge Motoru önerisidir.',
          title: 'PROTOTİP',
        ),
        const SizedBox(height: AppSpacing.lg),

        // ---- KART ----
        if (p == null)
          NoticeBar.warning('Denge Motoru önerisi yok; kart çizilemez.')
        else ...[
          Center(
            child: PremiumPlayerCard.fromCharacter(
              c,
              p,
              portraitUri: sunum.portraitUri,
              clubName: data.clubName,
              width: 230,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionTitle('Seviye çerçeveleri'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Aynı karakterin beş seviye görünümü (sadece çerçeve önizlemesi; '
            'oyun değeri ${p.tier.label} ${p.power}).',
            style: AppTypography.bodyS,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CardTier.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => PremiumPlayerCard.fromCharacter(
                c,
                p.copyWith(tier: CardTier.values[i]),
                portraitUri: sunum.portraitUri,
                width: 96,
                interactive: false,
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        // ---- KİMLİK ----
        const SectionTitle('Kimlik'),
        const SizedBox(height: AppSpacing.sm),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.displayName, style: AppTypography.display(size: 24, weight: FontWeight.w900)),
              Text(
                '${c.primaryPosition.label} · ${c.playstyle.label} · '
                '${data.regionName ?? c.regionCode} · ${data.clubName ?? c.clubCode}',
                style: AppTypography.bodyS,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [for (final k in c.personality) Chip(label: Text(k))],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(c.bioShort, style: AppTypography.bodyM),
              const SizedBox(height: AppSpacing.xs),
              Text(c.bioLong, style: AppTypography.bodyS),
              const SizedBox(height: AppSpacing.sm),
              Text('Üretim: ${c.createdBy} · ${c.generator}', style: AppTypography.bodyXS),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        // ---- VARLIK DURUMU ----
        const SectionTitle('Görsel ve 3B varlıklar'),
        const SizedBox(height: AppSpacing.sm),
        _VarlikDurumu(sunum: sunum),

        const SizedBox(height: AppSpacing.xl),
        // ---- ARENA ----
        const SectionTitle('Arena'),
        const SizedBox(height: AppSpacing.sm),
        _ArenaBolumu(vm: vm),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _VarlikDurumu extends StatelessWidget {
  final CharacterPresentation sunum;
  const _VarlikDurumu({required this.sunum});

  @override
  Widget build(BuildContext context) {
    Widget satir(String ad, bool var_) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(var_ ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 18, color: var_ ? AppColors.emerald : AppColors.danger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(ad, style: AppTypography.bodyM)),
              Text(var_ ? 'onaylı' : 'YOK', style: AppTypography.bodyS),
            ],
          ),
        );
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          satir('Portre', sunum.portraitUri != null),
          satir('3B model (glTF)', sunum.modelUri != null),
          satir('Rig (iskelet)', sunum.rigUri != null),
          satir('Sprite sayfası', sunum.spriteUri != null),
          const SizedBox(height: AppSpacing.sm),
          Text(
            sunum.missingClips.isEmpty
                ? 'Mevkinin bütün animasyon klipleri onaylı.'
                : 'Eksik animasyon klipleri (${sunum.missingClips.length}): '
                    '${sunum.missingClips.join(', ')}',
            style: AppTypography.bodyS,
          ),
        ],
      ),
    );
  }
}

class _ArenaBolumu extends StatefulWidget {
  final CharacterPreviewViewModel vm;
  const _ArenaBolumu({required this.vm});

  @override
  State<_ArenaBolumu> createState() => _ArenaBolumuState();
}

class _ArenaBolumuState extends State<_ArenaBolumu> {
  int _tekrar = 0;

  @override
  Widget build(BuildContext context) {
    final karar = widget.vm.renderer!;
    final olay = widget.vm.demoClash;
    final k = widget.vm.choreography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kullanılan katman: ${karar.chosen.label}',
                  style: AppTypography.body(size: 14, weight: FontWeight.w800)),
              // ✗ işareti yazı tipinde yok: ikon kullanılıyor
              for (final e in karar.skipped.entries) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.block_rounded, size: 14, color: AppColors.danger),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text('${e.key.label}: ${e.value}', style: AppTypography.bodyS),
                    ),
                  ],
                ),
              ],
              if (k != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('3B modelde oynatılacak klipler (sunucu sonucuna göre):',
                    style: AppTypography.bodyS),
                Text('Karakter: ${k.mine}', style: AppTypography.bodyS),
                Text('Rakip: ${k.opponent}', style: AppTypography.bodyS),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (olay != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              height: 460,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ArenaBackdrop(intensity: 0.55),
                  ClashScene(
                    key: ValueKey(_tekrar),
                    event: olay,
                    onFinished: () {},
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        GameButton.neutral(
          label: 'Tekrar oynat',
          icon: Icons.replay_rounded,
          onPressed: () => setState(() => _tekrar++),
        ),
      ],
    );
  }
}
