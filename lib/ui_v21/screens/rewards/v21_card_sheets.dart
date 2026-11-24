import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/progress/domain/progress_repository.dart';
import '../../ui_v21.dart';

/// V2.1 KART AYRINTISI (referans HTML demo `cardModal`: "KOLEKSİYON /
/// OYUNCU KARTI", açıklama paneli, oyun düğmeleri).
///
///   KOLEKSİYON · OYUNCU KARTI
///   büyük kart (açılış "pop" hareketi; Efsane/Elmas'ta nadirlik parlaması)
///   (GÜÇ) (NADİRLİK) (MEVKİ) · ŞUT/HIZ/DRİBLİNG/HIZLANMA/DEFANS/FİZİK çubukları
///   kulüp · uyruk · kilit / Efsane kuralı notları
///   [GELİŞİME GİT] [♥ FAVORİ] [KAPAT]
///
/// Veri yalnız sunucunun gönderdiği kart; özellikler yoksa bölüm gizlenir.
class V21CardDetailSheet extends StatelessWidget {
  final InventoryCard card;
  final bool isFavorite;

  /// `true` dönerse favori değişti; `false`: sınır (en fazla 50)
  final Future<bool> Function()? onToggleFavorite;

  const V21CardDetailSheet({super.key, required this.card, this.isFavorite = false, this.onToggleFavorite});

  static Future<void> show(
    BuildContext context,
    InventoryCard card, {
    bool isFavorite = false,
    Future<bool> Function()? onToggleFavorite,
  }) {
    final reduced = V21Motion.reduced(context);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: const Color(0xC0120933),
      transitionDuration: reduced ? Duration.zero : const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) =>
          V21CardDetailSheet(card: card, isFavorite: isFavorite, onToggleFavorite: onToggleFavorite),
      transitionBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = card.attributes;
    final r = V21Rarity.of(card.tier);
    return Theme(
      data: V21Theme.data(context),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Material(
                type: MaterialType.transparency,
                child: V21GamePanel(
                  radius: 20,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final cardW = math.min(210.0, c.maxWidth * 0.62);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'KOLEKSİYON',
                            textAlign: TextAlign.center,
                            style: V21Type.label(
                              13,
                              weight: FontWeight.w900,
                              color: const Color(0xFFFEDB70),
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'OYUNCU KARTI',
                            textAlign: TextAlign.center,
                            style: V21Type.title(
                              30,
                              shadows: const [Shadow(color: Color(0xFF1B0A57), offset: Offset(0, 4))],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: _Pop(
                              child: V21RarityGlow(
                                color: r.frameLight,
                                enabled: card.tier.rank >= CardTier.diamond.rank,
                                radius: 16 * cardW / V21PlayerCard.baseWidth,
                                child: V21PlayerCard(
                                  name: card.fullName,
                                  position: card.position,
                                  tier: card.tier,
                                  power: card.power,
                                  width: cardW,
                                  locked: card.isLocked,
                                  favorite: isFavorite,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _Fact(value: '${card.power}', label: 'GÜÇ'),
                              const SizedBox(width: 8),
                              _Fact(value: r.name, label: 'NADİRLİK', color: r.frameLight),
                              const SizedBox(width: 8),
                              _Fact(value: card.position.code, label: 'MEVKİ'),
                            ],
                          ),
                          if (card.level > 1) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Gelişim seviyesi ${card.level}',
                              textAlign: TextAlign.center,
                              style: V21Type.label(12, weight: FontWeight.w800, color: V21Colors.successText),
                            ),
                          ],
                          if (a != null && a.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            for (final (label, v) in [
                              ('ŞUT', a.shooting),
                              ('HIZ', a.pace),
                              ('DRİBLİNG', a.dribbling),
                              ('HIZLANMA', a.acceleration),
                              ('DEFANS', a.defending),
                              ('FİZİK', a.physical),
                            ])
                              _AttributeBar(label: label, value: v),
                          ],
                          if (card.club != null || card.nationality != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              [?card.club, ?card.nationality].join(' · '),
                              textAlign: TextAlign.center,
                              style: V21Type.label(12, weight: FontWeight.w700, color: V21Colors.textMuted),
                            ),
                          ],
                          if (card.isLocked)
                            const _Note(
                              icon: Icons.lock_rounded,
                              text: 'Bu kart devam eden bir maçta kilitli. Maç bitene kadar kadrondan çıkaramazsın.',
                            ),
                          if (card.isLegend)
                            const _Note(
                              icon: Icons.auto_awesome_rounded,
                              text:
                                  'Efsane kart: gücü ne olursa olsun alttaki 4 nadirliği yener. Sadece gücü daha yüksek '
                                  'bir Efsane yenebilir.',
                            ),
                          const SizedBox(height: 14),
                          if (getIt.isRegistered<ProgressRepository>()) ...[
                            V21GameButton(
                              label: 'GELİŞİME GİT',
                              size: V21ButtonSize.medium,
                              onPressed: () {
                                Navigator.of(context).maybePop();
                                GoRouter.maybeOf(context)?.push(AppRoutes.progress);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (onToggleFavorite != null) ...[
                            _FavoriteButton(initial: isFavorite, onToggle: onToggleFavorite!),
                            const SizedBox(height: 8),
                          ],
                          V21GameButton(
                            label: 'KAPAT',
                            tone: V21ButtonTone.purple,
                            size: V21ButtonSize.medium,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Açılış "pop" hareketi (küçükten büyüğe, hafif dönme)
class _Pop extends StatelessWidget {
  final Widget child;
  const _Pop({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!V21Motion.cardEffects(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: const Cubic(0.18, 1.4, 0.3, 1),
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

class _Fact extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Fact({required this.value, required this.label, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x66120933),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: V21Colors.ink, width: 2),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: V21Type.title(24, color: color)),
            ),
            Text(
              label,
              style: V21Type.label(10, weight: FontWeight.w800, color: V21Colors.textMuted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AttributeBar extends StatelessWidget {
  final String label;
  final int value;
  const _AttributeBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: V21Type.label(11, weight: FontWeight.w800, color: V21Colors.textMuted),
            ),
          ),
          Expanded(child: V21ProgressBar(value: value / 100, height: 10)),
          SizedBox(
            width: 34,
            child: Text('$value', textAlign: TextAlign.right, style: V21Type.title(16)),
          ),
        ],
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0x66120933), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: V21Colors.goldTop),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: V21Type.label(12, weight: FontWeight.w600, color: const Color(0xFFD9CAFB), height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Favori düğmesi: basınca hemen değişir; sınıra takılırsa geri döner
class _FavoriteButton extends StatefulWidget {
  final bool initial;
  final Future<bool> Function() onToggle;
  const _FavoriteButton({required this.initial, required this.onToggle});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  late bool _fav = widget.initial;

  Future<void> _press() async {
    final before = _fav;
    setState(() => _fav = !before);
    unawaited(GameFeedback.haptic(HapticStrength.selection));
    final ok = await widget.onToggle();
    if (!mounted || ok) return;
    setState(() => _fav = before);
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('En fazla 50 favori kartın olabilir.')));
  }

  @override
  Widget build(BuildContext context) => V21GameButton(
    label: _fav ? 'FAVORİDEN ÇIKAR' : 'FAVORİLERE EKLE',
    leadingIcon: _fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
    tone: V21ButtonTone.blue,
    size: V21ButtonSize.medium,
    onPressed: _press,
  );
}

// ====================================================================
// KART SEÇİCİ
// ====================================================================

/// V2.1 KART SEÇİCİ (referans HTML demo `deckModal`: "KADRO YÖNETİMİ /
/// OYUNCU DEĞİŞTİR").
///
/// Yalnız o mevkideki, kilitli olmayan ve kadroda bulunmayan kartlar gelir
/// (DeckViewModel.availableForSlot). Kartlar kimya + güce göre sıralanır;
/// her kartın köşesinde bu yuvaya konursa alacağı kimya.
class V21CardPickerSheet extends StatelessWidget {
  final CardPosition position;
  final List<InventoryCard> cards;
  final InventoryCard? current;
  final int Function(InventoryCard)? chemistryPreview;

  const V21CardPickerSheet({
    super.key,
    required this.position,
    required this.cards,
    this.current,
    this.chemistryPreview,
  });

  static Future<InventoryCard?> show(
    BuildContext context, {
    required CardPosition position,
    required List<InventoryCard> cards,
    InventoryCard? current,
    int Function(InventoryCard)? chemistryPreview,
  }) => showModalBottomSheet<InventoryCard>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) =>
        V21CardPickerSheet(position: position, cards: cards, current: current, chemistryPreview: chemistryPreview),
  );

  /// Kimya 3 puan, güç 1 puan sayılır (eski seçiciyle aynı sıralama)
  List<InventoryCard> get _sorted {
    final list = [...cards];
    final p = chemistryPreview;
    if (p == null) {
      list.sort((a, b) => a.tier.rank != b.tier.rank ? b.tier.rank.compareTo(a.tier.rank) : b.power.compareTo(a.power));
    } else {
      list.sort((a, b) => (p(b) * 3 + b.power).compareTo(p(a) * 3 + a.power));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final list = _sorted;
    return Theme(
      data: V21Theme.data(context),
      child: Container(
        height: h * 0.8,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: V21Colors.ink, width: 3)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A2BA8), Color(0xFF1E0E52)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(color: V21Colors.dash, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 10),
              Text(
                'KADRO YÖNETİMİ',
                style: V21Type.label(12, weight: FontWeight.w900, color: const Color(0xFFFEDB70), letterSpacing: 1.5),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${V21Format.upper(position.label)} SEÇ',
                        style: V21Type.title(28, shadows: V21Type.inkShadow(1)),
                      ),
                    ),
                    V21Tag(
                      text: '${cards.length} KART',
                      background: V21Colors.panel,
                      foreground: V21Colors.textMuted,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
              if (current != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Text(
                    'Şu an: ${current!.fullName} (${current!.power}). Değiştirmemek için aşağı kaydır.',
                    style: V21Type.label(12, weight: FontWeight.w700, color: V21Colors.textMuted),
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: cards.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: V21EmptyState(
                          icon: Icons.person_search_rounded,
                          title: 'UYGUN KART YOK',
                          message:
                              '${position.label} mevkisinde kullanabileceğin kart yok. Mağazadan paket açarak yeni '
                              'kartlar kazanabilirsin; devam eden maçta kilitli kartlar burada görünmez.',
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 170,
                          childAspectRatio: V21PlayerCard.baseWidth / V21PlayerCard.baseHeight,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final c = list[i];
                          final chem = chemistryPreview?.call(c);
                          return LayoutBuilder(
                            builder: (context, box) => Stack(
                              clipBehavior: Clip.none,
                              children: [
                                V21CardLift(
                                  child: V21PlayerCard(
                                    key: ValueKey(c.userCardId),
                                    name: c.fullName,
                                    position: c.position,
                                    tier: c.tier,
                                    power: c.power,
                                    width: box.maxWidth,
                                    onTap: () => Navigator.pop(context, c),
                                  ),
                                ),
                                if (chem != null)
                                  Positioned(
                                    right: -4,
                                    bottom: -6,
                                    child: Semantics(
                                      label: 'Kimya $chem',
                                      child: V21Tag(
                                        text: '+$chem KİMYA',
                                        background: chem >= 5
                                            ? V21Colors.success
                                            : (chem > 0 ? const Color(0xFFFFB01B) : const Color(0xFF6B5A9C)),
                                        foreground: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
