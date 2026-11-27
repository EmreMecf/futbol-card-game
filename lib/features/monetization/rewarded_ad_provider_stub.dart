import 'rewarded_ad_provider.dart';

/// Web ve `dart:io` olmayan ortamlar: reklam yok.
RewardedAdProvider createRewardedAdProvider() => const NoAdProvider();
