import 'package:flutter/foundation.dart';

class MockRewardedAdSystem {
  bool isAdAvailable = true;
  bool shouldAdSucceed = true;

  Future<bool> isRewardedAdLoaded() async {
    return isAdAvailable;
  }

  Future<bool> showRewardedAd(VoidCallback? onUserEarnedReward) async {
    if (!isAdAvailable) return false;

    await Future.delayed(Duration(milliseconds: 100)); // Simulate ad loading

    if (shouldAdSucceed && onUserEarnedReward != null) {
      onUserEarnedReward();
    }

    return shouldAdSucceed;
  }
}