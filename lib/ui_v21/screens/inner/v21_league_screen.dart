import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/leaderboard/presentation/viewmodel/league_tiers_view_model.dart';
import '../../ui_v21.dart';

/// V2.1 LİG YOLU (referans `assets/v21/screens/league.png`).
///
///   ‹ LİG YOLU                                   ( ● 1.825 )
///   [MC] MASTER CLASS  2.025+ kupa   ödül   🔒     ← üstteki ligler kilitli
///   [M ] MASTER  1.625 kupa  ▀▀▀▀░░  (SEN · M2)    ← oyuncunun ligi
///   [U ] USTA ✓   [A ] AMATÖR ✓                     ← geçilen ligler
///   Ligler yukarıdan aşağı; sol kenarda dikey yol (geçilen kısım yeşil).
///
/// VERİ: `LeagueTiersViewModel` (mevcut) → `/api/leaderboard/tiers`,
/// `/rank`, kupa yolu `/trophy-road` (açıksa her ligin giriş ödülü).
/// Referansın dilinde lig puanına "kupa" denir.
class V21LeagueScreen extends StatelessWidget {
  const V21LeagueScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<LeagueTiersViewModel>(
    create: (_) => getIt<LeagueTiersViewModel>()..initialize(),
    child: const _Body(),
  );
}

/// Lig kodu → kalkan rengi ve kısa kod (referans Lig Yolu renkleri)
(List<Color>, String) leagueShield(String code) => switch (code) {
  'master_class' => (const [Color(0xFFE3A9FA), Color(0xFF8A3FD0)], 'MC'),
  'master' => (const [Color(0xFFFFE27A), Color(0xFFE0A030)], 'M'),
  'usta' => (const [Color(0xFF9EF0FF), Color(0xFF3FB8E8)], 'U'),
  'amateur' => (const [Color(0xFFF5B98A), Color(0xFFC0703F)], 'A'),
  _ => (const [Color(0xFFC6D3E0), Color(0xFF7D8DA3)], code.isEmpty ? '?' : code[0].toUpperCase()),
};

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeagueTiersViewModel>();
    UserModel? user;
    try {
      user = context.watch<SessionManager>().user;
    } on ProviderNotFoundException {
      user = null;
    }
    final mmr = vm.myRank?.mmr ?? user?.mmr;
    return V21InnerPage(
      title: 'LİG YOLU',
      route: AppRoutes.leagueTiers,
      highlightRoute: AppRoutes.home,
      fallbackRoute: AppRoutes.home,
      state: vm.tiers.isEmpty ? (vm.hasError ? V21PageState.error : V21PageState.loading) : V21PageState.ready,
      errorMessage: vm.errorMessage,
      onRetry: vm.refresh,
      onRefresh: vm.refresh,
      trailing: (context, k) => V21ResourcePill(
        icon: V21CoinIcon(size: 24 * k),
        value: mmr,
        semanticsName: 'kupa',
        scale: k,
        width: 117,
      ),
      children: (context, k) {
        // Üstte en yüksek lig (referans): sunucu sırası tersine çevrilir
        final groups = vm.groups.reversed.toList();
        final mine = vm.myTierId;
        final myIndex = groups.indexWhere((g) => g.tiers.any((t) => t.tierId == mine));
        return [
          for (var i = 0; i < groups.length; i++)
            _LeagueRow(
              group: groups[i],
              status: myIndex < 0
                  ? _Status.locked
                  : i == myIndex
                  ? _Status.current
                  : (i > myIndex ? _Status.passed : _Status.locked),
              rank: vm.myRank,
              reward: groups[i].tiers.isEmpty ? null : vm.trophyTier(groups[i].tiers.first.tierId),
              showTopLine: i > 0,
              topLinePassed: myIndex >= 0 && i > myIndex,
              showBottomLine: i < groups.length - 1,
              bottomLinePassed: myIndex >= 0 && i >= myIndex,
              scale: k,
            ),
          SizedBox(height: 12 * k),
          Text(
            vm.trophyRoad == null
                ? 'Ligden düşme yok: en alt basamak zemin. Üst ligler daha fazla net galibiyet ister.'
                : 'Her lige İLK girişte ödül bir kez verilir. Sezon sonunda Usta ve üstü bir basamak geri iner; '
                      'geri çıkınca aynı ödül tekrar verilmez.',
            textAlign: TextAlign.center,
            style: V21Type.label(11 * k, weight: FontWeight.w600, color: V21Colors.textDim, height: 1.4),
          ),
        ];
      },
    );
  }
}

enum _Status { locked, current, passed }

class _LeagueRow extends StatelessWidget {
  final LeagueGroup group;
  final _Status status;
  final PlayerRank? rank;
  final TrophyRoadTier? reward;
  final bool showTopLine;
  final bool topLinePassed;
  final bool showBottomLine;
  final bool bottomLinePassed;
  final double scale;

  const _LeagueRow({
    required this.group,
    required this.status,
    required this.rank,
    required this.reward,
    required this.showTopLine,
    required this.topLinePassed,
    required this.showBottomLine,
    required this.bottomLinePassed,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final (colors, code) = leagueShield(group.code);
    final current = status == _Status.current;
    final locked = status == _Status.locked;
    final rewardText = reward?.rewardText ?? '';
    const passedLine = Color(0xFF6BE07A);
    const lockedLine = Color(0xFFF4B6A8);

    final shield = SizedBox(
      width: 90 * k,
      height: 100 * k,
      child: ClipPath(
        clipper: const V21ShieldClipper(),
        child: ColoredBox(
          color: V21Colors.ink,
          child: Padding(
            padding: EdgeInsets.all(4 * k),
            child: ClipPath(
              clipper: const V21ShieldClipper(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8 * k),
                    child: Text(code, style: V21Type.title(36 * k, shadows: V21Type.inkShadow(k * 1.2))),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final card = Container(
      margin: EdgeInsets.only(left: 66 * k, top: 10 * k, bottom: 22 * k),
      padding: EdgeInsets.fromLTRB(30 * k, 10 * k, 10 * k, 12 * k),
      constraints: BoxConstraints(minHeight: 120 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16 * k),
        border: Border.all(color: current ? const Color(0xFFFFC832) : V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: locked ? 0.6 : 1,
              child: Image.asset(V21Assets.chestGoldLarge, width: 72 * k, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 70 * k),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  V21Format.upper(group.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V21Type.title(
                    24 * k,
                    color: locked ? const Color(0xFFB9ADD8) : Colors.white,
                    shadows: V21Type.inkShadow(k),
                  ),
                ),
                SizedBox(height: 2 * k),
                Text(
                  '${V21Format.thousands(group.minMmr)}${locked && group.code == 'master_class' ? '+' : ''} kupa',
                  style: V21Type.label(13 * k, weight: FontWeight.w800, color: V21Colors.textMuted),
                ),
                SizedBox(height: 6 * k),
                Text(
                  rewardText.isEmpty ? 'Başlangıç' : rewardText,
                  style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                ),
                SizedBox(height: 8 * k),
                // Basamaklar (1·2·3): oyuncunun basamağı vurgulu
                Wrap(
                  spacing: 5 * k,
                  runSpacing: 4 * k,
                  children: [
                    for (final t in group.tiers)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7 * k, vertical: 2 * k),
                        decoration: BoxDecoration(
                          color: t.tierId == rank?.tierId ? const Color(0xFFFFC832) : const Color(0xFF231353),
                          borderRadius: BorderRadius.circular(10 * k),
                        ),
                        child: Text(
                          '${t.division} · ${V21Format.thousands(t.minMmr)}',
                          style: V21Type.label(
                            10 * k,
                            weight: FontWeight.w800,
                            color: t.tierId == rank?.tierId ? const Color(0xFF4A2A00) : V21Colors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                if (current && rank != null) ...[
                  SizedBox(height: 10 * k),
                  V21ProgressBar(
                    value: rank!.isTopTier ? 1 : rank!.progress,
                    height: 14 * k,
                    semanticsLabel: 'Basamak ilerlemesi',
                  ),
                ],
              ],
            ),
          ),
          if (locked)
            Positioned(
              right: 4 * k,
              top: 0,
              child: Icon(Icons.lock_rounded, size: 20 * k, color: const Color(0xFF8E7FBE)),
            ),
          if (status == _Status.passed)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 30 * k,
                height: 30 * k,
                decoration: BoxDecoration(
                  color: V21Colors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: V21Colors.ink, width: 2 * k),
                ),
                child: Icon(Icons.check_rounded, size: 20 * k, color: Colors.white),
              ),
            ),
          if (current && rank != null)
            Positioned(
              right: -6 * k,
              top: -28 * k,
              child: V21Tag(
                text: 'SEN · ${V21LeagueBadge.shortCode(rank!.leagueCode, rank!.division)}',
                background: const Color(0xFFFFC832),
                foreground: const Color(0xFF4A2A00),
                scale: k,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );

    final label = [
      V21Format.upper(group.name),
      '${V21Format.thousands(group.minMmr)} kupadan başlar',
      if (rewardText.isNotEmpty) 'ödül $rewardText${reward!.isGranted ? ', alındı' : ''}',
      switch (status) {
        _Status.current => 'şu an bu ligdesin',
        _Status.passed => 'geçildi',
        _Status.locked => 'kilitli',
      },
    ].join(', ');

    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(top: current ? 12 * k : 0),
        child: Stack(
          children: [
            // Dikey yol (kalkanın altından geçer)
            Positioned(
              left: 40 * k,
              top: 0,
              bottom: 0,
              width: 8 * k,
              child: Column(
                children: [
                  Expanded(
                    child: showTopLine
                        ? ColoredBox(color: topLinePassed ? passedLine : lockedLine)
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: showBottomLine
                        ? ColoredBox(color: bottomLinePassed ? passedLine : lockedLine)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            card,
            Positioned(left: 0, top: 0, child: shield),
          ],
        ),
      ),
    );
  }
}
