import 'package:vector_math/vector_math_64.dart' as vm;
import 'game_component.dart';
import 'player_component.dart';

/// Enemy component that poses threats to the player
class EnemyComponent extends GameComponent {
  /// Type of enemy
  EnemyType enemyType = EnemyType.basic;

  /// Enemy health
  int health = 1;

  /// Damage dealt to player
  int damage = 10;

  /// Score value when defeated
  int scoreValue = 100;

  /// Detection radius for player
  double detectionRadius = 150.0;

  /// Attack range
  double attackRange = 50.0;

  /// Movement speed
  double moveSpeed = 50.0;

  /// Attack cooldown timer
  double attackCooldown = 0.0;

  /// Maximum attack cooldown
  double maxAttackCooldown = 2.0;

  /// Current AI state
  AIState currentState = AIState.idle;

  /// Target player reference
  PlayerComponent? targetPlayer;

  /// Animation timer
  double animationTimer = 0.0;

  /// Patrol waypoints
  final List<vm.Vector2> patrolWaypoints = [];

  /// Current patrol waypoint index
  int currentWaypointIndex = 0;

  EnemyComponent() {
    size = vm.Vector2(40, 40);
    health = 1;
    damage = 10;
    scoreValue = 100;
    detectionRadius = 150.0;
    attackRange = 50.0;
    moveSpeed = 50.0;
    attackCooldown = 0.0;
    maxAttackCooldown = 2.0;
    currentState = AIState.idle;
    animationTimer = 0.0;
  }

  @override
  String get componentType => 'enemy';

  @override
  void update(double dt) {
    super.update(dt);

    if (!isActive) return;

    animationTimer += dt;

    // Update attack cooldown
    if (attackCooldown > 0) {
      attackCooldown -= dt;
    }

    // Execute AI behavior
    _updateAI(dt);
  }

  /// Update AI behavior based on current state
  void _updateAI(double dt) {
    switch (currentState) {
      case AIState.idle:
        _handleIdleState(dt);
        break;
      case AIState.patrol:
        _handlePatrolState(dt);
        break;
      case AIState.chase:
        _handleChaseState(dt);
        break;
      case AIState.attack:
        _handleAttackState(dt);
        break;
      case AIState.flee:
        _handleFleeState(dt);
        break;
    }
  }

  /// Handle idle state
  void _handleIdleState(double dt) {
    velocity.setZero();

    // Check for player in detection radius
    if (targetPlayer != null && _isPlayerInDetectionRadius()) {
      currentState = AIState.chase;
    } else if (patrolWaypoints.isNotEmpty) {
      currentState = AIState.patrol;
    }
  }

  /// Handle patrol state
  void _handlePatrolState(double dt) {
    if (patrolWaypoints.isEmpty) {
      currentState = AIState.idle;
      return;
    }

    final targetWaypoint = patrolWaypoints[currentWaypointIndex];
    final direction = (targetWaypoint - position).normalized();
    velocity = direction * moveSpeed;

    // Check if reached waypoint
    if (position.distanceTo(targetWaypoint) < 10.0) {
      currentWaypointIndex = (currentWaypointIndex + 1) % patrolWaypoints.length;
    }

    // Check for player
    if (targetPlayer != null && _isPlayerInDetectionRadius()) {
      currentState = AIState.chase;
    }
  }

  /// Handle chase state
  void _handleChaseState(double dt) {
    if (targetPlayer == null || !targetPlayer!.isActive || targetPlayer!.isDead) {
      currentState = AIState.patrol;
      return;
    }

    final direction = (targetPlayer!.position - position).normalized();
    velocity = direction * moveSpeed;

    // Check if in attack range
    if (_isPlayerInAttackRange()) {
      currentState = AIState.attack;
    }

    // Check if player lost
    if (!_isPlayerInDetectionRadius()) {
      currentState = AIState.patrol;
    }
  }

  /// Handle attack state
  void _handleAttackState(double dt) {
    velocity.setZero();

    if (targetPlayer == null || !targetPlayer!.isActive || targetPlayer!.isDead) {
      currentState = AIState.patrol;
      return;
    }

    if (_isPlayerInAttackRange() && attackCooldown <= 0) {
      _performAttack();
      attackCooldown = maxAttackCooldown;
    } else if (!_isPlayerInAttackRange()) {
      currentState = AIState.chase;
    }
  }

  /// Handle flee state
  void _handleFleeState(double dt) {
    if (targetPlayer == null) {
      currentState = AIState.patrol;
      return;
    }

    final direction = (position - targetPlayer!.position).normalized();
    velocity = direction * moveSpeed * 1.5; // Move faster when fleeing

    // Check if safe distance reached
    if (!_isPlayerInDetectionRadius()) {
      currentState = AIState.patrol;
    }
  }

  /// Check if player is in detection radius
  bool _isPlayerInDetectionRadius() {
    if (targetPlayer == null) return false;
    return position.distanceTo(targetPlayer!.position) <= detectionRadius;
  }

  /// Check if player is in attack range
  bool _isPlayerInAttackRange() {
    if (targetPlayer == null) return false;
    return position.distanceTo(targetPlayer!.position) <= attackRange;
  }

  /// Perform attack on player
  void _performAttack() {
    if (targetPlayer != null && attackCooldown <= 0) {
      targetPlayer!.takeDamage(damage);
      attackCooldown = maxAttackCooldown;
    }
  }

  /// Take damage
  void takeDamage(int damage) {
    health -= damage;
    if (health <= 0) {
      health = 0;
      isActive = false;
    }
  }

  /// Set enemy type with appropriate properties
  void setEnemyType(EnemyType type) {
    enemyType = type;

    switch (type) {
      case EnemyType.basic:
        health = 1;
        damage = 10;
        scoreValue = 100;
        moveSpeed = 50.0;
        detectionRadius = 150.0;
        break;
      case EnemyType.fast:
        health = 1;
        damage = 5;
        scoreValue = 150;
        moveSpeed = 100.0;
        detectionRadius = 200.0;
        break;
      case EnemyType.tank:
        health = 3;
        damage = 20;
        scoreValue = 300;
        moveSpeed = 30.0;
        detectionRadius = 120.0;
        break;
      case EnemyType.ranged:
        health = 1;
        damage = 15;
        scoreValue = 200;
        moveSpeed = 40.0;
        detectionRadius = 250.0;
        attackRange = 100.0;
        break;
    }
  }

  /// Set patrol waypoints
  void setPatrolWaypoints(List<vm.Vector2> waypoints) {
    patrolWaypoints.clear();
    patrolWaypoints.addAll(waypoints);
    currentWaypointIndex = 0;
  }

  /// Reset enemy to initial state
  @override
  void reset() {
    super.reset();
    health = 1;
    damage = 10;
    scoreValue = 100;
    attackCooldown = 0.0;
    currentState = AIState.idle;
    animationTimer = 0.0;
    targetPlayer = null;
    currentWaypointIndex = 0;
  }
}

/// Types of enemies
enum EnemyType {
  basic,
  fast,
  tank,
  ranged,
}

/// AI states for enemy behavior
enum AIState {
  idle,
  patrol,
  chase,
  attack,
  flee,
}