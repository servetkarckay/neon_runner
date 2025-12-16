import 'package:flutter/foundation.dart';

/// Build configuration for different environments
class BuildConfig {
  static const bool _isDebugMode = kDebugMode;
  static const bool _isReleaseMode = kReleaseMode;
  static const bool _isProfileMode = kProfileMode;

  // Debug flags
  static bool get isDebugMode => _isDebugMode;
  static bool get isReleaseMode => _isReleaseMode;
  static bool get isProfileMode => _isProfileMode;

  // Feature flags based on build mode
  static bool get enableLogs => _isDebugMode;
  static bool get enableDebugUI => _isDebugMode;
  static bool get enableFPSCounter => _isDebugMode || _isProfileMode;
  static bool get enableHitboxVisualization => _isDebugMode;
  static bool get enablePerformanceMetrics => _isProfileMode || _isDebugMode;
  static bool get enableAdSimulation => _isDebugMode;
  static bool get enableCheats => _isDebugMode;

  // Performance settings
  static int get maxParticles => _isReleaseMode ? 100 : (_isProfileMode ? 50 : 20);
  static int get maxTrailLength => _isReleaseMode ? 20 : (_isProfileMode ? 10 : 5);
  static double get targetFPS => _isReleaseMode ? 60.0 : (_isProfileMode ? 60.0 : 30.0);
  static bool get enableAdaptiveQuality => _isReleaseMode;

  // Error handling
  static bool get enableCrashReporting => _isReleaseMode;
  static bool get enableDebugErrorScreens => _isDebugMode;
  static bool get enableVerboseErrors => _isDebugMode;

  // Network settings
  static bool get enableNetworkLogging => _isDebugMode;
  static Duration get networkTimeout => _isDebugMode
    ? Duration(seconds: 30)
    : Duration(seconds: 10);

  // Asset loading
  static bool get preloadAllAssets => !_isDebugMode;
  static bool get enableAssetCaching => _isReleaseMode;

  // Ad settings
  static bool get enableRealAds => _isReleaseMode;
  static bool get enableAdTestMode => _isDebugMode;
  static Duration get adLoadTimeout => _isDebugMode
    ? Duration(seconds: 5)
    : Duration(seconds: 10);

  // Leaderboard settings
  static String get leaderboardEnvironment => _isDebugMode
    ? 'development'
    : 'production';
  static bool get enableLeaderboardCaching => _isReleaseMode;
  static Duration get leaderboardCacheTimeout => _isReleaseMode
    ? Duration(minutes: 5)
    : Duration(seconds: 30);

  // Analytics
  static bool get enableAnalytics => _isReleaseMode;
  static bool get enableDebugAnalytics => _isDebugMode;
  static int get analyticsBatchSize => _isReleaseMode ? 50 : 10;
  static Duration get analyticsFlushInterval => _isReleaseMode
    ? Duration(minutes: 5)
    : Duration(seconds: 30);

  // Input settings
  static bool get enableInputVisualization => _isDebugMode;
  static bool get showTouchIndicators => _isDebugMode;
  static double get touchIndicatorOpacity => _isDebugMode ? 0.5 : 0.0;

  // Audio settings
  static bool get enableAudioDebug => _isDebugMode;
  static bool get muteAudioInBackground => _isReleaseMode;

  // Memory management
  static bool get enableMemoryMonitoring => _isDebugMode || _isProfileMode;
  static int get memoryCheckInterval => _isDebugMode ? 60 : 300; // frames
  static bool get aggressiveGarbageCollection => _isReleaseMode;

  // Rendering settings
  static bool get enableParticleEffects => !_isDebugMode || maxParticles > 0;
  static bool get enableScreenShake => _isReleaseMode;
  static bool get enableMotionBlur => _isReleaseMode;
  static bool get enablePostProcessing => _isReleaseMode;

  // Testing helpers
  static bool get isTestMode => _isDebugMode &&
      (const String.fromEnvironment('FLUTTER_TEST') == 'true');

  // Platform-specific optimizations
  static bool get enablePlatformOptimizations => _isReleaseMode;
  static bool get useHardwareAcceleration => _isReleaseMode;

  // Build info
  static String get buildFlavor {
    if (_isReleaseMode) return 'release';
    if (_isProfileMode) return 'profile';
    return 'debug';
  }

  static String get buildVersion {
    const version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
    return version;
  }

  static int get buildNumber {
    const number = int.fromEnvironment('BUILD_NUMBER', defaultValue: 1);
    return number;
  }
}