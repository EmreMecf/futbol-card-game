import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';
import '../../../../shared/widgets/walkout/walkout.dart';
import '../../domain/reveal_style.dart';
import '../viewmodel/pack_opening_view_model.dart';
import 'pack_seal_scene.dart';

/// Paket açılış ekranı — kartlar tek tek, KADEMELİ olarak açılır.
///
/// ===================================================================
/// AKIŞ
/// ===================================================================
///   1. Mühürlü paket: dokununca açılır ("Hepsini göster" ile atlanır).
///   2. Kartlar TERSTEN (kötüden iyiye) açılır; en iyi kart sona kalır.
///   3. Her kart için [PackOpeningViewModel] bir kademe belirler:
///        Bronz/Gümüş -> hızlı dönme
///        Altın       -> parlamalı dönme
///        Elmas/Efsane (ve paketin en iyisi) -> WALKOUT (paket başına 1)
///   4. Özet: en iyi kart, nadirlik dağılımı, diğer kartlar.
///
/// Kart gösterimi referanstaki "✦ YENİ KART KEŞFEDİLDİ ✦" penceresinin
/// dilinde. İçerik tamamen sunucudan (PackOpenResult).
class PackRevealView extends StatelessWidget {
  final PackOpenResult result;
  final VoidCallback onClose;

  /// Mühürlü kutunun rengi (paketin imza seviyesi)
  final CardTier packTier;

  const PackRevealView({super.key, required this.result, required this.onClose, this.packTier = CardTier.gold});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PackOpeningViewModel>(
      // Paket sonucu değiştiğinde ViewModel de yenilensin
      key: ValueKey(result.packSlug + result.cards.length.toString()),
      create: (_) => PackOpeningViewModel(result),
      child: _PackRevealBody(onClose: onClose, packTier: packTier),
    );
  }
}

class _PackRevealBody extends StatelessWidget {
  final VoidCallback onClose;
  final CardTier packTier;

  const _PackRevealBody({required this.onClose, required this.packTier});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PackOpeningViewModel>();

    if (vm.isFinished) {
      return PackSummaryView(result: vm.result, onClose: onClose);
    }

    if (vm.isSealed) {
      return PackSealScene(result: vm.result, packTier: packTier, onOpened: vm.unseal, onSkipAll: vm.revealAll);
    }

    final kart = vm.currentCard!;
    final kademe = vm.styleFor(kart);

    // WALKOUT: kendi tam ekran sahnesi; üstüne arayüz bandı konmaz
    if (kademe.isWalkout) {
      vm.markWalkoutPlayed();
      return WalkoutScreen(key: ValueKey('walkout-${kart.userCardId}'), card: kart, onContinue: vm.next);
    }

    return _KartGosterimi(viewModel: vm, card: kart, style: kademe);
  }
}

// ====================================================================
// BASİT / ALTIN AÇILIŞ — referans "YENİ KART KEŞFEDİLDİ" penceresi
// ====================================================================
/// Referans `openPack()` modalı:
///   .caps.gold "✦ YENİ KART KEŞFEDİLDİ ✦" · .revealcard (açılış hareketi)
///   h2.gold "TEBRİKLER!" · muted "Kart koleksiyonuna eklendi." · .cta
///
/// Kart dönme animasyonu korunur (Bronz/Gümüş hızlı, Altın parlamalı).
/// "Hepsini göster" ile atlanabilir.
class _KartGosterimi extends StatelessWidget {
  final PackOpeningViewModel viewModel;
  final InventoryCard card;
  final RevealStyle style;

  const _KartGosterimi({required this.viewModel, required this.card, required this.style});

  @override
  Widget build(BuildContext context) {
    final nadir = card.tier.rank >= CardTier.diamond.rank;
    final iyi = card.tier.rank >= CardTier.gold.rank;
    final sonKart = viewModel.revealedCount + 1 >= viewModel.totalCount;

    return Scaffold(
      backgroundColor: Ref.phoneBg,
      body: SafeArea(
        child: GestureDetector(
          onTap: viewModel.next,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              clipBehavior: Clip.none,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 385),
                child: _RefModal(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const RefGlyphIcon(RefGlyph.sparkle, size: 9, color: Ref.gold),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              nadir
                                  ? 'BİR TANE DAHA ${RefRarity.of(card.tier).name.toUpperTr()}!'
                                  : 'YENİ KART KEŞFEDİLDİ',
                              maxLines: 1,
                              style: Ref.caps(Ref.gold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const RefGlyphIcon(RefGlyph.sparkle, size: 9, color: Ref.gold),
                      ],
                    ),
                    RefPill(viewModel.progressText),
                    // ValueKey: her yeni kartta dönme baştan oynasın
                    LayoutBuilder(
                      builder: (context, k) => CardFlipReveal(
                        key: ValueKey(card.userCardId),
                        card: card,
                        style: style,
                        width: k.maxWidth.clamp(0.0, 205.0),
                      ),
                    ),
                    Text(
                      iyi ? 'TEBRİKLER!' : card.fullName.toUpperTr(),
                      textAlign: TextAlign.center,
                      style: Ref.heading(36, color: Ref.gold),
                    ),
                    Text('Kart koleksiyonuna eklendi.', style: Ref.bodyText(14, color: Ref.muted)),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 290),
                      child: RefCta(sonKart ? 'PAKETİ GÖR' : 'SIRADAKİ KART', onTap: viewModel.next),
                    ),
                    if (!sonKart) RefNeutralButton(label: 'Hepsini göster', onTap: viewModel.revealAll),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// .modal { max-width:385px; border:1px solid #786c8b; border-radius:21px;
///   background:radial-gradient(ellipse at center top,#3f31577b,transparent 70%),#0f1a2e;
///   padding:25px; gap:16px; box-shadow:0 22px 90px #000e; text-align:center }
class _RefModal extends StatelessWidget {
  final List<Widget> children;
  const _RefModal({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topCenter,
        radius: 1.1,
        colors: [Color.alphaBlend(Ref.modalGlow, Ref.modalBg), Ref.modalBg],
        stops: const [0, 0.7],
      ),
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: Ref.modalBorder),
      boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 40, offset: Offset(0, 18))],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
      ],
    ),
  );
}

// ====================================================================
// PAKET SONUCU
// ====================================================================
/// Paketin özeti: en iyi kart öne çıkar, altında nadirlik dağılımı ve
/// diğer kartlar (sunucunun sırasıyla). Referans dili: .caps.gold başlık,
/// .revealcard, .collect-grid kartları, .cta.
class PackSummaryView extends StatelessWidget {
  final PackOpenResult result;
  final VoidCallback onClose;

  const PackSummaryView({super.key, required this.result, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final enIyi = result.bestCard;
    final digerleri = result.cards.where((k) => k.userCardId != enIyi?.userCardId).toList();

    final dagilim = <CardTier, int>{};
    for (final k in result.cards) {
      dagilim[k.tier] = (dagilim[k.tier] ?? 0) + 1;
    }
    final seviyeler = dagilim.keys.toList()..sort((a, b) => b.rank.compareTo(a.rank));

    RefPlayerCard kart(InventoryCard k, double w, {bool vitrin = false}) => RefPlayerCard(
      key: ValueKey(vitrin ? 'enIyi-${k.userCardId}' : k.userCardId),
      name: k.fullName,
      position: k.position,
      tier: k.tier,
      power: k.power,
      seed: k.cardId,
      kitSeed: k.club ?? k.nationality,
      imageUrl: k.imageUrl,
      width: w,
      layout: vitrin ? RefCardLayout.reveal : RefCardLayout.grid,
      animate: vitrin,
    );

    return Scaffold(
      backgroundColor: Ref.phoneBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, k) {
                  final kenar = (k.maxWidth - 720).clamp(0.0, double.infinity) / 2;
                  final genislik = k.maxWidth - kenar * 2 - Ref.pagePadding.horizontal;
                  final sutun = genislik < 520 ? 3 : 5;
                  final dolgu = EdgeInsets.fromLTRB(14 + kenar, 14, 14 + kenar, Ref.pageGap);
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: dolgu,
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const RefGlyphIcon(RefGlyph.sparkle, size: 9, color: Ref.gold),
                                  const SizedBox(width: 5),
                                  Text('PAKET AÇILDI', style: Ref.caps(Ref.gold)),
                                  const SizedBox(width: 5),
                                  const RefGlyphIcon(RefGlyph.sparkle, size: 9, color: Ref.gold),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                result.packName.toUpperTr(),
                                textAlign: TextAlign.center,
                                style: Ref.h2(result.hasRareCard ? Ref.gold : Ref.text),
                              ),
                              const SizedBox(height: Ref.pageGap),
                              if (enIyi != null) ...[
                                kart(enIyi, 168, vitrin: true),
                                const SizedBox(height: 8),
                                Text('EN İYİ KART', style: Ref.caps(Ref.muted)),
                                const SizedBox(height: Ref.pageGap),
                              ],
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 6,
                                runSpacing: 6,
                                children: [for (final t in seviyeler) _SeviyeSayaci(tier: t, count: dagilim[t]!)],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (digerleri.isNotEmpty)
                        SliverPadding(
                          padding: dolgu.copyWith(top: 0),
                          sliver: SliverGrid.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: sutun,
                              crossAxisSpacing: 7,
                              mainAxisSpacing: 7,
                              childAspectRatio: RefCardLayout.grid.aspectRatio,
                            ),
                            itemCount: digerleri.length,
                            itemBuilder: (context, i) =>
                                LayoutBuilder(builder: (context, kk) => kart(digerleri[i], kk.maxWidth)),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            // ---- ALT BANT ----
            Container(
              decoration: const BoxDecoration(
                color: Ref.navBg,
                border: Border(top: BorderSide(color: Ref.navBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${result.cards.length} kart koleksiyonuna eklendi · kalan ${trThousands(result.coinsLeft)} altın',
                        textAlign: TextAlign.center,
                        style: Ref.bodyText(11, color: Ref.muted),
                      ),
                      const SizedBox(height: 8),
                      RefCta(
                        'KOLEKSİYONA GİT',
                        fontSize: 21,
                        onTap: () {
                          onClose();
                          GoRouter.maybeOf(context)?.go(AppRoutes.collection);
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: RefNeutralButton(label: 'MAĞAZAYA DÖN', onTap: onClose),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 × ALTIN" — nadirlik renginde hap
class _SeviyeSayaci extends StatelessWidget {
  final CardTier tier;
  final int count;

  const _SeviyeSayaci({required this.tier, required this.count});

  @override
  Widget build(BuildContext context) {
    final r = RefRarity.of(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1424),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: r.color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count ×', style: Ref.heading(14, weight: FontWeight.w900)),
          const SizedBox(width: 5),
          Text(
            r.name.toUpperTr(),
            style: Ref.bodyText(10, color: r.color, weight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
