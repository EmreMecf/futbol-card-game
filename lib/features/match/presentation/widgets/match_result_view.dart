import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/game/game_ui.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../../../../shared/widgets/walkout/confetti_overlay.dart';
import '../arena/arena_backdrop.dart';
import '../viewmodel/match_view_model.dart';

/// MAÇ SONUCU (MD bölüm 4-D, prototipteki "winpanel").
///
/// ===================================================================
/// EN ÖNEMLİ KISIM: KART TRANSFERLERİ
/// ===================================================================
/// Yüksek Risk Modu bu oyunun kalbi. Kaybeden oyuncu korumaya almadığı
/// 3 kartını KALICI olarak kaptırır. Oyuncu hangi kartları kaybettiğini
/// burada görmeli; envanterine girip tek tek aramak zorunda kalmamalı.
///
/// Gösterilen her şey sunucudan: skor, el değiştiren kartlar ve maç
/// sonrası profil. Ödül farkları ([MatchRewardDelta]) maç öncesi ile
/// sunucunun gönderdiği yeni profil arasındaki fark; bilinmiyorsa ödül
/// kutuları hiç çizilmiyor.
class MatchResultView extends StatefulWidget {
  final MatchResultSummary? result;
  final MatchRewardDelta? rewardDelta;
  final VoidCallback onClose;

  /// "Yeni maç" butonu. Null ise buton gösterilmez.
  final VoidCallback? onNewMatch;

  const MatchResultView({
    super.key,
    required this.result,
    required this.onClose,
    this.rewardDelta,
    this.onNewMatch,
  });

  @override
  State<MatchResultView> createState() => _MatchResultViewState();
}

class _MatchResultViewState extends State<MatchResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giris;
  bool _titredi = false;

  @override
  void initState() {
    super.initState();
    _giris = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (GameFeedback.cardAnimationsEnabled) {
      _giris.forward();
    } else {
      _giris.value = 1;
    }
  }

  @override
  void didUpdateWidget(MatchResultView eski) {
    super.didUpdateWidget(eski);
    // Sonuç sunucudan geç gelebilir: geldiği anda bir kez titret
    _titret();
  }

  void _titret() {
    final s = widget.result;
    if (_titredi || s == null) return;
    _titredi = true;
    GameFeedback.haptic(
      s.didIWin
          ? HapticStrength.heavy
          : (s.isDraw ? HapticStrength.light : HapticStrength.medium),
    );
  }

  @override
  void dispose() {
    _giris.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sonuc = widget.result;

    if (sonuc == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    _titret();

    final g = _Gorunum.of(sonuc);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ArenaBackdrop(intensity: 0.35),

          // Zaferde konfeti — panelin ARKASINDA.
          // Önde olduğunda skoru ve "+25 puan"ı kapatıyordu; oyuncu en
          // çok merak ettiği anda sayıları okuyamıyordu. Arkada, panelin
          // etrafından fışkırıyor.
          if (sonuc.didIWin)
            ConfettiOverlay(
              active: GameFeedback.cardAnimationsEnabled,
              colors: const [
                AppColors.victoryGold,
                AppColors.emerald,
                AppColors.cyan,
                Colors.white,
              ],
            ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.screenEdge),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          children: [
                            _ZaferPaneli(
                              sonuc: sonuc,
                              gorunum: g,
                              delta: widget.rewardDelta,
                              giris: _giris,
                            ),
                            if (sonuc.cardsLost.isNotEmpty)
                              _KartBolumu(
                                baslik: 'Kaybettiğin kartlar',
                                aciklama:
                                    'Bu kartlar KALICI olarak rakibine geçti.',
                                kartlar: sonuc.cardsLost,
                                renk: AppColors.danger,
                                ikon: Icons.trending_down_rounded,
                              ),
                            if (sonuc.cardsWon.isNotEmpty)
                              _KartBolumu(
                                baslik: 'Kazandığın kartlar',
                                aciklama:
                                    'Bu kartlar artık senin; koleksiyonunda.',
                                kartlar: sonuc.cardsWon,
                                renk: AppColors.emerald,
                                ikon: Icons.trending_up_rounded,
                              ),
                            if (!sonuc.hasCardTransfers) ...[
                              const SizedBox(height: AppSpacing.lg),
                              GlassPanel(
                                child: Row(
                                  children: [
                                    const Icon(Icons.shield_rounded,
                                        color: AppColors.emerald, size: 20),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        sonuc.isDraw
                                            ? 'Beraberlikte kimse kart kaybetmez.'
                                            : 'Hiçbir kart el değiştirmedi.',
                                        style: AppTypography.bodyM,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ---- BUTONLAR ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenEdge,
                    AppSpacing.sm,
                    AppSpacing.screenEdge,
                    AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        if (widget.onNewMatch != null) ...[
                          GameButton(
                            label: 'Yeni maç',
                            icon: Icons.sports_soccer_rounded,
                            trailingIcon: Icons.play_arrow_rounded,
                            onPressed: widget.onNewMatch,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        GameButton.neutral(
                          label: 'Ana sayfa',
                          icon: Icons.home_rounded,
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

/// Sonuca göre renk, simge ve başlık
class _Gorunum {
  final Color renk;
  final IconData ikon;
  final String baslik;
  final String alt;

  const _Gorunum(this.renk, this.ikon, this.baslik, this.alt);

  static _Gorunum of(MatchResultSummary s) {
    if (s.isDraw) {
      return const _Gorunum(
        AppColors.textSecondary,
        Icons.handshake_rounded,
        'BERABERLİK',
        'Skor eşit bitti. Kimse kart kaybetmedi.',
      );
    }
    if (s.didIWin) {
      final n = s.cardsWon.length;
      return _Gorunum(
        AppColors.victoryGold,
        Icons.emoji_events_rounded,
        'ZAFER!',
        n > 0
            ? 'Rakibinden $n kart aldın.'
            : 'Rakibinin korumasız kartı kalmamıştı.',
      );
    }
    final n = s.cardsLost.length;
    return _Gorunum(
      AppColors.danger,
      Icons.shield_rounded,
      'MAĞLUBİYET',
      n > 0
          ? '$n kartını kalıcı olarak kaptırdın.'
          : 'Korumadaki kartların sayesinde hiç kart kaybetmedin.',
    );
  }
}

// ====================================================================
// ZAFER PANELİ
// ====================================================================
class _ZaferPaneli extends StatelessWidget {
  final MatchResultSummary sonuc;
  final _Gorunum gorunum;
  final MatchRewardDelta? delta;
  final Animation<double> giris;

  const _ZaferPaneli({
    required this.sonuc,
    required this.gorunum,
    required this.delta,
    required this.giris,
  });

  @override
  Widget build(BuildContext context) {
    final g = gorunum;
    final d = delta;

    return GlassPanel(
      accentColor: g.renk,
      glow: sonuc.didIWin,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Text('MAÇ SONUCU', style: AppTypography.label),
          const SizedBox(height: AppSpacing.md),

          // ---- Kupa: büyüyerek gelir ----
          AnimatedBuilder(
            animation: giris,
            builder: (context, cocuk) => Transform.scale(
              scale: 0.6 + 0.4 * Curves.easeOutBack.transform(giris.value),
              child: Opacity(opacity: giris.value, child: cocuk),
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  g.renk.withValues(alpha: 0.30),
                  g.renk.withValues(alpha: 0),
                ]),
              ),
              child: Icon(g.ikon, size: 88, color: g.renk),
            ),
          ),

          Text(
            g.baslik,
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: 52,
              weight: FontWeight.w900,
              color: g.renk,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(g.alt, textAlign: TextAlign.center, style: AppTypography.bodyS),

          const SizedBox(height: AppSpacing.lg),

          // ---- Skor ----
          Text(
            '${sonuc.myScore} – ${sonuc.opponentScore}',
            style: AppTypography.display(size: 48, weight: FontWeight.w900),
          ),
          Text(
            'SEN · ${(sonuc.opponent?.username ?? 'RAKİP').toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label,
          ),

          // ---- Ödüller (sadece gerçek fark biliniyorsa) ----
          if (d != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: _OdulKutusu(
                    ikon: Icons.monetization_on_rounded,
                    renk: AppColors.victoryGold,
                    deger: d.coins,
                    etiket: 'Coin',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _OdulKutusu(
                    ikon: Icons.emoji_events_rounded,
                    renk: AppColors.cyan,
                    deger: d.rating,
                    etiket: 'Puan',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _OdulKutusu(
                    ikon: Icons.shield_rounded,
                    renk: AppColors.emerald,
                    deger: d.protectionSlots,
                    etiket: 'Koruma',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OdulKutusu extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final int deger;
  final String etiket;

  const _OdulKutusu({
    required this.ikon,
    required this.renk,
    required this.deger,
    required this.etiket,
  });

  @override
  Widget build(BuildContext context) {
    // İşaret her zaman yazılır: "+25", "-25", "0"
    final metin = deger > 0 ? '+$deger' : '$deger';
    final yaziRengi = deger < 0
        ? AppColors.danger
        : (deger == 0 ? AppColors.textSecondary : AppColors.textPrimary);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.obsidian.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          Icon(ikon, color: renk, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text(
            metin,
            style: AppTypography.display(
              size: 22,
              weight: FontWeight.w900,
              color: yaziRengi,
            ),
          ),
          Text(etiket, style: AppTypography.bodyXS),
        ],
      ),
    );
  }
}

// ====================================================================
// KART TRANSFERLERİ
// ====================================================================
class _KartBolumu extends StatelessWidget {
  final String baslik;
  final String aciklama;
  final List<InventoryCard> kartlar;
  final Color renk;
  final IconData ikon;

  const _KartBolumu({
    required this.baslik,
    required this.aciklama,
    required this.kartlar,
    required this.renk,
    required this.ikon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: GlassPanel(
        accentColor: renk,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, color: renk, size: 20),
                const SizedBox(width: AppSpacing.sm),
                // Expanded: büyük yazı boyutu ayarında taşmasın
                Expanded(
                  child: Text(
                    '$baslik (${kartlar.length})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 15,
                      weight: FontWeight.w900,
                      color: renk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(aciklama, style: AppTypography.bodyS),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 152,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kartlar.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    PremiumPlayerCard.fromInventory(
                  kartlar[index],
                  key: ValueKey(kartlar[index].userCardId),
                  width: 104,
                  interactive: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
