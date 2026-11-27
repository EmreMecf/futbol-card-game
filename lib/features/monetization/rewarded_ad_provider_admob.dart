import 'dart:async';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'rewarded_ad_provider.dart';

/// Mobil: AdMob ödüllü reklam (`google_mobile_ads`).
RewardedAdProvider createRewardedAdProvider() =>
    (Platform.isAndroid || Platform.isIOS) ? AdMobRewardedProvider() : const NoAdProvider();

/// Reklam birimi kimlikleri. Varsayılan GOOGLE'IN RESMİ TEST kimlikleridir.
/// Gerçek kimlik yalnız yayın derlemesinde verilir:
///   --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-xxx/yyy
///   --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-xxx/yyy
/// Koda gerçek kimlik yazılmaz (docs/monetization/ADMOB_SETUP.md).
abstract final class AdUnitIds {
  static const String _android = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const String _ios = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );
  static String get rewarded => Platform.isIOS ? _ios : _android;
}

class AdMobRewardedProvider implements RewardedAdProvider {
  RewardedAd? _reklam;
  bool _baslatildi = false;

  Future<void> _baslat() async {
    if (_baslatildi) return;
    // Kritik akıştan ayrı, yalnız oyuncu reklam istediğinde başlatılır
    await MobileAds.instance.initialize();
    _baslatildi = true;
  }

  @override
  Future<bool> ensureConsent() async {
    final bitti = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {
          if (!bitti.isCompleted) bitti.complete();
        });
      },
      (_) {
        if (!bitti.isCompleted) bitti.complete();
      },
    );
    await bitti.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    // UMP: rıza alınamadıysa reklam İSTENMEZ
    return ConsentInformation.instance.canRequestAds();
  }

  @override
  Future<bool> load({required String ssvUserId, required String customData}) async {
    await _baslat();
    unawaited(_reklam?.dispose() ?? Future<void>.value());
    _reklam = null;
    final sonuc = Completer<RewardedAd?>();
    await RewardedAd.load(
      adUnitId: AdUnitIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => sonuc.complete(ad),
        onAdFailedToLoad: (_) => sonuc.complete(null),
      ),
    );
    final ad = await sonuc.future.timeout(const Duration(seconds: 30), onTimeout: () => null);
    if (ad == null) return false;
    // SSV: sunucu geri çağrıyı bu oturuma bağlar
    await ad.setServerSideOptions(ServerSideVerificationOptions(userId: ssvUserId, customData: customData));
    _reklam = ad;
    return true;
  }

  @override
  Future<AdShowResult> show() async {
    final ad = _reklam;
    if (ad == null) return AdShowResult.failed;
    _reklam = null;
    final sonuc = Completer<AdShowResult>();
    var kazandi = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!sonuc.isCompleted) sonuc.complete(kazandi ? AdShowResult.earned : AdShowResult.closedWithoutReward);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!sonuc.isCompleted) sonuc.complete(AdShowResult.failed);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => kazandi = true);
    return sonuc.future;
  }

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() async {
    final bitti = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) {
      if (!bitti.isCompleted) bitti.complete();
    });
    await bitti.future.timeout(const Duration(minutes: 5), onTimeout: () {});
  }

  @override
  void dispose() {
    _reklam?.dispose();
    _reklam = null;
  }
}
