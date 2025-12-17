class MockLeaderboardSystem {
  List<LeaderboardEntry> scores = [];
  List<int> submittedScores = [];

  Future<void> submitScore(String playerName, int score) async {
    scores.add(LeaderboardEntry(playerName: playerName, score: score));
    submittedScores.add(score);
    scores.sort((a, b) => b.score.compareTo(a.score));
    if (scores.length > 10) {
      scores = scores.take(10).toList();
    }
  }

  Future<List<LeaderboardEntry>> getTopScores() async {
    return scores;
  }
}

class LeaderboardEntry {
  final String playerName;
  final int score;

  LeaderboardEntry({required this.playerName, required this.score});
}