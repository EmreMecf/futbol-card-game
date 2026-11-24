import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/season/presentation/viewmodel/season_view_model.dart';
import '../../ui_v21.dart';
import '../home/v21_home_nav.dart';

/// V2.1 SEZON YOLU (referans `assets/v21/screens/season.png`).
///
///   SEZON YOLU                       ( ⏱ 22g 14s )   ← sezon bitişine kalan
///   ┌ ★7  KADEME 7 / 50  ▀▀▀░░  660 XP sonra… [TÜMÜNÜ AL (3)] ┐
///   (6)━(7)━(8)━(9)  ödül yolu (dokun: ödül ayrıntısı + al)
///   GÖREVLER: GÜNLÜK / HAFTALIK / SEZON satırları, ilerleme, XP rozeti
///
/// VERİ: `SeasonViewModel` (mevcut) → `/api/season`, `/api/season/missions`,
/// ödül alma `/api/season/claim` ve `/claim-all` (idempotency anahtarlı).
/// Görev XP'si sunucuda otomatik verilir; satırlardaki "✓ ALINDI" ve
/// "+200 XP" düğme değil, durum rozetidir. Sezon XP'si maçta güç vermez (K1).
class V21SeasonScreen extends StatelessWidget {
  const V21SeasonScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<SeasonViewModel>(
    create: (_) => getIt<SeasonViewModel>()..load(),
    child: Theme(
      data: V21Theme.data(context),
      child: V21ScreenLayout(
        background: V21Background.page,
        body: (context, sc) => _Body(scale: sc.s),
        bottomNavigation: (context, sc) => V21HomeNav(currentRoute: AppRoutes.season, scale: sc.s),
      ),
    ),
  );
}

/// "22g 14s" (referans biçimi); bir günden azsa "5s 12dk"
String v21SeasonRemaining(Duration d) {
  if (d.isNegative) return 'Bitti';
  if (d.inDays > 0) return '${d.inDays}g ${d.inHours % 24}s';
  if (d.inHours > 0) return '${d.inHours}s ${d.inMinutes % 60}dk';
  return '${d.inMinutes}dk';
}

class _Body extends StatelessWidget {
  final double scale;
  const _Body({required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final vm = context.watch<SeasonViewModel>();
    final s = vm.overview;
    final remaining = s?.endsAt != null && s?.serverTime != null ? s!.endsAt!.difference(s.serverTime!) : null;

    final title = Padding(
      padding: EdgeInsets.fromLTRB(16 * k, 15 * k, 8 * k, 0),
      child: V21PageTitle(
        title: 'SEZON YOLU',
        scale: k,
        trailing: remaining == null ? null : _RemainingPill(remaining: remaining, scale: k),
      ),
    );

    final List<Widget> content;
    if (s == null) {
      content = [
        if (vm.isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: V21Colors.goldTop)),
          )
        else
          V21EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'BAĞLANTI SORUNU',
            message: vm.errorMessage ?? 'Sezon bilgisi yüklenemedi.',
            actionLabel: 'TEKRAR DENE',
            onAction: vm.load,
            scale: k,
          ),
      ];
    } else if (!s.enabled) {
      content = [
        V21EmptyState(
          icon: Icons.star_rounded,
          title: 'SEZON YAKINDA',
          message: 'Sezon yolu henüz açık değil. Açıldığında maç oynayarak XP toplayıp ödül kazanacaksın.',
          scale: k,
        ),
      ];
    } else {
      final missions = vm.missions;
      content = [
        _TierCard(s: s, vm: vm, scale: k),
        if (vm.lastInfo != null || vm.actionError != null) ...[
          SizedBox(height: 8 * k),
          Text(
            vm.actionError ?? vm.lastInfo!,
            textAlign: TextAlign.center,
            style: V21Type.label(
              13 * k,
              weight: FontWeight.w800,
              color: vm.actionError != null ? V21Colors.danger : V21Colors.successText,
            ),
          ),
        ],
        SizedBox(height: 14 * k),
        _RewardRoad(s: s, vm: vm, scale: k),
        if (missions != null && missions.enabled && missions.missions.isNotEmpty) ...[
          SizedBox(height: 16 * k),
          Text('GÖREVLER', style: V21Type.title(26 * k, shadows: V21Type.inkShadow(k))),
          SizedBox(height: 10 * k),
          for (final (period, label) in const [('daily', 'GÜNLÜK'), ('weekly', 'HAFTALIK'), ('season', 'SEZON')])
            for (final m in missions.period(period)) ...[
              _MissionRow(mission: m, tag: label, scale: k),
              SizedBox(height: 10 * k),
            ],
        ],
        SizedBox(height: 8 * k),
        Text(
          'Sezon XP\'si ve ödüller dereceli maçta güç vermez. Kademe başına ${V21Format.thousands(s.xpPerTier)} XP. '
          'Sezon bitince ulaşıp almadığın ödüller otomatik verilir.',
          textAlign: TextAlign.center,
          style: V21Type.label(11 * k, weight: FontWeight.w600, color: V21Colors.textDim, height: 1.4),
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        SizedBox(height: 12 * k),
        Expanded(
          child: RefreshIndicator(
            color: V21Colors.goldTop,
            backgroundColor: V21Colors.panel,
            onRefresh: vm.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(12 * k, 0, 12 * k, 24 * k),
              children: content,
            ),
          ),
        ),
      ],
    );
  }
}

class _RemainingPill extends StatelessWidget {
  final Duration remaining;
  final double scale;
  const _RemainingPill({required this.remaining, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final text = v21SeasonRemaining(remaining);
    return Semantics(
      label: 'Sezonun bitmesine $text',
      excludeSemantics: true,
      child: Container(
        height: 32 * k,
        padding: EdgeInsets.symmetric(horizontal: 12 * k),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF7A8C), Color(0xFFE5294B)],
          ),
          borderRadius: BorderRadius.circular(32 * k),
          border: Border.all(color: V21Colors.ink, width: 2 * k),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_rounded, size: 15 * k, color: Colors.white),
            SizedBox(width: 5 * k),
            Text(text, style: V21Type.title(17 * k)),
          ],
        ),
      ),
    );
  }
}

/// Kademe kartı: büyük yıldız, "KADEME 7 / 50", XP çubuğu, TÜMÜNÜ AL
class _TierCard extends StatelessWidget {
  final SeasonOverview s;
  final SeasonViewModel vm;
  final double scale;
  const _TierCard({required this.s, required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final n = s.claimableCount;
    return V21GamePanel(
      scale: k,
      radius: 16,
      padding: EdgeInsets.fromLTRB(12 * k, 12 * k, 12 * k, 12 * k),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 96 * k,
            child: Stack(
              alignment: Alignment.center,
              children: [
                V21StarIcon(size: 96 * k, color: const Color(0xFFFFC832)),
                Padding(
                  padding: EdgeInsets.only(top: 8 * k),
                  child: Text('${s.tier}', style: V21Type.title(40 * k, shadows: V21Type.inkShadow(k * 1.2))),
                ),
              ],
            ),
          ),
          SizedBox(width: 12 * k),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('KADEME ${s.tier} / ${s.maxTier}', style: V21Type.title(23 * k, shadows: V21Type.inkShadow(k))),
                SizedBox(height: 8 * k),
                V21ProgressBar(
                  value: s.tierProgress,
                  height: 16 * k,
                  trackColor: const Color(0xFF201046),
                  fillColors: const [Color(0xFF9EDCFF), Color(0xFF3FA2F5)],
                  semanticsLabel: 'Kademe ilerlemesi',
                ),
                SizedBox(height: 6 * k),
                Text(
                  s.isMaxed
                      ? 'Son kademeye ulaştın.'
                      : '${V21Format.thousands(s.xpToNext)} XP sonra kademe ${s.tier + 1}',
                  style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                ),
                if (n > 0) ...[
                  SizedBox(height: 8 * k),
                  V21GameButton(
                    label: 'TÜMÜNÜ AL ($n)',
                    tone: V21ButtonTone.green,
                    size: V21ButtonSize.small,
                    scale: k,
                    status: vm.busyAction == 'all'
                        ? V21ButtonStatus.loading
                        : (vm.busyAction != null ? V21ButtonStatus.disabled : V21ButtonStatus.normal),
                    onPressed: vm.claimAll,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Yatay ödül yolu: kademe düğümleri + bağlantı çizgileri.
/// Açılışta oyuncunun bulunduğu kademeye kaydırılır.
class _RewardRoad extends StatefulWidget {
  final SeasonOverview s;
  final SeasonViewModel vm;
  final double scale;
  const _RewardRoad({required this.s, required this.vm, required this.scale});

  @override
  State<_RewardRoad> createState() => _RewardRoadState();
}

class _RewardRoadState extends State<_RewardRoad> {
  ScrollController? _scroll;

  double get _step => (70 + 26) * widget.scale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mevcut kademeden bir önceki düğüm solda görünsün (referans: 6 · 7 · 8 · 9)
    _scroll ??= ScrollController(initialScrollOffset: ((widget.s.tier - 2).clamp(0, 999)) * _step);
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.scale;
    final s = widget.s;
    final tiers = s.tiers;
    return SizedBox(
      height: 98 * k,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        itemCount: tiers.length,
        itemBuilder: (context, i) {
          final t = tiers[i];
          final reached = s.isReached(t.tier);
          final nextReached = i + 1 < tiers.length && s.isReached(tiers[i + 1].tier);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TierNode(tier: t, s: s, vm: widget.vm, scale: k),
              if (i + 1 < tiers.length)
                Container(
                  width: 26 * k,
                  height: 8 * k,
                  margin: EdgeInsets.only(top: 31 * k),
                  color: nextReached && reached ? const Color(0xFFFFA62B) : const Color(0xFF231353),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TierNode extends StatelessWidget {
  final SeasonTier tier;
  final SeasonOverview s;
  final SeasonViewModel vm;
  final double scale;
  const _TierNode({required this.tier, required this.s, required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final t = tier;
    final reached = s.isReached(t.tier);
    final claimable = vm.canClaim(t, 'free') || vm.canClaim(t, 'premium');
    final label = rewardLabel(t.free);
    final state = t.freeClaimed
        ? 'alındı'
        : claimable
        ? 'alınabilir'
        : (reached ? '' : 'ulaşılmadı');

    Widget box(double glow) => Container(
      width: 70 * k,
      height: 70 * k,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * k),
        border: Border.all(color: reached ? const Color(0xFFFFC832) : V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2BA8), Color(0xFF2A1470)],
        ),
        boxShadow: glow > 0
            ? [
                BoxShadow(
                  color: const Color(0xFFFFC832).withValues(alpha: 0.6 * glow),
                  blurRadius: 14 * k,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: reached ? 1 : 0.75,
            child: _RewardIcon(t.free, size: 44 * k),
          ),
          if (t.freeClaimed)
            Positioned(
              right: 3 * k,
              top: 3 * k,
              child: Icon(Icons.check_circle_rounded, size: 18 * k, color: V21Colors.success),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: 'Kademe ${t.tier}: $label${state.isEmpty ? '' : ', $state'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _showTier(context, k),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            claimable ? V21Pulse(builder: (context, g) => box(0.4 + 0.6 * g)) : box(0),
            SizedBox(height: 4 * k),
            Container(
              constraints: BoxConstraints(minWidth: 26 * k),
              height: 22 * k,
              padding: EdgeInsets.symmetric(horizontal: 6 * k),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: reached ? V21Colors.success : const Color(0xFF3B2F66),
                borderRadius: BorderRadius.circular(22 * k),
                border: Border.all(color: V21Colors.ink, width: 2 * k),
              ),
              child: Text('${t.tier}', style: V21Type.title(14 * k)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTier(BuildContext context, double k) async {
    final t = tier;
    final canFree = vm.canClaim(t, 'free');
    final canPremium = vm.canClaim(t, 'premium');
    String line(String track, SeasonReward r, bool claimed, bool can, {bool locked = false}) {
      final st = claimed
          ? 'alındı'
          : (can ? 'alınabilir' : (locked ? 'kilitli' : (s.isReached(t.tier) ? '' : 'ulaşılmadı')));
      return '$track: ${rewardLabel(r)}${st.isEmpty ? '' : ' ($st)'}';
    }

    final choice = await V21GameDialog.show<String>(
      context,
      subtitle: 'SEZON YOLU',
      title: 'KADEME ${t.tier}',
      icon: _RewardIcon(t.free, size: 64),
      message: [
        line('Ücretsiz', t.free, t.freeClaimed, canFree),
        line(s.premium ? 'Premium' : 'Premium (yakında)', t.premium, t.premiumClaimed, canPremium, locked: !s.premium),
      ].join('\n'),
      actions: [
        if (canFree) const V21DialogAction('ÜCRETSİZ ÖDÜLÜ AL', tone: V21ButtonTone.green, result: 'free'),
        if (canPremium) const V21DialogAction('PREMIUM ÖDÜLÜ AL', result: 'premium'),
        const V21DialogAction('KAPAT', tone: V21ButtonTone.blue),
      ],
    );
    if (choice == 'free' || choice == 'premium') await vm.claim(t, choice!);
  }
}

/// Ödül simgesi: altın, sandık, diğer (kart / eşya)
class _RewardIcon extends StatelessWidget {
  final SeasonReward reward;
  final double size;
  const _RewardIcon(this.reward, {required this.size});

  @override
  Widget build(BuildContext context) {
    if (reward.isCoins) return V21CoinIcon(size: size * 0.82);
    if (reward.isChest) return Image.asset(V21Assets.chestGoldLarge, width: size, height: size, fit: BoxFit.contain);
    return V21CardStackIcon(size: size * 0.85);
  }
}

class _MissionRow extends StatelessWidget {
  final Mission mission;
  final String tag;
  final double scale;
  const _MissionRow({required this.mission, required this.tag, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final m = mission;
    final done = m.completed;
    final (tagBg, tagFg) = switch (m.period) {
      'weekly' => (const Color(0xFF8FD3FF), const Color(0xFF0E3A66)),
      'season' => (const Color(0xFFD8B4FF), const Color(0xFF3B1272)),
      _ => (const Color(0xFF8BE38A), const Color(0xFF14361A)),
    };
    return Semantics(
      label:
          '$tag görev: ${m.title}, ${m.progress} / ${m.target}, '
          '${done ? 'tamamlandı, ${m.xp} XP alındı' : '${m.xp} XP ödül'}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(12 * k, 10 * k, 10 * k, 10 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * k),
          border: Border.all(color: done ? V21Colors.success : V21Colors.ink, width: 3 * k),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      V21Tag(text: tag, background: tagBg, foreground: tagFg, scale: k),
                      SizedBox(width: 10 * k),
                      Expanded(
                        child: Text(
                          m.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V21Type.title(18 * k, shadows: V21Type.inkShadow(k * 0.7)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8 * k),
                  V21ProgressBar(value: m.ratio, height: 13 * k, trackColor: const Color(0xFF201046)),
                ],
              ),
            ),
            SizedBox(width: 10 * k),
            // Durum rozeti (düğme değil): XP sunucuda otomatik verilir
            Container(
              width: 88 * k,
              height: 38 * k,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10 * k),
                border: Border.all(color: V21Colors.ink, width: 2 * k),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: done
                      ? const [Color(0xFFA4FF9C), Color(0xFF16B03D)]
                      : const [Color(0xFFFFD94E), Color(0xFFFF9307)],
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6 * k),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (done) ...[
                        Icon(Icons.check_rounded, size: 17 * k, color: Colors.white),
                        SizedBox(width: 2 * k),
                      ],
                      Text(
                        done ? 'ALINDI' : '+${V21Format.thousands(m.xp)} XP',
                        style: V21Type.title(
                          16 * k,
                          shadows: [
                            Shadow(
                              color: done ? const Color(0xFF0E5A22) : V21Colors.goldShadow,
                              offset: Offset(0, 1.5 * k),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
