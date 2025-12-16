import 'package:flutter_neon_runner/audio/audio_controller.dart';
import 'package:flutter_neon_runner/game/events/game_events.dart';
import 'package:flutter_neon_runner/game/systems/base_game_system.dart';
import 'package:flame_audio/flame_audio.dart';

/// System managing all audio playback and music
class AudioSystem extends EventHandlerSystem implements PausableSystem {
  late AudioController _audioController;
  bool _isPaused = false;
  bool _isMuted = false;

  @override
  String get systemName => 'AudioSystem';

  // Getters
  bool get isMuted => _isMuted;

  @override
  Future<void> initialize() async {
    _audioController = AudioController();
    await _audioController.init();

    // Subscribe to audio events
    GameEventBus.instance.subscribe<AudioPlayEvent>(_handleAudioPlayEvent);
    GameEventBus.instance.subscribe<AudioMusicControlEvent>(_handleMusicControlEvent);

    // Subscribe to game state events
    GameEventBus.instance.subscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.subscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.subscribe<GamePausedEvent>(_handleGamePaused);
    GameEventBus.instance.subscribe<GameResumedEvent>(_handleGameResumed);
  }

  @override
  void update(double dt) {
    // Audio system doesn't need per-frame updates
    // AudioController handles its own updates
  }

  @override
  void handleEvent(GameEvent event) {
    // Events are handled via subscriptions
  }

  @override
  List<Type> get handledEventTypes => [
    AudioPlayEvent,
    AudioMusicControlEvent,
    GameStartedEvent,
    GameOverEvent,
    GamePausedEvent,
    GameResumedEvent,
  ];

  @override
  void onPause() {
    _isPaused = true;
    _audioController.stopMusic();
  }

  @override
  void onResume() {
    _isPaused = false;
    if (!_isMuted) {
      _audioController.startMusic();
    }
  }

  @override
  bool get isPaused => _isPaused;

  // Public methods
  void toggleMute(bool? muteState) {
    if (muteState != null) {
      _isMuted = muteState;
    } else {
      _isMuted = !_isMuted;
    }

    _audioController.toggleMute(_isMuted);
  }

  void playSound(String soundType) {
    switch (soundType.toLowerCase()) {
      case 'jump':
        _audioController.playJump();
        break;
      case 'duck':
        _audioController.playDuck();
        break;
      case 'crash':
        _audioController.playCrash();
        break;
      case 'powerup':
        _audioController.playPowerUp();
        break;
      case 'shield_break':
        _audioController.playShieldBreak();
        break;
      case 'score':
        _audioController.playScore();
        break;
      case 'time_warp':
        _audioController.playTimeWarp();
        break;
      default:
        // Try to play as generic sfx
        FlameAudio.play('sfx/$soundType.mp3');
        break;
    }
  }

  void startMusic() {
    if (!_isMuted && !_isPaused) {
      _audioController.startMusic();
    }
  }

  void stopMusic() {
    _audioController.stopMusic();
  }

  void pauseMusic() {
    _audioController.stopMusic();
  }

  void resumeMusic() {
    if (!_isMuted && !_isPaused) {
      _audioController.startMusic();
    }
  }

  // Mobile-optimized audio methods
  void preloadSounds() {
    // Preload critical sounds for mobile performance
    final criticalSounds = [
      'jump',
      'crash',
      'powerup',
      'shield_break',
    ];

    for (final sound in criticalSounds) {
      FlameAudio.audioCache.load('sfx/$sound.mp3');
    }
  }

  void setMusicVolume(double volume) {
    FlameAudio.bgm.audioPlayer.setVolume(volume);
  }

  // Event handlers
  void _handleAudioPlayEvent(AudioPlayEvent event) {
    playSound(event.soundType);
  }

  void _handleMusicControlEvent(AudioMusicControlEvent event) {
    if (event.play) {
      startMusic();
    } else {
      stopMusic();
    }
  }

  void _handleGameStarted(GameStartedEvent event) {
    startMusic();
    preloadSounds();
  }

  void _handleGameOver(GameOverEvent event) {
    stopMusic();
    playSound('crash');
  }

  void _handleGamePaused(GamePausedEvent event) {
    pauseMusic();
  }

  void _handleGameResumed(GameResumedEvent event) {
    resumeMusic();
  }

  @override
  void dispose() {
    stopMusic();
    _audioController.dispose();

    GameEventBus.instance.unsubscribe<AudioPlayEvent>(_handleAudioPlayEvent);
    GameEventBus.instance.unsubscribe<AudioMusicControlEvent>(_handleMusicControlEvent);
    GameEventBus.instance.unsubscribe<GameStartedEvent>(_handleGameStarted);
    GameEventBus.instance.unsubscribe<GameOverEvent>(_handleGameOver);
    GameEventBus.instance.unsubscribe<GamePausedEvent>(_handleGamePaused);
    GameEventBus.instance.unsubscribe<GameResumedEvent>(_handleGameResumed);
  }
}