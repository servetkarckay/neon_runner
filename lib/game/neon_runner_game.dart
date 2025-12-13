import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_neon_runner/audio/audio_controller.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/game/player.dart'; // Import PlayerComponent
import 'package:flutter_neon_runner/game/obstacle_manager.dart'; // Import ObstacleManager
import 'package:flutter_neon_runner/game/powerup_manager.dart'; // Import PowerUpManager
import 'package:flutter_neon_runner/game/particle_manager.dart'; // Import ParticleManager
import 'package:flutter_neon_runner/ads_controller.dart'; // Import AdsController
import 'package:flutter_neon_runner/local_storage_service.dart'; // Import LocalStorageService
import 'package:flutter_neon_runner/utils/collision_utils.dart'; // For collision utilities
import 'package:flutter_neon_runner/utils/math_utils.dart'; // For math utilities like hslToColor and lineRect
import 'dart:math'; // For cos, sin, max, min functions
import 'dart:ui' as ui; // Import for ui.Rect

import 'package:flutter_neon_runner/game_state_provider.dart'; // Import GameStateProvider

class NeonRunnerGame extends FlameGame {
  late final GameStateProvider _gameStateProvider;

  NeonRunnerGame(this._gameStateProvider);

  late final AudioController _audioController;
  late final AdsController _adsController;
  late final LocalStorageService _localStorageService;
  late final PlayerData _playerData;
  late final PlayerComponent _playerComponent;
  late final ObstacleManager _obstacleManager;
  late final PowerUpManager _powerUpManager;
  late final ParticleManager _particleManager;

  PlayerData get playerData => _playerData;
  AudioController get audioController => _audioController;
  AdsController get adsController => _adsController;
  LocalStorageService get localStorageService => _localStorageService;

  // late final Hud _hud; // Declare Hud - Removed as it will be a Flutter Widget

  double speed = 0;
  int score = 0;
  int frames = 0;
  int highscore = 0;
  int nextSpawn = 0;
  bool inputLock = false;
  bool isTransitioning = false;
  bool scoreGlitch = false;
  String? _powerUpMessage;
  int _powerUpMessageTimer = 0;

  String? userId;
  String? userMask;

  bool tutorialActive = false;
  String tutorialState = 'INTRO'; // INTRO | JUMP_TEACH | DUCK_TEACH | COMPLETED

  final List<ui.Rect> _trailHistory = []; // Player trail history
  final Paint _playerTrailPaint = Paint()
    ..blendMode = BlendMode.plus;

  @override
  Color backgroundColor() => const Color(0xFF000000); // Black background

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Initialize components
    _audioController = AudioController();
    _adsController = AdsController();
    _localStorageService = LocalStorageService();
    _playerData = PlayerData();
    _playerComponent = PlayerComponent(_playerData); // Correct initialization
    add(_playerComponent); // Add to game
    _obstacleManager = ObstacleManager(
      baseWidth: GameConfig.baseWidth,
      groundLevel: GameConfig.groundLevel,
      currentSpeed: speed,
      frames: frames,
    );
    _powerUpManager = PowerUpManager(
      playerData: _playerData,
      baseWidth: GameConfig.baseWidth,
      groundLevel: GameConfig.groundLevel,
      currentSpeed: speed,
      frames: frames,
    );
    _particleManager = ParticleManager();

    // Initialize audio
    await _audioController.init();
    // Initialize ads
    await _adsController.init();
    // Initialize local storage
    await _localStorageService.init();

    highscore = _localStorageService.getHighscore();
    tutorialActive = !_localStorageService.getTutorialSeen();
    userId = _localStorageService.getUserId();

    // Set game dimensions (handled by FlameGame itself, removed direct assignment)


    add(_obstacleManager);
    add(_powerUpManager);
    add(_particleManager);

    // Set initial game state
    // For now, it will be menu, but we will add logic later to handle it
    // from an overlay widget.
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameStateProvider.currentGameState != GameState.playing) return;

    frames++;
    final timeScale = _playerData.timeWarpTimer > 0 ? 0.5 : 1.0; // Time warp speed reduction

    if (_playerData.timeWarpTimer > 0) {
      _playerData.timeWarpTimer--;
    }

    if (tutorialActive) {
      _updateTutorial();
    } else {
      if (speed < GameConfig.maxSpeed) {
        speed += GameConfig.speedIncrement;
      }
      if (frames >= nextSpawn) {
        _spawnObstacleAndPowerUp();
      }
    }

    // Score update
    if (frames % GameConfig.scoreUpdateFrequency == 0) {
      score += (1 * _playerData.scoreMultiplier).toInt();
      if (score > 0 && score % GameConfig.scoreGlitchTrigger == 0) {
        _audioController.playScore();
        scoreGlitch = true;
        Future.delayed(const Duration(milliseconds: GameConfig.scoreGlitchDurationLong), () {
          scoreGlitch = false;
        });
      }
    }
    if (Random().nextDouble() < GameConfig.randomScoreGlitchChance && !scoreGlitch) {
      scoreGlitch = true;
      Future.delayed(const Duration(milliseconds: GameConfig.scoreGlitchDurationShort), () {
        scoreGlitch = false;
      });
    }

    // Player physics
    // Capture player's initial rect before position update
    final playerInitialRect = ui.Rect.fromLTWH(_playerData.x, _playerData.y, _playerData.width, _playerData.height);

    if (_playerData.isJumping && _playerData.isHoldingJump && _playerData.jumpTimer > 0) {
      _playerData.velocityY -= GameConfig.jumpSustain * timeScale;
      _playerData.jumpTimer--;
    }
    _playerData.velocityY += GameConfig.gravity * timeScale;
    final prevY = _playerData.y;
    _playerData.y += _playerData.velocityY * timeScale;

    // Update player's current velocity (displacement for dt) for sweep collision
    _playerData.currentVelocity.x = speed * dt; // Horizontal displacement over dt
    _playerData.currentVelocity.y = _playerData.velocityY * dt; // Vertical displacement over dt

    if (_playerData.isDucking) {
      _playerData.height = GameConfig.playerDuckingHeight; // Using constant
    } else {
      _playerData.height = GameConfig.playerDefaultHeight; // Using constant
    }

    double groundTargetY = GameConfig.groundLevel;
    bool onPlatform = false;

    // Obstacle and player interaction
    for (final obs in _obstacleManager.activeObstacles) {
      if ((obs.type == ObstacleType.platform || obs.type == ObstacleType.movingPlatform) && _playerData.velocityY >= 0) {
        if (_playerData.x + _playerData.width > obs.x && _playerData.x < obs.x + obs.width) {
          final platformTop = obs.y;
          final playerBottomPrev = prevY + _playerData.height;
          final playerBottomCurr = _playerData.y + _playerData.height;
          const tolerance = GameConfig.hazardZoneSafeTolerance; // Using tolerance constant

          if (playerBottomCurr >= platformTop - tolerance && playerBottomPrev <= platformTop + tolerance) {
            if (platformTop < groundTargetY) {
              groundTargetY = platformTop;
              onPlatform = true;
            }
          }
        }
      }
    }

    final floorY = groundTargetY - _playerData.height;

    if (_playerData.y > floorY) {
      _playerData.y = floorY;
      _playerData.velocityY = 0;
      _playerData.isJumping = false;

      if (_playerData.jumpBufferTimer > 0) {
        performJump();
      } else {
        if (!onPlatform && groundTargetY == GameConfig.groundLevel) {
          _particleManager.createDust(_playerData.x, _playerData.y + _playerData.height);
        } else if (onPlatform) {
          if (Random().nextDouble() > 0.9) { // Consider making this a constant for particle effects
            _particleManager.createExplosion(_playerData.x + _playerData.width / 2, _playerData.y + _playerData.height, Colors.cyan, count: 1);
          }
        }
      }
    }

    if (_playerData.jumpBufferTimer > 0) {
      _playerData.jumpBufferTimer--;
    }

    // Power-up interaction - now using rectRectCollision directly
    _playerData.isGrazing = false;
    for (int i = _powerUpManager.activePowerUps.length - 1; i >= 0; i--) {
      final pu = _powerUpManager.activePowerUps[i];
      // Power-ups are generally simpler AABB collisions, no sweep needed unless very fast
      if (rectRectCollision(
          ui.Rect.fromLTWH(pu.x, pu.y, pu.width, pu.height))) {
        _activatePowerUp(pu.type);
        _powerUpManager.activePowerUps.removeAt(i);
        _particleManager.createExplosion(pu.x + pu.width / 2, pu.y + pu.height / 2, Colors.white, count: GameConfig.powerUpCollisionParticleCount);
      }
    }

    // Obstacle collision detection using sweep test
    for (int i = _obstacleManager.activeObstacles.length - 1; i >= 0; i--) {
      final obs = _obstacleManager.activeObstacles[i];

      // Calculate obstacle's displacement for this frame (dt)
      double obsDx = speed; // Base horizontal movement
      double obsDy = 0.0;
      double obsPredictedAngle = 0.0; // For rotating lasers

      // Apply specific obstacle movement logic here to determine obsDx, obsDy, obsPredictedAngle
      final currentFrame = frames; // Use current frame for calculations
      // final sin0_05 = sin(currentFrame * 0.05); // Not directly used
      // final sin0_1 = sin(currentFrame * 0.1); // Not directly used
      final cos0_05 = cos(currentFrame * 0.05);

      if (obs is MovingPlatformObstacleData && obs.oscillationAxis == OscillationAxis.horizontal) {
        obsDx -= cos0_05 * 4; // Horizontal oscillation velocity - consider making a constant
      }

      if (obs is MovingAerialObstacleData) {
        final nextY = obs.initialY + sin( (currentFrame + 1) * 0.1) * 40; // Predict next Y - consider making constants
        obsDy = nextY - obs.y; // Vertical oscillation displacement
      } else if (obs is HazardObstacleData) {
        final nextY = obs.initialY + sin( (currentFrame + 1) * 0.05) * 25; // Predict next Y - consider making constants
        obsDy = nextY - obs.y; // Vertical oscillation displacement
      } else if (obs is MovingPlatformObstacleData && obs.oscillationAxis != OscillationAxis.horizontal) {
        final nextY = obs.initialY + sin( (currentFrame + 1) * 0.05) * 50; // Predict next Y - consider making constants
        obsDy = nextY - obs.y; // Vertical oscillation displacement
      } else if (obs is FallingObstacleData) {
        obsDy = (obs.velocityY + (0.4 * timeScale * dt)); // Approx displacement considering acceleration - consider making a constant
      } else if (obs is RotatingLaserObstacleData) {
        obsPredictedAngle = (obs.angle + (obs.rotationSpeed * dt)); // Predicted angle for detailed check
      }

      final obstacleDisplacement = Vector2(-obsDx * dt, obsDy); // Total displacement for dt

      final playerCollisionRect = ui.Rect.fromLTWH(
          playerInitialRect.left + GameConfig.playerCollisionPadding, playerInitialRect.top + GameConfig.playerCollisionPadding,
          playerInitialRect.width - (GameConfig.playerCollisionPadding * 2), playerInitialRect.height - (GameConfig.playerCollisionPadding * 2)); // Player with padding

      final obstacleCollisionRect = ui.Rect.fromLTWH(obs.x, obs.y, obs.width, obs.height);

      final toi = sweepRectRectCollision(
          playerCollisionRect,
          _playerData.currentVelocity - obstacleDisplacement, // Relative velocity for sweep
          obstacleCollisionRect
      );

      bool isColliding = false;
      ui.Rect? playerRectAtTOI; // Declare outside for wider scope
      ui.Rect? obsRectAtTOI;    // Declare outside for wider scope

      if (toi != null) {
        // Calculate player and obstacle positions at TOI
        playerRectAtTOI = ui.Rect.fromLTWH(
            playerInitialRect.left + _playerData.currentVelocity.x * toi,
            playerInitialRect.top + _playerData.currentVelocity.y * toi,
            playerInitialRect.width,
            playerInitialRect.height
        );
        obsRectAtTOI = ui.Rect.fromLTWH(
            obs.x + obstacleDisplacement.x * toi,
            obs.y + obstacleDisplacement.y * toi,
            obs.width,
            obs.height
        );
        
        isColliding = _checkDetailedCollision(_playerData, obs, playerRectAtTOI, obsRectAtTOI, obsPredictedAngle);
      }

      if (isColliding) {
        bool safe = false; // Determine if collision is "safe" based on obstacle type and player state
        if ((obs.type == ObstacleType.platform || obs.type == ObstacleType.movingPlatform) && _playerData.velocityY >= 0) { // Check velocity against platform
          // If player is moving downwards or stopped, and hits top of platform, it's safe.
          // Note: This logic might need further refinement for precise platform interaction
          if (playerInitialRect.bottom <= obs.y && playerRectAtTOI != null && playerRectAtTOI.bottom > obs.y) { // Player landed on top
            _playerData.y = obs.y - _playerData.height; // Snap player to top of platform
            _playerData.velocityY = 0;
            _playerData.isJumping = false;
            safe = true;
          }
        } else if (obs.type == ObstacleType.hazardZone) {
          if (_playerData.y + _playerData.height > obs.y + obs.height - GameConfig.hazardZoneSafeTolerance) { // Use current player Y for this check
            safe = true; // Grazing hazard from below is safe, actual collision if player fully inside
          }
        }

        if (!safe) {
          if (_playerData.invincibleTimer > 0) {
            safe = true;
          } else if (_playerData.hasShield) {
            _playerData.hasShield = false;
            _playerData.invincibleTimer = GameConfig.playerInvincibleDuration;
            _particleManager.createExplosion(_playerData.x + _playerData.width / 2, _playerData.y + _playerData.height / 2, GameConfig.accentNeonColor, count: 30);
            obs.x = GameConfig.obstacleRemoveX;
            _audioController.playShieldBreak();
          } else {
            if (tutorialActive) {
              obs.x = GameConfig.baseWidth + 200; // Tutorial obstacle bypass
              _audioController.playCrash();
            } else {
              gameOver();
              return; // Exit update loop on game over
            }
          }
        } else {
          if (obs.type == ObstacleType.hazardZone) _playerData.isGrazing = true;
        }
      }

      // Grazing detection (needs to be adapted for sweep context or re-implemented)
      if (!isColliding && !obs.grazed) { // Only graze if not a full collision
        const grazeDist = GameConfig.grazeDistance;
        final playerCenter = Offset(_playerData.x + _playerData.width / 2, _playerData.y + _playerData.height / 2);
        final obsCenter = Offset(obs.x + obs.width / 2, obs.y + obs.height / 2);
        final distToObsCenter = (playerCenter - obsCenter).distance;

        if (distToObsCenter < obs.width / 2 + grazeDist || distToObsCenter < obs.height / 2 + grazeDist) {
          bool validGraze = true;
          if (obs.type == ObstacleType.laserGrid) {
            final lgObs = obs as LaserGridObstacleData;
            final safeTop = lgObs.gapY - lgObs.gapHeight / 2 + GameConfig.laserGridSafePadding;
            final safeBottom = lgObs.gapY + lgObs.gapHeight / 2 - GameConfig.laserGridSafePadding;
            if (_playerData.y > safeTop && (_playerData.y + _playerData.height) < safeBottom) validGraze = false;
          } else if (obs.type == ObstacleType.platform || obs.type == ObstacleType.movingPlatform) {
            if (_playerData.y > obs.y + obs.height) validGraze = false;
          }

          if (validGraze) {
            _playerData.isGrazing = true;
            // PWA logic: graze score awarded when player is past the center of the obstacle
            if (_playerData.x > obs.x + obs.width / 2) {
              obs.grazed = true;
              score += (GameConfig.grazeScoreAmount * _playerData.scoreMultiplier).toInt(); // Graze score amount - using constant
              _particleManager.createExplosion(_playerData.x + _playerData.width / 2, _playerData.y + _playerData.height / 2, Colors.white, count: 1);
            }
          }
        }
      }
    }

    // Power-up timers
    if (_playerData.multiplierTimer > 0) {
      _playerData.multiplierTimer--;
      if (_playerData.multiplierTimer <= 0) _playerData.scoreMultiplier = 1;
    }
    if (_playerData.magnetTimer > 0) {
      _playerData.magnetTimer--;
      if (_playerData.magnetTimer <= 0) _playerData.hasMagnet = false;
    }
    if (_playerData.invincibleTimer > 0) {
      _playerData.invincibleTimer--;
    }

    // Power-up message timer
    if (_powerUpMessageTimer > 0) {
      _powerUpMessageTimer--;
      if (_powerUpMessageTimer <= 0) {
        _powerUpMessage = null;
      }
    }


    // Update HUD (will be removed later as HUD is a Flutter Widget)
    // _hud.score = score;
    // _hud.speedPercent = ((speed - GameConfig.baseSpeed) / (GameConfig.maxSpeed - GameConfig.baseSpeed)) * 100;
    // _hud.hasShield = _playerData.hasShield;
    // _hud.multiplier = _playerData.scoreMultiplier.toInt();
    // _hud.multiplierTimer = _playerData.multiplierTimer;
    // _hud.timeWarpActive = _playerData.timeWarpTimer > 0;
    // _hud.timeWarpTimer = _playerData.timeWarpTimer;
    // _hud.magnetActive = _playerData.hasMagnet;
    // _hud.magnetTimer = _playerData.magnetTimer;
    // _hud.scoreGlitch = scoreGlitch;
    // _hud.isGrazing = _playerData.isGrazing;


    // Other updates (e.g., trail, background effects)

    // Player trail logic
    _trailHistory.add(ui.Rect.fromLTWH(_playerData.x, _playerData.y, _playerData.width, _playerData.height));
    final maxTrail = (10 + speed * 0.8).floor();
    if (_trailHistory.length > maxTrail) {
      _trailHistory.removeAt(0);
    }

    _gameStateProvider.updateHudData(); // Notify listeners of HUD data changes
  }

  void _spawnObstacleAndPowerUp() {
    _obstacleManager.spawnObstacle(nextSpawn); // This needs to be coordinated with nextSpawn
    final obstacle = _obstacleManager.activeObstacles.last;

    bool powerUpSpawned = false;
    if (obstacle.type == ObstacleType.hazardZone && Random().nextDouble() < 0.35) {
      final puY = obstacle.y - 70;
      final absoluteX = obstacle.x + obstacle.width / 2;
      final relativeOffset = absoluteX - GameConfig.baseWidth;
      _powerUpManager.spawnPowerUp(relativeOffset, fixedY: puY);
      powerUpSpawned = true;
    } else if ((obstacle.type == ObstacleType.platform || obstacle.type == ObstacleType.movingPlatform) && Random().nextDouble() < 0.4) {
      final puY = obstacle.y - 40;
      final absoluteX = obstacle.x + obstacle.width / 2;
      final relativeOffset = absoluteX - GameConfig.baseWidth;
      _powerUpManager.spawnPowerUp(relativeOffset, fixedY: puY);
      powerUpSpawned = true;
    } else if (obstacle.type == ObstacleType.laserGrid && Random().nextDouble() < 0.4) {
      final lg = obstacle as LaserGridObstacleData;
      final puY = lg.gapY;
      final absoluteX = obstacle.x + obstacle.width / 2;
      final relativeOffset = absoluteX - GameConfig.baseWidth;
      _powerUpManager.spawnPowerUp(relativeOffset, fixedY: puY);
      powerUpSpawned = true;
    }

    if (!powerUpSpawned && Random().nextDouble() < GameConfig.powerUpSpawnChance) {
      _powerUpManager.spawnPowerUp((nextSpawn * speed * 0.4).floorToDouble());
    }

    // This `nextSpawn` logic needs to be integrated properly into the obstacle manager.
    final minGap = (GameConfig.spawnRateMin - min((speed - GameConfig.baseSpeed) * 2, 30)).toInt();
    final maxGap = GameConfig.spawnRateMax;
    int gap = Random().nextInt(maxGap - minGap + 1) + minGap;

    if (obstacle.type == ObstacleType.hazardZone) gap += 20;
    if (obstacle.type == ObstacleType.movingPlatform) gap += 15;
    if (obstacle.type == ObstacleType.laserGrid) gap += 30;

    nextSpawn = frames + gap;
  }

  void performJump() {
    _playerData.isJumping = true;
    _playerData.isHoldingJump = true;
    _playerData.velocityY = -GameConfig.jumpForce;
    _playerData.jumpTimer = GameConfig.jumpTimerMax;
    _playerData.jumpBufferTimer = 0;
    _audioController.playJump();
  }

  // New helper method for detailed collision checks at a given TOI
  bool _checkDetailedCollision(PlayerData player, ObstacleData obs, ui.Rect playerRect, ui.Rect obsRect, double obsCurrentAngle) {
    bool isColliding = false;
    // Add padding back to playerRect for internal detailed checks
    const padding = 10.0;
    final paddedPlayerRect = ui.Rect.fromLTWH(playerRect.left + padding, playerRect.top + padding, playerRect.width - padding * 2, playerRect.height - padding * 2);

    if (obs.type == ObstacleType.rotatingLaser) {
      if (rectRectCollision(paddedPlayerRect, obsRect)) {
        isColliding = true;
      }
      if (!isColliding) {
        final RotatingLaserObstacleData rlObs = obs as RotatingLaserObstacleData;
        final double cx = obsRect.left + obsRect.width / 2;
        final double cy = obsRect.top + obsRect.height / 2;
        final double beamLen = rlObs.beamLength;
        final double endX = cx + cos(obsCurrentAngle) * beamLen;
        final double endY = cy + sin(obsCurrentAngle) * beamLen;
        if (lineRect(cx, cy, endX, endY, paddedPlayerRect)) isColliding = true;
      }
    } else if (obs.type == ObstacleType.laserGrid) {
      if (paddedPlayerRect.left + paddedPlayerRect.width > obsRect.left + 5 && paddedPlayerRect.left < obsRect.left + obsRect.width - 5) {
        final LaserGridObstacleData lgObs = obs as LaserGridObstacleData;
        final double gapY = lgObs.gapY;
        final double gapH = lgObs.gapHeight;
        final double safeTop = gapY - gapH / 2 + 5;
        final double safeBottom = gapY + gapH / 2 - 5;
        if (paddedPlayerRect.top < safeTop || (paddedPlayerRect.top + paddedPlayerRect.height) > safeBottom) isColliding = true;
      }
    } else if (obs.type == ObstacleType.fallingDrop) {
      final double cx = obsRect.left + obsRect.width / 2;
      final double cy = obsRect.top + obsRect.height / 2;
      final double r = obsRect.width / 2 - 6;
      final double testX = max(paddedPlayerRect.left, min(cx, paddedPlayerRect.left + paddedPlayerRect.width));
      final double testY = max(paddedPlayerRect.top, min(cy, paddedPlayerRect.top + paddedPlayerRect.height));
      final double dx = cx - testX;
      final double dy = cy - testY;
      if ((dx * dx + dy * dy) < (r * r)) isColliding = true;
    } else if (obs.type == ObstacleType.spike) {
      if (rectRectCollision(paddedPlayerRect, obsRect)) {
        final double tipX = obsRect.left + obsRect.width / 2;
        final double tipY = obsRect.top;
        if (lineRect(obsRect.left, obsRect.top + obsRect.height, tipX, tipY, paddedPlayerRect)) {
          isColliding = true;
        } else if (lineRect(tipX, tipY, 
            obsRect.left + obsRect.width, 
            obsRect.top + obsRect.height, 
            paddedPlayerRect)) {
          isColliding = true;
        }
        else {
          final double centerX = paddedPlayerRect.left + paddedPlayerRect.width / 2;
          final double bottomY = paddedPlayerRect.top + paddedPlayerRect.height;
          if (centerX > obsRect.left && centerX < obsRect.left + obsRect.width && bottomY > obsRect.top + obsRect.height / 2) {
            isColliding = true;
          }
        }
      }
    } else if (obs.type == ObstacleType.aerial || obs.type == ObstacleType.movingAerial) {
      if (rectRectCollision(paddedPlayerRect, obsRect)) {
        final double cx = obsRect.left + obsRect.width / 2;
        final double cy = obsRect.top + obsRect.height / 2;
        final double px = paddedPlayerRect.left;
        final double py = paddedPlayerRect.top;
        final double pw = paddedPlayerRect.width;
        final double ph = paddedPlayerRect.height;
        if (lineRect(obsRect.left, cy, cx, obsRect.top, ui.Rect.fromLTWH(px, py, pw, ph)) ||
            lineRect(cx, obsRect.top, obsRect.left + obsRect.width, cy, ui.Rect.fromLTWH(px, py, pw, ph)) ||
            lineRect(obsRect.left + obsRect.width, cy, cx, obsRect.top + obsRect.height, ui.Rect.fromLTWH(px, py, pw, ph)) ||
            lineRect(cx, obsRect.top + obsRect.height, obsRect.left, cy, ui.Rect.fromLTWH(px, py, pw, ph))) {
          isColliding = true;
        }
        if ( (paddedPlayerRect.left + paddedPlayerRect.width/2 - cx).abs() < 10 && (paddedPlayerRect.top + paddedPlayerRect.height/2 - cy).abs() < 10) isColliding = true;
      }
    } else if (obs.type == ObstacleType.slantedSurface) {
      final SlantedObstacleData sObs = obs as SlantedObstacleData;
      // Calculate world coordinates of the slanted line segment
      final double x1 = obsRect.left + sObs.lineX1;
      final double y1 = obsRect.top + sObs.lineY1;
      final double x2 = obsRect.left + sObs.lineX2;
      final double y2 = obsRect.top + sObs.lineY2;
      if (lineRect(x1, y1, x2, y2, paddedPlayerRect)) isColliding = true;
    } else {
      isColliding = rectRectCollision(paddedPlayerRect, obsRect);
    }

    return isColliding;
  }

  void _activatePowerUp(PowerUpType type) {
    _powerUpMessageTimer = GameConfig.powerUpMessageDisplayDuration;
    switch (type) {
      case PowerUpType.shield:
        _playerData.hasShield = true;
        _powerUpMessage = 'FIREWALL ACTIVATED';
        _audioController.playPowerUp();
        break;
      case PowerUpType.multiplier:
        _playerData.scoreMultiplier = GameConfig.powerUpMultiplierValue;
        _playerData.multiplierTimer = GameConfig.powerUpMultiplierDuration;
        _powerUpMessage = 'OVERCLOCK ACTIVATED';
        _audioController.playPowerUp();
        break;
      case PowerUpType.timeWarp:
        _playerData.timeWarpTimer = GameConfig.powerUpTimeWarpDuration;
        _powerUpMessage = 'TIME WARP';
        _audioController.playTimeWarp();
        break;
      case PowerUpType.magnet:
        _playerData.hasMagnet = true;
        _playerData.magnetTimer = GameConfig.powerUpMagnetDuration;
        _powerUpMessage = 'MAGNETIZED';
        _audioController.playPowerUp();
        break;
    }
  }

  void _updateTutorial() {
    if (tutorialState == 'INTRO') {
      if (frames > GameConfig.tutorialIntroDuration) tutorialState = 'JUMP_TEACH';
      return;
    }

    if (_obstacleManager.activeObstacles.isEmpty) {
      if (tutorialState == 'JUMP_TEACH') {
        // Spawn a simple ground obstacle for jump tutorial
        final obs = SimpleObstacleData(id: _obstacleManager.obstacleIdCounter, type: ObstacleType.ground, x: GameConfig.baseWidth + GameConfig.tutorialObstacleTutorialX, y: GameConfig.groundLevel - GameConfig.tutorialObstacleJumpYOffset, width: 30, height: 30);
        _obstacleManager.activeObstacles.add(obs);
      } else if (tutorialState == 'DUCK_TEACH') {
        // Spawn a hazard zone for duck tutorial
        final obs = HazardObstacleData(id: _obstacleManager.obstacleIdCounter, x: GameConfig.baseWidth + GameConfig.tutorialObstacleTutorialX, y: GameConfig.groundLevel - GameConfig.tutorialObstacleDuckYOffset, width: 200, height: 40, initialY: GameConfig.groundLevel - GameConfig.tutorialObstacleDuckYOffset);
        _obstacleManager.activeObstacles.add(obs);
      }
    }

    final firstObs = _obstacleManager.activeObstacles.isNotEmpty ? _obstacleManager.activeObstacles.first : null;
    if (firstObs != null) {
      final dist = firstObs.x - _playerData.x;
      if (dist < GameConfig.tutorialSlowdownDistMin && dist > GameConfig.tutorialSlowdownDistTarget) {
        speed = GameConfig.tutorialSpeed; // Slow down for tutorial
      } else {
        speed = GameConfig.baseSpeed;
      }

      if (tutorialState == 'JUMP_TEACH') {
        if (_playerData.isJumping) {
          if (firstObs.x + firstObs.width < _playerData.x) {
            tutorialState = 'DUCK_TEACH';
          }
        }
      } else if (tutorialState == 'DUCK_TEACH') {
        if (_playerData.isDucking) {
          if (firstObs.x + firstObs.width < _playerData.x) {
            tutorialState = 'COMPLETED';
            tutorialActive = false;
            _localStorageService.setTutorialSeen(true);
          }
        }
      }
    }
  }

  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final isKeyDown = event is KeyDownEvent;

    if (_gameStateProvider.currentGameState == GameState.menu || _gameStateProvider.currentGameState == GameState.gameOver) {
      if (isKeyDown && (keysPressed.contains(LogicalKeyboardKey.space) || keysPressed.contains(LogicalKeyboardKey.enter))) {
        initGame();
        return KeyEventResult.handled;
      }
    }

    if (keysPressed.contains(LogicalKeyboardKey.keyP)) {
      if (isKeyDown) {
        togglePause();
      }
      return KeyEventResult.handled;
    }

    if (_gameStateProvider.currentGameState == GameState.playing) {
      if (keysPressed.contains(LogicalKeyboardKey.arrowUp) || keysPressed.contains(LogicalKeyboardKey.space)) {
        if (!inputLock) {
          _playerData.isHoldingJump = isKeyDown;
          if (isKeyDown) {
            _playerData.jumpBufferTimer = GameConfig.jumpBufferDuration;
            if (!_playerData.isJumping) {
              performJump();
            }
          }
        }
      }
      if (keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
        _playerData.isDucking = isKeyDown;
        if (isKeyDown && !_playerData.isJumping) {
          _audioController.playDuck();
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw background grid lines (simplified for now)
    final gridPaint = Paint()
      ..color = const Color.fromRGBO(3, 160, 98, 0.3)
      ..strokeWidth = 1; // Consider making a constant for grid line width
    final gridOffset = (frames * speed) % GameConfig.gridLineOffsetDivisor;
    for (double i = 0; i < size.x / GameConfig.gridLineOffsetDivisor + 2; i++) {
      final gx = i * GameConfig.gridLineOffsetDivisor - gridOffset;
      canvas.drawLine(Offset(gx, GameConfig.groundLevel), Offset(gx, size.y), gridPaint);
    }

    // Draw ground
    canvas.drawLine(
      Offset(0, GameConfig.groundLevel),
      Offset(size.x, GameConfig.groundLevel),
      Paint()
        ..color = GameConfig.primaryNeonColor
        ..strokeWidth = GameConfig.groundLineStrokeWidth,
    );

    // Draw player trail
    for (int i = 0; i < _trailHistory.length; i++) {
      final trailNode = _trailHistory[i];
      final ratio = i / _trailHistory.length;
      final alpha = ratio * GameConfig.playerTrailAlphaMax; // Using constant
      // PWA uses HSL color and hue based on framesRef.current
      final hue = (frames * GameConfig.playerTrailHueCycleSpeed) % 360; // Using constant
      _playerTrailPaint.color = hslToColor(hue.toDouble(), 1.0, 0.5).withAlpha((255 * alpha).round());
      _playerTrailPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, ratio * GameConfig.playerTrailBlurRadiusMultiplier); // Using constant
      canvas.drawRect(trailNode, _playerTrailPaint);
    }

    // Draw tutorial overlay
    if (tutorialActive) {
      _drawTutorial(canvas);
    }

    // Draw magnet effect
    if (_playerData.hasMagnet) {
      final magnetPaint = Paint()
        ..color = const Color(0xFFFF00FF).withAlpha((255 * (GameConfig.magnetEffectAlphaBase + (sin(frames * GameConfig.magnetEffectAlphaOscillationFrequency) * GameConfig.magnetEffectAlphaOscillation))).round()); // Pulsing effect
      final magnetRadius = (_playerData.width / 2) + GameConfig.magnetRadiusBaseAdd + (sin(frames * GameConfig.magnetRadiusOscillationFrequency) * GameConfig.magnetRadiusOscillation); // Oscillating radius
      canvas.drawCircle(Offset(_playerData.x + _playerData.width / 2, _playerData.y + _playerData.height / 2), magnetRadius, magnetPaint);
    }

    // Draw power-up message
    if (_powerUpMessage != null && _powerUpMessageTimer > 0) {
      final textPainter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: _powerUpMessage,
          style: TextStyle(
            color: GameConfig.accentNeonColor.withAlpha((255 * (_powerUpMessageTimer / GameConfig.powerUpMessageDisplayDuration)).round()), // Fade out
            fontSize: GameConfig.hudPowerUpMessageFontSize, // Using constant
            fontFamily: 'Share Tech Mono',
            shadows: [
              Shadow(
                blurRadius: GameConfig.playerTrailBlurRadiusMultiplier, // Reusing blur radius for consistent neon glow
                color: GameConfig.accentNeonColor,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
      );
      textPainter.layout(maxWidth: size.x);
      textPainter.paint(canvas, Offset((size.x - textPainter.width) / 2, size.y / 2 - GameConfig.hudPowerUpMessageYOffset)); // Centered slightly above middle
    }

  void _drawTutorial(Canvas canvas) {
    canvas.save();
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    final textStyle = const TextStyle(
      color: GameConfig.primaryNeonColor,
      fontSize: 24, // Consider making a constant
      fontFamily: 'Share Tech Mono',
    );

    // Background for tutorial text
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.x, 100), Paint()..color = Colors.black.withAlpha((255 * GameConfig.tutorialBackgroundAlpha).round())); // Background for tutorial text

    String text = '';
    if (tutorialState == 'INTRO') {
      text = "INITIATING TRAINING PROTOCOL...";
    } else if (tutorialState == 'JUMP_TEACH') {
      text = "PRESS [UP] TO JUMP";
    } else if (tutorialState == 'DUCK_TEACH') {
      text = "PRESS [DOWN] TO DUCK";
    }

    textPainter.text = TextSpan(text: text, style: textStyle);
    textPainter.layout(maxWidth: size.x);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.x, 100), Paint()..color = Colors.black.withAlpha((255 * GameConfig.tutorialBackgroundAlpha).round())); // Background for tutorial text
    textPainter.paint(canvas, Offset((size.x - textPainter.width) / 2, 50 - textPainter.height / 2)); // Centered Y position for text

    // Draw arrow for jump/duck tutorial
    if (tutorialState == 'JUMP_TEACH' || tutorialState == 'DUCK_TEACH') {
      final arrowPaint = Paint()
        ..color = GameConfig.primaryNeonColor
        ..strokeWidth = GameConfig.tutorialArrowStrokeWidth
        ..style = PaintingStyle.stroke;

      final arrowPath = Path();
      if (tutorialState == 'JUMP_TEACH') {
        arrowPath.moveTo(_playerData.x + _playerData.width / 2, _playerData.y - 10); // Arrow start Y
        arrowPath.lineTo(_playerData.x + _playerData.width / 2, _playerData.y - 30); // Arrow end Y
        arrowPath.lineTo(_playerData.x + _playerData.width / 2 - 10, _playerData.y - 20); // Left wing
        arrowPath.moveTo(_playerData.x + _playerData.width / 2, _playerData.y - 30); // Back to end Y
        arrowPath.lineTo(_playerData.x + _playerData.width / 2 + 10, _playerData.y - 20); // Right wing
      } else { // DUCK_TEACH
        arrowPath.moveTo(_playerData.x + _playerData.width / 2, _playerData.y + _playerData.height + 10); // Arrow start Y
        arrowPath.lineTo(_playerData.x + _playerData.width / 2, _playerData.y + _playerData.height + 30); // Arrow end Y
        arrowPath.lineTo(_playerData.x + _playerData.width / 2 - 10, _playerData.y + _playerData.height + 20); // Left wing
        arrowPath.moveTo(_playerData.x + _playerData.width / 2, _playerData.y + _playerData.height + 30); // Back to end Y
        arrowPath.lineTo(_playerData.x + _playerData.width / 2 + 10, _playerData.y + _playerData.height + 20); // Right wing
      }
      canvas.drawPath(arrowPath, arrowPaint);
    }
    canvas.restore();
  }


  void initGame() {
    _audioController.startMusic();

    // Reset player data
    _playerData.reset();
    _playerData.y = GameConfig.groundLevel - _playerData.height; // Adjust player height

    // Reset managers
    _obstacleManager.reset();
    _powerUpManager.reset();
    _particleManager.reset();
    _trailHistory.clear(); // Clear trail history

    score = 0;
    frames = 0;
    speed = GameConfig.baseSpeed;
    inputLock = false;
    nextSpawn = 0;
    scoreGlitch = false;
    isTransitioning = false; // Reset transition flag

    // Check if tutorial needs to be shown
    tutorialActive = !_localStorageService.getTutorialSeen();
    tutorialState = 'INTRO';
    nextSpawn = 100; // Delay first obstacle during tutorial
  }

  void gameOver() {
    if (score > highscore) {
      highscore = score;
      _localStorageService.setHighscore(highscore);
    }
    _audioController.stopMusic();
    _audioController.playCrash();
    _particleManager.createExplosion(_playerData.x + _playerData.width/2, _playerData.y + _playerData.height/2, GameConfig.primaryNeonColor); // Explosion on game over
    inputLock = true;
    Future.delayed(const Duration(seconds: GameConfig.gameOverDelaySeconds), () { // Using constant for game over delay
      inputLock = false;
      // Offer rewarded ad to continue
      _adsController.showRewardedAd(() {
        // On reward earned, continue game
        _gameStateProvider.startGame(); // Use GameStateProvider to start game
      });
    });
  }

  void togglePause() {
    if (_gameStateProvider.currentGameState == GameState.playing) {
      _audioController.stopMusic();
    } else if (_gameStateProvider.currentGameState == GameState.paused) {
      _audioController.startMusic();
    }
  }

  void toggleMute() {
    _audioController.toggleMute(!_audioController.isMuted);
  }
}