import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_neon_runner/audio/audio_controller.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/models/game_state.dart';
import 'package:flutter_neon_runner/models/player_data.dart';
import 'package:flutter_neon_runner/models/obstacle_data.dart';
import 'package:flutter_neon_runner/game/components/player_component.dart' hide PowerUpType; // Import PlayerComponent
import 'package:flutter_neon_runner/game/systems/obstacle_system.dart'; // Import ObstacleSystem
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

class NeonRunnerGame extends FlameGame with KeyboardEvents {
  late final GameStateProvider _gameStateProvider;

  NeonRunnerGame(this._gameStateProvider);

  late final AudioController _audioController;
  late final AdsController _adsController;
  late final LocalStorageService _localStorageService;
  late final PlayerData _playerData;
  late final PlayerComponent _playerComponent;
  late final ObstacleSystem _obstacleSystem;
  late final ObstacleManager _obstacleManager;
  late final PowerUpManager _powerUpManager;
  late final ParticleManager _particleManager;

  PlayerData get playerData => _playerData;
  PlayerComponent get player => _playerComponent;
  AudioController get audioController => _audioController;
  AdsController get adsController => _adsController;
  LocalStorageService get localStorageService => _localStorageService;

  double speed = 0;
  int score = 0;
  int frames = 0;
  int highscore = 0;
  bool inputLock = false;
  bool isTransitioning = false;
  bool scoreGlitch = false;
  String? _powerUpMessage;
  int _powerUpMessageTimer = 0;
  int _hudUpdateCounter = 0;

  String? userId;
  String? userMask;

  bool tutorialActive = false;
  String tutorialState = 'INTRO'; // INTRO | JUMP_TEACH | DUCK_TEACH | COMPLETED

  final List<ui.Rect> _trailHistory = []; // Player trail history
  final Paint _playerTrailPaint = Paint()..blendMode = BlendMode.plus;

  // Pre-created Paint objects to avoid garbage collection in render loop
  final Paint _groundLinePaint = Paint()
    ..color = GameConfig.primaryNeonColor
    ..strokeWidth = GameConfig.groundLineStrokeWidth;
  final Paint _magnetPaint = Paint();

  // Warning counter for dt == 0 messages
  int _dtWarningCounter = 0;

  @override
  Color backgroundColor() => const Color(0xFF000000); // Black background

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    paused = true; // Start the game in a paused state until startGame is called

    // Initialize components
    _audioController = AudioController();
    _adsController = AdsController();
    _localStorageService = LocalStorageService();
    _playerData = PlayerData();

    // Initialize systems
    _obstacleSystem = ObstacleSystem();
    await _obstacleSystem.initialize();

    // Components that depend on the game instance
    _playerComponent = PlayerComponent();
    _obstacleManager = ObstacleManager(_obstacleSystem);
    _powerUpManager = PowerUpManager(this);
    _particleManager = ParticleManager();

    // Set PowerUpManager reference in ObstacleSystem
    _obstacleSystem.setPowerUpManager(_powerUpManager);

    // Add components to the game tree
    addAll([
      _playerComponent,
      _obstacleManager,
      _powerUpManager,
      _particleManager,
    ]);

    // Initialize services
    await _audioController.init();
    await _adsController.init();
    await _localStorageService.init();

    highscore = _localStorageService.getHighscore();
    tutorialActive = !_localStorageService.getTutorialSeen();
    userId = _localStorageService.getUserId();
  }

  @override
  void update(double dt) {
    // Comprehensive delta time validation to prevent game progression stalls
    const maxDt = 0.1; // Maximum 100ms per frame

    // Clamp delta time to prevent physics breakdown
    if (dt > maxDt) {
      dt = maxDt;
      _dtWarningCounter++;
      if (_dtWarningCounter % 60 == 0) {
        debugPrint('WARNING: dt clamped to $maxDt to prevent physics breakdown');
      }
    }

    // DEBUG: Log dt every 60 frames (1 second at 60fps)
    if (frames % 60 == 0 && !paused) {
      print('[DEBUG] frames=$frames dt=$dt speed=$speed obstacles=${_obstacleManager.activeObstacles.length}');
    }

    // Failsafe: use fallback for invalid dt instead of skipping entirely
    if (dt <= 0 || dt.isNaN || dt.isInfinite) {
      if (!paused) {
        _dtWarningCounter++;
        if (_dtWarningCounter % 30 == 0) {
          print('[CRITICAL] Invalid dt ($dt) - using fallback to prevent freeze');
        }
        dt = 1.0 / 60.0; // Use fallback instead of returning
      } else {
        return;
      }
    }

    super.update(dt);

    // Early return if game is paused to avoid unnecessary processing
    if (paused) return;

    frames++;
    final timeScale = _playerData.timeWarpTimer > 0
        ? 0.5
        : 1.0; // Time warp speed reduction

    // --- HUD Data Sync ---
    // Update HUD data periodically, not every frame.
    _hudUpdateCounter++;
    if (_hudUpdateCounter >= 5) {
      // Update roughly every 5 frames
      _hudUpdateCounter = 0;
      _gameStateProvider.updateHudData();
    }

    if (_playerData.timeWarpTimer > 0) {
      _playerData.timeWarpTimer--;
    }

    if (tutorialActive) {
      _updateTutorial();
    } else {
      if (speed < GameConfig.maxSpeed) {
        speed += GameConfig.speedIncrement;
      }
    }

    // Synchronize obstacle system speed to prevent desynchronization
    _obstacleSystem.setCurrentSpeed(speed);

    // Failsafe: enforce minimum speed to prevent movement stall
    if (speed < GameConfig.baseSpeed) {
      speed = GameConfig.baseSpeed;
      _obstacleSystem.setCurrentSpeed(speed);
    }

    // Score update
    if (frames % GameConfig.scoreUpdateFrequency == 0) {
      score += (1 * _playerData.scoreMultiplier).toInt();
      if (score > 0 && score % GameConfig.scoreGlitchTrigger == 0) {
        _audioController.playScore();
        scoreGlitch = true;
        Future.delayed(
          const Duration(milliseconds: GameConfig.scoreGlitchDurationLong),
          () {
            scoreGlitch = false;
          },
        );
      }
    }
    if (Random().nextDouble() < GameConfig.randomScoreGlitchChance &&
        !scoreGlitch) {
      scoreGlitch = true;
      Future.delayed(
        const Duration(milliseconds: GameConfig.scoreGlitchDurationShort),
        () {
          scoreGlitch = false;
        },
      );
    }

    // Player physics
    final playerInitialRect = ui.Rect.fromLTWH(
      _playerData.x,
      _playerData.y,
      _playerData.width,
      _playerData.height,
    );

    if (_playerData.isJumping &&
        _playerData.isHoldingJump &&
        _playerData.jumpTimer > 0) {
      _playerData.velocityY -= GameConfig.jumpSustain * timeScale;
      _playerData.jumpTimer--;
    }
    _playerData.velocityY += GameConfig.gravity * timeScale;
    final prevY = _playerData.y;
    _playerData.y += _playerData.velocityY * timeScale;

    _playerData.currentVelocity.x =
        speed * dt; // Horizontal displacement over dt
    _playerData.currentVelocity.y =
        _playerData.velocityY * dt; // Vertical displacement over dt

    if (_playerData.isDucking) {
      _playerData.height = GameConfig.playerDuckingHeight; // Using constant
    } else {
      _playerData.height = GameConfig.playerDefaultHeight; // Using constant
    }

    double groundTargetY = GameConfig.groundLevel;
    bool onPlatform = false;

    // Obstacle and player interaction
    for (final obs in _obstacleManager.activeObstacles) {
      if ((obs.type == ObstacleType.platform ||
              obs.type == ObstacleType.movingPlatform) &&
          _playerData.velocityY >= 0) {
        if (_playerData.x + _playerData.width > obs.x &&
            _playerData.x < obs.x + obs.width) {
          final platformTop = obs.y;
          final playerBottomPrev = prevY + _playerData.height;
          final playerBottomCurr = _playerData.y + _playerData.height;
          const tolerance =
              GameConfig.hazardZoneSafeTolerance; // Using tolerance constant

          if (playerBottomCurr >= platformTop - tolerance &&
              playerBottomPrev <= platformTop + tolerance) {
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
          _particleManager.createDust(
            _playerData.x,
            _playerData.y + _playerData.height,
          );
        } else if (onPlatform) {
          if (Random().nextDouble() > 0.9) {
            _particleManager.createExplosion(
              _playerData.x + _playerData.width / 2,
              _playerData.y + _playerData.height,
              Colors.cyan,
              count: 1,
            );
          }
        }
      }
    }

    if (_playerData.jumpBufferTimer > 0) {
      _playerData.jumpBufferTimer--;
    }

    // Power-up interaction
    _playerData.isGrazing = false;
    for (int i = _powerUpManager.activePowerUps.length - 1; i >= 0; i--) {
      final pu = _powerUpManager.activePowerUps[i];
      if (rectRectCollision(
        playerInitialRect,
        ui.Rect.fromLTWH(pu.x, pu.y, pu.width, pu.height),
      )) {
        _activatePowerUp(pu.type);
        _powerUpManager.activePowerUps.removeAt(i);
        _particleManager.createExplosion(
          pu.x + pu.width / 2,
          pu.y + pu.height / 2,
          Colors.white,
          count: GameConfig.powerUpCollisionParticleCount,
        );
      }
    }

    // Obstacle collision detection
    for (int i = _obstacleManager.activeObstacles.length - 1; i >= 0; i--) {
      final obs = _obstacleManager.activeObstacles[i];

      double obsDx = speed;
      double obsDy = 0.0;
      double obsPredictedAngle = 0.0;

      final currentFrame = frames;
      final cos0_05 = cos(currentFrame * 0.05);

      if (obs is MovingPlatformObstacleData &&
          obs.oscillationAxis == OscillationAxis.horizontal) {
        obsDx -= cos0_05 * 4;
      }

      if (obs is MovingAerialObstacleData) {
        final nextY = obs.initialY + sin((currentFrame + 1) * 0.1) * 40;
        obsDy = nextY - obs.y;
      } else if (obs is HazardObstacleData) {
        final nextY = obs.initialY + sin((currentFrame + 1) * 0.05) * 25;
        obsDy = nextY - obs.y;
      } else if (obs is MovingPlatformObstacleData &&
          obs.oscillationAxis != OscillationAxis.horizontal) {
        final nextY = obs.initialY + sin((currentFrame + 1) * 0.05) * 50;
        obsDy = nextY - obs.y;
      } else if (obs is FallingObstacleData) {
        obsDy = (obs.velocityY + (0.4 * timeScale * dt));
      } else if (obs is RotatingLaserObstacleData) {
        obsPredictedAngle = (obs.angle + (obs.rotationSpeed * dt));
      }

      final obstacleDisplacement = Vector2(-obsDx * dt, obsDy);

      final playerCollisionRect = ui.Rect.fromLTWH(
        playerInitialRect.left + GameConfig.playerCollisionPadding,
        playerInitialRect.top + GameConfig.playerCollisionPadding,
        playerInitialRect.width - (GameConfig.playerCollisionPadding * 2),
        playerInitialRect.height - (GameConfig.playerCollisionPadding * 2),
      );

      final obstacleCollisionRect = ui.Rect.fromLTWH(
        obs.x,
        obs.y,
        obs.width,
        obs.height,
      );

      final toi = sweepRectRectCollision(
        playerCollisionRect,
        _playerData.currentVelocity - obstacleDisplacement,
        obstacleCollisionRect,
      );

      bool isColliding = false;
      ui.Rect? playerRectAtTOI;
      ui.Rect? obsRectAtTOI;

      if (toi != null) {
        playerRectAtTOI = ui.Rect.fromLTWH(
          playerInitialRect.left + _playerData.currentVelocity.x * toi,
          playerInitialRect.top + _playerData.currentVelocity.y * toi,
          playerInitialRect.width,
          playerInitialRect.height,
        );
        obsRectAtTOI = ui.Rect.fromLTWH(
          obs.x + obstacleDisplacement.x * toi,
          obs.y + obstacleDisplacement.y * toi,
          obs.width,
          obs.height,
        );

        isColliding = _checkDetailedCollision(
          _playerData,
          obs,
          playerRectAtTOI,
          obsRectAtTOI,
          obsPredictedAngle,
        );
      }

      if (isColliding) {
        bool safe = false;
        if ((obs.type == ObstacleType.platform ||
                obs.type == ObstacleType.movingPlatform) &&
            _playerData.velocityY >= 0) {
          if (playerInitialRect.bottom <= obs.y &&
              playerRectAtTOI != null &&
              playerRectAtTOI.bottom > obs.y) {
            _playerData.y = obs.y - _playerData.height;
            _playerData.velocityY = 0;
            _playerData.isJumping = false;
            safe = true;
          }
        } else if (obs.type == ObstacleType.hazardZone) {
          if (_playerData.y + _playerData.height >
              obs.y + obs.height - GameConfig.hazardZoneSafeTolerance) {
            safe = true;
          }
        }

        if (!safe) {
          if (_playerData.invincibleTimer > 0) {
            safe = true;
          } else if (_playerData.hasShield) {
            _playerData.hasShield = false;
            _playerData.invincibleTimer = GameConfig.playerInvincibleDuration;
            _particleManager.createExplosion(
              _playerData.x + _playerData.width / 2,
              _playerData.y + _playerData.height / 2,
              GameConfig.accentNeonColor,
              count: 30,
            );
            obs.x = GameConfig.obstacleRemoveX;
            _audioController.playShieldBreak();
          } else {
            if (tutorialActive) {
              obs.x = GameConfig.baseWidth + 200;
              _audioController.playCrash();
            } else {
              handleGameOver();
              return; // Exit update loop
            }
          }
        } else {
          if (obs.type == ObstacleType.hazardZone) _playerData.isGrazing = true;
        }
      }

      // Grazing detection
      if (!isColliding && !obs.grazed) {
        const grazeDist = GameConfig.grazeDistance;
        final playerCenter = Offset(
          _playerData.x + _playerData.width / 2,
          _playerData.y + _playerData.height / 2,
        );
        final obsCenter = Offset(obs.x + obs.width / 2, obs.y + obs.height / 2);
        final distToObsCenter = (playerCenter - obsCenter).distance;

        if (distToObsCenter < obs.width / 2 + grazeDist ||
            distToObsCenter < obs.height / 2 + grazeDist) {
          bool validGraze = true;
          if (obs.type == ObstacleType.laserGrid) {
            final lgObs = obs as LaserGridObstacleData;
            final safeTop =
                lgObs.gapY -
                lgObs.gapHeight / 2 +
                GameConfig.laserGridSafePadding;
            final safeBottom =
                lgObs.gapY +
                lgObs.gapHeight / 2 -
                GameConfig.laserGridSafePadding;
            if (_playerData.y > safeTop &&
                (_playerData.y + _playerData.height) < safeBottom) {
              validGraze = false;
            }
          } else if (obs.type == ObstacleType.platform ||
              obs.type == ObstacleType.movingPlatform) {
            if (_playerData.y > obs.y + obs.height) validGraze = false;
          }

          if (validGraze) {
            _playerData.isGrazing = true;
            if (_playerData.x > obs.x + obs.width / 2) {
              obs.grazed = true;
              score +=
                  (GameConfig.grazeScoreAmount * _playerData.scoreMultiplier)
                      .toInt();
              _particleManager.createExplosion(
                _playerData.x + _playerData.width / 2,
                _playerData.y + _playerData.height / 2,
                Colors.white,
                count: 1,
              );
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

    if (_powerUpMessageTimer > 0) {
      _powerUpMessageTimer--;
      if (_powerUpMessageTimer <= 0) {
        _powerUpMessage = null;
      }
    }

    // Player trail logic
    _trailHistory.add(
      ui.Rect.fromLTWH(
        _playerData.x,
        _playerData.y,
        _playerData.width,
        _playerData.height,
      ),
    );
    final maxTrail = (10 + speed * 0.8).floor();
    if (_trailHistory.length > maxTrail) {
      _trailHistory.removeAt(0);
    }
  }

  
  void performJump() {
    _playerData.isJumping = true;
    _playerData.isHoldingJump = true;
    _playerData.velocityY = -GameConfig.jumpForce;
    _playerData.jumpTimer = GameConfig.jumpTimerMax;
    _playerData.jumpBufferTimer = 0;
    _audioController.playJump();
  }

  bool _checkDetailedCollision(
    PlayerData player,
    ObstacleData obs,
    ui.Rect playerRect,
    ui.Rect obsRect,
    double obsCurrentAngle,
  ) {
    bool isColliding = false;
    const padding = 10.0;
    final paddedPlayerRect = ui.Rect.fromLTWH(
      playerRect.left + padding,
      playerRect.top + padding,
      playerRect.width - padding * 2,
      playerRect.height - padding * 2,
    );

    if (obs.type == ObstacleType.rotatingLaser) {
      if (rectRectCollision(paddedPlayerRect, obsRect)) {
        isColliding = true;
      }
      if (!isColliding) {
        final RotatingLaserObstacleData rlObs =
            obs as RotatingLaserObstacleData;
        final double cx = obsRect.left + obsRect.width / 2;
        final double cy = obsRect.top + obsRect.height / 2;
        final double beamLen = rlObs.beamLength;
        final double endX = cx + cos(obsCurrentAngle) * beamLen;
        final double endY = cy + sin(obsCurrentAngle) * beamLen;
        if (lineRect(cx, cy, endX, endY, paddedPlayerRect)) isColliding = true;
      }
    } else if (obs.type == ObstacleType.laserGrid) {
      if (paddedPlayerRect.left + paddedPlayerRect.width > obsRect.left + 5 &&
          paddedPlayerRect.left < obsRect.left + obsRect.width - 5) {
        final LaserGridObstacleData lgObs = obs as LaserGridObstacleData;
        final double gapY = lgObs.gapY;
        final double gapH = lgObs.gapHeight;
        final double safeTop = gapY - gapH / 2 + 5;
        final double safeBottom = gapY + gapH / 2 - 5;
        if (paddedPlayerRect.top < safeTop ||
            (paddedPlayerRect.top + paddedPlayerRect.height) > safeBottom) {
          isColliding = true;
        }
      }
    } else if (obs.type == ObstacleType.fallingDrop) {
      final double cx = obsRect.left + obsRect.width / 2;
      final double cy = obsRect.top + obsRect.height / 2;
      final double r = obsRect.width / 2 - 6;
      final double testX = max(
        paddedPlayerRect.left,
        min(cx, paddedPlayerRect.left + paddedPlayerRect.width),
      );
      final double testY = max(
        paddedPlayerRect.top,
        min(cy, paddedPlayerRect.top + paddedPlayerRect.height),
      );
      final double dx = cx - testX;
      final double dy = cy - testY;
      if ((dx * dx + dy * dy) < (r * r)) isColliding = true;
    } else if (obs.type == ObstacleType.spike) {
      if (rectRectCollision(paddedPlayerRect, obsRect)) {
        final double tipX = obsRect.left + obsRect.width / 2;
        final double tipY = obsRect.top;
        if (lineRect(
          obsRect.left,
          obsRect.top + obsRect.height,
          tipX,
          tipY,
          paddedPlayerRect,
        )) {
          isColliding = true;
        } else if (lineRect(
          tipX,
          tipY,
          obsRect.left + obsRect.width,
          obsRect.top + obsRect.height,
          paddedPlayerRect,
        )) {
          isColliding = true;
        } else {
          final double centerX =
              paddedPlayerRect.left + paddedPlayerRect.width / 2;
          final double bottomY = paddedPlayerRect.top + paddedPlayerRect.height;
          if (centerX > obsRect.left &&
              centerX < obsRect.left + obsRect.width &&
              bottomY > obsRect.top + obsRect.height / 2) {
            isColliding = true;
          }
        }
      }
    } else if (obs.type == ObstacleType.aerial ||
        obs.type == ObstacleType.movingAerial) {
      if (rectRectCollision(paddedPlayerRect, obsRect)) {
        final double cx = obsRect.left + obsRect.width / 2;
        final double cy = obsRect.top + obsRect.height / 2;
        final double px = paddedPlayerRect.left;
        final double py = paddedPlayerRect.top;
        final double pw = paddedPlayerRect.width;
        final double ph = paddedPlayerRect.height;
        if (lineRect(
              obsRect.left,
              cy,
              cx,
              obsRect.top,
              ui.Rect.fromLTWH(px, py, pw, ph),
            ) ||
            lineRect(
              cx,
              obsRect.top,
              obsRect.left + obsRect.width,
              cy,
              ui.Rect.fromLTWH(px, py, pw, ph),
            ) ||
            lineRect(
              obsRect.left + obsRect.width,
              cy,
              cx,
              obsRect.top + obsRect.height,
              ui.Rect.fromLTWH(px, py, pw, ph),
            ) ||
            lineRect(
              cx,
              obsRect.top + obsRect.height,
              obsRect.left,
              cy,
              ui.Rect.fromLTWH(px, py, pw, ph),
            )) {
          isColliding = true;
        }
        if ((paddedPlayerRect.left + paddedPlayerRect.width / 2 - cx).abs() <
                10 &&
            (paddedPlayerRect.top + paddedPlayerRect.height / 2 - cy).abs() <
                10) {
          isColliding = true;
        }
      }
    } else if (obs.type == ObstacleType.slantedSurface) {
      final SlantedObstacleData sObs = obs as SlantedObstacleData;
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
      if (frames > GameConfig.tutorialIntroDuration) {
        tutorialState = 'JUMP_TEACH';
      }
      return;
    }

    if (_obstacleManager.activeObstacles.isEmpty) {
      if (tutorialState == 'JUMP_TEACH') {
        final obs = SimpleObstacleData(
          id: _obstacleManager.obstacleIdCounter,
          type: ObstacleType.ground,
          x: GameConfig.baseWidth + GameConfig.tutorialObstacleTutorialX,
          y: GameConfig.groundLevel - GameConfig.tutorialObstacleJumpYOffset,
          width: 30,
          height: 30,
        );
        _obstacleSystem.addObstacle(obs);
      } else if (tutorialState == 'DUCK_TEACH') {
        final obs = HazardObstacleData(
          id: _obstacleManager.obstacleIdCounter,
          x: GameConfig.baseWidth + GameConfig.tutorialObstacleTutorialX,
          y: GameConfig.groundLevel - GameConfig.tutorialObstacleDuckYOffset,
          width: 200,
          height: 40,
          initialY:
              GameConfig.groundLevel - GameConfig.tutorialObstacleDuckYOffset,
        );
        _obstacleSystem.addObstacle(obs);
      }
    }

    final firstObs = _obstacleManager.activeObstacles.isNotEmpty
        ? _obstacleManager.activeObstacles.first
        : null;
    if (firstObs != null) {
      final dist = firstObs.x - _playerData.x;
      if (dist < GameConfig.tutorialSlowdownDistMin &&
          dist > GameConfig.tutorialSlowdownDistTarget) {
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

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final isKeyDown = event is KeyDownEvent;
    final gameState = _gameStateProvider.currentGameState;

    if (gameState == GameState.menu || gameState == GameState.gameOver) {
      if (isKeyDown &&
          (keysPressed.contains(LogicalKeyboardKey.space) ||
              keysPressed.contains(LogicalKeyboardKey.enter))) {
        _gameStateProvider.startGame();
        return KeyEventResult.handled;
      }
    }

    // Unified pause/resume toggle
    if (isKeyDown && keysPressed.contains(LogicalKeyboardKey.keyP)) {
      if (gameState == GameState.playing) {
        _gameStateProvider.pauseGame();
      } else if (gameState == GameState.paused) {
        _gameStateProvider.resumeGame();
      }
      return KeyEventResult.handled;
    }

    if (gameState == GameState.playing) {
      if (keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
          keysPressed.contains(LogicalKeyboardKey.space)) {
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

    final gridPaint = Paint()
      ..color = const Color.fromRGBO(3, 160, 98, 0.3)
      ..strokeWidth = 1;
    final gridOffset = (frames * speed) % GameConfig.gridLineOffsetDivisor;
    for (double i = 0; i < size.x / GameConfig.gridLineOffsetDivisor + 2; i++) {
      final gx = i * GameConfig.gridLineOffsetDivisor - gridOffset;
      canvas.drawLine(
        Offset(gx, GameConfig.groundLevel),
        Offset(gx, size.y),
        gridPaint,
      );
    }

    canvas.drawLine(
      Offset(0, GameConfig.groundLevel),
      Offset(size.x, GameConfig.groundLevel),
      _groundLinePaint,
    );

    // Player trail
    for (int i = 0; i < _trailHistory.length; i++) {
      final trailNode = _trailHistory[i];
      final ratio = i / _trailHistory.length;
      final alpha = ratio * GameConfig.playerTrailAlphaMax;
      final hue = (frames * GameConfig.playerTrailHueCycleSpeed) % 360;
      _playerTrailPaint.color = hslToColor(
        hue.toDouble(),
        1.0,
        0.5,
      ).withAlpha((255 * alpha).round());
      _playerTrailPaint.maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        ratio * GameConfig.playerTrailBlurRadiusMultiplier,
      );
      canvas.drawRect(trailNode, _playerTrailPaint);
    }

    if (tutorialActive) {
      _drawTutorial(canvas);
    }

    if (_playerData.hasMagnet) {
      _magnetPaint.color = const Color(0xFFFF00FF).withAlpha(
        (255 *
                (GameConfig.magnetEffectAlphaBase +
                    (sin(
                          frames *
                              GameConfig
                                  .magnetEffectAlphaOscillationFrequency,
                        ) *
                        GameConfig.magnetEffectAlphaOscillation)))
            .round(),
      );
      final magnetRadius =
          (_playerData.width / 2) +
          GameConfig.magnetRadiusBaseAdd +
          (sin(frames * GameConfig.magnetRadiusOscillationFrequency) *
              GameConfig.magnetRadiusOscillation);
      canvas.drawCircle(
        Offset(
          _playerData.x + _playerData.width / 2,
          _playerData.y + _playerData.height / 2,
        ),
        magnetRadius,
        _magnetPaint,
      );
    }

    if (_powerUpMessage != null && _powerUpMessageTimer > 0) {
      final textPainter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: _powerUpMessage,
          style: TextStyle(
            color: GameConfig.accentNeonColor.withAlpha(
              (255 *
                      (_powerUpMessageTimer /
                          GameConfig.powerUpMessageDisplayDuration))
                  .round(),
            ),
            fontSize: GameConfig.hudPowerUpMessageFontSize,
            fontFamily: 'Share Tech Mono',
            shadows: [
              Shadow(
                blurRadius: GameConfig.playerTrailBlurRadiusMultiplier,
                color: GameConfig.accentNeonColor,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
      );
      textPainter.layout(maxWidth: size.x);
      textPainter.paint(
        canvas,
        Offset(
          (size.x - textPainter.width) / 2,
          size.y / 2 - GameConfig.hudPowerUpMessageYOffset,
        ),
      );
    }

    // Debug: Draw player hitbox
    if (GameConfig.debugShowHitboxes) {
      final playerCollisionRect = ui.Rect.fromLTWH(
        _playerData.x + GameConfig.playerCollisionPadding,
        _playerData.y + GameConfig.playerCollisionPadding,
        _playerData.width - (GameConfig.playerCollisionPadding * 2),
        _playerData.height - (GameConfig.playerCollisionPadding * 2),
      );
      canvas.drawRect(
        playerCollisionRect,
        Paint()
          ..color = const Color.fromARGB(128, 255, 255, 0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawTutorial(Canvas canvas) {
    canvas.save();
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    final textStyle = const TextStyle(
      color: GameConfig.primaryNeonColor,
      fontSize: 24,
      fontFamily: 'Share Tech Mono',
    );

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.x, 100),
      Paint()
        ..color = Colors.black.withAlpha(
          (255 * GameConfig.tutorialBackgroundAlpha).round(),
        ),
    );

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
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.x, 100),
      Paint()
        ..color = Colors.black.withAlpha(
          (255 * GameConfig.tutorialBackgroundAlpha).round(),
        ),
    );
    textPainter.paint(
      canvas,
      Offset((size.x - textPainter.width) / 2, 50 - textPainter.height / 2),
    );

    if (tutorialState == 'JUMP_TEACH' || tutorialState == 'DUCK_TEACH') {
      final arrowPaint = Paint()
        ..color = GameConfig.primaryNeonColor
        ..strokeWidth = GameConfig.tutorialArrowStrokeWidth
        ..style = PaintingStyle.stroke;

      final arrowPath = Path();
      if (tutorialState == 'JUMP_TEACH') {
        arrowPath.moveTo(
          _playerData.x + _playerData.width / 2,
          _playerData.y - 10,
        );
        arrowPath.lineTo(
          _playerData.x + _playerData.width / 2,
          _playerData.y - 30,
        );
        arrowPath.lineTo(
          _playerData.x + _playerData.width / 2 - 10,
          _playerData.y - 20,
        );
        arrowPath.moveTo(
          _playerData.x + _playerData.width / 2,
          _playerData.y - 30,
        );
        arrowPath.lineTo(
          _playerData.x + _playerData.width / 2 + 10,
          _playerData.y - 20,
        );
      } else {
        // DUCK_TEACH
        arrowPath.moveTo(
          _playerData.x + _playerData.width / 2,
          _playerData.y + _playerData.height + 10,
        );
        arrowPath.lineTo(
          _playerData.x + _playerData.width / 2,
          _playerData.y + _playerData.height + 30,
        );
        arrowPath.lineTo(
          _playerData.x + _playerData.width / 2 - 10,
          _playerData.y + _playerData.height + 20,
        );
        arrowPath.moveTo(
          _playerData.x + _playerData.width / 2,
          _playerData.y + _playerData.height + 30,
        );
        arrowPath.lineTo(
          _playerData.x + _playerData.width / 2 + 10,
          _playerData.y + _playerData.height + 20,
        );
      }
      canvas.drawPath(arrowPath, arrowPaint);
    }
    canvas.restore();
  }

  void initGame() {
    debugPrint('NeonRunnerGame.initGame() called. Setting paused = false.');
    _audioController.startMusic();
    _playerData.reset();
    _playerData.y = GameConfig.groundLevel - _playerData.height;

    _obstacleManager.reset();
    _powerUpManager.reset();
    _particleManager.reset();
    _trailHistory.clear();

    score = 0;
    frames = 0;
    _dtWarningCounter = 0;
    speed = GameConfig.baseSpeed;
    inputLock = false;
    scoreGlitch = false;
    isTransitioning = false;
    _hudUpdateCounter = 0;

    tutorialActive = !_localStorageService.getTutorialSeen();
    tutorialState = 'INTRO';

    paused = false; // Unpause the game to start the update loop
  }

  void handleGameOver() {
    paused = true; // Stop the game loop immediately

    if (score > highscore) {
      highscore = score;
      _localStorageService.setHighscore(highscore);
    }

    _audioController.stopMusic();
    _audioController.playCrash();
    _particleManager.createExplosion(
      _playerData.x + _playerData.width / 2,
      _playerData.y + _playerData.height / 2,
      GameConfig.primaryNeonColor,
    );

    inputLock = true;

    _gameStateProvider.gameOver(); // Notify provider to switch overlays

    Future.delayed(const Duration(seconds: GameConfig.gameOverDelaySeconds), () {
      inputLock = false;
      // The logic to show ads or other prompts is now handled by the UI listening to the provider
      // _adsController.showRewardedAd(() {
      //   _gameStateProvider.startGame();
      // });
      _gameStateProvider.updateGameState(
        GameState.menu,
      ); // Go back to menu for testing
    });
  }

  void toggleMute() {
    _audioController.toggleMute(!_audioController.isMuted);
  }
}
