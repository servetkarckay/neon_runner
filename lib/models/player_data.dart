import 'package:flame/components.dart';

class PlayerData {
  double x;
  double y;
  double width;
  double height;
  double velocityY;
  bool isJumping;
  bool isHoldingJump;
  bool isDucking;
  int jumpTimer;
  int jumpBufferTimer;
  bool hasShield;
  double scoreMultiplier;
  int multiplierTimer;
  int timeWarpTimer;
  bool hasMagnet;
  int magnetTimer;
  bool isGrazing;
  int invincibleTimer;
  Vector2 currentVelocity; // Added this line

  PlayerData({
    this.x = 50,
    this.y = 0,
    this.width = 40,
    this.height = 40,
    this.velocityY = 0,
    this.isJumping = false,
    this.isHoldingJump = false,
    this.isDucking = false,
    this.jumpTimer = 0,
    this.jumpBufferTimer = 0,
    this.hasShield = false,
    this.scoreMultiplier = 1,
    this.multiplierTimer = 0,
    this.timeWarpTimer = 0,
    this.hasMagnet = false,
    this.magnetTimer = 0,
    this.isGrazing = false,
    this.invincibleTimer = 0,
    Vector2? initialVelocity, // New parameter for initialization
  }) : currentVelocity = initialVelocity ?? Vector2.zero(); // Initialize here

  void reset() {
    x = 50;
    y = 0; // Will be set to ground level in initGame
    width = 40;
    height = 40;
    velocityY = 0;
    isJumping = false;
    isHoldingJump = false;
    isDucking = false;
    jumpTimer = 0;
    jumpBufferTimer = 0;
    hasShield = false;
    scoreMultiplier = 1;
    multiplierTimer = 0;
    timeWarpTimer = 0;
    hasMagnet = false;
    magnetTimer = 0;
    isGrazing = false;
    invincibleTimer = 0;
    currentVelocity = Vector2.zero(); // Reset currentVelocity
  }
}