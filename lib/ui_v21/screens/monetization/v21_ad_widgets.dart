import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/app_language.dart';
import '../../../features/monetization/monetization_models.dart';
import '../../../features/monetization/rewarded_ad_controller.dart';
import '../../ui_v21.dart';

/// 060 — Ödüllü reklam arayüzü.
///
/// İLKELER (docs/monetization): reklam her zaman isteğe bağlı ve
/// "REKLAM" diye açıkça etiketli; ödül ve gereken eylem önceden yazılı;
/// izlemeyen ya da yarıda bırakan oyuncu cezalandırılmaz; sunucu onayı
/// gelmeden ödül animasyonu gösterilmez. Özellik kapalıysa hiçbir şey
/// çizilmez (oyun eskisi gibi).

RewardedAdController? _yeniDenetleyici() =>
    getIt.isRegistered<RewardedAdController>() ? getIt<RewardedAdController>() : null;

/// GÜNLÜK ÖDÜL MERKEZİ: ana sayfada küçük "REKLAM İZLE · +40" hapı.
/// Kalan hak (2/2) görünür; hak yoksa soluk ve açıklamalı.
class V21AdRewardPill extends StatefulWidget {
  final double scale;
  const V21AdRewardPill({super.key, this.scale = 1});

  @override
  State<V21AdRewardPill> createState() => _V21AdRewardPillState();
}

class _V21AdRewardPillState extends State<V21AdRewardPill> {
  RewardedAdController? _ads;

  @override
  void initState() {
    super.initState();
    _ads = _yeniDenetleyici();
    _ads?.refreshStatus();
  }

  @override
  void dispose() {
    _ads?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = _ads;
    if (ads == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: ads,
      builder: (context, _) {
        final e = ads.status?.of(AdPlacement.dailyReward);
        if (e == null || e.featureOff) return const SizedBox.shrink();
        final k = widget.scale;
        final acik = e.eligible && !ads.busy;
        return Semantics(
          button: true,
          label: 'Reklam izle, ödül {r}. Bugün kalan {n}'.trArgs({'r': e.reward.label, 'n': e.remainingToday}) +
              (acik ? '' : '. ${e.reasonText}'),
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('reklam-odul-hapi'),
            behavior: HitTestBehavior.opaque,
            onTap: () => acik ? _onayVeIzle(context, ads, e) : _bilgi(context, e),
            child: Opacity(
              opacity: acik ? 1 : 0.55,
              child: Container(
                padding: EdgeInsets.fromLTRB(6 * k, 4 * k, 10 * k, 4 * k),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20 * k),
                  border: Border.all(color: V21Colors.ink, width: 2.5 * k),
                  gradient: const LinearGradient(colors: [Color(0xFF3B7BE0), Color(0xFF2A4FB0)]),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 5 * k, vertical: 1 * k),
                      decoration: BoxDecoration(color: V21Colors.ink, borderRadius: BorderRadius.circular(8 * k)),
                      child: Text('REKLAM'.tr, style: V21Type.label(9 * k, weight: FontWeight.w900, color: Colors.white)),
                    ),
                    SizedBox(width: 6 * k),
                    Icon(Icons.play_circle_fill_rounded, size: 18 * k, color: Colors.white),
                    SizedBox(width: 4 * k),
                    if (e.reward.isCoins) ...[V21CoinIcon(size: 16 * k), SizedBox(width: 3 * k)],
                    Text('+${e.reward.amount}', style: V21Type.title(15 * k)),
                    SizedBox(width: 6 * k),
                    Text(
                      '${e.remainingToday}/${e.placementLimit}',
                      style: V21Type.label(11 * k, weight: FontWeight.w800, color: const Color(0xFFCFE2FF)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _bilgi(BuildContext context, AdEligibility e) => V21GameDialog.show<void>(
    context,
    subtitle: 'GÜNLÜK ÖDÜL'.tr,
    title: 'REKLAM HAKKI'.tr,
    message: e.reasonText.isEmpty ? 'Şu an reklam açılamıyor.'.tr : e.reasonText,
    actions: [V21DialogAction('TAMAM'.tr, tone: V21ButtonTone.blue)],
  );

  Future<void> _onayVeIzle(BuildContext context, RewardedAdController ads, AdEligibility e) async {
    final izle = await V21GameDialog.show<bool>(
      context,
      subtitle: 'GÜNLÜK ÖDÜL · REKLAM'.tr,
      title: '{r} KAZAN'.trArgs({'r': V21Format.upper(e.reward.label)}),
      message: 'Kısa bir reklam izle, sonunda {r} hesabına geçsin.\nTamamen isteğe bağlı; izlemezsen hiçbir şey kaybetmezsin.\nBugün kalan hak: {n}/{l}'.trArgs({'r': e.reward.label, 'n': e.remainingToday, 'l': e.placementLimit}),
      actions: [
        V21DialogAction('REKLAMI İZLE'.tr, tone: V21ButtonTone.green, result: true),
        V21DialogAction('VAZGEÇ'.tr, tone: V21ButtonTone.purple, result: false),
      ],
    );
    if (izle == true && context.mounted) await runRewardedAd(context, ads, AdPlacement.dailyReward);
  }
}

/// Reklamı izlet ve sonucu göster. Sunucu "verildi" demeden ödül
/// gösterilmez; beklenirken "Ödülün doğrulanıyor…" yazar.
Future<AdLifecycleState> runRewardedAd(
  BuildContext context,
  RewardedAdController ads,
  AdPlacement placement, {
  String? targetId,
}) async {
  final islem = ads.watch(placement, targetId: targetId);
  // Doğrulama beklenirken kapatılamayan küçük durum kutusu
  final kutu = showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Reklam',
    barrierColor: const Color(0x99120933),
    pageBuilder: (_, _, _) => _AdProgress(ads: ads),
  );
  final son = await islem;
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  await kutu;
  if (!context.mounted) return son;
  final odul = son == AdLifecycleState.rewardGranted;
  await V21GameDialog.show<void>(
    context,
    subtitle: odul ? 'ÖDÜL'.tr : 'REKLAM'.tr,
    title: odul ? 'TEBRİKLER!'.tr : (son == AdLifecycleState.awaitingVerification ? 'DOĞRULANIYOR'.tr : 'ÖDÜL YOK'.tr),
    message: ads.message ?? '',
    actions: [V21DialogAction('TAMAM'.tr, tone: V21ButtonTone.green)],
  );
  ads.reset();
  return son;
}

class _AdProgress extends StatelessWidget {
  final RewardedAdController ads;
  const _AdProgress({required this.ads});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ads,
    builder: (context, _) {
      final metin = switch (ads.state) {
        AdLifecycleState.eligibilityChecking => 'Hazırlanıyor…'.tr,
        AdLifecycleState.loading || AdLifecycleState.ready => 'Reklam yükleniyor…'.tr,
        AdLifecycleState.showing => 'Reklam oynatılıyor…'.tr,
        AdLifecycleState.awaitingVerification => ads.message ?? 'Ödülün doğrulanıyor…'.tr,
        _ => '',
      };
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            key: const Key('reklam-durum'),
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF2E1675),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: V21Colors.ink, width: 3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3, color: V21Colors.goldTop),
                ),
                const SizedBox(width: 14),
                Flexible(child: Text(metin, style: V21Type.label(15, weight: FontWeight.w800))),
              ],
            ),
          ),
        ),
      );
    },
  );
}
