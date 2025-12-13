import 'package:flutter/material.dart';
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

  static const double playerDefaultHeight = 40;
  static const double playerDuckingHeight = 20;

  static const double powerUpMultiplierValue = 2;
  static const int powerUpMultiplierDuration = 600;
  static const int powerUpTimeWarpDuration = 300;
  static const int powerUpMagnetDuration = 600;
  static const int powerUpCollisionParticleCount = 10;
  static const int grazeScoreAmount = 5;

  // Timers and Durations (in frames)
  static const int playerInvincibleDuration = 90; // invincibility after shield break
  static const int powerUpMessageDisplayDuration = 90; // power-up message display time
  static const int scoreGlitchDurationLong = 500; // longer score glitch
  static const int scoreGlitchDurationShort = 200; // shorter score glitch
  static const int jumpBufferDuration = 8; // frames for jump buffer

  // Game Mechanics
  static const double collisionEpsilon = 1e-4; // Added for collision detection
  static const double playerCollisionPadding = 10.0;
  static const double hazardZoneSafeTolerance = 5.0; // for grazing hazard from below
  static const double grazeDistance = 30.0;
  static const double laserGridSafePadding = 5.0;
  static const double fallingDropRadiusAdjustment = 6.0;
  static const double aerialObstacleCollisionTolerance = 10.0;
  static const double obstacleRemoveX = -1000; // x-coordinate for removing obstacles

  // Scoring
  static const int scoreUpdateFrequency = 5; // update score every X frames
  static const int scoreGlitchTrigger = 100; // score multiple to trigger glitch
  static const double randomScoreGlitchChance = 0.002;

  // Visuals
  static const double playerTrailMaxLengthBase = 10;
  static const double playerTrailSpeedMultiplier = 0.8;
  static const int playerTrailHueCycleSpeed = 2; // frames
  static const double playerTrailAlphaMax = 0.5;
  static const double playerTrailBlurRadiusMultiplier = 5;

  static const double magnetEffectAlphaBase = 0.5;
  static const double magnetEffectAlphaOscillation = 0.2;
  static const double magnetEffectAlphaOscillationFrequency = 0.1;
  static const double magnetRadiusBaseAdd = 20;
  static const double magnetRadiusOscillation = 5;
  static const double magnetRadiusOscillationFrequency = 0.15;

  static const double gridLineOffsetDivisor = 100; // for background grid
  static const double groundLineStrokeWidth = 2;

  // Tutorial
  static const int tutorialIntroDuration = 150;
  static const double tutorialSlowdownDistMin = 200;
  static const double tutorialSlowdownDistTarget = 50;
  static const double tutorialSpeed = 2;
  static const double tutorialObstacleTutorialX = 200; // x-pos for tutorial obstacles to appear
  static const double tutorialObstacleJumpYOffset = 30; // y-offset for jump tutorial obstacle
  static const double tutorialObstacleDuckYOffset = 75; // y-offset for duck tutorial obstacle
  static const double tutorialBackgroundAlpha = 0.5;
  static const double tutorialArrowStrokeWidth = 3;

  // UI common (colors/opacities for consistent design)
  static const double overlayBackgroundAlpha = 0.8; // for Scaffold background in overlays
  static const double menuButtonBackgroundAlpha = 0.2;
  static const double menuButtonBorderWidth = 1;
  static const double menuButtonBorderRadius = 4;
  static const double menuButtonShadowAlpha = 0.1;
  static const double menuButtonShadowBlurRadius = 10;
  static const Color primaryNeonColor = Color(0xFF00FF41); // Green
  static const Color accentNeonColor = Color(0xFF00FFFF); // Cyan
  static const Color errorNeonColor = Colors.red;
  static const Color yellowNeonColor = Color(0xFFFFFF00);
  static const Color purpleNeonColor = Color(0xFFAA00FF);
  static const Color pinkNeonColor = Color(0xFFFF00FF);
  static const Color darkGreenOverlayColor = Color.fromARGB(255, 0, 20, 0);

  static const int framesPerSecond = 60;

  // HUD
  static const double hudMuteButtonBgAlpha = 0.6;
  static const double hudMuteButtonBorderWidth = 1;
  static const double hudScoreFontSize = 24;
  static const double hudScoreScaleAnimation = 0.1;
  static const int hudScoreAnimationDurationMs = 200;
  static const double hudScoreShadowAlpha = 0.8;
  static const double hudLabelFontSize = 12;
  static const double hudLabelAlpha = 0.7;
  static const double hudValueFontSize = 18;
  static const double hudPowerUpMessageFontSize = 30;
  static const double hudPowerUpMessageYOffset = 50;

  // Overlays general spacing/padding
  static const double defaultOverlayPadding = 16; // for Positioned widgets in overlays
  static const double defaultOverlaySpacing = 20; // vertical spacing between elements

  // Menu specifics
  static const double mainMenuTitleFontSize = 48;
  static const double mainMenuTitleBlurRadius = 20;
  static const double mainMenuSubtitleFontSize = 18;
  static const double mainMenuSubtitleLetterSpacing = 4;
  static const double mainMenuStartPromptFontSize = 20;
  static const double mainMenuStartPromptLetterSpacing = 2;
  static const double mainMenuSectionSpacing = 50; // between major sections
  static const double mainMenuButtonSpacing = 20; // between menu buttons
  static const double controlRowContainerPadding = 20;
  static const double controlRowContainerMarginHorizontal = 20;
  static const double controlRowContainerBorderWidth = 1;
  static const double controlRowContainerBgAlpha = 0.6;
  static const double controlRowContainerBorderRadius = 4;
  static const double controlRowContainerShadowAlpha = 0.1;
  static const double controlRowContainerShadowBlurRadius = 15;
  static const double controlRowVerticalPadding = 4;
  static const double controlRowKeyPaddingHorizontal = 6;
  static const double controlRowKeyPaddingVertical = 2;
  static const double controlRowKeyBorderRadius = 2;
  static const double controlRowKeyShadowAlpha = 0.5;
  static const double controlRowKeyShadowBlurRadius = 5;
  static const double controlRowKeyFontSize = 12;
  static const double controlRowActionFontSize = 14;
  static const double controlRowActionLetterSpacing = 1;
  static const double powerUpLegendIconFontSize = 16;
  static const double powerUpLegendTextSpacing = 8;
  static const double powerUpLegendTextFontSize = 14;
  static const double powerUpLegendContainerPadding = 20;
  static const double powerUpLegendContainerMarginHorizontal = 20;
  static const double powerUpLegendContainerBorderWidth = 1;
  static const double powerUpLegendContainerBgAlpha = 0.6;
  static const double powerUpLegendContainerBorderRadius = 4;
  static const double powerUpLegendContainerShadowAlpha = 0.1;
  static const double powerUpLegendContainerShadowBlurRadius = 15;
  static const double powerUpLegendTitlePaddingBottom = 8;
  static const double powerUpLegendTitleFontSize = 16;
  static const double powerUpLegendTitleBorderWidth = 1;

  // Pause menu specifics
  static const double pauseMenuTitleFontSize = 36;
  static const double pauseMenuTitleBlurRadius = 20;
  static const double pauseMenuButtonSpacing = 20;
  static const double pauseMenuActionButtonPaddingHorizontal = 40;
  static const double pauseMenuActionButtonPaddingVertical = 15;
  static const double pauseMenuActionButtonBorderRadius = 4;
  static const double pauseMenuActionButtonShadowAlpha = 0.5;
  static const double pauseMenuActionButtonElevation = 10;
  static const double pauseMenuActionButtonFontSize = 20;
  static const double pauseMenuActionButtonLetterSpacing = 2;

  // Game Over specifics
  static const double gameOverTitleFontSize = 36;
  static const double gameOverTitleBlurRadius = 20;
  static const double gameOverScoreFontSize = 24;
  static const double gameOverHighscoreFontSize = 16;
  static const double gameOverButtonSpacing = 20;

  // Leaderboard specifics
  static const double leaderboardContainerWidth = 400;
  static const double leaderboardContainerPadding = 30;
  static const double leaderboardContainerBorderWidth = 2;
  static const double leaderboardContainerShadowAlpha = 0.3;
  static const double leaderboardContainerShadowBlurRadius = 30;
  static const double leaderboardTitleFontSize = 28;
  static const double leaderboardTitleBlurRadius = 10;
  static const double leaderboardEntryVerticalPadding = 8;
  static const double leaderboardEntryFontSize = 18;
  static const double leaderboardButtonSpacing = 30;

  // Mobile controls specifics
  static const double mobileControlDuckJumpButtonSizeRatio = 0.15; // as percentage of screen width
  static const double mobileControlButtonHorizontalMarginRatio = 0.05;
  static const double mobileControlButtonBottomMarginRatio = 0.1;
  static const double mobileControlPauseButtonPadding = 8;
  static const double mobileControlPauseButtonBorderWidth = 1;
  static const double mobileControlPauseButtonBgAlpha = 0.6;
  static const double mobileControlPauseButtonBorderRadius = 8;
  static const double mobileControlButtonBgAlpha = 0.5;
  static const double mobileControlButtonBorderWidth = 2;
  static const double mobileControlButtonShadowAlpha = 0.2;
  static const double mobileControlButtonShadowBlurRadius = 15;
  static const double mobileControlButtonFontSize = 18;

  static const int gameOverDelaySeconds = 1;

  static const double vignetteStop1 = 0.6;
  static const double vignetteStop2 = 0.8;
  static const double vignetteStop3 = 1.0;
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