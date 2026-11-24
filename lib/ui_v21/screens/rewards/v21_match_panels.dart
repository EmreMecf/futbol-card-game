import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/chests/domain/chest_repository.dart';
import '../../../features/season/domain/season_repository.dart';
import '../../ui_v21.dart';
import '../inner/v21_league_screen.dart' show leagueShield;

/// V2.1 maç sonu panelleri (Zafer ekranının altında; yalnız dereceli maç).
/// Hepsi sunucunun verdiğini gösterir; veri yoksa yer kaplamaz.

/// Lig kalkanı (Lig Yolu renkleri): "M2"
class V21RankShield extends StatelessWidget {
  final PlayerRank rank;
  final double size;
  const V21RankShield({super.key, required this.rank, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final (colors, code) = leagueShield(rank.leagueCode);
    return Semantics(
      label: rank.label,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size * 1.12,
        child: ClipPath(
          clipper: const V21ShieldClipper(),
          child: ColoredBox(
            color: V21Colors.ink,
            child: Padding(
              padding: EdgeInsets.all(size * 0.05),
              child: ClipPath(
                clipper: const V21ShieldClipper(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
                  ),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: size * 0.1),
                      child: FittedBox(
                        child: Text(
                          '$code${rank.division}',
                          style: V21Type.title(size * 0.4, shadows: V21Type.inkShadow(size / 56)),
                        ),
                      ),
                    ),
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

/// MAÇIN LİG ETKİSİ: önceki → sonraki basamak, kupa farkı, basamak içi
/// ilerleme (öncesinden sonrasına dolar; animasyon azaltılmışsa anında).
class V21LeagueChangePanel extends StatelessWidget {
  final MatchLeagueChange change;
  final double scale;
  const V21LeagueChangePanel({super.key, required this.change, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final c = change;
    final up = c.isPromoted, down = c.isDemoted;
    final delta = c.mmrDelta;
    final ribbon = up
        ? (c.changedLeague ? 'LİG ATLADIN' : 'SEVİYE ATLADIN')
        : (down ? (c.changedLeague ? 'LİG DÜŞTÜN' : 'SEVİYE DÜŞTÜN') : null);
    final after = c.rankAfter;
    final sameTier = c.rankBefore.tierId == after.tierId;
    final from = sameTier ? c.rankBefore.progress : (up ? 0.0 : 1.0);
    final to = after.isTopTier ? 1.0 : after.progress;
    return Semantics(
      container: true,
      label:
          'Lig: ${c.rankBefore.label}${sameTier ? '' : ' → ${after.label}'}, '
          '${delta >= 0 ? '+' : ''}$delta kupa, ${c.mmrAfter} kupa${ribbon == null ? '' : ', ${ribbon.toLowerCase()}'}',
      excludeSemantics: true,
      child: V21GamePanel(
        scale: k,
        radius: 16,
        accent: up ? V21Colors.success : (down ? V21Colors.danger : null),
        padding: EdgeInsets.all(12 * k),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('LİG', style: V21Type.title(18 * k, color: V21Colors.textMuted)),
                ),
                if (ribbon != null)
                  V21Tag(
                    text: ribbon,
                    background: up ? V21Colors.success : V21Colors.danger,
                    foreground: Colors.white,
                    scale: k,
                    fontSize: 12,
                  ),
              ],
            ),
            SizedBox(height: 8 * k),
            Row(
              children: [
                V21RankShield(rank: c.rankBefore, size: 48 * k),
                if (!sameTier) ...[
                  SizedBox(width: 6 * k),
                  Icon(Icons.arrow_forward_rounded, color: V21Colors.goldTop, size: 26 * k),
                  SizedBox(width: 6 * k),
                  V21RankShield(rank: after, size: 48 * k),
                ],
                SizedBox(width: 12 * k),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(V21Format.upper(after.label), style: V21Type.title(20 * k, shadows: V21Type.inkShadow(k))),
                      Text(
                        '${V21Format.thousands(c.mmrAfter)} kupa (önce ${V21Format.thousands(c.mmrBefore)})',
                        style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${delta > 0 ? '+' : ''}$delta',
                  style: V21Type.title(
                    26 * k,
                    color: delta > 0
                        ? V21Colors.successText
                        : (delta < 0 ? const Color(0xFFFF8A9B) : V21Colors.textMuted),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10 * k),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: from, end: to),
              duration: V21Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 1100),
              curve: V21Motion.standard,
              builder: (context, v, _) =>
                  V21ProgressBar(value: v, height: 12 * k, semanticsLabel: 'Basamak ilerlemesi'),
            ),
            SizedBox(height: 4 * k),
            Text(
              after.isTopTier || after.nextLabel == null
                  ? 'En üst basamaktasın'
                  : '${after.pointsToNext} kupa sonra ${after.nextLabel}',
              style: V21Type.label(11 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// TERFİ KUTLAMASI: basamak atlandığında sonuç ekranının üstünde bir kez.
/// Sunucuda terfi ödülü yok; ekran ödül uydurmaz. Dokununca ya da DEVAM'a
/// basınca kapanır.
class V21LeaguePromotionOverlay extends StatefulWidget {
  final MatchLeagueChange change;
  final VoidCallback onContinue;
  const V21LeaguePromotionOverlay({super.key, required this.change, required this.onContinue});

  @override
  State<V21LeaguePromotionOverlay> createState() => _V21LeaguePromotionOverlayState();
}

class _V21LeaguePromotionOverlayState extends State<V21LeaguePromotionOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (V21Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.change;
    return LayoutBuilder(
      builder: (context, box) {
        final k = V21Scale.forSize(box.biggest).s;
        return Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          label: '${c.changedLeague ? 'Lig atladın' : 'Seviye atladın'}: ${c.rankBefore.label} → ${c.rankAfter.label}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onContinue,
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const V21RaysBackground(background: [Color(0xF28A3FD8), Color(0xF23A1680), Color(0xF216082F)]),
                  const V21Sparkles(color: Color(0xFFFFF4D6)),
                  SafeArea(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (context, child) => Transform.scale(
                          scale: 0.6 + 0.4 * Curves.easeOutBack.transform(_c.value),
                          child: Opacity(opacity: _c.value.clamp(0.0, 1.0), child: child),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24 * k),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c.changedLeague ? 'YENİ LİG!' : 'YENİ SEVİYE!',
                                style: V21Type.title(20 * k, color: const Color(0xFFFFE6A0)),
                              ),
                              V21HeroTitle('TERFİ!', size: 72 * k),
                              SizedBox(height: 16 * k),
                              V21RankShield(rank: c.rankAfter, size: 140 * k),
                              SizedBox(height: 16 * k),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    V21Format.upper(c.rankBefore.label),
                                    style: V21Type.title(20 * k, color: V21Colors.textMuted),
                                  ),
                                  SizedBox(width: 8 * k),
                                  Icon(Icons.arrow_forward_rounded, color: V21Colors.goldTop, size: 24 * k),
                                  SizedBox(width: 8 * k),
                                  Text(
                                    V21Format.upper(c.rankAfter.label),
                                    style: V21Type.title(26 * k, shadows: V21Type.inkShadow(k)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6 * k),
                              Text(
                                '${V21Format.thousands(c.mmrAfter)} kupa',
                                style: V21Type.label(14 * k, weight: FontWeight.w800, color: const Color(0xFFFFE3A6)),
                              ),
                              SizedBox(height: 24 * k),
                              SizedBox(
                                width: 260 * k,
                                child: V21GameButton(
                                  label: 'DEVAM',
                                  size: V21ButtonSize.large,
                                  scale: k,
                                  onPressed: widget.onContinue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// MAÇ SANDIĞI: "SANDIK KAZANDIN · ALTIN SANDIK · 2. yuvaya kondu".
/// Sandık maç bittiği an sunucuda verilir; panel yalnız o maçın sandığını
/// sorar (`/api/chests/match/:id`). Enerji yoksa açıklayıcı not.
class V21MatchChestPanel extends StatefulWidget {
  final String matchId;

  /// Test ve önizleme için doğrudan veri
  final SourceChest? preview;
  final double scale;
  const V21MatchChestPanel({super.key, required this.matchId, this.preview, this.scale = 1});

  @override
  State<V21MatchChestPanel> createState() => _V21MatchChestPanelState();
}

class _V21MatchChestPanelState extends State<V21MatchChestPanel> {
  SourceChest? _data;

  @override
  void initState() {
    super.initState();
    _data = widget.preview;
    if (_data == null && getIt.isRegistered<ChestRepository>()) _load();
  }

  Future<void> _load() async {
    final r = await getIt<ChestRepository>().fetchMatchChest(widget.matchId);
    if (mounted) setState(() => _data = r.dataOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.scale;
    final v = _data;
    if (v == null) return const SizedBox.shrink();
    final children = <Widget>[];
    if (v.skippedNoEnergy) {
      children.add(
        _Line(
          icon: Icon(Icons.bolt_rounded, size: 34 * k, color: const Color(0xFFFFB648)),
          title: 'SANDIK HAKKIN BİTMİŞTİ',
          subtitle: 'Maç ödüllerin (altın, kupa, koruma) geçerli. Sandık için hakkın dolunca oyna.',
          scale: k,
        ),
      );
    }
    final c = v.chest;
    if (c != null) {
      final where = switch (c.location) {
        'instant' when v.noEnergy => 'Sandık hakkın yoktu: Bronz sandık (hemen açılır)',
        'instant' => 'Hemen açılabilir',
        'slot' => '${c.slotNo}. yuvaya kondu',
        _ =>
          c.status == ChestStatus.compensated
              ? 'Kutu doluydu: ${(c.result?['compensation_coins'] as num?)?.toInt() ?? 0} altın telafi'
              : 'Yuvalar dolu: posta kutusunda bekliyor',
      };
      children.add(
        _Line(
          icon: V21ChestArt(width: 64 * k),
          kicker: 'SANDIK KAZANDIN',
          title: '${V21Format.upper(c.typeName)} SANDIK',
          subtitle: where,
          action: c.status == ChestStatus.compensated ? null : ('SANDIKLAR', AppRoutes.chests),
          scale: k,
        ),
      );
    }
    final copy = v.winCopyName;
    if (copy != null) {
      children.add(
        _Line(
          icon: Icon(Icons.trending_up_rounded, size: 34 * k, color: V21Colors.successText),
          title: '+1 GELİŞİM KOPYASI',
          subtitle: copy,
          action: ('GELİŞİM', AppRoutes.progress),
          scale: k,
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in children)
          Padding(
            padding: EdgeInsets.only(top: 10 * k),
            child: w,
          ),
      ],
    );
  }
}

/// SEZON XP: "+100 SEZON XP" (yalnız dereceli maç; `/api/season/match/:id`)
class V21MatchSeasonXpLine extends StatefulWidget {
  final String matchId;
  final MatchSeasonXp? preview;
  final double scale;
  const V21MatchSeasonXpLine({super.key, required this.matchId, this.preview, this.scale = 1});

  @override
  State<V21MatchSeasonXpLine> createState() => _V21MatchSeasonXpLineState();
}

class _V21MatchSeasonXpLineState extends State<V21MatchSeasonXpLine> {
  MatchSeasonXp? _data;

  @override
  void initState() {
    super.initState();
    _data = widget.preview;
    if (_data == null && getIt.isRegistered<SeasonRepository>()) _load();
  }

  Future<void> _load() async {
    final r = await getIt<SeasonRepository>().fetchMatchXp(widget.matchId);
    if (mounted) setState(() => _data = r.dataOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.scale;
    final v = _data;
    if (v == null || v.xp <= 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 10 * k),
      child: _Line(
        icon: V21StarIcon(size: 36 * k, color: const Color(0xFFFFC832)),
        title: '+${V21Format.thousands(v.xp)} SEZON XP',
        subtitle: v.noEnergy ? 'Sandık hakkın yoktu: bu maçta XP %25 verildi.' : 'Sezon yolunda ilerledin.',
        action: ('SEZON', AppRoutes.season),
        scale: k,
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final Widget icon;
  final String? kicker;
  final String title;
  final String subtitle;
  final (String, String)? action;
  final double scale;

  const _Line({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.scale,
    this.kicker,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final a = action;
    return Semantics(
      container: true,
      label: [?kicker, title, subtitle].join(', '),
      child: V21GamePanel(
        scale: k,
        radius: 16,
        padding: EdgeInsets.fromLTRB(10 * k, 10 * k, 10 * k, 10 * k),
        child: Row(
          children: [
            SizedBox(
              width: 64 * k,
              child: Center(child: icon),
            ),
            SizedBox(width: 8 * k),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kicker != null)
                      Text(
                        kicker!,
                        style: V21Type.label(
                          11 * k,
                          weight: FontWeight.w900,
                          color: const Color(0xFFFEDB70),
                          letterSpacing: 1,
                        ),
                      ),
                    Text(title, style: V21Type.title(19 * k, shadows: V21Type.inkShadow(k * 0.8))),
                    Text(
                      subtitle,
                      style: V21Type.label(11 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            if (a != null) ...[
              SizedBox(width: 6 * k),
              SizedBox(
                width: 96 * k,
                child: V21GameButton(
                  label: a.$1,
                  tone: V21ButtonTone.blue,
                  size: V21ButtonSize.small,
                  scale: k * 0.9,
                  onPressed: () => GoRouter.maybeOf(context)?.push(a.$2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
