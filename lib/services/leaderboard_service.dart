import 'dart:convert';
import 'package:http/http.dart' as http;

class LeaderboardService {
  final String _restUrl = "https://popular-oryx-36229.upstash.io";
  final String _restToken = "AY2FAAIncDE2NWRiMmJmNzMwMzQ0NDM3ODY3OTY1ZGYyZTM0ZmM5N3AxMzYyMjk";

  // In-memory cache for leaderboard data
  List<Map<String, dynamic>>? _cachedLeaderboard;
  DateTime? _cacheTimestamp;
  final Duration _cacheDuration = const Duration(seconds: 5);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_restToken',
        'Content-Type': 'application/json',
      };

  // Submit Score (ZADD)
  // Example command: `ZADD neon_runner_leaderboard <score> <playerId>:<name>`
  Future<bool> submitScore(String playerId, String name, int score) async {
    final response = await http.post(
      Uri.parse('$_restUrl/zadd/neon_runner_leaderboard/$score/$playerId:$name'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      // Invalidate cache on successful submission
      _cachedLeaderboard = null;
      _cacheTimestamp = null;
      return true;
    }

    return false;
  }

  // Load Top Scores (ZREVRANGE with WITHSCORES)
  // Example command: `ZREVRANGE neon_runner_leaderboard 0 <limit-1> WITHSCORES`
  Future<List<Map<String, dynamic>>> loadTopScores(int limit) async {
    // Check cache first
    if (_cachedLeaderboard != null && _cacheTimestamp != null && DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedLeaderboard!;
    }

    final response = await http.get(
      Uri.parse('$_restUrl/zrevrange/neon_runner_leaderboard/0/${limit - 1}/WITHSCORES'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> rawData = json.decode(response.body)['result'];
      final List<Map<String, dynamic>> leaderboard = [];
      for (int i = 0; i < rawData.length; i += 2) {
        final String playerEntry = rawData[i];
        final List<String> parts = playerEntry.split(':');
        final String playerId = parts[0];
        final String name = parts.length > 1 ? parts.sublist(1).join(':') : playerId; // Handle name with colons
        final int score = int.parse(rawData[i + 1]);
        leaderboard.add({
          'rank': (i / 2).toInt() + 1, // Rank is 1-based
          'playerId': playerId,
          'name': name,
          'score': score,
        });
      }
      _cachedLeaderboard = leaderboard;
      _cacheTimestamp = DateTime.now();
      return leaderboard;
    }

    return [];
  }

  // Get Rank (ZREVRANK)
  // Example command: `ZREVRANK neon_runner_leaderboard <playerId>:<name>`
  // Returns 0-based rank, or null if not found
  Future<int?> getRank(String playerId, String name) async {
    final response = await http.get(
      Uri.parse('$_restUrl/zrevrank/neon_runner_leaderboard/$playerId:$name'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final dynamic result = json.decode(response.body)['result'];
      if (result != null) {
        return result + 1; // Convert to 1-based rank
      }
    }

    return null;
  }
}
