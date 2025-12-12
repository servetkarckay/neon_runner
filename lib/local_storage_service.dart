import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // User ID
  String getUserId() {
    String? userId = _prefs.getString('neon_userId');
    if (userId == null) {
      userId = const Uuid().v4();
      _prefs.setString('neon_userId', userId);
    }
    return userId;
  }

  // Highscore
  int getHighscore() {
    return _prefs.getInt('neon_runner_highscore') ?? 0;
  }

  Future<void> setHighscore(int score) async {
    await _prefs.setInt('neon_runner_highscore', score);
  }

  // Tutorial seen status
  bool getTutorialSeen() {
    return _prefs.getBool('neon_runner_tutorial_seen') ?? false;
  }

  Future<void> setTutorialSeen(bool seen) async {
    await _prefs.setBool('neon_runner_tutorial_seen', seen);
  }
}
