import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/arena_card/arena_card.dart';
import '../../../shared/widgets/arena_card/rarity_style.dart';
import '../../../shared/widgets/avatar2d/avatar_painter.dart';
import '../../../shared/widgets/avatar2d/avatar_spec.dart';
import '../../../shared/widgets/avatar2d/concept_characters.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../match/domain/clash_event.dart';
import '../../match/presentation/arena/character_stage/character_stage.dart';
import '../../match/presentation/arena/stage2d/duel_stage.dart';
import '../../match/presentation/arena/stage2d/figure_painter.dart';
import '../../match/presentation/arena/stage2d/figure_rig.dart';
import '../data/character_repository.dart';
import 'character_preview_view_model.dart';

/// 2D STİL PROTOTİPİ — tek karakter (Kaelen Brisvoy) üzerinden
/// kart + detay + arena animasyonu. Geliştirici ekranı; oyunda görünmez.
///
/// Karakter verisi sunucudan gelir (026 taslak kayıt). Yüz ve figür
/// kodla çizilir (dosya yok). Rakip ve diğer 9 karakter yalnızca KONSEPT.
class StylePrototypeView extends StatelessWidget {
  const StylePrototypeView({super.key});

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

    Widget govde;
    if (vm.isLoading && v == null) {
      govde = const Center(child: CircularProgressIndicator(color: AppColors.primary));
    } else if (vm.hasError && v == null) {
      govde = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: NoticeBar.warning(vm.errorMessage ?? 'Yüklenemedi', title: 'Karakter alınamadı'),
        ),
      );
    } else if (v == null || v.proposal == null) {
      govde = const SizedBox.shrink();
    } else {
      govde = TabBarView(
        children: [
          _KartSekmesi(data: v),
          _DetaySekmesi(data: v),
          _ArenaSekmesi(data: v),
          const _KonseptSekmesi(),
        ],
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text('2D stil prototipi', style: AppTypography.display(size: 20, weight: FontWeight.w900)),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: AppTypography.display(size: 15, weight: FontWeight.w800),
            tabs: const [
              Tab(text: 'KART'),
              Tab(text: 'DETAY'),
              Tab(text: 'ARENA'),
              Tab(text: 'KONSEPTLER'),
            ],
          ),
        ),
        body: govde,
      ),
    );
  }
}

/// Ortak: Kaelen'in çizim tanımı ve kaynağı
(AvatarSpec, String) _cizim(CharacterCardData d) => resolveAvatar(d.character);

Widget _baslik(String metin) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Text(metin, style: AppTypography.display(size: 17, weight: FontWeight.w900)),
    );

Widget _not(String metin) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(metin, style: AppTypography.body(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary)),
    );

// =====================================================================
// 1) KART
// =====================================================================
class _KartSekmesi extends StatelessWidget {
  final CharacterCardData data;
  const _KartSekmesi({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = data.character;
    final p = data.proposal!;
    final (spec, _) = _cizim(data);

    ArenaCard kart(CardTier tier, double w, {bool animate = false}) => ArenaCard(
          spec: spec,
          name: c.displayName,
          position: c.primaryPosition,
          tier: tier,
          power: p.power,
          subtitle: c.playstyle.label,
          width: w,
          animate: animate,
        );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenEdge),
      children: [
        NoticeBar.info(
          'Kimlik sunucudaki taslak kayıttan, güç Denge Motoru önerisinden (${p.balanceEngineVersion}). '
          'Yüz kodla çizilir; dosya veya ücretli üretim yok. Bu karakter henüz oyunda değil.',
          title: 'Prototip',
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(child: LayoutBuilder(builder: (context, k) {
          final w = (k.maxWidth * 0.72).clamp(180.0, 260.0);
          return kart(p.tier, w, animate: true);
        })),
        const SizedBox(height: AppSpacing.sm),
        Center(child: _not('Gerçek nadirliği: ${RarityStyle.of(p.tier).label}')),
        _baslik('5 nadirlik çerçevesi'),
        _not('Aynı karakter, sadece çerçeve örneği. Zemin hep koyu; nadirlik çerçeve, vurgu rengi, '
            'taş köşe sayısı ve efektle anlaşılır.'),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 128 / ArenaCard.aspectRatio + 26,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: CardTier.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, i) => Column(
              children: [
                kart(CardTier.values[i], 128, animate: true),
                const SizedBox(height: 6),
                Text(_efektAdi(RarityStyle.of(CardTier.values[i]).effect),
                    style: AppTypography.body(size: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        _baslik('Boyut sınıfları'),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _boyut(kart(p.tier, 96), 'Küçük (el, ızgara)'),
            _boyut(kart(p.tier, 150), 'Normal (kadro)'),
            _boyut(
              const ArenaCard(
                spec: null,
                name: 'Portresiz kart',
                position: CardPosition.defender,
                tier: CardTier.silver,
                power: 70,
                width: 96,
                animate: false,
              ),
              'Portre yoksa',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  static String _efektAdi(RarityEffect e) => switch (e) {
        RarityEffect.none => 'mat',
        RarityEffect.sheen => 'parlak yüzey',
        RarityEffect.shine => 'parlama şeridi',
        RarityEffect.prism => 'kesik yüzey',
        RarityEffect.holo => 'dönen çerçeve',
      };

  Widget _boyut(Widget k, String ad) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [k, const SizedBox(height: 6), _not(ad)],
      );
}

// =====================================================================
// 2) DETAY
// =====================================================================
class _DetaySekmesi extends StatelessWidget {
  final CharacterCardData data;
  const _DetaySekmesi({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = data.character;
    final p = data.proposal!;
    final (spec, kaynak) = _cizim(data);
    final stil = RarityStyle.of(p.tier);
    final a = p.attributes;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenEdge),
      children: [
        // ---- Başlık: portre + kimlik ----
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [stil.backgroundTop, RarityStyle.backgroundBottom],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: stil.accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.3),
                  border: Border.all(color: stil.accent, width: 2),
                ),
                child: ClipOval(child: AvatarPortrait(spec: spec, size: 112)),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.displayName.toUpperCase(),
                        style: AppTypography.display(size: 24, weight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      '${c.primaryPosition.label}'
                      '${c.secondaryPosition != null ? ' / ${c.secondaryPosition!.label}' : ''}',
                      style: AppTypography.body(size: 13, color: stil.accent),
                    ),
                    Text(c.playstyle.label, style: AppTypography.body(size: 13)),
                    Text('${data.clubName ?? c.clubCode} · ${data.regionName ?? c.regionCode}',
                        style: AppTypography.body(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                children: [
                  Text('${p.power}',
                      style: AppTypography.display(size: 40, weight: FontWeight.w900, color: stil.accentLight)),
                  Text(stil.label, style: AppTypography.display(size: 12, color: stil.accent)),
                ],
              ),
            ],
          ),
        ),

        _baslik('Özellikler'),
        for (final (ad, deger) in [
          ('ŞUT', a.shooting),
          ('HIZ', a.pace),
          ('DRİBLİNG', a.dribbling),
          ('HIZLANMA', a.acceleration),
          ('FİZİK', a.physical),
          ('DEFANS', a.defending),
        ])
          _OzellikCubugu(ad: ad, deger: deger, renk: stil.accent),
        _not('Denge Motoru önerisi; yapay zekâ güç belirlemez.'),

        _baslik('Arenadaki görünüşü'),
        _FiguSpec(
          spec: spec,
          child: Row(
            children: [
              _figurKutusu('idle'),
              _figurKutusu('run'),
              Expanded(child: _not('Kart portresiyle aynı tanımdan çizilir: yüz, saç, forma ve bileklik birebir aynı.')),
            ],
          ),
        ),

        _baslik('Kişilik'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in c.personality)
              Chip(
                label: Text(k, style: AppTypography.body(size: 12)),
                backgroundColor: AppColors.surfaceLight,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        _baslik('Hikâye'),
        Text(c.bioShort, style: AppTypography.body(size: 14)),
        const SizedBox(height: 6),
        Text(c.bioLong, style: AppTypography.body(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),

        _baslik('Teknik durum'),
        _satir('Katalog', '${c.catalogVersion} · durum: ${c.status.name} (oyunda yok)'),
        _satir('Çizim tanımı', kaynak),
        _satir('Arena katmanı', RendererKind.vector2d.label),
        _satir('Dosya varlığı', 'Gerekmez (portre, model, sprite yok ve aranmıyor)'),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _figurKutusu(String klip) => Container(
        width: 96,
        height: 128,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFF1E6B3A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _DonguFiguru(clip: klip),
      );

  Widget _satir(String a, String b) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(a, style: AppTypography.body(size: 12, color: AppColors.textSecondary))),
            Expanded(child: Text(b, style: AppTypography.body(size: 12, weight: FontWeight.w600))),
          ],
        ),
      );
}

/// Figür kutularına çizim tanımını aktarır
class _FiguSpec extends InheritedWidget {
  final AvatarSpec spec;
  const _FiguSpec({required this.spec, required super.child});

  static AvatarSpec of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_FiguSpec>()!.spec;

  @override
  bool updateShouldNotify(_FiguSpec old) => old.spec != spec;
}

class _OzellikCubugu extends StatelessWidget {
  final String ad;
  final int deger;
  final Color renk;
  const _OzellikCubugu({required this.ad, required this.deger, required this.renk});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(width: 86, child: Text(ad, style: AppTypography.display(size: 14, color: AppColors.textSecondary))),
            SizedBox(width: 34, child: Text('$deger', style: AppTypography.display(size: 16, weight: FontWeight.w900))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: deger / 99,
                  minHeight: 8,
                  color: renk,
                  backgroundColor: AppColors.surfaceLight,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Bir klibi döngüde oynatan küçük figür (detay ekranı)
class _DonguFiguru extends StatefulWidget {
  final String clip;
  const _DonguFiguru({required this.clip});

  @override
  State<_DonguFiguru> createState() => _DonguFiguruState();
}

class _DonguFiguruState extends State<_DonguFiguru> with SingleTickerProviderStateMixin {
  late final FigureClip _klip = kFigureClips[widget.clip]!;
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: _klip.durationMs))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _FiguSpec.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(painter: FigurePainter(spec, _klip.poseAt(_c.value))),
    );
  }
}

// =====================================================================
// 3) ARENA
// =====================================================================
class _ArenaSekmesi extends StatefulWidget {
  final CharacterCardData data;
  const _ArenaSekmesi({required this.data});

  @override
  State<_ArenaSekmesi> createState() => _ArenaSekmesiState();
}

class _ArenaSekmesiState extends State<_ArenaSekmesi> {
  ClashOutcome _sonuc = ClashOutcome.win;
  late CardPosition _mevki = widget.data.character.primaryPosition;
  double _hiz = 1;
  int _tekrar = 0;

  /// Aynı mevkiden rakip konsept (Kaelen hariç)
  ConceptCharacter get _rakip => kConceptCharacters.firstWhere(
        (k) => k.position == _mevki && k.slug != widget.data.character.slug,
        orElse: () => kConceptCharacters[1],
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.data.character;
    final p = widget.data.proposal!;
    final (spec, _) = _cizim(widget.data);
    final rakip = _rakip;
    final kendiMevkisi = _mevki == c.primaryPosition;
    final benimKlipler = clipsFor(_mevki, _sonuc);
    final rakipKlipler = clipsFor(_mevki, switch (_sonuc) {
      ClashOutcome.win => ClashOutcome.loss,
      ClashOutcome.loss => ClashOutcome.win,
      ClashOutcome.draw => ClashOutcome.draw,
    });

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenEdge),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 3.2,
            child: DuelStage(
              key: ValueKey('$_tekrar-$_mevki-$_sonuc-$_hiz'),
              me: DuelSide(spec: spec, name: c.displayName, tier: p.tier, power: p.power, subtitle: c.playstyle.label),
              opponent: DuelSide(
                spec: rakip.spec,
                name: rakip.name,
                tier: CardTier.silver,
                power: 79,
                subtitle: rakip.playstyle.label,
              ),
              position: _mevki,
              outcome: _sonuc,
              speed: _hiz,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => setState(() => _tekrar++),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Tekrar oynat'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _hiz = _hiz == 1 ? 0.4 : 1),
                child: Text(_hiz == 1 ? 'Yavaş çekim' : 'Normal hız'),
              ),
            ),
          ],
        ),
        _baslik('Sonuç'),
        SegmentedButton<ClashOutcome>(
          segments: const [
            ButtonSegment(value: ClashOutcome.win, label: Text('Kazanır')),
            ButtonSegment(value: ClashOutcome.loss, label: Text('Kaybeder')),
            ButtonSegment(value: ClashOutcome.draw, label: Text('Berabere')),
          ],
          selected: {_sonuc},
          onSelectionChanged: (s) => setState(() => _sonuc = s.first),
        ),
        _not('Sonuç bu önizlemede seçilir. Gerçek maçta sonucu her zaman sunucu belirler; animasyon sadece gösterir.'),
        _baslik('Mevki animasyonları'),
        Wrap(
          spacing: 6,
          children: [
            for (final m in CardPosition.values)
              ChoiceChip(
                label: Text(m == c.primaryPosition ? '${m.label} (kendi)' : m.label),
                selected: _mevki == m,
                onSelected: (_) => setState(() => _mevki = m),
              ),
          ],
        ),
        if (!kendiMevkisi)
          _not('${m(c.primaryPosition)} Bu mevki sadece animasyon gösterimi içindir; oyunda kart kendi mevkisinde oynar.'),
        const SizedBox(height: AppSpacing.md),
        _satir('Kaelen', benimKlipler.toString()),
        _satir(rakip.name, rakipKlipler.toString()),
        const SizedBox(height: AppSpacing.sm),
        _not('Rakip (${rakip.name}) sadece konsept: gücü (79) ve nadirliği gösterim içindir, oyunda yok.'),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  static String m(CardPosition p) => 'Kaelen bir ${p.label.toLowerCase()}.';

  Widget _satir(String a, String b) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(a, style: AppTypography.body(size: 12, color: AppColors.textSecondary))),
            Expanded(child: Text(b, style: AppTypography.body(size: 12, weight: FontWeight.w700))),
          ],
        ),
      );
}

// =====================================================================
// 4) KONSEPTLER
// =====================================================================
class _KonseptSekmesi extends StatelessWidget {
  const _KonseptSekmesi();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenEdge),
      children: [
        NoticeBar.info(
          'Kurgusal 10 karakter. Sadece Kaelen Brisvoy veritabanında (taslak). Diğerlerinin gücü ve '
          'oyunda karşılığı YOK; yalnızca görsel stil denemesi.',
          title: 'Konseptler',
        ),
        const SizedBox(height: AppSpacing.md),
        for (final k in kConceptCharacters) _KonseptSatiri(k: k),
      ],
    );
  }
}

class _KonseptSatiri extends StatelessWidget {
  final ConceptCharacter k;
  const _KonseptSatiri({required this.k});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF1A2130),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: AvatarPortrait(spec: k.spec, size: 76)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(k.name.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.display(size: 17, weight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: k.inDatabase ? AppColors.primary : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          k.inDatabase ? 'TASLAK KAYIT' : 'KONSEPT',
                          style: AppTypography.display(
                              size: 11, color: k.inDatabase ? AppColors.onPrimary : AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  Text('${k.position.label} · ${k.playstyle.label} · ${k.clubName}',
                      style: AppTypography.body(size: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 3),
                  Text(k.concept, style: AppTypography.body(size: 12, weight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
}
