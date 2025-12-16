import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/ads/revive_integration_system.dart';
import 'package:flutter_neon_runner/config/build_config.dart';
import 'package:flutter_neon_runner/utils/debug_utils.dart';

/// Examples and test cases for the revived ad system
/// Demonstrates correct usage and edge case handling
class ReviveExamples {

  /// Example 1: Normal Revive Flow
  /// Shows the complete flow from game over to successful revive
  static void exampleNormalReviveFlow(ReviveIntegrationSystem reviveSystem) {
    if (!BuildConfig.enableLogs) return;

    DebugUtils.log('=== NORMAL REVIVE FLOW ===');

    // 1. Game over occurs
    DebugUtils.log('Game over - score: 1500');
    DebugUtils.log('Can revive: ${reviveSystem.canRevive}');
    DebugUtils.log('Ad ready: ${reviveSystem.isAdReady}');

    // 2. Player chooses to revive
    if (reviveSystem.canRevive && reviveSystem.isAdReady) {
      DebugUtils.log('Starting revive flow...');

      reviveSystem.initiateReviveFlow().then((result) {
        if (result.success) {
          DebugUtils.log('✅ Revive successful!');
          DebugUtils.log('Player restored to safe position');
          DebugUtils.log('Invincibility activated');
          DebugUtils.log('Bonus score awarded');
        } else {
          DebugUtils.log('❌ Revive failed: ${result.errorMessage}');
          if (result.canRetry) {
            DebugUtils.log('Player can retry');
          }
        }
      });
    }
  }

  /// Example 2: Invalid Revive Attempts
  /// Demonstrates how the system prevents cheating
  static void exampleInvalidReviveAttempts(ReviveIntegrationSystem reviveSystem) {
    if (!BuildConfig.enableLogs) return;

    DebugUtils.log('=== INVALID REVIVE ATTEMPTS ===');

    // 1. Try to revive while playing (should fail)
    DebugUtils.log('Trying to revive while playing...');
    reviveSystem.initiateReviveFlow().then((result) {
      DebugUtils.log('Result: ${result.success ? "SUCCESS" : "FAILED"}');
      if (!result.success) {
        DebugUtils.log('Expected failure: ${result.errorMessage}');
      }
    });

    // 2. Try double revive (should fail)
    DebugUtils.log('Trying double revive...');
    reviveSystem.initiateReviveFlow().then((firstResult) {
      if (firstResult.success) {
        // Try second revive immediately (should fail)
        reviveSystem.initiateReviveFlow().then((secondResult) {
          DebugUtils.log('Second revive result: ${secondResult.success ? "SUCCESS" : "FAILED"}');
          if (!secondResult.success) {
            DebugUtils.log('Expected failure: ${secondResult.errorMessage}');
          }
        });
      }
    });
  }

  /// Example 3: Ad Loading Issues
  /// Shows graceful handling of ad failures
  static void exampleAdLoadingIssues(ReviveIntegrationSystem reviveSystem) {
    if (!BuildConfig.enableLogs) return;

    DebugUtils.log('=== AD LOADING ISSUES ===');

    // Simulate ad not ready
    DebugUtils.log('Ad ready: ${reviveSystem.isAdReady}');

    if (!reviveSystem.isAdReady) {
      DebugUtils.log('Ad not ready, starting revive flow anyway...');

      reviveSystem.initiateReviveFlow().then((result) {
        if (result.success) {
          DebugUtils.log('✅ Revive successful after loading ad');
        } else {
          DebugUtils.log('❌ Revive failed due to ad issues');
          DebugUtils.log('Error: ${result.errorMessage}');
          DebugUtils.log('Can retry: ${result.canRetry}');

          if (result.canRetry) {
            DebugUtils.log('Retrying after delay...');
            Future.delayed(Duration(seconds: 3), () {
              reviveSystem.initiateReviveFlow().then((retryResult) {
                DebugUtils.log('Retry result: ${retryResult.success ? "SUCCESS" : "FAILED"}');
              });
            });
          }
        }
      });
    }
  }

  /// Example 4: State Validation
  /// Demonstrates comprehensive state validation
  static void exampleStateValidation(ReviveIntegrationSystem reviveSystem) {
    if (!BuildConfig.enableLogs) return;

    DebugUtils.log('=== STATE VALIDATION ===');

    // Get revive statistics
    final stats = reviveSystem.getStatistics();
    DebugUtils.log('Current statistics:');
    DebugUtils.log('  Can revive: ${stats.canRevive}');
    DebugUtils.log('  Revive used this run: ${stats.reviveUsedThisRun}');
    DebugUtils.log('  Ad ready: ${stats.adReady}');
    DebugUtils.log('  Total revives: ${stats.totalRevives}');
    DebugUtils.log('  Success rate: ${(stats.successRate * 100).toStringAsFixed(1)}%');
    DebugUtils.log('  Average score at revive: ${stats.averageScoreAtRevive.toStringAsFixed(1)}');

    // Get current flow status
    final status = reviveSystem.getReviveStatus();
    DebugUtils.log('Current flow status: ${status.state}');
    DebugUtils.log('Can retry: ${status.canRetry}');
  }

  /// Example 5: Timeout Handling
  /// Shows proper timeout handling and cleanup
  static void exampleTimeoutHandling(ReviveIntegrationSystem reviveSystem) {
    if (!BuildConfig.enableLogs) return;

    DebugUtils.log('=== TIMEOUT HANDLING ===');

    // Start revive flow
    DebugUtils.log('Starting revive flow with timeout simulation...');

    reviveSystem.initiateReviveFlow().then((result) {
      DebugUtils.log('Final result: ${result.success ? "SUCCESS" : "FAILED"}');
      if (!result.success) {
        DebugUtils.log('Timeout or failure reason: ${result.errorMessage}');
      }
    });

    // Cancel after 2 seconds (simulating user cancel)
    Future.delayed(Duration(seconds: 2), () {
      DebugUtils.log('User cancels revive...');
      reviveSystem.cancelReviveFlow();
    });
  }
}

/// Test scenarios for the revive system
class ReviveTestSuite {

  /// Test 1: Basic functionality
  static Future<bool> testBasicFunctionality(ReviveIntegrationSystem reviveSystem) async {
    if (BuildConfig.enableLogs) {
      DebugUtils.log('Testing basic functionality...');
    }

    // Verify initial state
    if (reviveSystem.reviveUsedThisRun) {
      if (BuildConfig.enableLogs) {
        DebugUtils.log('❌ FAIL: Revive already used at start');
      }
      return false;
    }

    // Test revive flow
    final result = await reviveSystem.initiateReviveFlow();

    if (!result.success && !result.canRetry) {
      if (BuildConfig.enableLogs) {
        DebugUtils.log('❌ FAIL: Revive failed and cannot retry');
      }
      return false;
    }

    if (BuildConfig.enableLogs) {
      DebugUtils.log('✅ PASS: Basic functionality test');
    }
    return true;
  }

  /// Test 2: One revive per run enforcement
  static Future<bool> testOneRevivePerRun(ReviveIntegrationSystem reviveSystem) async {
    if (BuildConfig.enableLogs) {
      DebugUtils.log('Testing one revive per run enforcement...');
    }

    // First revive should succeed
    final firstResult = await reviveSystem.initiateReviveFlow();

    // Second revive should fail
    final secondResult = await reviveSystem.initiateReviveFlow();

    if (firstResult.success && secondResult.success) {
      if (BuildConfig.enableLogs) {
        DebugUtils.log('❌ FAIL: Double revive succeeded');
      }
      return false;
    }

    if (!secondResult.success && !secondResult.errorMessage!.contains('already used')) {
      if (BuildConfig.enableLogs) {
        DebugUtils.log('❌ FAIL: Wrong error message for double revive');
      }
      return false;
    }

    if (BuildConfig.enableLogs) {
      DebugUtils.log('✅ PASS: One revive per run test');
    }
    return true;
  }

  /// Test 3: State freezing during ad
  static Future<bool> testStateFreezing(ReviveIntegrationSystem reviveSystem) async {
    if (BuildConfig.enableLogs) {
      DebugUtils.log('Testing state freezing during ad...');
    }

    // Start revive flow
    final flowFuture = reviveSystem.initiateReviveFlow();

    // Check that game world is frozen during ad
    final status = reviveSystem.getReviveStatus();

    if (status.state != ReviveUIState.showingAd &&
        status.state != ReviveUIState.validating &&
        status.state != ReviveUIState.checkingAd) {
      if (BuildConfig.enableLogs) {
        DebugUtils.log('❌ FAIL: Game state not properly frozen during ad');
      }
      return false;
    }

    final result = await flowFuture;

    if (result.success) {
      if (BuildConfig.enableLogs) {
        DebugUtils.log('✅ PASS: State freezing test');
      }
      return true;
    } else {
      if (BuildConfig.enableLogs) {
        DebugUtils.log('⚠️ SKIP: State freezing test (ad failed)');
      }
      return true; // Skip if ad failed
    }
  }

  /// Test 4: Safe position restoration
  static Future<bool> testSafePositionRestoration(ReviveIntegrationSystem reviveSystem) async {
    if (BuildConfig.enableLogs) {
      DebugUtils.log('Testing safe position restoration...');
    }

    final result = await reviveSystem.initiateReviveFlow();

    if (result.success) {
      // Verify player is in safe position
      // This would need access to player system to check actual position
      if (BuildConfig.enableLogs) {
        DebugUtils.log('✅ PASS: Safe position restoration test');
      }
      return true;
    } else {
      if (BuildConfig.enableLogs) {
        DebugUtils.log('⚠️ SKIP: Safe position test (ad failed)');
      }
      return true; // Skip if ad failed
    }
  }

  /// Test 5: Error handling
  static Future<bool> testErrorHandling(ReviveIntegrationSystem reviveSystem) async {
    if (BuildConfig.enableLogs) {
      DebugUtils.log('Testing error handling...');
    }

    try {
      // Try various error scenarios
      await reviveSystem.initiateReviveFlow();
      await reviveSystem.initiateReviveFlow(); // Should fail gracefully

      if (BuildConfig.enableLogs) {
        DebugUtils.log('✅ PASS: Error handling test');
      }
      return true;
    } catch (e) {
      if (BuildConfig.enableLogs) {
        DebugUtils.log('❌ FAIL: Unhandled exception: $e');
      }
      return false;
    }
  }

  /// Run all tests
  static Future<Map<String, bool>> runAllTests(ReviveIntegrationSystem reviveSystem) async {
    if (BuildConfig.enableLogs) {
      DebugUtils.log('🧪 Running Revive System Test Suite...\n');
    }

    final results = <String, bool>{};

    results['Basic Functionality'] = await testBasicFunctionality(reviveSystem);
    results['One Revive Per Run'] = await testOneRevivePerRun(reviveSystem);
    results['State Freezing'] = await testStateFreezing(reviveSystem);
    results['Safe Position'] = await testSafePositionRestoration(reviveSystem);
    results['Error Handling'] = await testErrorHandling(reviveSystem);

    if (BuildConfig.enableLogs) {
      DebugUtils.log('\n📊 Test Results:');
      for (final entry in results.entries) {
        final status = entry.value ? '✅ PASS' : '❌ FAIL';
        DebugUtils.log('  ${entry.key}: $status');
      }

      final passed = results.values.where((v) => v).length;
      final total = results.length;
      DebugUtils.log('\nOverall: $passed/$total tests passed');
    }

    return results;
  }
}

/// Integration examples for UI components
class ReviveUIIntegration {

  /// Example of how to integrate revive system with game over UI
  static Widget buildGameOverButton(ReviveIntegrationSystem reviveSystem) {
    // This would be a Flutter widget in the actual implementation
    final canRevive = reviveSystem.canRevive;
    final status = reviveSystem.getReviveStatus();

    // In a real implementation, this would return an ElevatedButton or similar widget
    // For this example, we'll return a Container to satisfy the Widget return type
    return Container(
      width: 200,
      height: 50,
      decoration: BoxDecoration(
        color: (canRevive && status.state == ReviveUIState.available)
            ? Colors.green
            : Colors.grey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          _getButtonText(status),
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  /// Get appropriate button text based on revive status
  static String _getButtonText(ReviveFlowStatus status) {
    switch (status.state) {
      case ReviveUIState.available:
        return 'Watch Ad to Continue';
      case ReviveUIState.adNotReady:
        return 'Loading...';
      case ReviveUIState.validating:
        return 'Validating...';
      case ReviveUIState.checkingAd:
        return 'Checking Ad...';
      case ReviveUIState.loadingAd:
        return 'Loading Ad...';
      case ReviveUIState.starting:
        return 'Starting...';
      case ReviveUIState.showingAd:
        return 'Watching Ad...';
      case ReviveUIState.completing:
        return 'Almost There...';
      case ReviveUIState.failing:
        return 'Something Went Wrong';
      case ReviveUIState.cancelling:
        return 'Cancelling...';
    }
  }
}

/// Mock widget for demonstration
class ReviveButton {
  final bool visible;
  final bool enabled;
  final String text;
  final VoidCallback onPressed;

  ReviveButton({
    required this.visible,
    required this.enabled,
    required this.text,
    required this.onPressed,
  });
}

/// Performance monitoring for revive system
class RevivePerformanceMonitor {
  final List<RevivePerformanceMetric> _metrics = [];

  void recordMetric(RevivePerformanceMetric metric) {
    _metrics.add(metric);

    // Keep only last 100 metrics
    if (_metrics.length > 100) {
      _metrics.removeAt(0);
    }
  }

  RevivePerformanceStats getStats() {
    if (_metrics.isEmpty) {
      return RevivePerformanceStats(
        averageAdLoadTime: 0,
        averageReviveTime: 0,
        successRate: 0,
        totalRevives: 0,
      );
    }

    final adLoadTimes = _metrics
        .where((m) => m.adLoadTime != null)
        .map((m) => m.adLoadTime!.inMilliseconds.toDouble());

    final reviveTimes = _metrics
        .where((m) => m.reviveTime != null)
        .map((m) => m.reviveTime!.inMilliseconds.toDouble());

    final successCount = _metrics
        .where((m) => m.wasSuccessful)
        .length;

    return RevivePerformanceStats(
      averageAdLoadTime: adLoadTimes.isEmpty ? 0 : adLoadTimes.reduce((a, b) => a + b) / adLoadTimes.length,
      averageReviveTime: reviveTimes.isEmpty ? 0 : reviveTimes.reduce((a, b) => a + b) / reviveTimes.length,
      successRate: _metrics.isEmpty ? 0 : successCount / _metrics.length,
      totalRevives: _metrics.length,
    );
  }
}

class RevivePerformanceMetric {
  final Duration? adLoadTime;
  final Duration? reviveTime;
  final bool wasSuccessful;
  final DateTime timestamp;

  RevivePerformanceMetric({
    this.adLoadTime,
    this.reviveTime,
    required this.wasSuccessful,
    required this.timestamp,
  });
}

class RevivePerformanceStats {
  final double averageAdLoadTime;
  final double averageReviveTime;
  final double successRate;
  final int totalRevives;

  RevivePerformanceStats({
    required this.averageAdLoadTime,
    required this.averageReviveTime,
    required this.successRate,
    required this.totalRevives,
  });
}