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

  // Player name
  String getPlayerName() {
    return _prefs.getString('neon_runner_player_name') ?? 'Player';
  }

  Future<void> setPlayerName(String name) async {
    await _prefs.setString('neon_runner_player_name', name);
  }

  // Score caching methods
  Future<void> setCachedScore(String key, int value) async {
    await _prefs.setInt('score_cache_$key', value);
  }

  Future<int?> getCachedScore(String key) async {
    return _prefs.getInt('score_cache_$key');
  }

  // Leaderboard cache methods
  Future<void> setLeaderboardCache(String key, List<Map<String, dynamic>> data) async {
    final json = data.map((e) => e.toString()).join('|');
    await _prefs.setString('leaderboard_cache_$key', json);
  }

  Future<List<Map<String, dynamic>>> getLeaderboardCache(String key) async {
    final json = _prefs.getString('leaderboard_cache_$key');
    if (json == null) return [];

    try {
      final parts = json.split('|');
      return parts.map((e) => {'data': e}).toList();
    } catch (e) {
      return [];
    }
  }

  // Leaderboard entry-specific cache methods
  Future<void> setLeaderboardEntryCache(String key, List<String> entries) async {
    await _prefs.setString('leaderboard_entries_$key', entries.join('|'));
  }

  Future<List<String>> getLeaderboardEntryCache(String key) async {
    final json = _prefs.getString('leaderboard_entries_$key');
    if (json == null) return [];
    return json.split('|');
  }
}
