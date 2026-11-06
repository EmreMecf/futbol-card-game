import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/turkish_text.dart';

// ====================================================================
// TAKTİK GÖRSEL KİMLİĞİ
// ====================================================================
/// Her taktiğin ikonu, rengi ve kısa adı. Tek yerde tanımlı ki maç
/// ekranı, çatışma sahnesi ve geçmiş aynı dili konuşsun.
///
/// Renk seçimi taş-kâğıt-makas döngüsünü hatırlatsın diye sıcak/soğuk:
/// pres = kırmızı (saldırı), kontra = camgöbeği (hız), duvar = yeşil
/// (savunma).
extension MatchTacticStyle on MatchTactic {
  IconData get icon => switch (this) {
        MatchTactic.highPress => Icons.local_fire_department_rounded,
        MatchTactic.counterAttack => Icons.bolt_rounded,
        MatchTactic.defensiveWall => Icons.shield_rounded,
        MatchTactic.none => Icons.remove_rounded,
      };

  Color get color => switch (this) {
        MatchTactic.highPress => AppColors.dangerRed,
        MatchTactic.counterAttack => AppColors.cyan,
        MatchTactic.defensiveWall => AppColors.emerald,
        MatchTactic.none => AppColors.textSecondary,
      };

  /// Düğmelerdeki tek kelimelik ad
  String get shortLabel => switch (this) {
        MatchTactic.highPress => 'Pres',
        MatchTactic.counterAttack => 'Kontra',
        MatchTactic.defensiveWall => 'Duvar',
        MatchTactic.none => 'Yok',
      };
}

// ====================================================================
// ENERJİ GÖSTERGESİ
// ====================================================================
/// Enerji: şimşek ikonu + sayı + doluluk noktaları.
///
/// Değer SUNUCUDAN gelir ve yalnızca tur çözülünce değişir.
class EnergyMeter extends StatelessWidget {
  final int energy;
  final int maxEnergy;

  /// Seçili taktiğin harcayacağı miktar (noktalarda soluk gösterilir)
  final int pendingCost;

  const EnergyMeter({
    super.key,
    required this.energy,
    required this.maxEnergy,
    this.pendingCost = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Enerji $energy / $maxEnergy',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded,
                    size: 18, color: AppColors.victoryGold),
                Text(
                  '$energy',
                  style: AppTypography.display(
                    size: 20,
                    weight: FontWeight.w900,
                    color: AppColors.victoryGold,
                  ),
                ),
                Text(
                  '/$maxEnergy',
                  style: AppTypography.body(
                    size: 11,
                    weight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < maxEnergy; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i >= energy
                          ? AppColors.surfaceLight
                          // Harcanacak kısım soluk: "bu taktik şu kadar götürecek"
                          : i >= energy - pendingCost
                              ? AppColors.victoryGold.withValues(alpha: 0.35)
                              : AppColors.victoryGold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// TAKTİK ÇUBUĞU
// ====================================================================
/// Enerji göstergesi + üç taktik düğmesi.
///
/// Seçim sadece SEÇİMDİR: kart oynandığında taktik onunla birlikte
/// sunucuya gider; enerji kontrolü, bonus ve sonuç sunucudadır.
/// Düğmeye uzun basmak (veya fareyle üstüne gelmek) taktiğin ne işe
/// yaradığını gösterir.
class TacticBar extends StatelessWidget {
  final int energy;
  final int maxEnergy;
  final MatchTactic selected;

  /// Bu taktik şu an seçilebilir mi?
  final bool Function(MatchTactic tactic) isEnabled;
  final ValueChanged<MatchTactic> onSelect;

  const TacticBar({
    super.key,
    required this.energy,
    required this.maxEnergy,
    required this.selected,
    required this.isEnabled,
    required this.onSelect,
  });

  /// Telefon yerleşimi bu yüksekliği ayırır (bkz. match_view)
  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          EnergyMeter(
            energy: energy,
            maxEnergy: maxEnergy,
            pendingCost: selected.cost,
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final t in MatchTactic.playable) ...[
            Expanded(
              child: TacticButton(
                tactic: t,
                isSelected: selected == t,
                isEnabled: isEnabled(t),
                onTap: () => onSelect(t),
              ),
            ),
            if (t != MatchTactic.playable.last)
              const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// Tek taktik düğmesi: ikon, ad ve enerji maliyeti.
class TacticButton extends StatelessWidget {
  final MatchTactic tactic;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const TacticButton({
    super.key,
    required this.tactic,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final renk = tactic.color;
    final soluk = !isEnabled && !isSelected;

    return Tooltip(
      message: '${tactic.label} · ${tactic.cost} enerji\n${tactic.hint}',
      triggerMode: TooltipTriggerMode.longPress,
      child: Semantics(
        button: true,
        selected: isSelected,
        enabled: isEnabled,
        label: '${tactic.label}, ${tactic.cost} enerji',
        child: Opacity(
          opacity: soluk ? 0.38 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isEnabled
                  ? () {
                      GameFeedback.haptic(HapticStrength.selection);
                      onTap();
                    }
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AnimatedContainer(
                duration: AppDurations.cardSelect,
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? renk.withValues(alpha: 0.22)
                      : AppColors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected ? renk : AppColors.surfaceLight,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: renk.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tactic.icon, size: 18, color: renk),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tactic.shortLabel.toUpperTr(),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: AppTypography.display(
                              size: 12,
                              weight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${tactic.cost} enerji',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: AppTypography.body(
                              size: 9.5,
                              weight: FontWeight.w800,
                              color: AppColors.victoryGold,
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ====================================================================
// TAKTİK ROZETİ (masa ve çatışma sahnesi)
// ====================================================================
/// Oynanmış bir hamlenin taktiği.
///
/// * Taktik biliniyor ve bonus aldı  -> "PRES +9"
/// * Taktik kırıldı (bonus 0)         -> "PRES" üstü çizili
/// * Taktik GİZLİ (rakip, tur sürüyor) -> "TAKTİK ?"
/// * Taktik yok                        -> hiçbir şey çizilmez
///
/// [resolved] tur çözüldü mü? Çözülmemiş turda kendi taktiğimin
/// bonusu henüz hesaplanmadığı için "+0" değil sadece ad gösterilir.
class TacticBadge extends StatelessWidget {
  final MatchMove move;
  final bool resolved;

  const TacticBadge({super.key, required this.move, this.resolved = true});

  @override
  Widget build(BuildContext context) {
    if (move.isPass) return const SizedBox.shrink();

    final taktik = move.tactic;

    // GİZLİ: sunucu taktiği göndermedi
    if (taktik == null) {
      return const _Kapsul(
        color: AppColors.textSecondary,
        icon: Icons.help_outline_rounded,
        text: 'TAKTİK ?',
        semantics: 'Rakibin taktiği gizli',
      );
    }
    if (taktik.isNone) return const SizedBox.shrink();

    final kirildi = resolved && move.tacticBonus == 0;
    final metin = resolved && !kirildi
        ? '${taktik.shortLabel.toUpperTr()} +${move.tacticBonus}'
        : taktik.shortLabel.toUpperTr();

    return _Kapsul(
      color: taktik.color,
      icon: taktik.icon,
      text: metin,
      struck: kirildi,
      semantics: kirildi
          ? '${taktik.label} kırıldı, bonus yok'
          : '${taktik.label}${resolved ? ', artı ${move.tacticBonus}' : ''}',
    );
  }
}

class _Kapsul extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final bool struck;
  final String semantics;

  const _Kapsul({
    required this.color,
    required this.icon,
    required this.text,
    required this.semantics,
    this.struck = false,
  });

  @override
  Widget build(BuildContext context) {
    final renk = struck ? AppColors.textSecondary : color;
    return Semantics(
      label: semantics,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.obsidian.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: renk.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: renk),
              const SizedBox(width: 3),
              Text(
                text,
                style: AppTypography.display(
                  size: 11,
                  weight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: renk,
                ).copyWith(
                  decoration: struck ? TextDecoration.lineThrough : null,
                  decorationColor: renk,
                  decorationThickness: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
