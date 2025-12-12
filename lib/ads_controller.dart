import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdsController {
  static final AdsController _instance = AdsController._internal();
  factory AdsController() => _instance;
  AdsController._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  String get _rewardedAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-7189140147236524/7831774002';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-7189140147236524/4383529681';
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      return 'ca-app-pub-7189140147236524/4383529681'; // Using iOS ad unit for macOS, or you can use a separate one
    }
    return ''; // Other platforms not supported
  }

  Future<void> init() async {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) {
      await MobileAds.instance.initialize();
      _loadRewardedAd();
    }
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          debugPrint('RewardedAd loaded.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedAdReady = false;
          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  void showRewardedAd(Function() onRewardEarned) {
    if (!_isRewardedAdReady) {
      debugPrint('Rewarded ad is not ready yet.');
      onRewardEarned(); // Optionally give reward anyway or show a message
      return;
    }

    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('$ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        _isRewardedAdReady = false;
        _loadRewardedAd(); // Load another ad for next time
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _isRewardedAdReady = false;
        _loadRewardedAd(); // Load another ad for next time
        onRewardEarned(); // Optionally give reward anyway or show a message
      },
    );

    _rewardedAd?.show(onUserEarnedReward: (ad, reward) {
      debugPrint('User earned reward: ${reward.amount}, ${reward.type}');
      onRewardEarned();
    });
  }

  void dispose() {
    _rewardedAd?.dispose();
  }
}