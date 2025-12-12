import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neon_runner/config/game_config.dart';
import 'package:flutter_neon_runner/models/player_data.dart';

class PlayerComponent extends Component {
  final PlayerData playerData;
  final Paint _playerPaint = Paint();
  final Paint _shieldPaint = Paint();
  final Paint _magnetPaint = Paint();

  PlayerComponent(this.playerData) {
    _playerPaint.color = Colors.white; // Default player color
    _shieldPaint
      ..color = const Color(0xAA00FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _magnetPaint
      ..color = const Color(0xAAFF00FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Apply invincibility flicker
    if (playerData.invincibleTimer > 0) {
      if ((playerData.invincibleTimer ~/ 5) % 2 == 0) {
        // Flickers by making the player semi-transparent
        _playerPaint.color = _playerPaint.color.withAlpha((255 * 0.3).round());
      } else {
        _playerPaint.color = _playerPaint.color.withAlpha((255 * 1.0).round());
      }
    } else {
      _playerPaint.color = Colors.white.withAlpha(255); // Ensure full opacity when not invincible
    }

    // Player body
    canvas.drawRect(
      Rect.fromLTWH(
        playerData.x,
        playerData.y,
        playerData.width,
        playerData.height,
      ),
      _playerPaint,
    );

    // Shield effect
    if (playerData.hasShield) {
      canvas.drawCircle(
        Offset(playerData.x + playerData.width / 2, playerData.y + playerData.height / 2),
        30,
        _shieldPaint,
      );
    }

    // Magnet effect
    if (playerData.hasMagnet) {
      canvas.drawCircle(
        Offset(playerData.x + playerData.width / 2, playerData.y + playerData.height / 2),
        35 + (GameConfig.baseSpeed * 0.2).abs(), // Simple animation for now
        _magnetPaint,
      );
    }
  }

  // No update method here, player physics handled in the main game loop for now
}
