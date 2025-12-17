import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_neon_runner/game/collision/collision_types.dart';
import 'package:flutter_neon_runner/game/collision/collision_engine.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/models/game_state.dart';

void main() {
  group('Collision Resolution Tests', () {
    late CollisionEngine collisionEngine;
    late PlayerEntity player;
    late ObstacleEntity obstacle;

    setUp(() {
      collisionEngine = CollisionEngine(cellSize: 100.0);
    });

    test('should separate overlapping entities', () {
      // Create player and overlapping obstacle
      final playerData = PlayerData();
      playerData.x = 100;
      playerData.y = 100;
      playerData.width = 50;
      playerData.height = 50;
      playerData.currentVelocity = Vector2(10, 0);

      player = PlayerEntity(
        id: 'player',
        playerData: playerData,
        currentHitbox: ui.Rect.fromLTWH(playerData.x, playerData.y, playerData.width, playerData.height),
      );

      final obstacleData = SimpleObstacleData(
        id: 1,
        type: ObstacleType.platform,
        x: 130, // Overlapping by 30 pixels
        y: 100,
        width: 50,
        height: 50,
      );

      obstacle = ObstacleEntity(
        id: 'obstacle1',
        obstacleData: obstacleData,
      );

      // Add entities to collision system
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);

      // Process collisions
      final events = collisionEngine.detectAndResolveCollisions();

      // Verify collision was detected
      expect(events.length, 1);

      // Verify entities were separated
      expect(playerData.x, lessThan(100)); // Player should be pushed left
      expect(obstacleData.x, 130.0); // Obstacle should not move (static)
    });

    test('should resolve multiple collisions', () {
      // Create player
      final playerData = PlayerData();
      playerData.x = 100;
      playerData.y = 100;
      playerData.width = 40;
      playerData.height = 40;
      playerData.currentVelocity = Vector2(0, 0);

      player = PlayerEntity(
        id: 'player',
        playerData: playerData,
        currentHitbox: ui.Rect.fromLTWH(playerData.x, playerData.y, playerData.width, playerData.height),
      );

      // Create two overlapping obstacles
      final obstacle1Data = SimpleObstacleData(
        id: 1,
        type: ObstacleType.platform,
        x: 130, // Overlapping by 30 pixels on right
        y: 100,
        width: 40,
        height: 40,
      );

      final obstacle2Data = MovingPlatformObstacleData(
        id: 2,
        x: 100, // Overlapping vertically
        y: 130,
        width: 40,
        height: 40,
        initialY: 130,
        oscillationAxis: OscillationAxis.vertical,
      );

      final obstacle1 = ObstacleEntity(
        id: 'obstacle1',
        obstacleData: obstacle1Data,
      );

      final obstacle2 = ObstacleEntity(
        id: 'obstacle2',
        obstacleData: obstacle2Data,
      );

      // Add entities
      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle1);
      collisionEngine.addEntity(obstacle2);

      // Process collisions
      final events = collisionEngine.detectAndResolveCollisions();

      // Verify both collisions were detected
      expect(events.length, 2);

      // Verify player was pushed away from both obstacles
      expect(playerData.x, lessThan(100)); // Pushed left from obstacle1
      expect(playerData.y, lessThan(100)); // Pushed up from obstacle2
    });

    test('should handle deep penetration', () {
      // Create player
      final playerData = PlayerData();
      playerData.x = 100;
      playerData.y = 100;
      playerData.width = 50;
      playerData.height = 50;
      playerData.currentVelocity = Vector2(0, 0);

      player = PlayerEntity(
        id: 'player',
        playerData: playerData,
        currentHitbox: ui.Rect.fromLTWH(playerData.x, playerData.y, playerData.width, playerData.height),
      );

      // Create obstacle deeply overlapping with player
      final obstacleData = SimpleObstacleData(
        id: 1,
        type: ObstacleType.platform,
        x: 110, // Overlapping by 40 pixels
        y: 110,
        width: 50,
        height: 50,
      );

      obstacle = ObstacleEntity(
        id: 'obstacle1',
        obstacleData: obstacleData,
      );

      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);

      // Process collisions
      final events = collisionEngine.detectAndResolveCollisions();

      // Verify collision was detected
      expect(events.length, 1);

      // Verify entities were completely separated
      expect(playerData.x, lessThan(100)); // Player should be pushed left
      expect(playerData.y, lessThan(100)); // Player should be pushed up
    });

    test('should not move static obstacles', () {
      // Create player
      final playerData = PlayerData();
      playerData.x = 100;
      playerData.y = 100;
      playerData.width = 50;
      playerData.height = 50;
      playerData.currentVelocity = Vector2(10, 0);

      player = PlayerEntity(
        id: 'player',
        playerData: playerData,
        currentHitbox: ui.Rect.fromLTWH(playerData.x, playerData.y, playerData.width, playerData.height),
      );

      // Create static obstacle
      final obstacleData = SimpleObstacleData(
        id: 1,
        type: ObstacleType.platform,
        x: 130, // Overlapping
        y: 100,
        width: 50,
        height: 50,
      );

      obstacle = ObstacleEntity(
        id: 'obstacle1',
        obstacleData: obstacleData,
      );

      final originalObstacleX = obstacleData.x;
      final originalObstacleY = obstacleData.y;

      collisionEngine.addEntity(player);
      collisionEngine.addEntity(obstacle);

      // Process collisions
      final events = collisionEngine.detectAndResolveCollisions();

      // Verify collision was detected and resolved
      expect(events.length, 1);

      // Verify obstacle didn't move (static)
      expect(obstacleData.x, originalObstacleX);
      expect(obstacleData.y, originalObstacleY);

      // Verify player moved away
      expect(playerData.x, lessThan(100));
    });

    test('should not move static obstacles when they collide', () {
      // Create two static obstacles overlapping
      final obstacle1Data = SimpleObstacleData(
        id: 1,
        type: ObstacleType.platform,
        x: 100,
        y: 100,
        width: 50,
        height: 50,
      );

      final obstacle2Data = SimpleObstacleData(
        id: 2,
        type: ObstacleType.platform,
        x: 130, // Overlapping by 30 pixels
        y: 100,
        width: 50,
        height: 50,
      );

      final obstacle1 = ObstacleEntity(
        id: 'obstacle1',
        obstacleData: obstacle1Data,
      );

      final obstacle2 = ObstacleEntity(
        id: 'obstacle2',
        obstacleData: obstacle2Data,
      );

      final originalObstacle1X = obstacle1Data.x;
      final originalObstacle2X = obstacle2Data.x;

      collisionEngine.addEntity(obstacle1);
      collisionEngine.addEntity(obstacle2);

      // Process collisions
      final events = collisionEngine.detectAndResolveCollisions();

      // Since both are static obstacles, no resolution should occur
      expect(events.length, 0);

      // Verify neither obstacle moved
      expect(obstacle1Data.x, originalObstacle1X);
      expect(obstacle2Data.x, originalObstacle2X);
    });
  });
}