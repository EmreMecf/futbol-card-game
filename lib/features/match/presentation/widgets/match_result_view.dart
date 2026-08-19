import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';

/// Mac bitis ekrani.
///
/// EN ONEMLI KISIM: KART TRANSFERLERI
/// Yuksek Risk Modu bu oyunun kalbi. Kaybeden oyuncu korumaya almadigi
/// 3 kartini KALICI olarak kaptirir. Oyuncu hangi kartlari kaybettigini
/// burada gormeli; envanterine girip tek tek aramak zorunda kalmamali.
class MatchResultView extends StatelessWidget {
  final MatchResultSummary? result;
  final VoidCallback onClose;

  const MatchResultView({
    super.key,
    required this.result,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final sonuc = result;

    if (sonuc == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final (renk, ikon) = _gorunum(sonuc);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // ---- BASLIK ----
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: renk.withValues(alpha: 0.15),
                        border: Border.all(
                          color: renk.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(ikon, size: 44, color: renk),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      sonuc.headline,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: renk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sonuc.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---- SKOR ----
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _skor('Sen', sonuc.myScore, AppColors.success),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              '-',
                              style: TextStyle(
                                fontSize: 22,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          _skor(
                            sonuc.opponent?.username ?? 'Rakip',
                            sonuc.opponentScore,
                            AppColors.danger,
                          ),
                        ],
                      ),
                    ),

                    // ---- KAYBEDILEN KARTLAR ----
                    if (sonuc.cardsLost.isNotEmpty)
                      _kartBolumu(
                        baslik: 'Kaybettigin kartlar',
                        aciklama:
                            'Bu kartlar KALICI olarak rakibine gecti.',
                        kartlar: sonuc.cardsLost,
                        renk: AppColors.danger,
                        ikon: Icons.trending_down,
                      ),

                    // ---- KAZANILAN KARTLAR ----
                    if (sonuc.cardsWon.isNotEmpty)
                      _kartBolumu(
                        baslik: 'Kazandigin kartlar',
                        aciklama:
                            'Bu kartlar artik senin. Koleksiyonunda.',
                        kartlar: sonuc.cardsWon,
                        renk: AppColors.success,
                        ikon: Icons.trending_up,
                      ),

                    // ---- KART DEGISMEDIYSE ----
                    if (!sonuc.hasCardTransfers) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                color: AppColors.success, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Hicbir kart el degistirmedi.',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ---- GUNCEL PROFIL ----
                    if (sonuc.myProfile != null) ...[
                      const SizedBox(height: 24),
                      _profilOzeti(sonuc.myProfile!),
                    ],
                  ],
                ),
              ),
            ),

            // ---- KAPAT ----
            Padding(
              padding: const EdgeInsets.all(24),
              child: AppButton(
                label: 'ANA SAYFAYA DON',
                icon: Icons.home,
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _gorunum(MatchResultSummary sonuc) {
    if (sonuc.isDraw) {
      return (AppColors.warning, Icons.handshake_outlined);
    }
    if (sonuc.didIWin) {
      return (AppColors.success, Icons.emoji_events);
    }
    return (AppColors.danger, Icons.sentiment_dissatisfied);
  }

  Widget _skor(String etiket, int deger, Color renk) {
    return Column(
      children: [
        Text(
          '$deger',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: renk,
          ),
        ),
        Text(
          etiket,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _kartBolumu({
    required String baslik,
    required String aciklama,
    required List<InventoryCard> kartlar,
    required Color renk,
    required IconData ikon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, color: renk, size: 18),
              const SizedBox(width: 8),
              Text(
                '$baslik (${kartlar.length})',
                style: TextStyle(
                  color: renk,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            aciklama,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kartlar.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return PremiumPlayerCard.fromInventory(
                  kartlar[index],
                  key: ValueKey(kartlar[index].userCardId),
                  width: 106,
                  interactive: false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilOzeti(UserModel profil) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _profilKutusu('Coin', '${profil.coins}', Icons.monetization_on),
          _profilKutusu('Puan', '${profil.mmr}', Icons.leaderboard),
          _profilKutusu(
            'Koruma',
            '${profil.protectionSlots}',
            Icons.shield_outlined,
          ),
          _profilKutusu(
            'G/M/B',
            '${profil.wins}/${profil.losses}/${profil.draws}',
            Icons.sports_soccer,
          ),
        ],
      ),
    );
  }

  Widget _profilKutusu(String etiket, String deger, IconData ikon) {
    return Column(
      children: [
        Icon(ikon, size: 16, color: AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(
          deger,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        Text(
          etiket,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
