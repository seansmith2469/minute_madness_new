// lib/services/momentum_bot_service.dart - MOMENTUM WHEEL BOT SERVICE
import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

// Bot difficulty levels for momentum wheel challenge
enum MomentumBotDifficulty {
  wobbler,    // Poor wheel timing - 200-800 points per spin (40% of bots)
  steady,     // Average timing - 400-700 points per spin (35% of bots)
  precise,    // Good timing - 600-900 points per spin (20% of bots)
  master,     // Excellent timing - 800-1000 points per spin (5% of bots)
}

class MomentumBotPlayer {
  final String id;
  final String name;
  final MomentumBotDifficulty difficulty;

  MomentumBotPlayer({
    required this.id,
    required this.name,
    required this.difficulty,
  });

  // Generate realistic momentum wheel performance with 3 spins
  List<int> generateSpinScores() {
    final random = math.Random();
    final spinScores = <int>[];
    double momentum = 1.0; // Start with base momentum

    for (int spin = 0; spin < 3; spin++) {
      final baseScore = _generateBaseSpin();

      // Apply momentum effect - better scores increase momentum
      final momentumAdjustedScore = (baseScore * momentum).round();
      final finalScore = math.min(momentumAdjustedScore, 1000); // Cap at 1000

      spinScores.add(finalScore);

      // Update momentum based on performance
      if (finalScore >= 800) {
        momentum += 0.3; // Excellent spin boosts momentum
      } else if (finalScore >= 600) {
        momentum += 0.1; // Good spin slightly boosts momentum
      } else if (finalScore < 400) {
        momentum = math.max(1.0, momentum - 0.2); // Poor spin reduces momentum
      }

      // Cap momentum at realistic levels
      momentum = math.min(momentum, 4.0);
    }

    return spinScores;
  }

  // Generate base spin score based on difficulty
  int _generateBaseSpin() {
    final random = math.Random();

    switch (difficulty) {
      case MomentumBotDifficulty.wobbler:
      // Poor timing - mostly miss the target zone
      // 70% chance of 200-500, 25% chance of 500-700, 5% chance of 700-800
        final chance = random.nextInt(100);
        if (chance < 5) return 700 + random.nextInt(101); // 700-800 (rare good hit)
        if (chance < 30) return 500 + random.nextInt(201); // 500-700 (occasional decent)
        return 200 + random.nextInt(301); // 200-500 (mostly poor)

      case MomentumBotDifficulty.steady:
      // Average timing - consistent mid-range performance
      // 15% chance of 200-500, 60% chance of 500-700, 25% chance of 700-900
        final chance = random.nextInt(100);
        if (chance < 25) return 700 + random.nextInt(201); // 700-900 (good hits)
        if (chance < 85) return 500 + random.nextInt(201); // 500-700 (steady range)
        return 200 + random.nextInt(301); // 200-500 (occasional miss)

      case MomentumBotDifficulty.precise:
      // Good timing - frequently hits target zone
      // 5% chance of 300-500, 30% chance of 500-700, 50% chance of 700-900, 15% chance of 900-1000
        final chance = random.nextInt(100);
        if (chance < 15) return 900 + random.nextInt(101); // 900-1000 (excellent)
        if (chance < 65) return 700 + random.nextInt(201); // 700-900 (very good)
        if (chance < 95) return 500 + random.nextInt(201); // 500-700 (decent)
        return 300 + random.nextInt(201); // 300-500 (rare miss)

      case MomentumBotDifficulty.master:
      // Excellent timing - almost always hits target, often perfect
      // 5% chance of 500-700, 40% chance of 700-900, 40% chance of 900-980, 15% chance of 980-1000
        final chance = random.nextInt(100);
        if (chance < 15) return 980 + random.nextInt(21); // 980-1000 (near perfect)
        if (chance < 55) return 900 + random.nextInt(81); // 900-980 (excellent)
        if (chance < 95) return 700 + random.nextInt(201); // 700-900 (very good)
        return 500 + random.nextInt(201); // 500-700 (rare off day)
    }
  }

  // Calculate total score from spin scores
  int calculateTotalScore() {
    final spinScores = generateSpinScores();
    return spinScores.fold<int>(0, (sum, score) => sum + score);
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

class MomentumBotService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final math.Random _random = math.Random();

  // Momentum/wheel themed bot names
  static final List<String> _momentumBotNames = [
    // Wheel/Spinning themed
    'WheelMaster', 'SpinDoctor', 'WheelWizard', 'SpinSage', 'WheelWarrior',
    'RotationRex', 'SpinSpecialist', 'WheelWhisperer', 'SpinSensei', 'CircleSage',
    'WheelWarden', 'SpinSorcerer', 'RotationRuler', 'WheelWanderer', 'SpinSpirit',
    'DiscDynamo', 'WheelWalker', 'SpinSeeker', 'RotationRider', 'CircleChamp',

    // Momentum themed
    'MomentumMaster', 'ForceFlyer', 'VelocityViper', 'AccelAce', 'SpeedSpin',
    'MomentumMage', 'ForceField', 'VelocityVault', 'AccelArrow', 'SpeedStar',
    'MomentumMonk', 'ForceFury', 'VelocityViking', 'AccelAngle', 'SpeedSpark',
    'FlowForce', 'RushRider', 'PowerPulse', 'EnergyEdge', 'DynamicDash',

    // Precision/Timing themed
    'PinpointPro', 'PrecisionPilot', 'BullseyeBoss', 'TargetTitan', 'AimAce',
    'AccuracyAngel', 'PerfectPulse', 'PrecisionPunk', 'TargetTracker', 'FocusFire',
    'SharpshotSpin', 'PinpointPower', 'AccurateArrow', 'PrecisionPro', 'TargetTamer',
    'BullseyeBeast', 'AimAssassin', 'FocusedForce', 'SteadySpin', 'CenterSeeker',

    // Gaming style names
    'SpinMaster42', 'WheelGuru99', 'MomentumKing', 'SpinCrusher', 'WheelNinja',
    'RotationRage', 'SpinStorm', 'WheelWrecker', 'MomentumMayhem', 'SpinShock',
    'WheelWarpath', 'RotationRiot', 'SpinSlayer', 'MomentumMelt', 'WheelWild',
    'CircleCrush', 'DiscDestroy', 'SpinSmash', 'WheelWave', 'RotationRush',

    // Human-like usernames
    'Alex_Spinner', 'Sarah_Wheel', 'Mike_Rotation', 'Emma_Momentum', 'David_Spin',
    'Lisa_Circle', 'Tom_Velocity', 'Amy_Precision', 'Jake_Target', 'Nina_Accuracy',
    'Ryan_Wheel', 'Maya_Spin', 'Luke_Force', 'Zoe_Speed', 'Evan_Flow',
    'Aria_Rush', 'Cole_Power', 'Luna_Energy', 'Max_Dynamic', 'Ivy_Pulse',

    // Tech/Cyber themed
    'CyberSpin', 'DigitalDisc', 'DataWheel', 'ByteRotation', 'CodeCircle',
    'NetSpinner', 'WebWheel', 'CloudCircle', 'StreamSpin', 'FlowDisk',
    'PulseRotation', 'WaveWheel', 'EchoSpin', 'SignalCircle', 'FreqForce',
    'AmpAccel', 'VoltVelocity', 'CircuitSpin', 'ChipCircle', 'ProcessorPro',

    // Abstract/Cool names
    'ZenWheel', 'FlowSpin', 'WheelZone', 'SpinFlow', 'CircleRealm',
    'DiscDimension', 'WheelWave', 'SpinSphere', 'RotationRealm', 'CircleCore',
    'VortexVision', 'SpiralSoul', 'CircularSage', 'OrbitalOracle', 'CyclicCrush',
    'RadialRage', 'CircularStorm', 'WheelWhirlwind', 'SpinSpiral', 'DiscDynamo',

    // Tournament themed
    'ChampionSpin', 'LegendWheel', 'EliteRotation', 'ProSpinner', 'MasterCircle',
    'TourneyTwist', 'BracketBeast', 'PlayoffPro', 'FinalsSpin', 'CrownCircle',
    'VictoryVelocity', 'WinnerWheel', 'TriumphTwist', 'GloryGrip', 'PodiumPro',

    // Simple numbered variants
    'Spin_01', 'Wheel_02', 'Circle_03', 'Disc_04', 'Rotation_05',
    'Momentum_06', 'Force_07', 'Velocity_08', 'Speed_09', 'Flow_10',
    'Power_11', 'Energy_12', 'Dynamic_13', 'Pulse_14', 'Rush_15',
  ];

  // Balanced distribution for realistic tournament progression
  // 40% wobbler (eliminated early), 35% steady, 20% precise, 5% master
  static MomentumBotDifficulty _getRandomDifficulty() {
    final rand = _random.nextInt(100);
    if (rand < 40) return MomentumBotDifficulty.wobbler;  // 40% - poor performers
    if (rand < 75) return MomentumBotDifficulty.steady;   // 35% - average performers
    if (rand < 95) return MomentumBotDifficulty.precise;  // 20% - good performers
    return MomentumBotDifficulty.master;                  // 5% - excellent performers
  }

  // Generate unique momentum bot with collision avoidance
  static MomentumBotPlayer _generateBot(Set<String> usedNames) {
    final botId = 'momentum_bot_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';

    // Ensure unique name
    String botName;
    int attempts = 0;
    do {
      botName = _momentumBotNames[_random.nextInt(_momentumBotNames.length)];
      if (usedNames.contains(botName)) {
        botName = '${botName}_${_random.nextInt(9999).toString().padLeft(4, '0')}';
      }
      attempts++;
    } while (usedNames.contains(botName) && attempts < 100);

    final difficulty = _getRandomDifficulty();

    return MomentumBotPlayer(
      id: botId,
      name: botName,
      difficulty: difficulty,
    );
  }

  // Add bots to momentum tournament with name collision prevention
  static Future<List<MomentumBotPlayer>> addBotsToTournament(String tourneyId, int count) async {
    try {
      final bots = <MomentumBotPlayer>[];
      final usedNames = <String>{};

      // Get existing bot names to avoid collisions
      final tourneyDoc = await _db.collection('momentum_tournaments').doc(tourneyId).get();
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
      final tourneyRef = _db.collection('momentum_tournaments').doc(tourneyId);

      for (int i = 0; i < count; i++) {
        final bot = _generateBot(usedNames);
        bots.add(bot);
        usedNames.add(bot.name);

        // Add bot to tournament
        batch.update(tourneyRef, {
          'players': FieldValue.arrayUnion([bot.id]),
          'playerCount': FieldValue.increment(1),
          'bots.${bot.id}': bot.toMap(),
        });
      }

      await batch.commit();
      print('🎯 Successfully added ${bots.length} bots to momentum tournament $tourneyId');
      return bots;

    } catch (e) {
      print('🎯 Error adding bots to momentum tournament: $e');
      return [];
    }
  }

  // Submit bot results for momentum tournament
  static Future<void> submitBotResults(String tourneyId, List<MomentumBotPlayer> bots) async {
    try {
      print('🎯 Submitting momentum results for ${bots.length} bots');

      // Submit each bot result with realistic delays
      for (int i = 0; i < bots.length; i++) {
        final bot = bots[i];

        // Realistic submission delays (2-6 seconds, spread out)
        final delay = 2000 + (i * 150) + _random.nextInt(3000);

        Timer(Duration(milliseconds: delay), () async {
          try {
            // Check if this bot already submitted to prevent duplicates
            final existingResult = await _db
                .collection('momentum_tournaments')
                .doc(tourneyId)
                .collection('results')
                .doc(bot.id)
                .get();

            if (existingResult.exists) {
              print('🎯 Momentum bot ${bot.name} already submitted - skipping');
              return;
            }

            // Generate bot performance
            final spinScores = bot.generateSpinScores();
            final totalScore = spinScores.fold<int>(0, (sum, score) => sum + score);

            // Calculate momentum multiplier based on performance
            double momentum = 1.0;
            for (final score in spinScores) {
              if (score >= 800) {
                momentum += 0.3;
              } else if (score >= 600) {
                momentum += 0.1;
              } else if (score < 400) {
                momentum = math.max(1.0, momentum - 0.2);
              }
              momentum = math.min(momentum, 4.0);
            }

            await _db
                .collection('momentum_tournaments')
                .doc(tourneyId)
                .collection('results')
                .doc(bot.id)
                .set({
              'uid': bot.id,
              'totalScore': totalScore,
              'spinScores': spinScores,
              'momentum': momentum,
              'submittedAt': FieldValue.serverTimestamp(),
              'isBot': true,
              'botDifficulty': bot.difficulty.name,
            });

            print('🎯 Momentum bot ${bot.name} (${bot.difficulty.name}) scored $totalScore '
                'with spins [${spinScores.join(", ")}] and ${momentum.toStringAsFixed(1)}x momentum');

          } catch (e) {
            print('🎯 Error submitting momentum bot result: $e');
          }
        });
      }

    } catch (e) {
      print('🎯 Error in momentum submitBotResults: $e');
    }
  }

  // Get tournament bots
  static Future<List<MomentumBotPlayer>> getTournamentBots(String tourneyId) async {
    try {
      final doc = await _db.collection('momentum_tournaments').doc(tourneyId).get();
      final data = doc.data();
      if (data == null || !data.containsKey('bots')) return [];

      final botsData = data['bots'] as Map<String, dynamic>;
      return botsData.entries.map((entry) {
        final botData = entry.value as Map<String, dynamic>;
        return MomentumBotPlayer(
          id: entry.key,
          name: botData['name'],
          difficulty: MomentumBotDifficulty.values.firstWhere(
                (d) => d.name == botData['difficulty'],
          ),
        );
      }).toList();
    } catch (e) {
      print('🎯 Error getting momentum tournament bots: $e');
      return [];
    }
  }

  // NEW: Tournament progression utilities

  // Get tournament round information for momentum tournaments
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

    return math.min(targetForNextRound[round] ?? 1, currentPlayers ~/ 2);
  }

  // Cleanup eliminated bots from tournament
  static Future<void> cleanupEliminatedBots(
      String tourneyId,
      List<String> advancingPlayerIds
      ) async {
    try {
      final tourneyDoc = await _db.collection('momentum_tournaments').doc(tourneyId).get();
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
      await _db.collection('momentum_tournaments').doc(tourneyId).update({
        'bots': advancingBots,
      });

      print('🎯 Cleaned up momentum bots: ${currentBots.length - advancingBots.length} eliminated, ${advancingBots.length} advancing');

    } catch (e) {
      print('🎯 Error cleaning up eliminated momentum bots: $e');
    }
  }

  // Get bot statistics for a momentum tournament
  static Future<Map<String, dynamic>> getTournamentBotStats(String tourneyId) async {
    try {
      final tourneyDoc = await _db.collection('momentum_tournaments').doc(tourneyId).get();
      if (!tourneyDoc.exists) return {};

      final data = tourneyDoc.data();
      final bots = data?['bots'] as Map<String, dynamic>? ?? {};

      final difficultyCount = <String, int>{};
      for (final difficulty in MomentumBotDifficulty.values) {
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
      print('🎯 Error getting momentum tournament bot stats: $e');
      return {};
    }
  }

  // Simulate a complete bot performance for testing/preview
  static Map<String, dynamic> simulateBotPerformance(MomentumBotDifficulty difficulty) {
    final bot = MomentumBotPlayer(
      id: 'test_bot',
      name: 'TestBot',
      difficulty: difficulty,
    );

    final spinScores = bot.generateSpinScores();
    final totalScore = spinScores.fold<int>(0, (sum, score) => sum + score);

    double momentum = 1.0;
    for (final score in spinScores) {
      if (score >= 800) {
        momentum += 0.3;
      } else if (score >= 600) {
        momentum += 0.1;
      } else if (score < 400) {
        momentum = math.max(1.0, momentum - 0.2);
      }
      momentum = math.min(momentum, 4.0);
    }

    return {
      'difficulty': difficulty.name,
      'spinScores': spinScores,
      'totalScore': totalScore,
      'momentum': momentum.toStringAsFixed(1),
    };
  }
}