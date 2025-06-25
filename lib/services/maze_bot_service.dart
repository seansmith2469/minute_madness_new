// lib/services/maze_bot_service.dart - FIXED MAZE MADNESS BOT SERVICE
import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MazeBotDifficulty {
  novice,    // 20% success rate per round
  explorer,  // 35% success rate per round
  navigator, // 50% success rate per round
  pathfinder, // 65% success rate per round
  mazemaster, // 80% success rate per round
}

class MazeBotPlayer {
  final String id;
  final String name;
  final MazeBotDifficulty difficulty;

  MazeBotPlayer({
    required this.id,
    required this.name,
    required this.difficulty,
  });

  // Convert to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'difficulty': difficulty.name,
      'isBot': true,
    };
  }
}

class MazeBotService {
  static final _random = math.Random();
  static final _db = FirebaseFirestore.instance;

  // Generate realistic bot names
  static final List<String> _botNames = [
    'MindMapper', 'PathSeeker', 'MazeRunner', 'MemoryVault', 'RouteExplorer',
    'NavigatorX', 'MazeWalker', 'PathMaster', 'ExplorerBot', 'RouteGenie',
    'MazeGuide', 'PathFinder', 'MemoryBank', 'RouteWiz', 'MazeProbe',
    'NavigatorAI', 'PathTracer', 'MazeScout', 'RouteHunter', 'MemoryCore',
    'MazeWhiz', 'PathSage', 'NavigatorPro', 'RouteBot', 'MazeGenius',
    'PathWarden', 'MazeSharp', 'RouteKing', 'NavigatorElite', 'PathLord',
    'MazePhantom', 'RouteDemon', 'PathGhost', 'MazeTitan', 'RouteGod',
    'PathSpectre', 'MazeWizard', 'RouteSorcerer', 'PathMage', 'MazeOracle',
    'RouteProphet', 'PathSeer', 'MazeVision', 'RouteMyth', 'PathLegend',
    'MazeEternal', 'RouteInfinity', 'PathCosmic', 'MazeQuantum', 'RoutePulse'
  ];

  // FIXED: Create and add bots to fill remaining slots only
  static Future<List<MazeBotPlayer>> addBotsToSurvival(String survivalId, int botCount) async {
    final bots = <MazeBotPlayer>[];

    try {
      print('🧩 Adding $botCount maze bots to survival $survivalId');

      // Get existing survival data to avoid name collisions
      final survivalDoc = await _db.collection('maze_survival').doc(survivalId).get();
      final usedNames = <String>{};

      if (survivalDoc.exists) {
        final data = survivalDoc.data();
        final existingBots = data?['bots'] as Map<String, dynamic>? ?? {};
        for (final botData in existingBots.values) {
          if (botData is Map<String, dynamic>) {
            final name = botData['name'] as String?;
            if (name != null) usedNames.add(name);
          }
        }
      }

      final batch = _db.batch();
      final survivalRef = _db.collection('maze_survival').doc(survivalId);

      for (int i = 0; i < botCount; i++) {
        final bot = _generateBot(usedNames);
        bots.add(bot);
        usedNames.add(bot.name);

        // Add bot to survival using batch update
        batch.update(survivalRef, {
          'players': FieldValue.arrayUnion([bot.id]),
          'playerCount': FieldValue.increment(1),
          'bots.${bot.id}': bot.toMap(),
        });
      }

      await batch.commit();
      print('🧩 Successfully added ${bots.length} maze bots to survival $survivalId');
      return bots;

    } catch (e) {
      print('🧩 Error adding maze bots: $e');
      return [];
    }
  }

  // Generate a single bot with realistic difficulty distribution and unique name
  static MazeBotPlayer _generateBot(Set<String> usedNames) {
    final botId = 'maze_bot_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';

    // Ensure unique name
    String botName;
    int attempts = 0;
    do {
      botName = _botNames[_random.nextInt(_botNames.length)];
      if (usedNames.contains(botName)) {
        botName = '${botName}_${_random.nextInt(9999).toString().padLeft(4, '0')}';
      }
      attempts++;
    } while (usedNames.contains(botName) && attempts < 100);

    // Realistic difficulty distribution - most bots are average
    final difficultyRoll = _random.nextDouble();
    MazeBotDifficulty difficulty;

    if (difficultyRoll < 0.05) {
      difficulty = MazeBotDifficulty.mazemaster; // 5% - very skilled
    } else if (difficultyRoll < 0.2) {
      difficulty = MazeBotDifficulty.pathfinder; // 15% - skilled
    } else if (difficultyRoll < 0.5) {
      difficulty = MazeBotDifficulty.navigator; // 30% - average
    } else if (difficultyRoll < 0.8) {
      difficulty = MazeBotDifficulty.explorer; // 30% - below average
    } else {
      difficulty = MazeBotDifficulty.novice; // 20% - poor
    }

    return MazeBotPlayer(
      id: botId,
      name: botName,
      difficulty: difficulty,
    );
  }

  // FIXED: Submit bot results for a round with proper round tracking
  static Future<void> submitBotResults(String survivalId, int round, List<MazeBotPlayer> bots) async {
    if (bots.isEmpty) return;

    try {
      print('🧩 Submitting maze results for ${bots.length} bots in round $round');

      // Submit bot results in batches with staggered timing for realism
      final futures = <Future>[];

      for (int i = 0; i < bots.length; i++) {
        final bot = bots[i];

        // Staggered delays (0-10 seconds) to simulate realistic submission timing
        final delay = i * 100 + _random.nextInt(3000);

        final future = Future.delayed(Duration(milliseconds: delay), () async {
          try {
            // Check if this bot already submitted for THIS ROUND
            final resultId = '${bot.id}_round_$round';
            final existingDoc = await _db
                .collection('maze_survival')
                .doc(survivalId)
                .collection('results')
                .doc(resultId)
                .get();

            if (existingDoc.exists) {
              print('🧩 Maze bot ${bot.name} already submitted for round $round - skipping');
              return;
            }

            // Generate bot performance
            final result = _simulateMazePerformance(bot, round);

            // Submit bot result
            await _db
                .collection('maze_survival')
                .doc(survivalId)
                .collection('results')
                .doc(resultId)
                .set({
              'uid': bot.id,
              'completed': result['completed'],
              'completionTimeMs': result['completionTimeMs'],
              'wrongMoves': result['wrongMoves'],
              'round': round,
              'isBot': true,
              'botDifficulty': bot.difficulty.name,
              'submittedAt': FieldValue.serverTimestamp(),
            });

            final status = result['completed'] ? 'completed' : 'failed';
            print('🧩 Maze bot ${bot.name} (${bot.difficulty.name}) $status round $round '
                'in ${result['completionTimeMs']}ms with ${result['wrongMoves']} wrong moves');

          } catch (e) {
            print('🧩 Error submitting maze bot result for ${bot.name}: $e');
          }
        });

        futures.add(future);
      }

      // Wait for all bot submissions to complete (with timeout)
      await Future.wait(futures).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('🧩 Bot result submission timeout after 30 seconds');
          return [];
        },
      );

      print('🧩 All bot results submitted for round $round');

    } catch (e) {
      print('🧩 Error in maze submitBotResults: $e');
    }
  }

  // Simulate realistic maze performance based on bot difficulty and round
  static Map<String, dynamic> _simulateMazePerformance(MazeBotPlayer bot, int round) {
    // Success rates decrease each round as mazes get harder
    final baseSuccessRate = _getBaseSuccessRate(bot.difficulty);
    final roundPenalty = (round - 1) * 0.1; // 10% penalty per round
    final successRate = math.max(0.05, baseSuccessRate - roundPenalty); // Minimum 5% chance

    final completed = _random.nextDouble() < successRate;

    if (completed) {
      // Generate realistic completion time and wrong moves for successful runs
      return _generateSuccessfulResult(bot, round);
    } else {
      // Generate failure result
      return _generateFailureResult(bot, round);
    }
  }

  static double _getBaseSuccessRate(MazeBotDifficulty difficulty) {
    switch (difficulty) {
      case MazeBotDifficulty.novice:
        return 0.2; // 20%
      case MazeBotDifficulty.explorer:
        return 0.35; // 35%
      case MazeBotDifficulty.navigator:
        return 0.5; // 50%
      case MazeBotDifficulty.pathfinder:
        return 0.65; // 65%
      case MazeBotDifficulty.mazemaster:
        return 0.8; // 80%
    }
  }

  static Map<String, dynamic> _generateSuccessfulResult(MazeBotPlayer bot, int round) {
    // Base time increases with round difficulty
    int baseTime = 5000 + (round * 2000); // Start at 5s, +2s per round

    // Skill affects completion time and accuracy
    double skillMultiplier;
    int maxWrongMoves;

    switch (bot.difficulty) {
      case MazeBotDifficulty.mazemaster:
        skillMultiplier = 0.7; // 30% faster
        maxWrongMoves = 0;
        break;
      case MazeBotDifficulty.pathfinder:
        skillMultiplier = 0.8; // 20% faster
        maxWrongMoves = 1;
        break;
      case MazeBotDifficulty.navigator:
        skillMultiplier = 1.0; // Average speed
        maxWrongMoves = 2;
        break;
      case MazeBotDifficulty.explorer:
        skillMultiplier = 1.2; // 20% slower
        maxWrongMoves = 3;
        break;
      case MazeBotDifficulty.novice:
        skillMultiplier = 1.5; // 50% slower
        maxWrongMoves = 5;
        break;
    }

    // Add random variation (±30%)
    final timeVariation = 0.7 + (_random.nextDouble() * 0.6);
    final completionTime = (baseTime * skillMultiplier * timeVariation).round();

    // Generate wrong moves based on skill
    final wrongMoves = _random.nextInt(maxWrongMoves + 1);

    return {
      'completed': true,
      'completionTimeMs': completionTime,
      'wrongMoves': wrongMoves,
    };
  }

  static Map<String, dynamic> _generateFailureResult(MazeBotPlayer bot, int round) {
    // Failed attempts - time represents how long they lasted before failing
    int baseTime = 3000 + (round * 1000); // Shorter time for failures

    // Skill affects how long they last before failing
    double skillMultiplier;
    int minWrongMoves;

    switch (bot.difficulty) {
      case MazeBotDifficulty.mazemaster:
        skillMultiplier = 1.2; // Last longer before failing
        minWrongMoves = 2;
        break;
      case MazeBotDifficulty.pathfinder:
        skillMultiplier = 1.1;
        minWrongMoves = 3;
        break;
      case MazeBotDifficulty.navigator:
        skillMultiplier = 1.0;
        minWrongMoves = 4;
        break;
      case MazeBotDifficulty.explorer:
        skillMultiplier = 0.9;
        minWrongMoves = 5;
        break;
      case MazeBotDifficulty.novice:
        skillMultiplier = 0.7; // Fail quickly
        minWrongMoves = 6;
        break;
    }

    // Add random variation
    final timeVariation = 0.5 + (_random.nextDouble() * 1.0);
    final failureTime = (baseTime * skillMultiplier * timeVariation).round();

    // More wrong moves for failures
    final wrongMoves = minWrongMoves + _random.nextInt(5);

    return {
      'completed': false,
      'completionTimeMs': failureTime,
      'wrongMoves': wrongMoves,
    };
  }

  // Get bots for a specific survival
  static Future<List<MazeBotPlayer>> getBotsForSurvival(String survivalId) async {
    try {
      final survivalDoc = await _db.collection('maze_survival').doc(survivalId).get();

      if (!survivalDoc.exists) return [];

      final data = survivalDoc.data();
      if (data == null || !data.containsKey('bots')) return [];

      final botsData = data['bots'] as Map<String, dynamic>;
      final bots = <MazeBotPlayer>[];

      for (final entry in botsData.entries) {
        final botData = entry.value as Map<String, dynamic>;
        final difficulty = MazeBotDifficulty.values.firstWhere(
              (d) => d.name == botData['difficulty'],
          orElse: () => MazeBotDifficulty.navigator,
        );

        bots.add(MazeBotPlayer(
          id: entry.key,
          name: botData['name'],
          difficulty: difficulty,
        ));
      }

      return bots;
    } catch (e) {
      print('🧩 Error getting maze bots: $e');
      return [];
    }
  }

  // FIXED: Update bots for next round (remove eliminated bots)
  static Future<void> updateBotsForNextRound(String survivalId, List<String> eliminatedBotIds) async {
    if (eliminatedBotIds.isEmpty) return;

    try {
      final survivalDoc = _db.collection('maze_survival').doc(survivalId);
      final survivalData = await survivalDoc.get();

      if (!survivalData.exists) return;

      final data = survivalData.data();
      if (data == null || !data.containsKey('bots')) return;

      final botsData = Map<String, dynamic>.from(data['bots'] as Map<String, dynamic>);

      // Remove eliminated bots
      for (final botId in eliminatedBotIds) {
        botsData.remove(botId);
      }

      // Update the document
      await survivalDoc.update({
        'bots': botsData,
        'playerCount': FieldValue.increment(-eliminatedBotIds.length),
      });

      print('🧩 Removed ${eliminatedBotIds.length} eliminated maze bots');
    } catch (e) {
      print('🧩 Error updating maze bots: $e');
    }
  }

  // FIXED: Cleanup eliminated bots from survival
  static Future<void> cleanupEliminatedBots(
      String survivalId,
      List<String> advancingPlayerIds
      ) async {
    try {
      final survivalDoc = await _db.collection('maze_survival').doc(survivalId).get();
      if (!survivalDoc.exists) return;

      final data = survivalDoc.data();
      final currentBots = data?['bots'] as Map<String, dynamic>? ?? {};

      // Filter to keep only advancing bots
      final advancingBots = <String, dynamic>{};
      for (final playerId in advancingPlayerIds) {
        if (currentBots.containsKey(playerId)) {
          advancingBots[playerId] = currentBots[playerId];
        }
      }

      // Update survival with only advancing bots
      await _db.collection('maze_survival').doc(survivalId).update({
        'bots': advancingBots,
      });

      print('🧩 Cleaned up maze bots: ${currentBots.length - advancingBots.length} eliminated, ${advancingBots.length} advancing');

    } catch (e) {
      print('🧩 Error cleaning up eliminated maze bots: $e');
    }
  }

  // Get bot statistics for a maze survival
  static Future<Map<String, dynamic>> getSurvivalBotStats(String survivalId) async {
    try {
      final survivalDoc = await _db.collection('maze_survival').doc(survivalId).get();
      if (!survivalDoc.exists) return {};

      final data = survivalDoc.data();
      final bots = data?['bots'] as Map<String, dynamic>? ?? {};

      final difficultyCount = <String, int>{};
      for (final difficulty in MazeBotDifficulty.values) {
        difficultyCount[difficulty.name] = 0;
      }

      for (final botData in bots.values) {
        if (botData is Map<String, dynamic>) {
          final difficulty = botData['difficulty'] as String?;
          if (difficulty != null && difficultyCount.containsKey(difficulty)) {
            difficultyCount[difficulty] = difficultyCount[difficulty]! + 1;
          }
        }
      }

      return {
        'totalBots': bots.length,
        'difficultyDistribution': difficultyCount,
        'survivalId': survivalId,
      };

    } catch (e) {
      print('🧩 Error getting maze survival bot stats: $e');
      return {};
    }
  }
}