import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';

/// Kart detayı — referans `showCard()` modalı.
///
/// .modalback { background:#020810ca; backdrop-filter:blur(8px) }
/// .modal { max-width:385px; border:1px solid #786c8b; border-radius:21px;
///   background: radial-gradient(ellipse at center top,#3f31577b,transparent 70%),#0f1a2e;
///   padding:25px; gap:16px; text-align:center }
/// İçerik: .revealcard (205x295, .anim-pop) + .statrow + .cta "KOLEKSİYONA DÖN"
///
/// Referansta olmayan ama oyunda GERÇEK olan bilgiler (özellikler,
/// kulüp, kilit, Efsane kuralı, favori) aynı bileşen diliyle altta.
class CardDetailSheet extends StatelessWidget {
  final InventoryCard card;
  final bool isFavorite;

  /// Favori butonuna basılınca. `true` dönerse işlem başarılı.
  final Future<bool> Function()? onToggleFavorite;

  const CardDetailSheet({super.key, required this.card, this.isFavorite = false, this.onToggleFavorite});

  static Future<void> show(
    BuildContext context,
    InventoryCard card, {
    bool isFavorite = false,
    Future<bool> Function()? onToggleFavorite,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: Ref.modalBack,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: CardDetailSheet(card: card, isFavorite: isFavorite, onToggleFavorite: onToggleFavorite),
      ),
      transitionBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = card.attributes;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          // Gölge kaydırma alanında kesilmesin (sert kenarlı kutu oluşuyordu)
          clipBehavior: Clip.none,
          // .modalback { padding:20px }
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 385),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  // Işık, düz zeminin ÜSTÜNE karıştırılır (BoxDecoration'da
                  // degrade varken renk yok sayılır)
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.1,
                    colors: [Color.alphaBlend(Ref.modalGlow, Ref.modalBg), Ref.modalBg],
                    stops: const [0, 0.7],
                  ),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: Ref.modalBorder),
                  boxShadow: const [BoxShadow(color: Color(0xEE000000), blurRadius: 90, offset: Offset(0, 22))],
                ),
                child: LayoutBuilder(builder: (context, k) {
                  final kartGenislik = math.min(205.0, k.maxWidth);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Pop(
                        child: RefPlayerCard(
                          name: card.fullName,
                          position: card.position,
                          tier: card.tier,
                          power: card.power,
                          seed: card.cardId,
                          kitSeed: card.club ?? card.nationality,
                          imageUrl: card.imageUrl,
                          width: kartGenislik,
                          layout: RefCardLayout.reveal,
                          isLocked: card.isLocked,
                          animate: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RefStatRow([
                        RefStat('${card.power}', 'GÜÇ'),
                        RefStat(RefRarity.of(card.tier).name.toUpperCase(), 'NADİRLİK', valueSize: 20),
                        RefStat(card.position.code, 'MEVKİ'),
                      ]),
                      if (a != null && a.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        RefStatRow([
                          RefStat('${a.shooting}', 'ŞUT', valueSize: 20),
                          RefStat('${a.pace}', 'HIZ', valueSize: 20),
                          RefStat('${a.dribbling}', 'DRİBLİNG', valueSize: 20),
                        ]),
                        const SizedBox(height: 7),
                        RefStatRow([
                          RefStat('${a.acceleration}', 'HIZLANMA', valueSize: 20),
                          RefStat('${a.defending}', 'DEFANS', valueSize: 20),
                          RefStat('${a.physical}', 'FİZİK', valueSize: 20),
                        ]),
                      ],
                      if (card.club != null || card.nationality != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          [?card.club, ?card.nationality].join(' · '),
                          textAlign: TextAlign.center,
                          style: Ref.bodyText(11, color: Ref.muted),
                        ),
                      ],
                      if (card.isLocked) ...[
                        const SizedBox(height: 12),
                        const RefNote('Bu kart devam eden bir maçta kilitli. Maç bitene kadar kadrondan çıkaramazsın.',
                            title: 'Kilitli kart'),
                      ],
                      if (card.isLegend) ...[
                        const SizedBox(height: 12),
                        const RefNote(
                            'Gücü ne olursa olsun alttaki 4 nadirliği yener. Sadece gücü daha yüksek bir Efsane yenebilir.',
                            title: 'Efsane kart'),
                      ],
                      if (onToggleFavorite != null) ...[
                        const SizedBox(height: 16),
                        _FavoriButonu(baslangic: isFavorite, onToggle: onToggleFavorite!),
                      ],
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 290),
                        child: RefCta('KOLEKSİYONA DÖN', onTap: () => Navigator.of(context).maybePop()),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// .anim-pop: from { opacity:.3; scale(.65) rotate(-4deg) } .55s
/// cubic-bezier(.18,1.4,.3,1). Animasyonlar kapalıysa beklemeden görünür.
class _Pop extends StatelessWidget {
  final Widget child;
  const _Pop({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!GameFeedback.cardAnimationsEnabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Ref.pop,
      curve: Ref.popCurve,
      child: child,
      builder: (_, t, c) => Opacity(
        opacity: (0.3 + 0.7 * t).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: -4 * math.pi / 180 * (1 - t),
          child: Transform.scale(scale: 0.65 + 0.35 * t, child: c),
        ),
      ),
    );
  }
}

/// Favori düğmesi (.neutral-button). Basınca hemen değişir; sınıra
/// takılırsa geri döner ve nedenini söyler.
class _FavoriButonu extends StatefulWidget {
  final bool baslangic;
  final Future<bool> Function() onToggle;
  const _FavoriButonu({required this.baslangic, required this.onToggle});

  @override
  State<_FavoriButonu> createState() => _FavoriButonuState();
}

class _FavoriButonuState extends State<_FavoriButonu> {
  late bool _favori = widget.baslangic;

  Future<void> _bas() async {
    final onceki = _favori;
    setState(() => _favori = !onceki);
    unawaited(GameFeedback.haptic(HapticStrength.selection));
    final basarili = await widget.onToggle();
    if (!mounted) return;
    if (!basarili) {
      setState(() => _favori = onceki);
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('En fazla 50 favori kartın olabilir.')));
    }
  }

  @override
  Widget build(BuildContext context) => RefNeutralButton(
        onTap: _bas,
        semanticLabel: _favori ? 'Favorilerden çıkar' : 'Favorilere ekle',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_favori ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 15, color: _favori ? Ref.red : Ref.neutralText),
            const SizedBox(width: 6),
            Text(_favori ? 'FAVORİLERDEN ÇIKAR' : 'FAVORİLERE EKLE',
                style: Ref.bodyText(11, color: Ref.neutralText, weight: FontWeight.w800)),
          ],
        ),
      );
}
