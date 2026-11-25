import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/sbc/presentation/viewmodel/sbc_list_view_model.dart';
import '../../ui_v21.dart';
import '../../../core/l10n/app_language.dart';

/// V2.1 KART TAKASI (referans `assets/v21/screens/sbc.png`).
///
///   ‹ KART TAKASI
///   ┌ Kullanmadığın kartları ver, daha değerli ödül al!   (sandık) ┐
///   ┌ BRONZ TEMİZLİĞİ  [▮▮▮] → [● 750]  5 Bronz kart     [BAŞLA] ┐
///   ┌ GÜMÜŞ YÜKSELTME (yeşil kenar) …                    [✓ YAPILDI] ┐
///   "Verilen kartlar kalıcı olarak silinir"
///
/// VERİ: `SbcListViewModel` (mevcut) → `/api/sbc`. BAŞLA mevcut kadro
/// kurma ekranını açar (`/gorevler/:id`, Ref UI; ayrı faz). Kart yığını
/// görseli şartın nadirliğini gösterir; örnek futbolcu uydurulmaz.
class V21SbcScreen extends StatelessWidget {
  const V21SbcScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<SbcListViewModel>(create: (_) => getIt<SbcListViewModel>()..load(), child: const _Body());
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SbcListViewModel>();
    return V21InnerPage(
      title: 'KART TAKASI'.tr,
      route: AppRoutes.sbc,
      fallbackRoute: AppRoutes.store,
      state: vm.challenges.isEmpty
          ? (vm.isLoading ? V21PageState.loading : (vm.hasError ? V21PageState.error : V21PageState.disabled))
          : V21PageState.ready,
      errorMessage: vm.errorMessage,
      onRetry: vm.load,
      onRefresh: vm.load,
      disabledTitle: 'GÖREV YOK'.tr,
      disabledMessage: 'Şu an aktif kart takası yok. Yeni takaslar eklendiğinde burada görünür.'.tr,
      children: (context, k) => [
        _Banner(scale: k),
        SizedBox(height: 14 * k),
        for (final c in vm.challenges) ...[_ChallengeCard(challenge: c, scale: k), SizedBox(height: 14 * k)],
        Text(
          'Verilen kartlar kalıcı olarak silinir'.tr,
          textAlign: TextAlign.center,
          style: V21Type.label(13 * k, weight: FontWeight.w800, color: const Color(0xFFFF8A9B)),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final double scale;
  const _Banner({required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Container(
      height: 82 * k,
      padding: EdgeInsets.only(left: 14 * k, right: 6 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16 * k),
        border: Border.all(color: V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(colors: [Color(0xFFFF9A2E), Color(0xFFE5394B)]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Kullanmadığın kartları ver,\ndaha değerli ödül al!'.tr,
              style: V21Type.title(19 * k, shadows: V21Type.inkShadow(k * 0.7)),
            ),
          ),
          V21ChestArt(width: 86 * k),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final SbcChallenge challenge;
  final double scale;
  const _ChallengeCard({required this.challenge, required this.scale});

  /// Şartlardaki ilk nadirlik (yığın rengi); yoksa Altın
  CardTier get _tier => challenge.requirements.map((r) => r.tier).whereType<CardTier>().firstOrNull ?? CardTier.gold;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final c = challenge;
    final done = c.isCompleted || (c.remainingAttempts != null && c.remainingAttempts! <= 0);
    void open() => context.push(AppRoutes.sbcBuilderWithId(c.id), extra: c);
    final summary = c.requirements.map((r) => r.label).join(' · ');
    return Semantics(
      container: true,
      label: '{name}. Ödül: {rewardSummary}. Şartlar: {summary}{p}'.trArgs({'name': c.name, 'rewardSummary': c.rewardSummary, 'summary': summary, 'p': done ? '. Yapıldı'.tr : ''}),
      child: Container(
        padding: EdgeInsets.fromLTRB(14 * k, 12 * k, 14 * k, 12 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18 * k),
          border: Border.all(color: done ? V21Colors.success : V21Colors.ink, width: 3 * k),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(V21Format.upper(c.name), style: V21Type.title(22 * k, shadows: V21Type.inkShadow(k))),
            SizedBox(height: 8 * k),
            SizedBox(
              height: 92 * k,
              child: Row(
                children: [
                  SizedBox(
                    width: 150 * k,
                    child: _CardFan(tier: _tier, scale: k),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 30 * k, color: V21Colors.goldTop),
                  SizedBox(width: 6 * k),
                  Expanded(
                    child: _RewardBox(rewards: c.rewards, scale: k),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8 * k),
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                  ),
                ),
                SizedBox(width: 8 * k),
                SizedBox(
                  width: 112 * k,
                  child: done
                      ? V21GameButton(
                          label: 'YAPILDI'.tr,
                          leadingIcon: Icons.check_rounded,
                          tone: V21ButtonTone.green,
                          size: V21ButtonSize.small,
                          status: V21ButtonStatus.disabled,
                          scale: k,
                          onPressed: null,
                        )
                      : V21GameButton(
                          label: 'BAŞLA'.tr,
                          tone: V21ButtonTone.green,
                          size: V21ButtonSize.small,
                          scale: k,
                          semanticsLabel: '{name}: başla'.trArgs({'name': c.name}),
                          onPressed: open,
                        ),
                ),
              ],
            ),
            if (!done && c.isRepeatable && c.completedCount > 0)
              Padding(
                padding: EdgeInsets.only(top: 4 * k),
                child: Text(
                  '{completedCount} kez yapıldı · tekrarlanabilir'.trArgs({'completedCount': c.completedCount}),
                  style: V21Type.label(11 * k, weight: FontWeight.w700, color: V21Colors.textDim),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Şartın nadirliğinde üç kart (yelpaze); örnek futbolcu yok
class _CardFan extends StatelessWidget {
  final CardTier tier;
  final double scale;
  const _CardFan({required this.tier, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final r = V21Rarity.of(tier);
    Widget card(double angle) => Transform.rotate(
      angle: angle,
      child: Container(
        width: 56 * k,
        height: 80 * k,
        padding: EdgeInsets.all(2.5 * k),
        decoration: BoxDecoration(
          color: V21Colors.ink,
          borderRadius: BorderRadius.circular(9 * k),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4 * k)],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7 * k),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [r.frameLight, r.frame],
            ),
          ),
          child: Center(
            child: V21StarIcon(size: 24 * k, color: Colors.white),
          ),
        ),
      ),
    );
    return Semantics(
      label: '{name} kartlar'.trArgs({'name': r.name}),
      excludeSemantics: true,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(left: 0, child: card(-0.12)),
          Positioned(left: 36 * k, child: card(-0.03)),
          Positioned(
            left: 72 * k,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                card(0.06),
                SizedBox(height: 2 * k),
              ],
            ),
          ),
          Positioned(
            left: 76 * k,
            bottom: 0,
            child: Text(r.name, style: V21Type.title(12 * k, shadows: V21Type.inkShadow(k * 0.6))),
          ),
        ],
      ),
    );
  }
}

class _RewardBox extends StatelessWidget {
  final List<SbcReward> rewards;
  final double scale;
  const _RewardBox({required this.rewards, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final coins = rewards.where((r) => r.type == 'coins').fold<int>(0, (a, r) => a + (r.amount ?? 0));
    final hasPack = rewards.any((r) => r.type == 'pack');
    final hasCard = rewards.any((r) => r.type == 'card');
    final Widget icon = hasPack || hasCard ? V21CardStackIcon(size: 40 * k) : V21CoinIcon(size: 38 * k);
    final label = [
      if (hasPack) 'PAKET'.tr,
      if (hasCard) 'KART'.tr,
      if (coins > 0) hasPack || hasCard ? '+${V21Format.thousands(coins)}' : V21Format.thousands(coins),
    ].join('');
    return Container(
      height: 78 * k,
      padding: EdgeInsets.symmetric(horizontal: 8 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * k),
        border: Border.all(color: const Color(0xFFFFC832), width: 3 * k),
        color: const Color(0xFF2A1460),
      ),
      child: Row(
        children: [
          icon,
          SizedBox(width: 6 * k),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label.isEmpty ? 'ÖDÜL'.tr : label,
                style: V21Type.title(24 * k, color: const Color(0xFFFFD45E), shadows: V21Type.inkShadow(k)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
