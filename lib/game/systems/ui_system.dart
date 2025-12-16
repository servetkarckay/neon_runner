import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flutter_neon_runner/game/systems/player_system.dart';
import 'package:flutter_neon_runner/utils/math_utils.dart';

/// System managing all UI rendering and visual effects
class UISystem extends EventHandlerSystem {
  final PlayerSystem _playerSystem;
  Canvas? _canvas;
  Size? _screenSize;

  // UI state
  String? _powerUpMessage;
  int _powerUpMessageTimer = 0;
  bool _tutorialActive = false;
  String _tutorialState = 'INTRO';

  // Text painters for performance
  final Map<String, TextPainter> _textPainters = {};

  UISystem(this._playerSystem);

  @override
  String get systemName => 'UISystem';

  @override
  Future<void> initialize() async {
    // Subscribe to events
    GameEventBus.instance.subscribe<PlayerPowerUpActivatedEvent>(_handlePowerUpMessage);
    GameEventBus.instance.subscribe<ShowMessageEvent>(_handleShowMessage);
    GameEventBus.instance.subscribe<GameStartedEvent>(_handleGameStarted);

    // Initialize text painters
    _initializeTextPainters();
  }

  @override
  void update(double dt) {
    if (_canvas == null || _screenSize == null) return;

    _updatePowerUpMessage();
    _updateUIElements();
  }

  @override
  void handleEvent(GameEvent event) {
    // Events are handled via subscriptions
  }

  @override
  List<Type> get handledEventTypes => [
    PlayerPowerUpActivatedEvent,
    ShowMessageEvent,
    GameStartedEvent,
  ];

  // Public methods
  void render(Canvas canvas, Size screenSize) {
    _canvas = canvas;
    _screenSize = screenSize;

    // Render background elements
    _renderBackground();
    _renderGround();
    _renderPlayerTrail();

    // Render UI overlays
    if (_tutorialActive) {
      _renderTutorial();
    }

    if (_powerUpMessage != null && _powerUpMessageTimer > 0) {
      _renderPowerUpMessage();
    }

    _renderMagnetEffect();
    _renderDebugInfo();
  }

  void setTutorialState(bool active, String state) {
    _tutorialActive = active;
    _tutorialState = state;
  }

  // Private methods
  void _initializeTextPainters() {
    _textPainters['powerUp'] = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      text: TextSpan(
        style: TextStyle(
          color: GameConfig.accentNeonColor,
          fontSize: GameConfig.hudPowerUpMessageFontSize,
          fontFamily: 'Share Tech Mono',
          shadows: [
            Shadow(
              blurRadius: GameConfig.playerTrailBlurRadiusMultiplier,
              color: GameConfig.accentNeonColor,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ),
    );

    _textPainters['tutorial'] = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      text: TextSpan(
        style: const TextStyle(
          color: GameConfig.primaryNeonColor,
          fontSize: 24,
          fontFamily: 'Share Tech Mono',
        ),
      ),
    );
  }

  void _renderBackground() {
    final gridPaint = Paint()
      ..color = const Color.fromRGBO(3, 160, 98, 0.3)
      ..strokeWidth = 1;

    // Render moving grid
    final gridOffset = (0 * 0) % GameConfig.gridLineOffsetDivisor; // Will be replaced with frame count
    for (double i = 0; i < (_screenSize?.width ?? 0) / GameConfig.gridLineOffsetDivisor + 2; i++) {
      final gx = i * GameConfig.gridLineOffsetDivisor - gridOffset;
      _canvas?.drawLine(
        Offset(gx, GameConfig.groundLevel),
        Offset(gx, _screenSize?.height ?? 0),
        gridPaint,
      );
    }
  }

  void _renderGround() {
    _canvas?.drawLine(
      Offset(0, GameConfig.groundLevel),
      Offset(_screenSize?.width ?? 0, GameConfig.groundLevel),
      Paint()
        ..color = GameConfig.primaryNeonColor
        ..strokeWidth = GameConfig.groundLineStrokeWidth,
    );
  }

  void _renderPlayerTrail() {
    final trailHistory = _playerSystem.trailHistory;

    if (trailHistory.isEmpty) return;

    final playerTrailPaint = Paint()..blendMode = BlendMode.plus;

    for (int i = 0; i < trailHistory.length; i++) {
      final trailNode = trailHistory[i];
      final ratio = i / trailHistory.length;
      final alpha = ratio * GameConfig.playerTrailAlphaMax;
      final hue = (0 * GameConfig.playerTrailHueCycleSpeed) % 360; // Will use frame count

      playerTrailPaint.color = hslToColor(
        hue.toDouble(),
        1.0,
        0.5,
      ).withAlpha((255 * alpha).round());

      playerTrailPaint.maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        ratio * GameConfig.playerTrailBlurRadiusMultiplier,
      );

      _canvas?.drawRect(trailNode, playerTrailPaint);
    }
  }

  void _renderTutorial() {
    _canvas?.save();

    final textPainter = _textPainters['tutorial']!;
    String text = '';

    switch (_tutorialState) {
      case 'INTRO':
        text = "INITIATING TRAINING PROTOCOL...";
        break;
      case 'JUMP_TEACH':
        text = "TAP UPPER SCREEN TO JUMP";
        break;
      case 'DUCK_TEACH':
        text = "TAP LOWER SCREEN TO DUCK";
        break;
    }

    textPainter.text = TextSpan(text: text, style: textPainter.text!.style!);
    textPainter.layout(maxWidth: _screenSize?.width ?? 0);

    // Background
    _canvas?.drawRect(
      Rect.fromLTWH(0, 0, _screenSize?.width ?? 0, 100),
      Paint()
        ..color = Colors.black.withAlpha(
          (255 * GameConfig.tutorialBackgroundAlpha).round(),
        ),
    );

    // Text
    textPainter.paint(
      _canvas!,
      Offset(((_screenSize?.width ?? 0) - textPainter.width) / 2, 50 - textPainter.height / 2),
    );

    // Draw tutorial arrow if needed
    if (_tutorialState == 'JUMP_TEACH' || _tutorialState == 'DUCK_TEACH') {
      _drawTutorialArrow();
    }

    _canvas?.restore();
  }

  void _drawTutorialArrow() {
    final playerData = _playerSystem.playerData;
    final arrowPaint = Paint()
      ..color = GameConfig.primaryNeonColor
      ..strokeWidth = GameConfig.tutorialArrowStrokeWidth
      ..style = PaintingStyle.stroke;

    final arrowPath = Path();

    if (_tutorialState == 'JUMP_TEACH') {
      arrowPath.moveTo(
        playerData.x + playerData.width / 2,
        playerData.y - 10,
      );
      arrowPath.lineTo(
        playerData.x + playerData.width / 2,
        playerData.y - 30,
      );
      arrowPath.moveTo(
        playerData.x + playerData.width / 2,
        playerData.y - 30,
      );
      arrowPath.lineTo(
        playerData.x + playerData.width / 2 - 10,
        playerData.y - 20,
      );
      arrowPath.moveTo(
        playerData.x + playerData.width / 2,
        playerData.y - 30,
      );
      arrowPath.lineTo(
        playerData.x + playerData.width / 2 + 10,
        playerData.y - 20,
      );
    } else {
      // DUCK_TEACH
      arrowPath.moveTo(
        playerData.x + playerData.width / 2,
        playerData.y + playerData.height + 10,
      );
      arrowPath.lineTo(
        playerData.x + playerData.width / 2,
        playerData.y + playerData.height + 30,
      );
      arrowPath.moveTo(
        playerData.x + playerData.width / 2,
        playerData.y + playerData.height + 30,
      );
      arrowPath.lineTo(
        playerData.x + playerData.width / 2 - 10,
        playerData.y + playerData.height + 20,
      );
      arrowPath.moveTo(
        playerData.x + playerData.width / 2,
        playerData.y + playerData.height + 30,
      );
      arrowPath.lineTo(
        playerData.x + playerData.width / 2 + 10,
        playerData.y + playerData.height + 20,
      );
    }

    _canvas?.drawPath(arrowPath, arrowPaint);
  }

  void _renderPowerUpMessage() {
    final textPainter = _textPainters['powerUp']!;
    textPainter.text = TextSpan(
      text: _powerUpMessage,
      style: TextStyle(
        color: GameConfig.accentNeonColor.withAlpha(
          (255 *
                  (_powerUpMessageTimer / GameConfig.powerUpMessageDisplayDuration))
              .round(),
        ),
        fontSize: GameConfig.hudPowerUpMessageFontSize,
        fontFamily: 'Share Tech Mono',
        shadows: [
          Shadow(
            blurRadius: GameConfig.playerTrailBlurRadiusMultiplier,
            color: GameConfig.accentNeonColor,
            offset: const Offset(0, 0),
          ),
        ],
      ),
    );

    textPainter.layout(maxWidth: _screenSize?.width ?? 0);
    textPainter.paint(
      _canvas!,
      Offset(
        ((_screenSize?.width ?? 0) - textPainter.width) / 2,
        (_screenSize?.height ?? 0) / 2 - GameConfig.hudPowerUpMessageYOffset,
      ),
    );
  }

  void _renderMagnetEffect() {
    final playerData = _playerSystem.playerData;
    if (!playerData.hasMagnet) return;

    final magnetPaint = Paint()
      ..color = const Color(0xFFFF00FF).withAlpha(
        (255 *
                (GameConfig.magnetEffectAlphaBase +
                    (sin(
                          0 *
                              GameConfig.magnetEffectAlphaOscillationFrequency,
                        ) *
                        GameConfig.magnetEffectAlphaOscillation)))
            .round(),
      );

    final magnetRadius = (playerData.width / 2) +
        GameConfig.magnetRadiusBaseAdd +
        (sin(0 * GameConfig.magnetRadiusOscillationFrequency) *
            GameConfig.magnetRadiusOscillation);

    _canvas?.drawCircle(
      Offset(
        playerData.x + playerData.width / 2,
        playerData.y + playerData.height / 2,
      ),
      magnetRadius,
      magnetPaint,
    );
  }

  void _renderDebugInfo() {
    if (!GameConfig.debugShowHitboxes) return;

    final playerData = _playerSystem.playerData;
    final playerCollisionRect = Rect.fromLTWH(
      playerData.x + GameConfig.playerCollisionPadding,
      playerData.y + GameConfig.playerCollisionPadding,
      playerData.width - (GameConfig.playerCollisionPadding * 2),
      playerData.height - (GameConfig.playerCollisionPadding * 2),
    );

    _canvas?.drawRect(
      playerCollisionRect,
      Paint()
        ..color = const Color.fromARGB(128, 255, 255, 0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _updatePowerUpMessage() {
    if (_powerUpMessageTimer > 0) {
      _powerUpMessageTimer--;
      if (_powerUpMessageTimer <= 0) {
        _powerUpMessage = null;
      }
    }
  }

  void _updateUIElements() {
    // Update any animated UI elements here
  }

  // Event handlers
  void _handlePowerUpMessage(PlayerPowerUpActivatedEvent event) {
    _powerUpMessage = event.message;
    _powerUpMessageTimer = GameConfig.powerUpMessageDisplayDuration;
  }

  void _handleShowMessage(ShowMessageEvent event) {
    _powerUpMessage = event.message;
    _powerUpMessageTimer = event.duration.inMilliseconds;
  }

  void _handleGameStarted(GameStartedEvent event) {
    _tutorialActive = false;
    _tutorialState = 'INTRO';
  }

  @override
  void dispose() {
    _textPainters.clear();

    GameEventBus.instance.unsubscribe<PlayerPowerUpActivatedEvent>(_handlePowerUpMessage);
    GameEventBus.instance.unsubscribe<ShowMessageEvent>(_handleShowMessage);
    GameEventBus.instance.unsubscribe<GameStartedEvent>(_handleGameStarted);
  }
}