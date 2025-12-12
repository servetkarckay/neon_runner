enum GameState {
  menu,
  playing,
  paused,
  gameOver,
  leaderboardView,
  settings,
}

enum InputAction {
  jump,
  duck,
  pause,
  start,
}

enum ObstacleType {
  ground,
  aerial,
  movingAerial,
  platform,
  movingPlatform,
  spike,
  hazardZone,
  fallingDrop,
  rotatingLaser,
  laserGrid,
  slantedSurface,
}

enum PowerUpType {
  shield,
  multiplier,
  timeWarp,
  magnet,
}
