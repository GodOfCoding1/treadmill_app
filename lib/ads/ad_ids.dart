import 'package:flutter/foundation.dart';

/// Google-provided test IDs — safe for development; never click your own live ads.
const _testAppId = 'ca-app-pub-3940256099942544~3347511713';
const _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

/// Production IDs are passed at build time so they stay out of source control:
///   flutter build appbundle \
///     --dart-define=ADMOB_APP_ID=ca-app-pub-XXXX~YYYY \
///     --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-XXXX/ZZZZ
const _prodAppId = String.fromEnvironment('ADMOB_APP_ID');
const _prodInterstitialId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');

/// AdMob application ID for AndroidManifest / SDK init.
String get admobAppId {
  if (!kReleaseMode || _prodAppId.isEmpty) return _testAppId;
  return _prodAppId;
}

/// Interstitial ad unit shown after a workout ends.
String get postWorkoutInterstitialId {
  if (!kReleaseMode || _prodInterstitialId.isEmpty) return _testInterstitialId;
  return _prodInterstitialId;
}
