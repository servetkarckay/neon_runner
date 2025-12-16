import 'package:flame/components.dart' hide Vector2;
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Base component class for all game objects
abstract class GameComponent extends Component {
  /// Position of the component in game world
  vm.Vector2 position = vm.Vector2.zero();

  /// Size of the component
  vm.Vector2 size = vm.Vector2.zero();

  /// Velocity for moving components
  vm.Vector2 velocity = vm.Vector2.zero();

  /// Current hitbox for collision detection
  Rect? currentHitbox;

  /// Whether this component is active
  bool isActive = true;

  /// Component type identifier
  String get componentType;

  GameComponent() {
    position = vm.Vector2.zero();
    size = vm.Vector2.zero();
    velocity = vm.Vector2.zero();
  }

  /// Update component logic
  @override
  void update(double dt) {
    super.update(dt);
    if (isActive) {
      position.add(velocity * dt);
    }
  }

  /// Get the bounding rectangle for this component
  Rect getBounds() {
    return Rect.fromLTWH(
      position.x,
      position.y,
      size.x,
      size.y,
    );
  }

  /// Check if this component overlaps with another
  bool overlaps(GameComponent other) {
    return getBounds().overlaps(other.getBounds());
  }

  /// Set the component's active state
  void setActive(bool active) {
    isActive = active;
  }

  /// Reset component to initial state
  void reset() {
    position.setValues(0, 0);
    velocity.setValues(0, 0);
    currentHitbox = null;
    isActive = true;
  }
}