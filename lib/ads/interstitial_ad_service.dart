import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// Minimum time between interstitial impressions.
const _frequencyCap = Duration(minutes: 5);

/// Loads and shows post-workout interstitial ads with a frequency cap.
class InterstitialAdService {
  InterstitialAd? _ad;
  bool _isLoading = false;
  DateTime? _lastShownAt;

  /// Preloads the next interstitial. Safe to call repeatedly.
  Future<void> preload() async {
    if (_ad != null || _isLoading) return;
    _isLoading = true;

    await InterstitialAd.load(
      adUnitId: postWorkoutInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isLoading = false;
        },
      ),
    );
  }

  /// Shows a post-workout ad if one is ready and the frequency cap allows it.
  /// Always completes — never blocks the user when no ad is available.
  Future<void> showPostWorkoutAdIfReady() async {
    final now = DateTime.now();
    if (_lastShownAt != null &&
        now.difference(_lastShownAt!) < _frequencyCap) {
      return;
    }

    final ad = _ad;
    if (ad == null) {
      unawaited(preload());
      return;
    }

    _ad = null;
    final completer = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissed) {
        dismissed.dispose();
        _lastShownAt = DateTime.now();
        unawaited(preload());
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (failed, error) {
        debugPrint('InterstitialAd failed to show: $error');
        failed.dispose();
        unawaited(preload());
        if (!completer.isCompleted) completer.complete();
      },
    );

    ad.show();
    await completer.future;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
