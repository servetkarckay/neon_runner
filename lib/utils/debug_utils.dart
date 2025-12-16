import 'package:flutter/foundation.dart';
import 'package:flutter_neon_runner/config/build_config.dart';

/// Debug utilities for development
class DebugUtils {
  static void log(String message, {String? tag}) {
    if (BuildConfig.enableLogs) {
      final prefix = tag != null ? '[$tag] ' : '';
      print('$prefix$message');
    }
  }

  static void logError(Object error, StackTrace? stackTrace, {String? tag}) {
    if (BuildConfig.enableVerboseErrors) {
      final prefix = tag != null ? '[$tag] ' : '';
      print('$prefix$error');
      if (stackTrace != null) {
        print('$prefix$stackTrace');
      }
    }
  }

  static void logPerformance(String metric, dynamic value) {
    if (BuildConfig.enablePerformanceMetrics) {
      print('[PERF] $metric: $value');
    }
  }

  static void logNetwork(String request, String response) {
    if (BuildConfig.enableNetworkLogging) {
      print('[NET] Request: $request');
      print('[NET] Response: $response');
    }
  }

  static void assertCondition(bool condition, String message) {
    if (BuildConfig.isDebugMode && !condition) {
      throw AssertionError(message);
    }
  }
}

/// Performance profiler for debugging
class PerformanceProfiler {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, List<double>> _durations = {};

  static void start(String operation) {
    if (BuildConfig.enablePerformanceMetrics) {
      _startTimes[operation] = DateTime.now();
    }
  }

  static void end(String operation) {
    if (BuildConfig.enablePerformanceMetrics && _startTimes.containsKey(operation)) {
      final duration = DateTime.now().difference(_startTimes[operation]!).inMicroseconds.toDouble() / 1000.0;

      _durations[operation] ??= [];
      _durations[operation]!.add(duration);

      // Keep only last 100 measurements
      if (_durations[operation]!.length > 100) {
        _durations[operation]!.removeAt(0);
      }

      _startTimes.remove(operation);

      DebugUtils.logPerformance('$operation (ms)', duration.toStringAsFixed(2));
    }
  }

  static Map<String, double> getAverageDurations() {
    final averages = <String, double>{};

    for (final entry in _durations.entries) {
      if (entry.value.isNotEmpty) {
        final sum = entry.value.reduce((a, b) => a + b);
        averages[entry.key] = sum / entry.value.length;
      }
    }

    return averages;
  }

  static void reset() {
    _startTimes.clear();
    _durations.clear();
  }
}
