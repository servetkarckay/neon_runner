import 'package:flame_audio/flame_audio.dart';

class AudioController {
  static final AudioController _instance = AudioController._internal();

  factory AudioController() {
    return _instance;
  }

  AudioController._internal();

  bool _muted = false;

  Future<void> init() async {
    FlameAudio.bgm.initialize();
    await FlameAudio.audioCache.loadAll([
      'sfx/jump.mp3',
      'sfx/duck.mp3',
      'sfx/crash.mp3',
      'sfx/score.mp3',
      'sfx/powerup.mp3',
      'sfx/shield_break.mp3',
      'sfx/time_warp.mp3',
    ]);
  }

  void startMusic() {
    if (!_muted) {
      FlameAudio.bgm.play('music/background_music.mp3', volume: 0.5);
    }
  }

  void stopMusic() {
    FlameAudio.bgm.stop();
  }

  void playJump() {
    if (!_muted) {
      FlameAudio.play('sfx/jump.mp3');
    }
  }

  void playDuck() {
    if (!_muted) {
      FlameAudio.play('sfx/duck.mp3');
    }
  }

  void playCrash() {
    if (!_muted) {
      FlameAudio.play('sfx/crash.mp3', volume: 0.7);
    }
  }

  void playScore() {
    if (!_muted) {
      FlameAudio.play('sfx/score.mp3', volume: 0.5);
    }
  }

  void playPowerUp() {
    if (!_muted) {
      FlameAudio.play('sfx/powerup.mp3');
    }
  }

  void playShieldBreak() {
    if (!_muted) {
      FlameAudio.play('sfx/shield_break.mp3');
    }
  }

  void playTimeWarp() {
    if (!_muted) {
      FlameAudio.play('sfx/time_warp.mp3');
    }
  }

  void toggleMute(bool mute) {
    _muted = mute;
    if (_muted) {
      FlameAudio.bgm.pause();
    } else {
      FlameAudio.bgm.resume();
    }
  }

  bool get isMuted => _muted;

  void dispose() {
    FlameAudio.bgm.dispose();
  }
}