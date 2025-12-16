# NEON RUNNER

A production-ready, mobile-first endless runner game built with Flutter and Flame engine.

## 🎮 Features

- **Mobile-First Design**: Touch controls, thumb-friendly UI, neon cyber visual style
- **Robust Systems**: Modular architecture with single responsibility principle
- **Performance Optimized**: Stable 60 FPS on mid-range Android devices
- **Monetization**: Rewarded ad revive system with anti-cheat measures
- **Leaderboard**: Redis-backed with validation and offline resilience
- **Game Loop Safety**: Comprehensive error handling and recovery

## 🚀 Performance

### Target Device Specifications
- **Minimum**: Snapdragon 425+ (2015+), 2GB RAM, 720p display
- **Performance**: Stable 60 FPS, <16.67ms frame time
- **Memory**: <150MB peak usage
- **Battery**: 2+ hours continuous gameplay

### Optimization Features
- Object pooling for zero allocations
- Adaptive quality based on device performance
- Delta-time based movement
- Memory pressure detection

## 🧪 Testing

### Unit Tests
- Collision logic validation
- Revive system integrity
- State machine transitions
- Score validation and anti-cheat

### Integration Tests
- Complete game flow scenarios
- Ad integration testing
- Leaderboard submission flow
- Performance stress testing

### Running Tests
```bash
# Run all tests
flutter test

# Run unit tests only
flutter test test/unit/

# Run integration tests only
flutter test test/integration/

# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 🔧 Debug vs Production

### Debug Mode
- FPS counter overlay
- Hitbox visualization
- Performance metrics display
- Memory usage monitoring
- Touch input indicators
- Verbose logging
- Ad simulation mode

### Production Mode
- No debug UI
- No console logs
- Maximum performance
- Aggressive garbage collection
- Hardware acceleration
- Crash reporting enabled

### Build Configuration
```dart
import 'package:flutter_neon_runner/config/build_config.dart';

// Check build mode
if (BuildConfig.isDebugMode) {
  // Debug-only features
}

// Feature flags
final maxParticles = BuildConfig.maxParticles;
final enableFPSCounter = BuildConfig.enableFPSCounter;
final targetFPS = BuildConfig.targetFPS;
```

## 🏗️ Architecture

### Core Systems
- **GameStateController**: Central state management with FSM
- **GameLoopController**: Coordinates all game systems
- **PlayerSystem**: Player movement, animation, state
- **EnemySystem**: Enemy spawning and behavior
- **ObstacleSystem**: Obstacle generation and patterns
- **CollisionSystem**: Optimized collision detection
- **UISystem**: Mobile-optimized UI rendering
- **AudioSystem**: Sound and music management
- **AdsSystem**: Rewarded ad integration
- **LeaderboardSystem**: Score tracking and submission

### Data Flow
```
Input → GameStateController → System Updates → Render
    ↓                                    ↓
Events ← GameEventBus ← System Communication
```

## 🎯 Game Flow Integration

### Complete Play Session
1. **Main Menu** → Start Game
2. **Playing** → Collect power-ups, avoid obstacles
3. **Death** → Show Game Over
4. **Revive Option** → Watch ad → Continue playing
5. **Game Over** → Submit score → Main Menu

### State Transitions
```
menu → playing
playing ↔ paused
playing → gameOver
playing → reviving → playing
reviving → gameOver
gameOver → menu
```

## 🛡️ Safety & Validation

### Game Loop Safety
- Never crashes main loop
- Comprehensive error recovery
- Safe mode for critical errors
- Automatic state validation

### Score Integrity
- Hash-based validation
- Duplicate submission prevention
- Rate limiting
- Revive abuse detection

### Performance Protection
- Frame time monitoring
- Memory pressure detection
- Adaptive quality adjustment
- Emergency performance modes

## 📱 Mobile Optimization

### UI/UX Guidelines
- **Simple Text**: START, SOUND, LEADERBOARD, GAME OVER
- **Thumb-Friendly**: Minimum 48dp touch targets
- **Neon Style**: Dark backgrounds, glowing UI, minimal text
- **Animations**: Smooth fade and scale transitions
- **Readability**: Large fonts, high contrast

### Touch Controls
- Single tap for jump
- Swipe down for duck
- Large hit areas
- Visual feedback

## 🔌 Integration

### Rewarded Ads
```dart
// Show ad for revive
gameState.gameInstance.adsController.showRewardedAd(() {
  gameStateProvider.resumeGame();
});
```

### Leaderboard
```dart
// Submit score
await leaderboardSystem.submitScore(score);

// Get leaderboard
final leaderboard = await leaderboardSystem.getLeaderboard();
```

## 📊 Performance Metrics

### Target Performance
| Metric | Target | Acceptable |
|--------|--------|------------|
| FPS | 60 | 45-60 |
| Frame Time | <16.67ms | <25ms |
| Memory | <150MB | <200MB |
| Startup Time | <2s | <3s |

### Debug Tools
```dart
// Performance profiling
PerformanceProfiler.start('update_operation');
// ... perform operation
PerformanceProfiler.end('update_operation');

// Memory monitoring
final stats = performanceSystem.getPerformanceStats();
print('Pool sizes: ${stats.vector2PoolSize}');
```

## 🎨 Visual Design

### Color Palette
- Primary Neon: `#03A062` (Green)
- Accent: `#FF6B6B` (Red)
- Background: `#000000` (Black)
- Text: `#FFFFFF` (White)
- UI Glow: Neon colors with 80% opacity

### Font Stack
- Primary: 'Orbitron' (Titles, buttons)
- Secondary: 'Share Tech Mono' (Score, labels)

## 🔧 Development Setup

### Requirements
- Flutter SDK 3.19+
- Dart 3.0+
- Android API 21+ (Android 5.0)
- iOS 12.0+

### Local Development
```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run --debug

# Run in profile mode
flutter run --profile

# Run tests
flutter test

# Analyze code
flutter analyze
```

### Build Commands
```bash
# Debug build
flutter build apk --debug

# Profile build
flutter build apk --profile

# Release build
flutter build apk --release

# Web build
flutter build web --release
```

## 📋 Testing Checklist

Before release:
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Performance meets targets on test devices
- [ ] No memory leaks detected
- [ ] Ad integration works correctly
- [ ] Leaderboard submission succeeds
- [ ] Game never crashes during normal play
- [ ] UI is responsive and readable
- [ ] Audio works correctly
- [ ] Game state persists properly

## 🚨 Troubleshooting

### Common Issues
1. **Low FPS**: Check adaptive quality settings, reduce particles
2. **Memory Issues**: Verify object pool usage, check for leaks
3. **Ad Problems**: Ensure ad units are configured correctly
4. **Leaderboard Errors**: Check network connectivity, API keys

### Debug Mode
Enable debug mode to see:
- FPS counter
- Hitbox visualization
- Performance metrics
- Memory usage
- Touch indicators

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
