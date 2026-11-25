import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/leaderboard/presentation/viewmodel/leaderboard_view_model.dart';
import '../../ui_v21.dart';
import 'v21_league_screen.dart' show leagueShield;
import '../../../core/l10n/app_language.dart';

/// V2.1 SIRALAMA (liderlik tablosu). HTML referansında karşılığı yok;
/// Lig Yolu ve Profil ekranlarının dilinden türetildi.
///
///   ‹ SIRALAMA                                   ( ● 1.825 )
///   ┌ [M] MASTER 2  1.825 kupa  ▀▀▀▀░░  50 kupa sonra Master 3 (2 galibiyet) ┐
///   kürsü: 2. · 1. · 3.  (avatar, ad, kupa)
///   4…50 satırları; oyuncunun satırı altın kenarlı; listede değilse ayrıca
///   [ LİG YOLU ] [ DERECELİ MAÇ OYNA ]
///
/// VERİ: `LeaderboardViewModel` (mevcut) → `/api/leaderboard` ve `/rank`.
/// Sıra numaralarını SUNUCU verir; istemci saymaz.
class V21LeaderboardScreen extends StatelessWidget {
  const V21LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<LeaderboardViewModel>(
    create: (_) => getIt<LeaderboardViewModel>()..initialize(),
    child: const _Body(),
  );
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeaderboardViewModel>();
    final entries = vm.entries;
    return V21InnerPage(
      title: 'SIRALAMA'.tr,
      route: AppRoutes.leaderboard,
      highlightRoute: AppRoutes.home,
      fallbackRoute: AppRoutes.home,
      onRefresh: vm.refresh,
      trailing: (context, k) => V21ResourcePill(
        icon: V21CoinIcon(size: 24 * k),
        value: vm.myRank?.mmr,
        semanticsName: 'kupa'.tr,
        scale: k,
        width: 117,
      ),
      children: (context, k) => [
        _MyRank(rank: vm.myRank, position: vm.myPosition, scale: k),
        SizedBox(height: 16 * k),
        if (vm.isLoading && entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator(color: V21Colors.goldTop)),
          )
        else if (entries.isEmpty)
          V21EmptyState(
            icon: vm.hasError ? Icons.cloud_off_rounded : Icons.emoji_events_rounded,
            title: vm.hasError ? 'BAĞLANTI SORUNU'.tr : 'SIRALAMA BOŞ'.tr,
            message: vm.errorMessage ?? 'Henüz sıralamada oyuncu yok. İlk dereceli maçı oynayan sen ol!'.tr,
            actionLabel: vm.hasError ? 'TEKRAR DENE'.tr : null,
            onAction: vm.hasError ? vm.refresh : null,
            scale: k,
          )
        else ...[
          if (entries.length >= 3) ...[
            _Podium(top: entries.take(3).toList(), myId: vm.myUserId, scale: k),
            SizedBox(height: 14 * k),
          ],
          for (final e in entries.skip(entries.length >= 3 ? 3 : 0)) ...[
            // 056: oyuncuya dokun → açık profil
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(AppRoutes.playerFor(e.userId)),
              child: _Row(
                position: e.rankPosition,
                name: e.userId == vm.myUserId ? '{username} (sen)'.trArgs({'username': e.username}) : e.username,
                league: e.rankLabel,
                points: e.mmr,
                me: e.userId == vm.myUserId,
                seed: 'oyuncu-${e.userId}',
                scale: k,
              ),
            ),
            SizedBox(height: 8 * k),
          ],
          if (!vm.amIInList && vm.myPosition != null && vm.myRank != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4 * k),
              child: Center(
                child: Icon(Icons.more_vert_rounded, color: V21Colors.textDim, size: 22 * k),
              ),
            ),
            _Row(
              position: vm.myPosition!,
              name: 'Sen'.tr,
              league: vm.myRank!.label,
              points: vm.myRank!.mmr,
              me: true,
              seed: 'oyuncu-${vm.myUserId ?? 'ben'}',
              scale: k,
            ),
          ],
        ],
        SizedBox(height: 16 * k),
        Row(
          children: [
            Expanded(
              child: V21GameButton(
                label: 'LİG YOLU'.tr,
                tone: V21ButtonTone.blue,
                size: V21ButtonSize.medium,
                scale: k,
                onPressed: () => context.push(AppRoutes.leagueTiers),
              ),
            ),
            SizedBox(width: 10 * k),
            Expanded(
              child: V21GameButton(
                label: 'MAÇ OYNA'.tr,
                size: V21ButtonSize.medium,
                scale: k,
                semanticsLabel: 'Dereceli maç oyna'.tr,
                onPressed: () => context.go(AppRoutes.matchmaking),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MyRank extends StatelessWidget {
  final PlayerRank? rank;
  final int? position;
  final double scale;
  const _MyRank({required this.rank, required this.position, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final r = rank;
    final (colors, code) = leagueShield(r?.leagueCode ?? '');
    final String detail;
    if (r == null) {
      detail = 'Lig bilgisi yükleniyor'.tr;
    } else if (r.isTopTier || r.nextLabel == null) {
      detail = 'En üst basamaktasın'.tr;
    } else {
      detail = '{pointsToNext} kupa sonra {nextLabel} ({winsToNext} galibiyet)'.trArgs({'pointsToNext': r.pointsToNext, 'nextLabel': r.nextLabel, 'winsToNext': r.winsToNext});
    }
    return Semantics(
      container: true,
      label: [
        if (r != null) 'Ligin {label}, {mmr} kupa'.trArgs({'label': r.label, 'mmr': r.mmr}),
        if (position != null) 'sıralamada {position}.'.trArgs({'position': position}),
        detail,
      ].join(', '),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(12 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18 * k),
          border: Border.all(color: const Color(0xFFFFC832), width: 3 * k),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)],
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 70 * k,
              height: 78 * k,
              child: ClipPath(
                clipper: const V21ShieldClipper(),
                child: ColoredBox(
                  color: V21Colors.ink,
                  child: Padding(
                    padding: EdgeInsets.all(3 * k),
                    child: ClipPath(
                      clipper: const V21ShieldClipper(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: colors,
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 6 * k),
                            child: Text(
                              r == null ? '?' : '$code${r.division}',
                              style: V21Type.title(26 * k, shadows: V21Type.inkShadow(k)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12 * k),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r == null ? 'LİG'.tr : V21Format.upper(r.label),
                          style: V21Type.title(24 * k, shadows: V21Type.inkShadow(k)),
                        ),
                      ),
                      if (position != null)
                        V21Tag(
                          text: '$position.',
                          background: const Color(0xFFFFC832),
                          foreground: const Color(0xFF4A2A00),
                          scale: k,
                          fontSize: 13,
                        ),
                    ],
                  ),
                  SizedBox(height: 6 * k),
                  V21ProgressBar(
                    value: r == null ? 0 : (r.isTopTier ? 1 : r.progress),
                    height: 12 * k,
                    semanticsLabel: 'Basamak ilerlemesi'.tr,
                  ),
                  SizedBox(height: 5 * k),
                  Text(
                    detail,
                    style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// İlk üç: ortada 1., solda 2., sağda 3. (yükseklikler 1 > 2 > 3)
class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> top;
  final String? myId;
  final double scale;
  const _Podium({required this.top, required this.myId, required this.scale});

  static const _medal = [Color(0xFFFFC832), Color(0xFFD5E0EC), Color(0xFFE09A62)];

  @override
  Widget build(BuildContext context) {
    final k = scale;
    Widget spot(LeaderboardEntry e, double height) {
      final i = e.rankPosition - 1;
      final color = _medal[i.clamp(0, 2)];
      final me = e.userId == myId;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(AppRoutes.playerFor(e.userId)),
          child: Semantics(
            label: '{rankPosition}. sıra, {username}{p}, {mmr} kupa, {rankLabel}'.trArgs({'rankPosition': e.rankPosition, 'username': e.username, 'p': me ? ' (sen)' : '', 'mmr': e.mmr, 'rankLabel': e.rankLabel}),
            excludeSemantics: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                V21PlayerAvatar(
                  seed: 'oyuncu-${e.userId}',
                  semanticsLabel: e.username,
                  size: (i == 0 ? 68 : 56) * k,
                  ringColor: color,
                  background: const Color(0xFF7FC0FF),
                ),
                SizedBox(height: 4 * k),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    me ? '{username} (sen)'.trArgs({'username': e.username}) : e.username,
                    maxLines: 1,
                    style: V21Type.title(15 * k, color: me ? V21Colors.goldTop : Colors.white),
                  ),
                ),
                Text(
                  V21Format.thousands(e.mmr),
                  style: V21Type.label(12 * k, weight: FontWeight.w800, color: color),
                ),
                SizedBox(height: 4 * k),
                Container(
                  height: height * k,
                  margin: EdgeInsets.symmetric(horizontal: 6 * k),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12 * k)),
                    border: Border.all(color: V21Colors.ink, width: 3 * k),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color, Color.lerp(color, V21Colors.ink, 0.55)!],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text('${e.rankPosition}', style: V21Type.title(30 * k, shadows: V21Type.inkShadow(k))),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [spot(top[1], 64), spot(top[0], 86), spot(top[2], 48)],
    );
  }
}

class _Row extends StatelessWidget {
  final int position;
  final String name;
  final String league;
  final int points;
  final bool me;
  final String seed;
  final double scale;

  const _Row({
    required this.position,
    required this.name,
    required this.league,
    required this.points,
    required this.me,
    required this.seed,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Semantics(
      label: '{position}. sıra, {name}, {points} kupa, {league}{p}'.trArgs({'position': position, 'name': name, 'points': points, 'league': league, 'p': me ? ', sen'.tr : ''}),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * k, vertical: 8 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * k),
          border: Border.all(color: me ? const Color(0xFFFFC832) : V21Colors.ink, width: (me ? 3 : 2) * k),
          color: me ? const Color(0xFF3A1F86) : const Color(0xFF2E1675),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 38 * k,
              child: Text(
                '$position',
                textAlign: TextAlign.center,
                style: V21Type.title(22 * k, color: me ? V21Colors.goldTop : Colors.white),
              ),
            ),
            V21PlayerAvatar(seed: seed, semanticsLabel: name, size: 38 * k),
            SizedBox(width: 10 * k),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V21Type.label(14 * k, weight: FontWeight.w800),
                  ),
                  Text(
                    league,
                    style: V21Type.label(11 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                  ),
                ],
              ),
            ),
            V21CoinIcon(size: 18 * k),
            SizedBox(width: 4 * k),
            Text(V21Format.thousands(points), style: V21Type.title(18 * k, color: const Color(0xFFFFD45E))),
          ],
        ),
      ),
    );
  }
}
