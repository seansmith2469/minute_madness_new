// lib/services/match_bot_service.dart - ENHANCED WITH MULTI-ROUND TOURNAMENT SUPPORT
import 'dart:math' as math;  // FIXED: Added missing import
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

// Enhanced difficulty system with more granular levels
enum MatchBotDifficulty {
  slow,      // 45-90 seconds + many penalties (40% of bots)
  average,   // 25-50 seconds + some penalties (35% of bots)
  fast,      // 15-30 seconds + few penalties (20% of bots)
  lightning, // 8-18 seconds + minimal penalties (5% of bots)
}

class MatchBotPlayer {
  final String id;
  final String name;
  final MatchBotDifficulty difficulty;

  MatchBotPlayer({
    required this.id,
    required this.name,
    required this.difficulty,
  });

  // Enhanced completion time generation with round-based improvements
  int generateCompletionTime({int round = 1, int remainingPlayers = 64}) {
    final random = math.Random();

    // Base time ranges by difficulty
    final Map<String, int> baseRange = _getBaseTimeRange();
    final baseTime = baseRange['min']! + random.nextInt(baseRange['max']! - baseRange['min']! + 1);
    final basePenalties = generatePenaltyCount(round: round);

    // Round adjustment - bots get better in later rounds (tournament pressure)
    final roundFactor = _getRoundAdjustmentFactor(round, remainingPlayers);
    final adjustedTime = (baseTime * roundFactor).round();

    // Ensure minimum reasonable times
    final finalTime = math.max(adjustedTime, 8000); // FIXED: Proper math import usage

    return finalTime + (basePenalties * 1000);
  }

  // Round-adjusted penalty generation
  int generatePenaltyCount({int round = 1}) {
    final random = math.Random();
    final basePenalties = _getBasePenalties();

    // Fewer penalties in later rounds (increased focus)
    final roundReduction = round > 3 ? 0.6 : round > 1 ? 0.8 : 1.0;
    final adjustedPenalties = (basePenalties * roundReduction).round();

    return math.max(adjustedPenalties, 0); // FIXED: Proper math import usage
  }

  // Get base time range for this difficulty
  Map<String, int> _getBaseTimeRange() {
    switch (difficulty) {
      case MatchBotDifficulty.slow:
        return {'min': 30000, 'max': 50000}; // 30-50s base
      case MatchBotDifficulty.average:
        return {'min': 20000, 'max': 35000}; // 20-35s base
      case MatchBotDifficulty.fast:
        return {'min': 12000, 'max': 20000}; // 12-20s base
      case MatchBotDifficulty.lightning:
        return {'min': 8000, 'max': 14000}; // 8-14s base
    }
  }

  // Get base penalty count for this difficulty
  int _getBasePenalties() {
    final random = math.Random();
    switch (difficulty) {
      case MatchBotDifficulty.slow:
        return 3 + random.nextInt(5); // 3-7 penalties
      case MatchBotDifficulty.average:
        return 1 + random.nextInt(3); // 1-3 penalties
      case MatchBotDifficulty.fast:
        return random.nextInt(2); // 0-1 penalties
      case MatchBotDifficulty.lightning:
        return random.nextInt(2) == 0 ? 0 : 1; // Rarely 1 penalty
    }
  }

  // Calculate round performance adjustment
  static double _getRoundAdjustmentFactor(int round, int remainingPlayers) {
    // Bots perform better under tournament pressure in later rounds
    switch (round) {
      case 1: return 1.0;      // Round of 64 - normal performance
      case 2: return 0.95;     // Round of 32 - 5% better
      case 3: return 0.90;     // Round of 16 - 10% better
      case 4: return 0.85;     // Quarterfinals - 15% better
      case 5: return 0.80;     // Semifinals - 20% better
      case 6: return 0.75;     // Finals - 25% better (max pressure)
      default: return 0.90;
    }
  }

  // Convert to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'difficulty': difficulty.name,
      'isBot': true,
    };
  }
}

class MatchBotService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final math.Random _random = math.Random(); // FIXED: Proper math import usage

  // Enhanced bot names - keeping your excellent collection plus some additions
  static final List<String> _matchBotNames = [
    // Card/Tarot themed
    'CardMaster', 'TarotReader', 'MatchMaker', 'PairFinder', 'CardSharp',
    'TarotSage', 'MysticMatcher', 'CardCrafter', 'PairPro', 'MatchWizard',
    'TarotTitan', 'CardCrusher', 'MatchMagic', 'PairPower', 'CardChamp',
    'TarotTracker', 'MatchMania', 'PairPerfect', 'CardCraze', 'TarotTornado',

    // Mystical/Fortune themed
    'CrystalBall', 'FortuneSeeker', 'MysticEye', 'OracleOwl', 'ProphetPro',
    'DivineDeck', 'SacredSeer', 'CosmicCards', 'AstralAce', 'ZenZapper',
    'KarmicKing', 'SpiritSpirit', 'RuneReader', 'VisionVault', 'DreamDeck',
    'EtherealEdge', 'CelestialCard', 'InfiniteInsight', 'LunarLogic', 'SolarSeeker',

    // Speed/Matching themed
    'QuickMatch', 'FastFlip', 'SpeedSeeker', 'RapidReader', 'SwiftSpotter',
    'LightningLink', 'FlashFinder', 'BoltBrain', 'TurboTarot', 'NitroNinja',
    'VelocityVision', 'AccelAce', 'ZoomZen', 'DashDiviner', 'RushReader',
    'BlitzBrain', 'JetJoker', 'RocketReader', 'MeteorMatcher', 'CometCard',

    // Gaming style names
    'MatchHunter42', 'CardSeeker99', 'PairMaster', 'TarotGuru', 'FlipMaster',
    'MatchMind', 'CardCognition', 'PairPsyche', 'TarotThought', 'MatchMemory',
    'CardClairvoyant', 'PairProphet', 'TarotTelekinesis', 'MatchMedium', 'CardCrystal',
    'PairPhoenix', 'TarotThunderbolt', 'MatchMystique', 'CardCosmos', 'PairPlanet',

    // Human-like usernames
    'Alex_Tarot', 'Sarah_Cards', 'Mike_Match', 'Emma_Pair', 'David_Flip',
    'Lisa_Mystic', 'Tom_Oracle', 'Amy_Vision', 'Jake_Prophet', 'Nina_Divine',
    'Ryan_Crystal', 'Maya_Spirit', 'Luke_Rune', 'Zoe_Dream', 'Evan_Lunar',
    'Aria_Solar', 'Cole_Astral', 'Luna_Cosmic', 'Max_Zen', 'Ivy_Karma',

    // Tech/Cyber themed
    'CyberCard', 'DigitalDeck', 'DataDiviner', 'ByteReader', 'CodeCards',
    'NetNinja', 'WebWizard', 'CloudCard', 'StreamSeeker', 'FlowFinder',
    'PulseReader', 'WaveWatcher', 'EchoEye', 'SignalSeeker', 'FreqFinder',
    'AmpAce', 'VoltVision', 'CircuitCard', 'ChipChamp', 'ProcessorPro',

    // Simple numbered variants
    'Match_01', 'Card_02', 'Pair_03', 'Tarot_04', 'Flip_05',
    'Mystic_06', 'Oracle_07', 'Vision_08', 'Prophet_09', 'Divine_10',
    'Crystal_11', 'Spirit_12', 'Rune_13', 'Dream_14', 'Lunar_15',

    // Additional tournament-themed names
    'ChampionCard', 'LegendMatch', 'ElitePair', 'ProTarot', 'MasterFlip',
    'TourneyTiger', 'BracketBeast', 'PlayoffPro', 'FinalsFury', 'CrownCard',
  ];

  // Balanced distribution for realistic tournament results
  // 40% slow, 35% average, 20% fast, 5% lightning
  static MatchBotDifficulty _getRandomDifficulty() {
    final rand = _random.nextInt(100);
    if (rand < 40) return MatchBotDifficulty.slow;     // 40% - eliminated early
    if (rand < 75) return MatchBotDifficulty.average;  // 35% - mid-tier performance
    if (rand < 95) return MatchBotDifficulty.fast;     // 20% - good performance
    return MatchBotDifficulty.lightning;               // 5% - excellent performance
  }

  // Generate unique match bot with collision avoidance
  static MatchBotPlayer _generateBot(Set<String> usedNames) {
    final botId = 'match_bot_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';

    // Ensure unique name
    String botName;
    int attempts = 0;
    do {
      botName = _matchBotNames[_random.nextInt(_matchBotNames.length)];
      if (usedNames.contains(botName)) {
        botName = '${botName}_${_random.nextInt(9999).toString().padLeft(4, '0')}';
      }
      attempts++;
    } while (usedNames.contains(botName) && attempts < 100);

    final difficulty = _getRandomDifficulty();

    return MatchBotPlayer(
      id: botId,
      name: botName,
      difficulty: difficulty,
    );
  }

  // Enhanced bot addition with name collision prevention
  static Future<List<MatchBotPlayer>> addBotsToTournament(String tourneyId, int count) async {
    try {
      final bots = <MatchBotPlayer>[];
      final usedNames = <String>{};

      // Get existing bot names to avoid collisions
      final tourneyDoc = await _db.collection('match_tournaments').doc(tourneyId).get();
      if (tourneyDoc.exists) {
        final data = tourneyDoc.data();
        final existingBots = data?['bots'] as Map<String, dynamic>? ?? {};
        for (final botData in existingBots.values) {
          if (botData is Map<String, dynamic>) {
            final name = botData['name'] as String?;
            if (name != null) usedNames.add(name);
          }
        }
      }

      final batch = _db.batch();
      final tourneyRef = _db.collection('match_tournaments').doc(tourneyId);

      for (int i = 0; i < count; i++) {
        final bot = _generateBot(usedNames);
        bots.add(bot);
        usedNames.add(bot.name);

        // Add bot to tournament with enhanced data structure
        batch.update(tourneyRef, {
          'players': FieldValue.arrayUnion([bot.id]),
          'playerCount': FieldValue.increment(1),
          'bots.${bot.id}': bot.toMap(),
        });
      }

      await batch.commit();
      print('🃏 Successfully added ${bots.length} bots to match tournament $tourneyId');
      return bots;

    } catch (e) {
      print('🃏 Error adding bots to tournament: $e');
      return [];
    }
  }

  // Enhanced bot result submission with round awareness
  static Future<void> submitBotResults(String tourneyId, List<MatchBotPlayer> bots) async {
    try {
      // Get current tournament state for round-adjusted performance
      final tourneyDoc = await _db.collection('match_tournaments').doc(tourneyId).get();
      if (!tourneyDoc.exists) return;

      final tourneyData = tourneyDoc.data();
      final currentRound = tourneyData?['round'] as int? ?? 1;
      final playerCount = tourneyData?['playerCount'] as int? ?? 64;

      print('🃏 Submitting match results for ${bots.length} bots in round $currentRound');

      // Submit each bot result with realistic delays and round-adjusted performance
      for (int i = 0; i < bots.length; i++) {
        final bot = bots[i];

        // Realistic submission delays (2-8 seconds, spread out)
        final delay = 2000 + (i * 200) + _random.nextInt(4000);

        Timer(Duration(milliseconds: delay), () async {
          try {
            // Check if this bot already submitted to prevent duplicates
            final existingResult = await _db
                .collection('match_tournaments')
                .doc(tourneyId)
                .collection('results')
                .doc(bot.id)
                .get();

            if (existingResult.exists) {
              print('🃏 Bot ${bot.name} already submitted - skipping');
              return;
            }

            // Generate round-adjusted performance
            final completionTime = bot.generateCompletionTime(
                round: currentRound,
                remainingPlayers: playerCount
            );
            final penalties = bot.generatePenaltyCount(round: currentRound);

            await _db
                .collection('match_tournaments')
                .doc(tourneyId)
                .collection('results')
                .doc(bot.id)
                .set({
              'uid': bot.id,
              'completionTimeMs': completionTime,
              'penaltySeconds': penalties,
              'submittedAt': FieldValue.serverTimestamp(),
              'isBot': true,
              'botDifficulty': bot.difficulty.name,
              'round': currentRound,
            });

            print('🃏 Match bot ${bot.name} (${bot.difficulty.name}) completed round $currentRound in ${(completionTime / 1000).toStringAsFixed(1)}s with $penalties penalties');

          } catch (e) {
            print('🃏 Error submitting match bot result: $e');
          }
        });
      }

    } catch (e) {
      print('🃏 Error in submitBotResults: $e');
    }
  }

  // Get tournament bots (unchanged from your original)
  static Future<List<MatchBotPlayer>> getTournamentBots(String tourneyId) async {
    try {
      final doc = await _db.collection('match_tournaments').doc(tourneyId).get();
      final data = doc.data();
      if (data == null || !data.containsKey('bots')) return [];

      final botsData = data['bots'] as Map<String, dynamic>;
      return botsData.entries.map((entry) {
        final botData = entry.value as Map<String, dynamic>;
        return MatchBotPlayer(
          id: entry.key,
          name: botData['name'],
          difficulty: MatchBotDifficulty.values.firstWhere(
                (d) => d.name == botData['difficulty'],
          ),
        );
      }).toList();
    } catch (e) {
      print('🃏 Error getting tournament bots: $e');
      return [];
    }
  }

  // NEW: Tournament progression utilities

  // Get tournament round information
  static Map<int, String> getTournamentRounds() {
    return {
      1: 'Round of 64',
      2: 'Round of 32',
      3: 'Round of 16',
      4: 'Quarterfinals',
      5: 'Semifinals',
      6: 'Finals',
    };
  }

  // Calculate expected advancing players for a round
  static int getAdvancingPlayers(int round, int currentPlayers) {
    if (round >= 6) return 1; // Finals - only 1 winner

    // Standard tournament elimination
    final targetForNextRound = {
      1: 32, // From 64 to 32
      2: 16, // From 32 to 16
      3: 8,  // From 16 to 8
      4: 4,  // From 8 to 4
      5: 2,  // From 4 to 2
    };

    return math.min(targetForNextRound[round] ?? 1, currentPlayers ~/ 2); // FIXED: Proper math import usage
  }

  // Cleanup eliminated bots from tournament
  static Future<void> cleanupEliminatedBots(
      String tourneyId,
      List<String> advancingPlayerIds
      ) async {
    try {
      final tourneyDoc = await _db.collection('match_tournaments').doc(tourneyId).get();
      if (!tourneyDoc.exists) return;

      final data = tourneyDoc.data();
      final currentBots = data?['bots'] as Map<String, dynamic>? ?? {};

      // Filter to keep only advancing bots
      final advancingBots = <String, dynamic>{};
      for (final playerId in advancingPlayerIds) {
        if (currentBots.containsKey(playerId)) {
          advancingBots[playerId] = currentBots[playerId];
        }
      }

      // Update tournament with only advancing bots
      await _db.collection('match_tournaments').doc(tourneyId).update({
        'bots': advancingBots,
      });

      print('🃏 Cleaned up bots: ${currentBots.length - advancingBots.length} eliminated, ${advancingBots.length} advancing');

    } catch (e) {
      print('🃏 Error cleaning up eliminated bots: $e');
    }
  }

  // Get bot statistics for a tournament
  static Future<Map<String, dynamic>> getTournamentBotStats(String tourneyId) async {
    try {
      final tourneyDoc = await _db.collection('match_tournaments').doc(tourneyId).get();
      if (!tourneyDoc.exists) return {};

      final data = tourneyDoc.data();
      final bots = data?['bots'] as Map<String, dynamic>? ?? {};

      final difficultyCount = <String, int>{};
      for (final difficulty in MatchBotDifficulty.values) {
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
        'tournamentId': tourneyId,
      };

    } catch (e) {
      print('🃏 Error getting tournament bot stats: $e');
      return {};
    }
  }
}