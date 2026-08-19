import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';

/// Paket açılış ekranı — kartlar tek tek açılır.
///
/// NEDEN TEK TEK?
/// Bütün kartları aynı anda göstermek paketin heyecanını öldürür.
/// Sunucu kartları en iyiden kötüye sıralı gönderiyor; biz TERSTEN
/// açıyoruz. Böylece en iyi kart EN SONA kalıyor ve gerilim artıyor —
/// FIFA'nın "walkout" anının basit ama etkili bir karşılığı.
class PackRevealView extends StatefulWidget {
  final PackOpenResult result;
  final VoidCallback onClose;

  const PackRevealView({
    super.key,
    required this.result,
    required this.onClose,
  });

  @override
  State<PackRevealView> createState() => _PackRevealViewState();
}

class _PackRevealViewState extends State<PackRevealView> {
  /// Kaç kart açıldı?
  int _acilan = 0;

  /// Kartlar tersten (kötüden iyiye) açılıyor
  late final List<InventoryCard> _sira =
      widget.result.cards.reversed.toList();

  bool get _hepsiAcildi => _acilan >= _sira.length;

  InventoryCard? get _mevcut =>
      _acilan < _sira.length ? _sira[_acilan] : null;

  void _sonraki() {
    if (_hepsiAcildi) return;
    setState(() => _acilan++);
  }

  void _hepsiniAc() {
    setState(() => _acilan = _sira.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _hepsiAcildi ? _ozetEkrani() : _acilisEkrani(),
      ),
    );
  }

  // ------------------------------------------------------------------
  // TEK TEK AÇILIŞ
  // ------------------------------------------------------------------
  Widget _acilisEkrani() {
    final kart = _mevcut!;
    final tema = CardTierTheme.of(kart.tier);

    return GestureDetector(
      // Ekranın herhangi bir yerine dokunmak sonraki karta geçer
      onTap: _sonraki,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '${_acilan + 1} / ${_sira.length}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _hepsiniAc,
                  child: const Text('Hepsini göster'),
                ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: TweenAnimationBuilder<double>(
                // Her yeni kartta baştan oynasın diye key veriyoruz
                key: ValueKey(kart.userCardId),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutBack,
                builder: (context, deger, child) {
                  return Opacity(
                    opacity: deger.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.7 + deger * 0.3,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nadir kartlarda üstte bir vurgu
                    if (kart.tier.rank >= CardTier.diamond.rank)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: tema.frame,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            kart.tier == CardTier.legend
                                ? 'LEGEND!'
                                : kart.tier.label.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                    // Paket açılışı kartın vitrini: tüm efektler açık
                    PremiumPlayerCard.fromInventory(
                      kart,
                      width: 210,
                      interactive: true,
                      useGyroscope: true,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(bottom: 28),
            child: Text(
              'Devam etmek için dokun',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // ÖZET
  // ------------------------------------------------------------------
  Widget _ozetEkrani() {
    final sonuc = widget.result;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            children: [
              Icon(
                sonuc.hasRareCard ? Icons.auto_awesome : Icons.card_giftcard,
                size: 40,
                color: sonuc.hasRareCard
                    ? AppColors.tierLegend
                    : AppColors.accent,
              ),
              const SizedBox(height: 12),
              Text(
                sonuc.packName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${sonuc.cards.length} kart kazandın · '
                'kalan ${sonuc.coinsLeft} coin',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              childAspectRatio: 0.66,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemCount: sonuc.cards.length,
            itemBuilder: (context, index) {
              final kart = sonuc.cards[index];
              return LayoutBuilder(
                builder: (context, kisitlar) {
                  return PremiumPlayerCard.fromInventory(
                    kart,
                    key: ValueKey(kart.userCardId),
                    width: kisitlar.maxWidth,
                    interactive: false,
                  );
                },
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: AppButton(
            label: 'TAMAM',
            icon: Icons.check,
            onPressed: widget.onClose,
          ),
        ),
      ],
    );
  }
}
