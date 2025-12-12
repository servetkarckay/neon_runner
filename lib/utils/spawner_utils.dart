import 'dart:math';

import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/models/powerup_data.dart';
import 'package:flutter_neon_runner/models/particle_data.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter/material.dart'; // For Color

// --- Object Pooling ---

ObstacleData getObstacleFromPool(List<ObstacleData> pool, int idCounter) {
  ObstacleData obs;

  if (pool.isNotEmpty) {
    obs = pool.removeLast();
  } else {
    // Create new object if pool is empty
    obs = SimpleObstacleData(
      id: idCounter,
      type: ObstacleType.ground,
      x: 0,
      y: 0,
      width: 0,
      height: 0,
    );
  }

  // Reset Core Identity
  obs.id = idCounter;
  obs.passed = false;
  obs.grazed = false;

  // AGGRESSIVE SANITIZATION: Reset all potential dynamic properties
  // This ensures no "ghost" physics (like velocity, rotation, or oscillation) leak from previous lives.
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

PowerUpData getPowerUpFromPool(List<PowerUpData> pool, PowerUpType type, double x, double y) {
  PowerUpData pu;
  if (pool.isNotEmpty) {
    pu = pool.removeLast();
    // When re-using from pool, update its properties
    pu.id = Random().nextInt(100000); // Unique ID for key in lists
    pu.updatePosition(x, y, newWidth: PowerUpConfig.width, newHeight: PowerUpConfig.height);
    pu.type = type;
    pu.active = true;
    pu.floatOffset = Random().nextDouble() * 100;
  } else {
    pu = PowerUpData(
      id: Random().nextInt(100000), // Unique ID for key in lists
      type: type,
      active: true,
      floatOffset: Random().nextDouble() * 100,
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

// --- Configuration Logic ---

double configureObstacle(ObstacleData obs, double speed, GameConfig config, double baseX) {
  final typeRoll = Random().nextDouble();
  final groundLevel = GameConfig.groundLevel;

  // Find matching config
  ObstacleConfig? selectedSpec;
  for (var spec in obstacleSpecs) {
    if (speed > spec.minSpeed && typeRoll > spec.weight) {
      selectedSpec = spec;
      break;
    }
  }

  // Default to GROUND if no match
  final selectedType = selectedSpec?.type ?? ObstacleType.ground;

  // Set Type-Specific Properties
  obs.x = baseX;
  obs.type = selectedType;
  obs.grazed = false;
  obs.passed = false;
  
  // Now apply specific properties based on type
  switch (selectedType) {
    case ObstacleType.laserGrid:
      obs as LaserGridObstacleData;
      obs.type = ObstacleType.laserGrid;
      obs.width = 40;
      obs.height = groundLevel;
      obs.y = 0;
      final double safeZoneSize = 90;
      final double minSafe = 60;
      final double maxSafe = groundLevel - 60;
      obs.gapY = (Random().nextDouble() * (maxSafe - minSafe + 1) + minSafe);
      obs.gapHeight = safeZoneSize;
      return 50;

    case ObstacleType.rotatingLaser:
      obs as RotatingLaserObstacleData;
      obs.type = ObstacleType.rotatingLaser;
      final rlHeight = Random().nextDouble() > 0.5 ? groundLevel - 45 : groundLevel - 80;
      obs.width = 20;
      obs.height = 20;
      obs.y = rlHeight;
      obs.initialY = rlHeight;
      obs.beamLength = 120;
      obs.rotationSpeed = 0.05 + Random().nextDouble() * 0.05;
      obs.angle = Random().nextDouble() * pi * 2;
      return 40;

    case ObstacleType.fallingDrop:
      obs as FallingObstacleData;
      obs.type = ObstacleType.fallingDrop;
      obs.width = 40;
      obs.height = 40;
      obs.y = -100;
      obs.initialY = -100;
      obs.velocityY = 0;
      return 20;

    case ObstacleType.movingAerial:
      obs as MovingAerialObstacleData;
      obs.type = ObstacleType.movingAerial;
      obs.width = 30;
      obs.height = 30;
      final maY = groundLevel - 90;
      obs.y = maY;
      obs.initialY = maY;
      return 0;

    case ObstacleType.hazardZone:
      obs as HazardObstacleData;
      obs.type = ObstacleType.hazardZone;
      final hzW = 200 + Random().nextDouble() * 100;
      obs.width = hzW;
      obs.height = 40;
      final hzY = groundLevel - 75;
      obs.y = hzY;
      obs.initialY = hzY;
      return (hzW / speed).floor() + 40;

    case ObstacleType.movingPlatform:
      obs as MovingPlatformObstacleData;
      obs.type = ObstacleType.movingPlatform;
      final isMoving = speed > 10 && Random().nextDouble() > 0.5;
      final mpW = 120 + Random().nextDouble() * 80;
      obs.width = mpW;
      obs.height = 20;
      final mpY = groundLevel - 65;
      obs.y = mpY;
      obs.initialY = mpY;
      if (isMoving) {
        obs.oscillationAxis = Random().nextDouble() > 0.5 ? OscillationAxis.horizontal : OscillationAxis.vertical;
      } else {
        // Downgrade to standard PLATFORM if not moving
        obs.type = ObstacleType.platform;
      }
      // Fix: Add extra gap for horizontal oscillation amplitude (approx 40px safety)
      return ((mpW + 50) / speed).floor() + 30;

    case ObstacleType.aerial:
      obs as SimpleObstacleData;
      obs.type = ObstacleType.aerial;
      final isHigh = Random().nextDouble() > 0.5;
      obs.width = 40;
      obs.height = 30;
      obs.y = groundLevel - (isHigh ? 90 : 50);
      return 0;

    case ObstacleType.spike:
      obs as SimpleObstacleData;
      obs.type = ObstacleType.spike;
      obs.width = 60;
      obs.height = 40;
      obs.y = groundLevel - 40;
      return 0;

    case ObstacleType.ground:
    case ObstacleType.platform:
    default: // GROUND or PLATFORM
      obs as SimpleObstacleData;
      obs.type = ObstacleType.ground; // Default to ground
      obs.width = 30;
      obs.height = 30;
      obs.y = groundLevel - 30;
      return 0;
  }
}
