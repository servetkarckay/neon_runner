import 'dart:math';

import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/models/powerup_data.dart';
import 'package:flutter_neon_runner/models/particle_data.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter/material.dart'; // For Color

/// Represents the configuration for spawning a new obstacle.
class SpawnConfig {
  final ObstacleType type;
  final double y;
  final double width;
  final double height;
  final OscillationAxis? oscillationAxis; // For MovingPlatformObstacleData
  final double? gapY; // For LaserGridObstacleData
  final double? gapHeight; // For LaserGridObstacleData

  SpawnConfig({
    required this.type,
    required this.y,
    required this.width,
    required this.height,
    this.oscillationAxis,
    this.gapY,
    this.gapHeight,
  });
}

class SpawnerSystem {
  final Random _random = Random();
  final List<ObstacleConfig> obstacleSpecs = [
    // Define your obstacle specs here, similar to how it was implied in getObstacleFromPool
    // Example:
    // ObstacleConfig(ObstacleType.ground, 0.5, 0),
    // ObstacleConfig(ObstacleType.aerial, 0.7, 5),
    // ObstacleConfig(ObstacleType.movingAerial, 0.8, 10),
  ];

  // This will be populated from game_config.dart
  // For now, I will use a placeholder
  final double groundLevel = GameConfig.groundLevel;


  // NOTE: The previous spawner_utils.dart had a global getRandomSpawnConfig.
  // Now it's a method of SpawnerSystem.
  // This needs to implement the logic for selecting an obstacle type and its initial properties.
  // For now, a placeholder that mimics basic functionality.
  SpawnConfig getRandomSpawnConfig(double currentSpeed) {
    ObstacleType selectedType;
    // Example logic - this needs to be properly defined based on game balance
    if (currentSpeed < 10) {
      selectedType = ObstacleType.ground;
    } else if (currentSpeed < 20) {
      selectedType = _random.nextBool() ? ObstacleType.ground : ObstacleType.aerial;
    } else {
      selectedType = ObstacleType.values[_random.nextInt(ObstacleType.values.length)];
    }

    double y = groundLevel - 30; // Default for ground
    double width = 30;
    double height = 30;
    OscillationAxis? oscillationAxis;
    double? gapY;
    double? gapHeight;

    // Based on selectedType, adjust y, width, height, and other specific properties
    switch (selectedType) {
      case ObstacleType.aerial:
        y = groundLevel - (_random.nextBool() ? 90 : 50);
        width = 40;
        height = 30;
        break;
      case ObstacleType.movingAerial:
        y = groundLevel - 90;
        width = 30;
        height = 30;
        break;
      case ObstacleType.hazardZone:
        width = 200 + _random.nextDouble() * 100;
        height = 40;
        y = groundLevel - 75;
        break;
      case ObstacleType.movingPlatform:
        width = 120 + _random.nextDouble() * 80;
        height = 20;
        y = groundLevel - 65;
        oscillationAxis = _random.nextDouble() > 0.5
            ? OscillationAxis.horizontal
            : OscillationAxis.vertical;
        break;
      case ObstacleType.laserGrid:
        width = 40;
        height = groundLevel;
        y = 0;
        final double safeZoneSize = 90;
        final double minSafe = 60;
        final double maxSafe = groundLevel - 60;
        gapY = (_random.nextDouble() * (maxSafe - minSafe + 1) + minSafe);
        gapHeight = safeZoneSize;
        break;
      case ObstacleType.rotatingLaser:
        width = 40;
        height = 40;
        y = _random.nextDouble() > 0.5 ? groundLevel - 45 : groundLevel - 80;
        break;
      case ObstacleType.fallingDrop:
        width = 40;
        height = 40;
        y = -100;
        break;
      case ObstacleType.spike:
        width = 60;
        height = 40;
        y = groundLevel - 40;
        break;
      case ObstacleType.slantedSurface:
        width = 80;
        height = 30;
        y = groundLevel - 30;
        break;
      case ObstacleType.platform:
        width = 80;
        height = 10;
        y = groundLevel - 30;
        break;
      case ObstacleType.ground:
        // Default values already set
        break;
    }

    return SpawnConfig(
      type: selectedType,
      y: y,
      width: width,
      height: height,
      oscillationAxis: oscillationAxis,
      gapY: gapY,
      gapHeight: gapHeight,
    );
  }

  ObstacleData getObstacleFromPool(List<ObstacleData> pool, int idCounter) {
    final typeRoll = _random.nextDouble();
    final speed = 10.0; // Assuming a default speed for type determination
    ObstacleConfig? selectedSpec;
    for (var spec in obstacleSpecs) {
      if (speed > spec.minSpeed && typeRoll > spec.weight) {
        selectedSpec = spec;
        break;
      }
    }
    final selectedType = selectedSpec?.type ?? ObstacleType.ground;

    // Find a suitable obstacle in the pool
    ObstacleData? obs;
    int? obsIndex;
    for (var i = 0; i < pool.length; i++) {
      if (pool[i].type == selectedType) {
        obs = pool[i];
        obsIndex = i;
        break;
      }
    }

    if (obsIndex != null) {
      obs = pool[obsIndex];
      pool.removeAt(obsIndex);
    } else {
      obs = createObstacle(selectedType, idCounter);
    }

    // Reset Core Identity
    obs.id = idCounter;
    obs.passed = false;
    obs.grazed = false;

    // AGGRESSIVE SANITIZATION: Reset all potential dynamic properties
    if (obs is HazardObstacleData) obs.initialY = 0;
    if (obs is MovingAerialObstacleData) obs.initialY = 0;
    if (obs is MovingPlatformObstacleData) {
      obs.initialY = 0;
      obs.oscillationAxis = OscillationAxis.vertical;
    }
    if (obs is FallingObstacleData) {
      obs.initialY = 0;
      obs.velocityY = 0;
    }
    if (obs is RotatingLaserObstacleData) {
      obs.initialY = 0;
      obs.angle = 0;
      obs.rotationSpeed = 0;
      obs.beamLength = 0;
    }
    if (obs is LaserGridObstacleData) {
      obs.gapY = 0;
      obs.gapHeight = 0;
    }

    return obs;
  }

  ObstacleData createObstacle(ObstacleType type, int id) {
    // Provide default values for x, y, width, height for initial creation.
    // These will be updated later when spawned.
    const double defaultX = 0;
    const double defaultY = 0;
    const double defaultWidth = 0;
    const double defaultHeight = 0;

    switch (type) {
      case ObstacleType.laserGrid:
        return LaserGridObstacleData(
          id: id,
          x: defaultX,
          y: defaultY,
          width: defaultWidth,
          height: defaultHeight,
          gapY: 0, // Placeholder
          gapHeight: 0, // Placeholder
        );
      case ObstacleType.rotatingLaser:
        return RotatingLaserObstacleData(
          id: id,
          x: defaultX,
          y: defaultY,
          width: defaultWidth,
          height: defaultHeight,
          initialY: defaultY, // Placeholder
        );
      case ObstacleType.fallingDrop:
        return FallingObstacleData(
          id: id,
          x: defaultX,
          y: defaultY,
          width: defaultWidth,
          height: defaultHeight,
          initialY: defaultY, // Placeholder
        );
      case ObstacleType.movingAerial:
        return MovingAerialObstacleData(
          id: id,
          x: defaultX,
          y: defaultY,
          width: defaultWidth,
          height: defaultHeight,
          initialY: defaultY, // Placeholder
        );
      case ObstacleType.hazardZone:
        return HazardObstacleData(
          id: id,
          x: defaultX,
          y: defaultY,
          width: defaultWidth,
          height: defaultHeight,
          initialY: defaultY, // Placeholder
        );
      case ObstacleType.movingPlatform:
        return MovingPlatformObstacleData(
          id: id,
          x: defaultX,
          y: defaultY,
          width: defaultWidth,
          height: defaultHeight,
          initialY: defaultY, // Placeholder
        );
      case ObstacleType.slantedSurface:
        return SlantedObstacleData(
          id: id,
          x: defaultX,
          y: defaultY,
          width: defaultWidth,
          height: defaultHeight,
          lineX1: 0,
          lineY1: 0,
          lineX2: 0,
          lineY2: 0,
        );
      case ObstacleType.spike:
        return SpikeObstacleData(
          id: id,
          x: defaultX,
          y: defaultY,
          width: defaultWidth,
          height: defaultHeight,
        );
      case ObstacleType.aerial:
        return AerialObstacleData(
          id: id,
          x: defaultX,
          y: defaultY,
          width: defaultWidth,
          height: defaultHeight,
        );
      case ObstacleType.ground:
      case ObstacleType.platform: // Use SimpleObstacleData for platform
        return SimpleObstacleData(
          id: id,
          type: type,
          x: defaultX,
          y: defaultY,
          width: defaultWidth,
          height: defaultHeight,
        );
    }
  }

  PowerUpData getPowerUpFromPool(
      List<PowerUpData> pool, PowerUpType type, double x, double y) {
    PowerUpData pu;
    if (pool.isNotEmpty) {
      pu = pool.removeLast();
      // When re-using from pool, update its properties
      pu.id = _random.nextInt(100000); // Unique ID for key in lists
      pu.updatePosition(x, y,
          newWidth: PowerUpConfig.width, newHeight: PowerUpConfig.height);
      pu.type = type;
      pu.active = true;
      pu.floatOffset = _random.nextDouble() * 100;
    } else {
      pu = PowerUpData(
        id: _random.nextInt(100000), // Unique ID for key in lists
        type: type,
        active: true,
        floatOffset: _random.nextDouble() * 100,
        x: x,
        y: y,
        width: PowerUpConfig.width,
        height: PowerUpConfig.height,
      );
    }
    return pu;
  }

  ParticleData getParticleFromPool(
    List<ParticleData> pool,
    double x,
    double y,
    double vx,
    double vy,
    Color color,
    double size,
    double life,
  ) {
    ParticleData p;
    if (pool.isNotEmpty) {
      p = pool.removeLast();
    } else {
      p = ParticleData(
        x: 0,
        y: 0,
        velocityX: 0,
        velocityY: 0,
        life: 0,
        maxLife: 0,
        color: Colors.transparent,
        size: 0,
      );
    }
    p.x = x;
    p.y = y;
    p.velocityX = vx;
    p.velocityY = vy;
    p.color = color;
    p.size = size;
    p.life = life;
    p.maxLife = life;
    return p;
  }
}

class ObstacleConfig {
  final ObstacleType type;
  final double weight;
  final double minSpeed;

  ObstacleConfig(this.type, this.weight, this.minSpeed);
}