import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';

/// Macin oynandigi masa.
///
/// Ust yarida rakibin karti, alt yarida benimki. Ortada tur numarasi ve
/// beraberlikten kalan kart sayisi.
class MatchTable extends StatelessWidget {
  final MatchMove? myMove;
  final MatchMove? opponentMove;

  /// Beraberliklerden masada biriken kart sayisi
  final int potCount;
  final int roundNumber;
  final MatchRound? lastRound;
  final String? myUserId;

  const MatchTable({
    super.key,
    this.myMove,
    this.opponentMove,
    this.potCount = 0,
    this.roundNumber = 1,
    this.lastRound,
    this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF11321F), AppColors.background],
        ),
      ),
      child: Column(
        children: [
          // ---- RAKIBIN KARTI ----
          Expanded(
            child: _KartYuvasi(
              move: opponentMove,
              etiket: 'Rakip',
              bosMesaj: 'Rakip henuz kart atmadi',
            ),
          ),

          // ---- ORTA BANT ----
          _OrtaBant(
            roundNumber: roundNumber,
            potCount: potCount,
            lastRound: lastRound,
            myUserId: myUserId,
          ),

          // ---- BENIM KARTIM ----
          Expanded(
            child: _KartYuvasi(
              move: myMove,
              etiket: 'Sen',
              bosMesaj: 'Kartini sec',
            ),
          ),
        ],
      ),
    );
  }
}

class _KartYuvasi extends StatelessWidget {
  final MatchMove? move;
  final String etiket;
  final String bosMesaj;

  const _KartYuvasi({
    required this.move,
    required this.etiket,
    required this.bosMesaj,
  });

  @override
  Widget build(BuildContext context) {
    final hamle = move;

    if (hamle == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.crop_portrait,
              size: 34,
              color: AppColors.textSecondary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 6),
            Text(
              bosMesaj,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.6),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      );
    }

    // Oyuncu "bu pozisyonda kartim yok" deyip turu kaybettiyse
    if (hamle.isPass) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.danger.withValues(alpha: 0.4),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, color: AppColors.danger, size: 18),
              SizedBox(width: 8),
              Text(
                'Kart yok - tur kaybedildi',
                style: TextStyle(color: AppColors.danger, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    // Kart bilgisi eksikse (beklenmedik durum) cizmeye calisma
    final pozisyon = hamle.position;
    final seviye = hamle.tier;
    final guc = hamle.power;
    if (pozisyon == null || seviye == null || guc == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: TweenAnimationBuilder<double>(
        // Kart masaya "dusme" animasyonu
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (context, deger, child) {
          return Transform.scale(scale: 0.85 + deger * 0.15, child: child);
        },
        child: PremiumPlayerCard(
          key: ValueKey(hamle.userCardId),
          fullName: hamle.fullName ?? 'Kart',
          position: pozisyon,
          tier: seviye,
          power: guc,
          imageUrl: hamle.imageUrl,
          width: 108,
          interactive: false,
        ),
      ),
    );
  }
}

class _OrtaBant extends StatelessWidget {
  final int roundNumber;
  final int potCount;
  final MatchRound? lastRound;
  final String? myUserId;

  const _OrtaBant({
    required this.roundNumber,
    required this.potCount,
    this.lastRound,
    this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _rozet(Icons.repeat, '$roundNumber. tur', AppColors.textSecondary),

          if (potCount > 0) ...[
            const SizedBox(width: 10),
            // Beraberlikte kartlar masada kalir; sonraki turu alan
            // hepsini birden toplar.
            _rozet(
              Icons.layers,
              'Masada $potCount kart',
              AppColors.accent,
            ),
          ],

          if (lastRound != null && lastRound!.roundNumber == roundNumber - 1)
            ...[
            const SizedBox(width: 10),
            _sonTurRozeti(lastRound!),
          ],
        ],
      ),
    );
  }

  Widget _sonTurRozeti(MatchRound tur) {
    if (tur.isDraw) {
      return _rozet(Icons.remove, 'Berabere', AppColors.warning);
    }

    final benKazandim = tur.winnerId == myUserId;
    return _rozet(
      benKazandim ? Icons.arrow_downward : Icons.arrow_upward,
      benKazandim ? 'Turu aldin' : 'Turu rakip aldi',
      benKazandim ? AppColors.success : AppColors.danger,
    );
  }

  Widget _rozet(IconData ikon, String metin, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 13, color: renk),
          const SizedBox(width: 5),
          Text(
            metin,
            style: TextStyle(
              color: renk,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
