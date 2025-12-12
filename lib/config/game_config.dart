import 'package:flutter_neon_runner/models/game_state.dart';

class GameConfig {
  static const double gravity = 0.9;
  static const double jumpForce = 9;
  static const double jumpSustain = 1.0;
  static const int jumpTimerMax = 12;
  static const double groundLevel = 400 - 50; // BASE_HEIGHT - 50
  static const double baseSpeed = 7;
  static const double maxSpeed = 17;
  static const double speedIncrement = 0.001;
  static const int spawnRateMin = 50;
  static const int spawnRateMax = 110;
  static const double powerUpSpawnChance = 0.12;
  static const double baseWidth = 800;
  static const double baseHeight = 400;
}

class ObstacleConfig {
  final ObstacleType type;
  final double minSpeed;
  final double weight;
  final double width;
  final double height;
  final double yOffset; // Offset from ground level
  final int? gapModDivider;
  final int? gapModBase;
  final int? gapMod;

  ObstacleConfig({
    required this.type,
    required this.minSpeed,
    required this.weight,
    required this.width,
    required this.height,
    required this.yOffset,
    this.gapModDivider,
    this.gapModBase,
    this.gapMod,
  });
}

final List<ObstacleConfig> obstacleSpecs = [
  ObstacleConfig(
    type: ObstacleType.laserGrid,
    minSpeed: 10.0,
    weight: 0.92,
    width: 40,
    height: GameConfig.groundLevel,
    yOffset: 0,
    gapMod: 50,
  ),
  ObstacleConfig(
    type: ObstacleType.rotatingLaser,
    minSpeed: 9.0,
    weight: 0.90,
    width: 20,
    height: 20,
    yOffset: 0, // Dynamic logic in spawner
    gapMod: 40,
  ),
  ObstacleConfig(
    type: ObstacleType.fallingDrop,
    minSpeed: 7.0,
    weight: 0.85,
    width: 40,
    height: 40,
    yOffset: 0, // Ignored
    gapMod: 20,
  ),
  ObstacleConfig(
    type: ObstacleType.movingAerial,
    minSpeed: 7.0,
    weight: 0.88,
    width: 30,
    height: 30,
    yOffset: 90,
    gapMod: 0,
  ),
  ObstacleConfig(
    type: ObstacleType.hazardZone,
    minSpeed: 5.0,
    weight: 0.70,
    width: 200, // randomized in logic
    height: 40,
    yOffset: 75,
    gapModDivider: 1, // Logic handles this
    gapModBase: 40,
  ),
  ObstacleConfig(
    type: ObstacleType.movingPlatform,
    minSpeed: 8.0,
    weight: 0.60,
    width: 120, // randomized
    height: 20,
    yOffset: 65,
    gapModDivider: 1,
    gapModBase: 30,
  ),
  ObstacleConfig(
    type: ObstacleType.aerial,
    minSpeed: 0,
    weight: 0.45,
    width: 40,
    height: 30,
    yOffset: 50, // randomized
    gapMod: 0,
  ),
  ObstacleConfig(
    type: ObstacleType.spike,
    minSpeed: 0,
    weight: 0.30,
    width: 60, // Increased width for better visibility
    height: 40, // Increased height for better visibility
    yOffset: 40, // Adjusted yOffset to match height
    gapMod: 0,
  ),
];

class PowerUpConfig {
  static const double width = 30;
  static const double height = 30;
  static const Map<PowerUpType, double> spawnWeights = {
    PowerUpType.shield: 0.25, // remainder after others
    PowerUpType.multiplier: 0.25, // > 0.75
    PowerUpType.timeWarp: 0.15, // > 0.55
    PowerUpType.magnet: 0.15, // > 0.40
  };
}