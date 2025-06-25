// lib/services/ultimate_tournament_service.dart - ULTIMATE TOURNAMENT ORCHESTRATOR
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

enum UltimateBotDifficulty { novice, skilled, expert, master, ultimate }

class UltimateBotPlayer {
  final String id;
  final String name;
  final UltimateBotDifficulty difficulty;

  UltimateBotPlayer({
    required this.id,
    required this.name,
    required this.difficulty,
  });
}

class UltimateTournamentService {
  static final _db = FirebaseFirestore.instance;
  static final _random = math.Random();

  // Bot names for Ultimate Tournament
  static const List<String> _ultimateBotNames = [
    'Ultimate Warrior', 'Champion Mind', 'Memory Master', 'Precision Pro',
    'Speed Demon', 'Maze Runner', 'Pattern King', 'Timing Lord',
    'Momentum God', 'Card Shark', 'Brain Storm', 'Focus Force',
    'Quick Strike', 'Mental Giant', 'Game Boss', 'Skill Lord',
    'Power Player', 'Mind Bender', 'Time Master', 'Space Ace',
    'Logic Legend', 'Rapid Fire', 'Sharp Shot', 'Fast Track',
    'Mental Muscle', 'Game Guru', 'Skill Sage', 'Power Pro',
    'Mind Mage', 'Time Titan', 'Space Ninja', 'Logic Lion',
    'Rapid Rex', 'Sharp Shark', 'Fast Fox', 'Mental Monster',
    'Game Ghost', 'Skill Spirit', 'Power Phantom', 'Mind Monk',
    'Time Tiger', 'Space Spider', 'Logic Lynx', 'Rapid Rabbit',
    'Sharp Snake', 'Fast Falcon', 'Mental Moose', 'Game Giraffe',
    'Skill Sloth', 'Power Panda', 'Mind Monkey', 'Time Turtle',
  ];

  /// Add bots to an Ultimate Tournament
  static Future<void> addBotsToTournament(String tourneyId, int count) async {
    try {
      final tourneyRef = _db.collection('ultimate_tournaments').doc(tourneyId);
      final snapshot = await tourneyRef.get();

      if (!snapshot.exists) {
        throw Exception('Tournament not found');
      }

      final data = snapshot.data()!;
      final currentBots = data['bots'] as Map<String, dynamic>? ?? {};
      final currentCount = data['playerCount'] as int? ?? 0;

      final Map<String, dynamic> newBots = Map.from(currentBots);

      for (int i = 0; i < count; i++) {
        final botId = 'bot_${DateTime.now().millisecondsSinceEpoch}_$i';
        final botName = _ultimateBotNames[_random.nextInt(_ultimateBotNames.length)];

        // Assign difficulty based on tournament position
        final difficulty = _assignUltimateBotDifficulty(currentCount + i + 1);

        newBots[botId] = {
          'name': botName,
          'difficulty': difficulty.name,
          'isBot': true,
        };
      }

      await tourneyRef.update({
        'bots': newBots,
        'playerCount': FieldValue.increment(count),
      });

      print('✨ Added $count ultimate bots to tournament $tourneyId');
    } catch (e) {
      print('❌ Error adding ultimate bots: $e');
      rethrow;
    }
  }

  /// Assign bot difficulty based on tournament progression
  static UltimateBotDifficulty _assignUltimateBotDifficulty(int playerPosition) {
    if (playerPosition <= 10) return UltimateBotDifficulty.ultimate;  // Top 10 are ultimate
    if (playerPosition <= 25) return UltimateBotDifficulty.master;    // Next 15 are masters
    if (playerPosition <= 45) return UltimateBotDifficulty.expert;    // Next 20 are experts
    if (playerPosition <= 60) return UltimateBotDifficulty.skilled;   // Next 15 are skilled
    return UltimateBotDifficulty.novice;                              // Last 4 are novices
  }

  /// Submit bot results for a specific game in the Ultimate Tournament
  static Future<void> submitBotResults(
      String tourneyId,
      String gameType,
      List<UltimateBotPlayer> bots,
      ) async {
    try {
      print('🎮 Submitting ${bots.length} bot results for $gameType in Ultimate Tournament $tourneyId');

      final batch = _db.batch();

      for (final bot in bots) {
        final result = _generateUltimateBotResult(gameType, bot.difficulty);

        final resultRef = _db
            .collection('ultimate_tournaments')
            .doc(tourneyId)
            .collection('game_results')
            .doc('${bot.id}_$gameType');

        batch.set(resultRef, {
          'playerId': bot.id,
          'gameType': gameType,
          'score': result['score'],
          'rank': result['rank'],
          'details': result['details'],
          'isBot': true,
          'botDifficulty': bot.difficulty.name,
          'submittedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ Ultimate bot results submitted for $gameType');
    } catch (e) {
      print('❌ Error submitting ultimate bot results: $e');
    }
  }

  /// Generate bot result based on game type and difficulty
  static Map<String, dynamic> _generateUltimateBotResult(
      String gameType,
      UltimateBotDifficulty difficulty,
      ) {
    final basePerformance = _getBasePerformance(difficulty);
    final variance = _getVariance(difficulty);

    switch (gameType) {
      case 'precision':
        return _generatePrecisionResult(basePerformance, variance);
      case 'momentum':
        return _generateMomentumResult(basePerformance, variance);
      case 'memory':
        return _generateMemoryResult(basePerformance, variance);
      case 'match':
        return _generateMatchResult(basePerformance, variance);
      case 'maze':
        return _generateMazeResult(basePerformance, variance);
      default:
        throw Exception('Unknown game type: $gameType');
    }
  }

  static double _getBasePerformance(UltimateBotDifficulty difficulty) {
    switch (difficulty) {
      case UltimateBotDifficulty.novice:
        return 0.3;  // 30% performance
      case UltimateBotDifficulty.skilled:
        return 0.5;  // 50% performance
      case UltimateBotDifficulty.expert:
        return 0.7;  // 70% performance
      case UltimateBotDifficulty.master:
        return 0.85; // 85% performance
      case UltimateBotDifficulty.ultimate:
        return 0.95; // 95% performance
    }
  }

  static double _getVariance(UltimateBotDifficulty difficulty) {
    switch (difficulty) {
      case UltimateBotDifficulty.novice:
        return 0.3;  // High variance
      case UltimateBotDifficulty.skilled:
        return 0.25; // Medium-high variance
      case UltimateBotDifficulty.expert:
        return 0.2;  // Medium variance
      case UltimateBotDifficulty.master:
        return 0.15; // Low variance
      case UltimateBotDifficulty.ultimate:
        return 0.1;  // Very low variance
    }
  }

  static Map<String, dynamic> _generatePrecisionResult(double base, double variance) {
    final performance = _clamp(base + (_random.nextDouble() - 0.5) * variance, 0.0, 1.0);
    final targetMs = 3000;
    final maxError = 2000; // 2 seconds max error
    final errorMs = (maxError * (1.0 - performance)).round();

    return {
      'score': math.max(0, 1000 - errorMs),
      'rank': _calculateRankFromPerformance(performance),
      'details': {
        'errorMs': errorMs,
        'targetMs': targetMs,
      },
    };
  }

  static Map<String, dynamic> _generateMomentumResult(double base, double variance) {
    final performance = _clamp(base + (_random.nextDouble() - 0.5) * variance, 0.0, 1.0);
    final baseScore = 5000; // Base score for 10 spins
    final score = (baseScore * performance).round();

    return {
      'score': score,
      'rank': _calculateRankFromPerformance(performance),
      'details': {
        'totalScore': score,
        'spins': 10,
      },
    };
  }

  static Map<String, dynamic> _generateMemoryResult(double base, double variance) {
    final performance = _clamp(base + (_random.nextDouble() - 0.5) * variance, 0.0, 1.0);
    final maxLevel = 15;
    final level = math.max(1, (maxLevel * performance).round());

    return {
      'score': level * 100,
      'rank': _calculateRankFromPerformance(performance),
      'details': {
        'level': level,
        'maxLevel': maxLevel,
      },
    };
  }

  static Map<String, dynamic> _generateMatchResult(double base, double variance) {
    final performance = _clamp(base + (_random.nextDouble() - 0.5) * variance, 0.0, 1.0);
    final baseTime = 30000; // 30 seconds base
    final timeMs = (baseTime * (2.0 - performance)).round(); // Lower time is better

    return {
      'score': math.max(1000, 60000 - timeMs), // Convert to score
      'rank': _calculateRankFromPerformance(performance),
      'details': {
        'completionTimeMs': timeMs,
        'penalties': 0,
      },
    };
  }

  static Map<String, dynamic> _generateMazeResult(double base, double variance) {
    final performance = _clamp(base + (_random.nextDouble() - 0.5) * variance, 0.0, 1.0);
    final completed = performance > 0.4; // 40% chance to complete
    final round = completed ? math.max(1, (6 * performance).round()) : 1;

    return {
      'score': completed ? round * 1000 : 0,
      'rank': _calculateRankFromPerformance(performance),
      'details': {
        'round': round,
        'completed': completed,
      },
    };
  }

  static int _calculateRankFromPerformance(double performance) {
    // Convert performance (0.0-1.0) to rank (1-64)
    final rank = ((1.0 - performance) * 63).round() + 1;
    return math.max(1, math.min(64, rank));
  }

  static double _clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  /// Calculate overall rankings across all games
  static Future<List<Map<String, dynamic>>> calculateOverallRankings(String tourneyId) async {
    try {
      print('🏆 Calculating overall Ultimate Tournament rankings for $tourneyId');

      final resultsSnapshot = await _db
          .collection('ultimate_tournaments')
          .doc(tourneyId)
          .collection('game_results')
          .get();

      // Group results by player
      final Map<String, Map<String, dynamic>> playerResults = {};

      for (final doc in resultsSnapshot.docs) {
        final data = doc.data();
        final playerId = data['playerId'] as String;
        final gameType = data['gameType'] as String;
        final score = data['score'] as int;
        final rank = data['rank'] as int;

        if (!playerResults.containsKey(playerId)) {
          playerResults[playerId] = {
            'playerId': playerId,
            'isBot': data['isBot'] ?? false,
            'games': <String, Map<String, dynamic>>{},
            'totalScore': 0,
            'averageRank': 0.0,
            'gamesCompleted': 0,
          };
        }

        playerResults[playerId]!['games'][gameType] = {
          'score': score,
          'rank': rank,
          'details': data['details'],
        };

        playerResults[playerId]!['totalScore'] += score;
        playerResults[playerId]!['gamesCompleted'] += 1;
      }

      // Calculate average ranks and sort
      final rankings = <Map<String, dynamic>>[];

      for (final playerData in playerResults.values) {
        final games = playerData['games'] as Map<String, dynamic>;
        double totalRank = 0;
        int gameCount = 0;

        for (final gameData in games.values) {
          totalRank += (gameData['rank'] as int);
          gameCount++;
        }

        playerData['averageRank'] = gameCount > 0 ? totalRank / gameCount : 64.0;
        rankings.add(playerData);
      }

      // Sort by total score (descending), then by average rank (ascending)
      rankings.sort((a, b) {
        final scoreComparison = (b['totalScore'] as int).compareTo(a['totalScore'] as int);
        if (scoreComparison != 0) return scoreComparison;

        return (a['averageRank'] as double).compareTo(b['averageRank'] as double);
      });

      print('✅ Calculated ${rankings.length} player rankings');
      return rankings;
    } catch (e) {
      print('❌ Error calculating overall rankings: $e');
      return [];
    }
  }

  /// Advance tournament to next game
  static Future<void> advanceToNextGame(String tourneyId) async {
    try {
      await _db.collection('ultimate_tournaments').doc(tourneyId).update({
        'currentGameIndex': FieldValue.increment(1),
      });
    } catch (e) {
      print('❌ Error advancing to next game: $e');
    }
  }

  /// Complete the tournament with a champion
  static Future<void> completeTournament(String tourneyId, String championId) async {
    try {
      await _db.collection('ultimate_tournaments').doc(tourneyId).update({
        'status': 'completed',
        'championId': championId,
        'completedAt': FieldValue.serverTimestamp(),
      });

      print('🏆 Ultimate Tournament $tourneyId completed with champion $championId');
    } catch (e) {
      print('❌ Error completing tournament: $e');
    }
  }
}