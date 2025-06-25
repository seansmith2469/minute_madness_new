// lib/services/ultimate_tournament_service.dart - SERVICE FOR ULTIMATE TOURNAMENTS
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

enum UltimateBotDifficulty {
  casual,     // 30-70% performance
  skilled,    // 50-85% performance
  expert,     // 70-95% performance
  champion    // 85-98% performance
}

class UltimateBotPlayer {
  final String id;
  final String name;
  final UltimateBotDifficulty difficulty;

  UltimateBotPlayer({
    required this.id,
    required this.name,
    required this.difficulty,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'difficulty': difficulty.name,
      'isBot': true,
    };
  }
}

class UltimateTournamentService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final List<String> _botNames = [
    // Precision bots
    'TimeMaster', 'PerfectPulse', 'ChronoSniper', 'TickTock', 'PrecisionPro',

    // Momentum bots
    'SpinCycle', 'MomentumKing', 'WheelWarrior', 'SpeedDemon', 'RotationRex',

    // Memory bots
    'BrainBox', 'MemoryMaster', 'PatternPro', 'RecallRocket', 'MindMeld',

    // Match bots
    'CardCrafter', 'MatchMaker', 'TarotTitan', 'PairPerfect', 'FlipFlash',

    // Maze bots
    'MazeRunner', 'PathFinder', 'LabyLord', 'RouteRanger', 'WallWalker',

    // Ultimate champions
    'UltimateAce', 'GrandMaster', 'ChampionX', 'PerfectPlayer', 'EliteBot',
    'MegaMind', 'SuperStar', 'ProGamer', 'WinWizard', 'VictoryViper',
    'TopTier', 'AlphaBot', 'MaxPower', 'UltraBot', 'PrimePlayer',
    'SkillSage', 'GameGod', 'WinBot', 'ProBot', 'ChampBot',
  ];

  /// Add bots to an ultimate tournament
  static Future<List<UltimateBotPlayer>> addBotsToTournament(String tourneyId, int count) async {
    try {
      print('🏆 Adding $count ultimate bots to tournament $tourneyId');

      final random = math.Random();
      final newBots = <UltimateBotPlayer>[];
      final botsToAdd = <String, dynamic>{};

      for (int i = 0; i < count; i++) {
        final botId = 'ultimate_bot_${DateTime.now().millisecondsSinceEpoch}_$i';
        final name = _botNames[random.nextInt(_botNames.length)];

        // Weighted difficulty distribution for ultimate tournament
        final difficultyRoll = random.nextDouble();
        UltimateBotDifficulty difficulty;

        if (difficultyRoll < 0.15) {
          difficulty = UltimateBotDifficulty.champion; // 15% champions
        } else if (difficultyRoll < 0.35) {
          difficulty = UltimateBotDifficulty.expert; // 20% experts
        } else if (difficultyRoll < 0.70) {
          difficulty = UltimateBotDifficulty.skilled; // 35% skilled
        } else {
          difficulty = UltimateBotDifficulty.casual; // 30% casual
        }

        final bot = UltimateBotPlayer(
          id: botId,
          name: name,
          difficulty: difficulty,
        );

        newBots.add(bot);
        botsToAdd[botId] = bot.toFirestore();
      }

      // Add bots to Firestore
      await _db.collection('ultimate_tournaments').doc(tourneyId).update({
        'playerCount': FieldValue.increment(count),
        'players': FieldValue.arrayUnion(newBots.map((b) => b.id).toList()),
        'bots': botsToAdd,
      });

      print('🏆 Successfully added ${newBots.length} ultimate bots');
      return newBots;

    } catch (e) {
      print('🏆 Error adding ultimate bots: $e');
      rethrow;
    }
  }

  /// Submit bot results for a specific game in the ultimate tournament
  static Future<void> submitBotResults(
      String tourneyId,
      String gameType,
      List<UltimateBotPlayer> bots,
      ) async {
    try {
      print('🏆 Submitting ultimate bot results for $gameType in $tourneyId');

      final batch = _db.batch();
      final random = math.Random();

      for (final bot in bots) {
        final result = _generateGameResult(gameType, bot.difficulty, random);

        final resultDoc = _db
            .collection('ultimate_tournaments')
            .doc(tourneyId)
            .collection('game_results')
            .doc('${bot.id}_$gameType');

        batch.set(resultDoc, {
          'playerId': bot.id,
          'gameType': gameType,
          'score': result['score'],
          'rank': result['rank'],
          'details': result['details'],
          'isBot': true,
          'submittedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('🏆 Ultimate bot results submitted for $gameType');

    } catch (e) {
      print('🏆 Error submitting ultimate bot results: $e');
    }
  }

  /// Generate game-specific results based on bot difficulty
  static Map<String, dynamic> _generateGameResult(
      String gameType,
      UltimateBotDifficulty difficulty,
      math.Random random,
      ) {
    // Performance ranges based on difficulty
    final (minPerf, maxPerf) = switch (difficulty) {
      UltimateBotDifficulty.casual => (0.3, 0.7),
      UltimateBotDifficulty.skilled => (0.5, 0.85),
      UltimateBotDifficulty.expert => (0.7, 0.95),
      UltimateBotDifficulty.champion => (0.85, 0.98),
    };

    final performance = minPerf + (random.nextDouble() * (maxPerf - minPerf));

    switch (gameType) {
      case 'precision':
        return _generatePrecisionResult(performance, random);
      case 'momentum':
        return _generateMomentumResult(performance, random);
      case 'memory':
        return _generateMemoryResult(performance, random);
      case 'match':
        return _generateMatchResult(performance, random);
      case 'maze':
        return _generateMazeResult(performance, random);
      default:
        throw ArgumentError('Unknown game type: $gameType');
    }
  }

  static Map<String, dynamic> _generatePrecisionResult(double performance, math.Random random) {
    // Target is 3000ms, perfect score is 0 error
    final maxError = 2000; // 2 second max error
    final errorMs = ((1.0 - performance) * maxError).round();
    final actualError = random.nextBool() ? errorMs : -errorMs; // Can be early or late

    return {
      'score': errorMs, // Lower is better
      'rank': (performance * 1000).round(),
      'details': {
        'errorMs': actualError,
        'targetMs': 3000,
      },
    };
  }

  static Map<String, dynamic> _generateMomentumResult(double performance, math.Random random) {
    // 10 spins, max 1000 points per spin
    final maxScore = 10000;
    final score = (performance * maxScore).round();

    // Generate individual spin scores
    final spinScores = <int>[];
    var remaining = score;

    for (int i = 0; i < 10; i++) {
      if (i == 9) {
        spinScores.add(remaining); // Last spin gets remainder
      } else {
        final spinScore = math.min(1000, (remaining / (10 - i) * (0.8 + random.nextDouble() * 0.4)).round());
        spinScores.add(spinScore);
        remaining -= spinScore;
      }
    }

    return {
      'score': score,
      'rank': score,
      'details': {
        'totalScore': score,
        'spinScores': spinScores,
        'maxSpeed': 1.0 + (performance * 4.0), // 1x to 5x speed
      },
    };
  }

  static Map<String, dynamic> _generateMemoryResult(double performance, math.Random random) {
    // Level achieved (1-20+)
    final maxLevel = 15;
    final level = math.max(1, (performance * maxLevel).round());

    // Time bonus based on performance
    final timeMs = (5000 + random.nextInt(10000)).round(); // 5-15 seconds per level average

    return {
      'score': level,
      'rank': level * 1000 - timeMs, // Higher level is better, lower time is better
      'details': {
        'level': level,
        'completionTimeMs': timeMs,
      },
    };
  }

  static Map<String, dynamic> _generateMatchResult(double performance, math.Random random) {
    // Time to complete match game (lower is better)
    final minTime = 10000; // 10 seconds for perfect
    final maxTime = 120000; // 2 minutes for poor
    final timeRange = maxTime - minTime;
    final completionTime = minTime + ((1.0 - performance) * timeRange).round();

    // Penalty seconds for wrong matches
    final maxPenalties = 20;
    final penalties = ((1.0 - performance) * maxPenalties).round();

    return {
      'score': completionTime,
      'rank': 200000 - completionTime, // Lower time is better
      'details': {
        'completionTimeMs': completionTime,
        'penaltySeconds': penalties,
      },
    };
  }

  static Map<String, dynamic> _generateMazeResult(double performance, math.Random random) {
    // Round completed (1-6), with completion status
    final maxRound = 6;
    final round = math.max(1, (performance * maxRound).round());
    final completed = performance > 0.7 ? random.nextBool() : false;

    // Time and wrong moves
    final baseTime = round * 15000; // 15 seconds per round base
    final timeVariation = random.nextInt(10000); // +/- 10 seconds
    final completionTime = baseTime + timeVariation;

    final maxWrongMoves = 10;
    final wrongMoves = ((1.0 - performance) * maxWrongMoves).round();

    return {
      'score': round,
      'rank': round * 10000 + (completed ? 5000 : 0) - completionTime ~/ 100,
      'details': {
        'round': round,
        'completed': completed,
        'completionTimeMs': completionTime,
        'wrongMoves': wrongMoves,
      },
    };
  }

  /// Calculate overall tournament rankings across all games
  static Future<List<Map<String, dynamic>>> calculateOverallRankings(String tourneyId) async {
    try {
      print('🏆 Calculating overall rankings for $tourneyId');

      // Get all game results
      final resultsSnapshot = await _db
          .collection('ultimate_tournaments')
          .doc(tourneyId)
          .collection('game_results')
          .get();

      // Group results by player
      final Map<String, Map<String, dynamic>> playerScores = {};

      for (final doc in resultsSnapshot.docs) {
        final data = doc.data();
        final playerId = data['playerId'] as String;
        final gameType = data['gameType'] as String;
        final score = data['score'] as int;
        final rank = data['rank'] as int;

        playerScores.putIfAbsent(playerId, () => {
          'playerId': playerId,
          'gameScores': <String, int>{},
          'gameRanks': <String, int>{},
          'totalScore': 0,
          'averageRank': 0.0,
          'gamesPlayed': 0,
        });

        playerScores[playerId]!['gameScores'][gameType] = score;
        playerScores[playerId]!['gameRanks'][gameType] = rank;
        playerScores[playerId]!['gamesPlayed'] = (playerScores[playerId]!['gamesPlayed'] as int) + 1;
      }

      // Calculate overall scores (sum of ranks across all games)
      final rankings = <Map<String, dynamic>>[];

      for (final playerData in playerScores.values) {
        final gameRanks = playerData['gameRanks'] as Map<String, int>;
        final totalRank = gameRanks.values.fold<int>(0, (sum, rank) => sum + rank);
        final gamesPlayed = playerData['gamesPlayed'] as int;

        if (gamesPlayed == 5) { // Only include players who completed all games
          rankings.add({
            ...playerData,
            'totalScore': totalRank,
            'averageRank': totalRank / gamesPlayed,
          });
        }
      }

      // Sort by total rank (higher is better)
      rankings.sort((a, b) => (b['totalScore'] as int).compareTo(a['totalScore'] as int));

      print('🏆 Calculated rankings for ${rankings.length} players');
      return rankings;

    } catch (e) {
      print('🏆 Error calculating overall rankings: $e');
      return [];
    }
  }

  /// Get tournament status and progress
  static Future<Map<String, dynamic>?> getTournamentStatus(String tourneyId) async {
    try {
      final doc = await _db.collection('ultimate_tournaments').doc(tourneyId).get();
      return doc.data();
    } catch (e) {
      print('🏆 Error getting tournament status: $e');
      return null;
    }
  }

  /// Update tournament to next game
  static Future<void> advanceToNextGame(String tourneyId) async {
    try {
      await _db.collection('ultimate_tournaments').doc(tourneyId).update({
        'currentGameIndex': FieldValue.increment(1),
        'lastGameCompletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🏆 Error advancing to next game: $e');
    }
  }

  /// Complete the tournament
  static Future<void> completeTournament(String tourneyId, String winnerId) async {
    try {
      await _db.collection('ultimate_tournaments').doc(tourneyId).update({
        'status': 'completed',
        'winnerId': winnerId,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🏆 Error completing tournament: $e');
    }
  }
}