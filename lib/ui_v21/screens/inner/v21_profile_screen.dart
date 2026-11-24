import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/items/cosmetics/equipped_cosmetics.dart';
import '../../../features/items/domain/items_repository.dart';
import '../../../features/profile/domain/achievements.dart';
import '../../../features/profile/presentation/viewmodel/profile_view_model.dart';
import '../../../ui_v21/components/v21_cosmetics.dart';
import '../../ui_v21.dart';

/// V2.1 PROFİL (referans `assets/v21/screens/profile.png`).
///
///   ‹ PROFİL
///   ┌ (avatar) testoyuncu  [MASTER 2]  24G · 9M · 2B  ▀▀▀▀░  %69 kazanma ┐
///   (35 MAÇ) (1.825 KUPA) (2.450 ALTIN)
///   BAŞARIMLAR 5/6 — 3 sütun yıldız rozeti (kilitliler soluk + ilerleme)
///   [ AYARLAR ]   + (referansta olmayan, oyunda gerçek) ENVANTER · SIRALAMA
///   SON MAÇLAR
///
/// VERİ: `ProfileViewModel` (mevcut) → oturum (ad, altın, G/M/B, kupa),
/// `/api/leaderboard/rank`, `/api/match/history`; başarımlar bu veriden
/// hesaplanır. Avatar çerçevesi giyilen kozmetikten (`EquippedCosmetics`).
class V21ProfileScreen extends StatelessWidget {
  const V21ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<ProfileViewModel>(
    create: (_) => getIt<ProfileViewModel>()..initialize(),
    child: const _Body(),
  );
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    return V21InnerPage(
      title: 'PROFİL',
      route: AppRoutes.profile,
      fallbackRoute: AppRoutes.home,
      onRefresh: vm.refresh,
      children: (context, k) {
        final u = vm.user;
        final achievements = vm.achievements;
        return [
          _IdentityCard(vm: vm, scale: k),
          SizedBox(height: 12 * k),
          Row(
            children: [
              Expanded(
                child: _StatTile(value: '${vm.totalMatches}', label: 'MAÇ', color: const Color(0xFF8FC8FF), scale: k),
              ),
              SizedBox(width: 8 * k),
              Expanded(
                child: _StatTile(
                  value: V21Format.thousands(u?.mmr ?? 0),
                  label: 'KUPA',
                  color: const Color(0xFFFFD45E),
                  scale: k,
                ),
              ),
              SizedBox(width: 8 * k),
              Expanded(
                child: _StatTile(
                  value: V21Format.thousands(u?.coins ?? 0),
                  label: 'ALTIN',
                  color: const Color(0xFFFFD45E),
                  scale: k,
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * k),
          V21SectionTitle('BAŞARIMLAR ${vm.unlockedAchievementCount}/${achievements.length}', scale: k),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth / 3;
              return Wrap(
                runSpacing: 14 * k,
                children: [
                  for (final a in achievements)
                    SizedBox(
                      width: w,
                      child: _Achievement(a: a, scale: k),
                    ),
                ],
              );
            },
          ),
          SizedBox(height: 18 * k),
          V21GameButton(
            label: 'AYARLAR',
            tone: V21ButtonTone.blue,
            size: V21ButtonSize.large,
            scale: k,
            onPressed: () => context.push(AppRoutes.settings),
          ),
          SizedBox(height: 10 * k),
          Row(
            children: [
              if (getIt.isRegistered<ItemsRepository>()) ...[
                Expanded(
                  child: V21GameButton(
                    label: 'ENVANTER',
                    tone: V21ButtonTone.purple,
                    size: V21ButtonSize.small,
                    scale: k * 1.1,
                    onPressed: () => context.push(AppRoutes.inventory),
                  ),
                ),
                SizedBox(width: 8 * k),
              ],
              Expanded(
                child: V21GameButton(
                  label: 'SIRALAMA',
                  tone: V21ButtonTone.purple,
                  size: V21ButtonSize.small,
                  scale: k * 1.1,
                  semanticsLabel: 'Lig sıralamasını gör',
                  onPressed: () => context.go(AppRoutes.leaderboard),
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * k),
          V21SectionTitle('SON MAÇLAR', trailing: '${vm.history.length} MAÇ', scale: k),
          if (vm.history.isEmpty)
            Text(
              'Henüz bitmiş maçın yok. İlk maçını oyna; sonuçların burada görünür.',
              style: V21Type.label(12 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
            )
          else
            for (final m in vm.history.take(10)) ...[_MatchRow(entry: m, scale: k), SizedBox(height: 8 * k)],
        ];
      },
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final ProfileViewModel vm;
  final double scale;
  const _IdentityCard({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final u = vm.user;
    final r = vm.rank;
    final rate = vm.winRate;
    final avatar = V21PlayerAvatar(
      seed: 'oyuncu-${u?.id ?? u?.username ?? '?'}',
      semanticsLabel: 'Avatar',
      name: u?.username,
      size: 108 * k,
      ringColor: const Color(0xFFFFC832),
      background: const Color(0xFFFF9F5A),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(14 * k, 16 * k, 14 * k, 16 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18 * k),
        border: Border.all(color: V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)],
        ),
      ),
      child: Row(
        children: [
          CosmeticFrame(slug: EquippedCosmetics.current?.frame, size: 108 * k, child: avatar),
          SizedBox(width: 14 * k),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(u?.username ?? 'Oyuncu', style: V21Type.title(28 * k, shadows: V21Type.inkShadow(k))),
                ),
                SizedBox(height: 6 * k),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14 * k, vertical: 3 * k),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20 * k),
                    border: Border.all(color: V21Colors.ink, width: 2 * k),
                    gradient: const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFE0A030)]),
                  ),
                  child: Text(
                    r == null ? 'LİG' : V21Format.upper(r.label),
                    style: V21Type.title(16 * k, color: const Color(0xFF3A1E00)),
                  ),
                ),
                SizedBox(height: 8 * k),
                Text(
                  u == null || u.totalMatches == 0 ? 'Henüz maç oynamadın' : '${u.wins}G · ${u.losses}M · ${u.draws}B',
                  style: V21Type.title(17 * k, color: V21Colors.textMuted),
                ),
                SizedBox(height: 6 * k),
                V21ProgressBar(
                  value: rate,
                  height: 12 * k,
                  trackColor: const Color(0xFF201046),
                  fillColors: const [Color(0xFFFFD94E), Color(0xFFFF9307)],
                  semanticsLabel: 'Kazanma oranı',
                ),
                SizedBox(height: 4 * k),
                Text(
                  vm.totalMatches == 0 ? 'Kazanma oranı —' : '%${(rate * 100).round()} kazanma',
                  style: V21Type.label(12 * k, weight: FontWeight.w800, color: const Color(0xFFFFE3A6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final double scale;
  const _StatTile({required this.value, required this.label, required this.color, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: V21GamePanel(
        scale: k,
        radius: 14,
        padding: EdgeInsets.symmetric(vertical: 12 * k, horizontal: 6 * k),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: V21Type.title(27 * k, color: color, shadows: V21Type.inkShadow(k)),
              ),
            ),
            SizedBox(height: 4 * k),
            Text(
              label,
              style: V21Type.label(12 * k, weight: FontWeight.w800, color: V21Colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Achievement extends StatelessWidget {
  final Achievement a;
  final double scale;
  const _Achievement({required this.a, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final on = a.isUnlocked;
    return Semantics(
      label: '${a.title}: ${a.description}. ${on ? 'Açıldı' : 'İlerleme ${a.progressText}'}',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 70 * k,
            height: 70 * k,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: V21Colors.ink, width: 4 * k),
              gradient: on
                  ? RadialGradient(
                      center: const Alignment(-0.3, -0.4),
                      colors: [Color.lerp(a.color, Colors.white, 0.35)!, a.color],
                    )
                  : null,
              color: on ? null : const Color(0xFF3B2F66),
            ),
            child: Center(
              child: Icon(Icons.star_border_rounded, size: 40 * k, color: on ? V21Colors.ink : const Color(0xFF5E4F8E)),
            ),
          ),
          SizedBox(height: 6 * k),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              a.title,
              style: V21Type.label(13 * k, weight: FontWeight.w800, color: on ? Colors.white : const Color(0xFF8E7FBE)),
            ),
          ),
          if (!on)
            Text(
              a.progressText,
              style: V21Type.label(10 * k, weight: FontWeight.w700, color: V21Colors.textDim),
            ),
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final MatchHistoryEntry entry;
  final double scale;
  const _MatchRow({required this.entry, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final color = switch (entry.outcome) {
      MatchOutcome.win => V21Colors.success,
      MatchOutcome.loss => V21Colors.danger,
      MatchOutcome.draw => V21Colors.goldTop,
    };
    final transfer = entry.transferText;
    // Kazanan daha fazla kart toplamadıysa maç hükmen bitti (teslim / hamle yok)
    final hukmen = switch (entry.outcome) {
      MatchOutcome.win => entry.myScore <= entry.opponentScore,
      MatchOutcome.loss => entry.myScore >= entry.opponentScore,
      MatchOutcome.draw => false,
    };
    final etiket = hukmen ? 'Hükmen' : entry.outcome.shortLabel;
    return Semantics(
      label:
          '${entry.opponentUsername} karşı ${entry.scoreText}, ${hukmen ? '${entry.outcome.shortLabel}, hükmen' : entry.outcome.shortLabel}${transfer == null ? '' : ', $transfer'}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 10 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * k),
          border: Border.all(color: V21Colors.ink, width: 2 * k),
          color: const Color(0xFF2E1675),
        ),
        child: Row(
          children: [
            Container(
              width: 6 * k,
              height: 34 * k,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3 * k)),
            ),
            SizedBox(width: 10 * k),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.opponentUsername,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V21Type.label(14 * k, weight: FontWeight.w800),
                  ),
                  if (transfer != null)
                    Text(
                      transfer,
                      style: V21Type.label(11 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
                    ),
                ],
              ),
            ),
            Text(entry.scoreText, style: V21Type.title(20 * k)),
            SizedBox(width: 10 * k),
            V21Tag(text: etiket, background: color, foreground: Colors.white, scale: k),
          ],
        ),
      ),
    );
  }
}
