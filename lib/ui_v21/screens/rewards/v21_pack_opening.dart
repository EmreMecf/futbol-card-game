import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/router/app_routes.dart';
import '../../../features/store/domain/reveal_style.dart';
import '../../../features/store/presentation/viewmodel/pack_opening_view_model.dart';
import '../../../features/store/presentation/widgets/pack_reveal_view.dart' show progressSummary;
import 'v21_walkout.dart';
import '../../ui_v21.dart';

/// V2.1 PAKET AÇILIŞI (referans `packSeal.png` ve `packLegend.png`).
///
///   1. MÜHÜR    paket adı, HEPSİNİ GÖSTER, eğik kart arka yüzü, parıltı,
///               dokunma göstergesi, "DOKUN!", "5 kart seni bekliyor"
///   2. AÇILIŞ   ışın arka planı, "YENİ KART!", "EFSANE!", kart arka yüzden
///               döner (V21CardFlip), Elmas/Efsane'de nadirlik parlaması,
///               ilerleme noktaları, DEVAM
///      Walkout hakkı olan en iyi kart V2.1 `V21WalkoutScreen` sinematiğiyle
///   3. ÖZET     PAKET AÇILDI, en iyi kart, nadirlik dağılımı, gelişim
///               kopyaları, KOLEKSİYONA GİT / MAĞAZAYA DÖN
///
/// Sonuç sunucudan gelmiştir; ekran yalnız gösterir. Sıra, walkout kararı
/// ve "hepsini göster" mevcut `PackOpeningViewModel`'de.
class V21PackOpening extends StatelessWidget {
  final PackOpenResult result;
  final VoidCallback onClose;

  const V21PackOpening({super.key, required this.result, required this.onClose});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<PackOpeningViewModel>(
    key: ValueKey(result.packSlug + result.cards.length.toString()),
    create: (_) => PackOpeningViewModel(result),
    child: Theme(
      data: V21Theme.data(context),
      child: _Body(onClose: onClose),
    ),
  );
}

class _Body extends StatelessWidget {
  final VoidCallback onClose;
  const _Body({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PackOpeningViewModel>();
    if (vm.isFinished) return _Summary(result: vm.result, onClose: onClose);
    if (vm.isSealed) return _Seal(vm: vm);
    final card = vm.currentCard!;
    final style = vm.styleFor(card);
    if (style == RevealStyle.walkout) {
      vm.markWalkoutPlayed();
      return V21WalkoutScreen(key: ValueKey('walkout-${card.userCardId}'), card: card, onContinue: vm.next);
    }
    return _Reveal(key: ValueKey(card.userCardId), vm: vm, card: card);
  }
}

// ====================================================================
// 1. MÜHÜR
// ====================================================================
class _Seal extends StatefulWidget {
  final PackOpeningViewModel vm;
  const _Seal({required this.vm});

  @override
  State<_Seal> createState() => _SealState();
}

class _SealState extends State<_Seal> with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  Future<void> _open() async {
    if (_burst.isAnimating) return;
    if (V21Motion.cardEffects(context)) await _burst.forward();
    widget.vm.unseal();
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final n = vm.totalCount;
    return Scaffold(
      backgroundColor: V21Colors.inkDeep,
      body: LayoutBuilder(
        builder: (context, c) {
          final k = V21Scale.forSize(c.biggest).s;
          return Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.2),
                      radius: 0.85,
                      colors: [Color(0xFF6A3BC8), Color(0xFF2A1260), Color(0xFF120830)],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(child: V21Sparkles()),
              SafeArea(
                child: Semantics(
                  button: true,
                  label: 'Paketi açmak için dokun. $n kart seni bekliyor',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _open,
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16 * k, 12 * k, 12 * k, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    V21Format.upper(vm.result.packName),
                                    style: V21Type.title(28 * k, shadows: V21Type.inkShadow(k)),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 150 * k,
                                child: V21GameButton(
                                  label: 'HEPSİNİ GÖSTER',
                                  tone: V21ButtonTone.blue,
                                  size: V21ButtonSize.small,
                                  scale: k * 1.1,
                                  onPressed: vm.revealAll,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _burst,
                              builder: (context, child) => Transform.scale(
                                scale: 1 + _burst.value * 0.12,
                                child: Opacity(opacity: 1 - _burst.value * 0.6, child: child),
                              ),
                              child: SizedBox(
                                width: 260 * k,
                                height: 340 * k,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 300 * k,
                                      height: 300 * k,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(colors: [Color(0x66B79CFF), Color(0x00B79CFF)]),
                                      ),
                                    ),
                                    Transform.rotate(
                                      angle: 0.07,
                                      child: V21CardBack(width: 200 * k, semanticsLabel: ''),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 10 * k,
                                      child: V21TapHint(size: 74 * k),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        V21HeroTitle('DOKUN!', size: 56 * k),
                        SizedBox(height: 8 * k),
                        Text('$n kart seni bekliyor', style: V21Type.title(18 * k, color: const Color(0xFFD9CAFB))),
                        SizedBox(height: 22 * k),
                        _MiniBacks(count: n, scale: k),
                        SizedBox(height: 40 * k),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Alttaki küçük kart arka yüzleri (paketteki kart sayısı kadar, en çok 11)
class _MiniBacks extends StatelessWidget {
  final int count;
  final double scale;
  const _MiniBacks({required this.count, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final n = count.clamp(0, 11);
    final w = (n <= 5 ? 40 : 28) * k;
    return ExcludeSemantics(
      child: Wrap(
        spacing: 8 * k,
        runSpacing: 6 * k,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < n; i++)
            Transform.rotate(
              angle: (i - (n - 1) / 2) * 0.06,
              child: V21CardBack(width: w, semanticsLabel: ''),
            ),
        ],
      ),
    );
  }
}

// ====================================================================
// 2. KART KART AÇILIŞ
// ====================================================================
class _Reveal extends StatefulWidget {
  final PackOpeningViewModel vm;
  final InventoryCard card;
  const _Reveal({super.key, required this.vm, required this.card});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _front = false;

  @override
  void initState() {
    super.initState();
    // İlk kare arka yüzle çizilir, sonra döner (animasyon azaltılmışsa anında)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _front = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final card = widget.card;
    final r = V21Rarity.of(card.tier);
    final rare = card.tier.rank >= CardTier.diamond.rank;
    final last = vm.revealedCount + 1 >= vm.totalCount;
    final best = vm.bestCard?.userCardId == card.userCardId;
    return Scaffold(
      backgroundColor: V21Colors.inkDeep,
      body: LayoutBuilder(
        builder: (context, c) {
          final k = V21Scale.forSize(c.biggest).s;
          final cardW = math.min(260 * k, c.maxWidth - 60);
          final front = V21PlayerCard(
            name: card.fullName,
            position: card.position,
            tier: card.tier,
            power: card.power,
            seed: card.cardId,
            kitSeed: card.club ?? card.nationality,
            imageUrl: card.imageUrl,
            width: cardW,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: V21RaysBackground(
                  background: rare
                      ? const [Color(0xFF8A3FD8), Color(0xFF3A1680), Color(0xFF16082F)]
                      : const [Color(0xFF4A2BA8), Color(0xFF26135F), Color(0xFF120830)],
                ),
              ),
              const Positioned.fill(child: V21Sparkles(color: Color(0xFFFFF4D6))),
              SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: vm.next,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 24 * k, vertical: 16 * k),
                      child: Column(
                        children: [
                          Text('YENİ KART!', style: V21Type.title(20 * k, color: const Color(0xFFFFE6A0))),
                          SizedBox(height: 2 * k),
                          V21HeroTitle('${r.name}!', size: 64 * k),
                          SizedBox(height: 14 * k),
                          V21RarityGlow(
                            color: r.frameLight,
                            enabled: rare,
                            radius: 16 * cardW / V21PlayerCard.baseWidth,
                            child: V21CardFlip(
                              showFront: _front,
                              back: V21CardBack(width: cardW, semanticsLabel: 'Kart açılıyor'),
                              front: front,
                            ),
                          ),
                          SizedBox(height: 22 * k),
                          V21PageDots(count: vm.totalCount, current: vm.revealedCount, scale: k),
                          SizedBox(height: 10 * k),
                          Text(
                            best
                                ? 'Paketteki en iyi kart · ${vm.progressText}'
                                : 'Koleksiyonuna eklendi · ${vm.progressText}',
                            style: V21Type.label(13 * k, weight: FontWeight.w800, color: const Color(0xFFE3D6FF)),
                          ),
                          SizedBox(height: 26 * k),
                          SizedBox(
                            width: 300 * k,
                            child: V21GameButton(
                              label: last ? 'PAKETİ GÖR' : 'DEVAM',
                              size: V21ButtonSize.large,
                              scale: k * 1.05,
                              onPressed: vm.next,
                            ),
                          ),
                          if (!last) ...[
                            SizedBox(height: 8 * k),
                            TextButton(
                              onPressed: vm.revealAll,
                              child: Text(
                                'Hepsini göster',
                                style: V21Type.label(13 * k, weight: FontWeight.w800, color: V21Colors.textMuted),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ====================================================================
// 3. ÖZET
// ====================================================================
class _Summary extends StatelessWidget {
  final PackOpenResult result;
  final VoidCallback onClose;
  const _Summary({required this.result, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final best = result.bestCard;
    final counts = <CardTier, int>{};
    for (final c in result.cards) {
      counts[c.tier] = (counts[c.tier] ?? 0) + 1;
    }
    final tiers = CardTier.values.reversed.where((t) => (counts[t] ?? 0) > 0).toList();
    final others = result.cards.where((c) => c.userCardId != best?.userCardId).toList();
    return Scaffold(
      backgroundColor: V21Colors.inkDeep,
      body: LayoutBuilder(
        builder: (context, c) {
          final k = V21Scale.forSize(c.biggest).s;
          return Stack(
            children: [
              const Positioned.fill(child: V21RaysBackground(rayColor: Color(0x1FFFD27A))),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: V21Metrics.maxContentWidth * k),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(16 * k, 16 * k, 16 * k, 24 * k),
                      children: [
                        Text(
                          'PAKET AÇILDI',
                          textAlign: TextAlign.center,
                          style: V21Type.title(18 * k, color: const Color(0xFFFFE6A0)),
                        ),
                        Center(child: V21HeroTitle(V21Format.upper(result.packName), size: 40 * k)),
                        SizedBox(height: 14 * k),
                        if (best != null) ...[
                          Text(
                            'EN İYİ KART',
                            textAlign: TextAlign.center,
                            style: V21Type.label(12 * k, weight: FontWeight.w900, color: V21Colors.textMuted),
                          ),
                          SizedBox(height: 6 * k),
                          Center(
                            child: V21RarityGlow(
                              color: V21Rarity.of(best.tier).frameLight,
                              enabled: best.tier.rank >= CardTier.diamond.rank,
                              radius: 16 * 180 * k / V21PlayerCard.baseWidth,
                              child: V21PlayerCard(
                                name: best.fullName,
                                position: best.position,
                                tier: best.tier,
                                power: best.power,
                                seed: best.cardId,
                                kitSeed: best.club ?? best.nationality,
                                imageUrl: best.imageUrl,
                                width: 180 * k,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 14 * k),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8 * k,
                          runSpacing: 6 * k,
                          children: [
                            for (final t in tiers)
                              V21Tag(
                                text: '${counts[t]} × ${V21Rarity.of(t).name}',
                                background: V21Rarity.of(t).frameLight,
                                foreground: V21Colors.ink,
                                scale: k,
                                fontSize: 12,
                              ),
                          ],
                        ),
                        if (others.isNotEmpty) ...[
                          SizedBox(height: 14 * k),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10 * k,
                            runSpacing: 12 * k,
                            children: [
                              for (final o in others)
                                V21PlayerCard(
                                  name: o.fullName,
                                  position: o.position,
                                  tier: o.tier,
                                  power: o.power,
                                  seed: o.cardId,
                                  kitSeed: o.club ?? o.nationality,
                                  imageUrl: o.imageUrl,
                                  width: 96 * k,
                                ),
                            ],
                          ),
                        ],
                        if (result.progress.isNotEmpty) ...[
                          SizedBox(height: 14 * k),
                          V21GamePanel(
                            scale: k,
                            padding: EdgeInsets.all(12 * k),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('GELİŞİM KOPYASI', style: V21Type.title(16 * k, color: V21Colors.successText)),
                                SizedBox(height: 4 * k),
                                Text(
                                  progressSummary(result.progress),
                                  style: V21Type.label(12 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 14 * k),
                        Text(
                          '${result.cards.length} kart koleksiyonuna eklendi · kalan '
                          '${V21Format.thousands(result.coinsLeft)} altın',
                          textAlign: TextAlign.center,
                          style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                        ),
                        SizedBox(height: 16 * k),
                        V21GameButton(
                          label: 'KOLEKSİYONA GİT',
                          size: V21ButtonSize.large,
                          scale: k,
                          onPressed: () {
                            onClose();
                            GoRouter.maybeOf(context)?.go(AppRoutes.collection);
                          },
                        ),
                        SizedBox(height: 10 * k),
                        V21GameButton(
                          label: 'MAĞAZAYA DÖN',
                          tone: V21ButtonTone.blue,
                          size: V21ButtonSize.medium,
                          scale: k,
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
