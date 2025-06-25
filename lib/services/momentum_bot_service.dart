// lib/services/momentum_bot_service.dart - SUPER COMPETITIVE BOTS
import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

// Bot difficulty levels for 10-spin momentum wheel challenge
enum MomentumBotDifficulty {
  rookie,     // Poor performance - 2000-4000 total (25% of bots)
  amateur,    // Below average - 3500-5500 total (30% of bots)
  skilled,    // Average-good - 5000-7000 total (25% of bots)
  expert,     // Good-excellent - 6500-8500 total (15% of bots)
  master,     // Elite level - 8000-9500+ total (5% of bots)
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

  // Generate realistic momentum wheel performance with 10 spins
  List<int> generateSpinScores() {
    final random = math.Random();
    final spinScores = <int>[];
    double momentum = 1.0; // Start with base momentum

    // Progressive speed increase simulation (like player experience)
    double progressiveMultiplier = 1.0;

    for (int spin = 0; spin < 10; spin++) {
      // Progressive speed increase (spins get faster)
      progressiveMultiplier = 1.0 + (spin / 9.0) * 3.0; // 1x to 4x speed progression

      final baseScore = _generateBaseSpin();

      // Apply momentum effect - better scores increase momentum
      final momentumAdjustedScore = (baseScore * momentum).round();

      // Apply progressive speed bonus for later spins (more aggressive)
      final speedBonus = progressiveMultiplier > 2.0 ?
      ((progressiveMultiplier - 2.0) * 50).round() : 0; // Increased from 20 to 50

      final finalScore = math.min(momentumAdjustedScore + speedBonus, 1000); // Cap at 1000

      spinScores.add(finalScore);

      // Update momentum based on performance (same as players but more aggressive)
      if (finalScore >= 950) {
        momentum *= 2.0; // Increased from 1.8
      } else if (finalScore >= 900) {
        momentum *= 1.7; // Increased from 1.5
      } else if (finalScore >= 800) {
        momentum *= 1.4; // Increased from 1.3
      } else if (finalScore >= 700) {
        momentum *= 1.2; // Increased from 1.1
      } else if (finalScore >= 500) {
        momentum *= 0.95; // Same
      } else {
        momentum *= 0.8; // Same
      }

      // Cap the multiplier (same as players)
      momentum = math.min(momentum, 20.0);
      momentum = math.max(momentum, 0.5);
    }

    return spinScores;
  }

  // Generate base spin score based on difficulty - MUCH MORE AGGRESSIVE
  int _generateBaseSpin() {
    final random = math.Random();

    switch (difficulty) {
      case MomentumBotDifficulty.rookie:
      // Poor timing - but still some decent shots
      // Average per spin: ~300-400 (total: 3000-4000)
        final chance = random.nextInt(100);
        if (chance < 5) return 700 + random.nextInt(201); // 700-900 (rare good)
        if (chance < 20) return 500 + random.nextInt(201); // 500-700 (some decent)
        if (chance < 60) return 300 + random.nextInt(201); // 300-500 (average poor)
        return 150 + random.nextInt(151); // 150-300 (bad shots)

      case MomentumBotDifficulty.amateur:
      // Below average but trying
      // Average per spin: ~450-550 (total: 4500-5500)
        final chance = random.nextInt(100);
        if (chance < 10) return 750 + random.nextInt(201); // 750-950 (occasional good)
        if (chance < 35) return 600 + random.nextInt(151); // 600-750 (decent shots)
        if (chance < 75) return 400 + random.nextInt(201); // 400-600 (steady range)
        return 200 + random.nextInt(201); // 200-400 (off shots)

      case MomentumBotDifficulty.skilled:
      // Average to good players
      // Average per spin: ~600-700 (total: 6000-7000)
        final chance = random.nextInt(100);
        if (chance < 15) return 850 + random.nextInt(151); // 850-1000 (good hits)
        if (chance < 50) return 650 + random.nextInt(201); // 650-850 (solid performance)
        if (chance < 85) return 450 + random.nextInt(201); // 450-650 (decent)
        return 250 + random.nextInt(201); // 250-450 (rare miss)

      case MomentumBotDifficulty.expert:
      // Good to excellent players
      // Average per spin: ~750-850 (total: 7500-8500)
        final chance = random.nextInt(100);
        if (chance < 25) return 900 + random.nextInt(101); // 900-1000 (frequent excellence)
        if (chance < 65) return 750 + random.nextInt(151); // 750-900 (very good)
        if (chance < 90) return 600 + random.nextInt(151); // 600-750 (good)
        return 400 + random.nextInt(201); // 400-600 (occasional off)

      case MomentumBotDifficulty.master:
      // Elite level players - should beat most humans
      // Average per spin: ~850-950 (total: 8500-9500+)
        final chance = random.nextInt(100);
        if (chance < 40) return 950 + random.nextInt(51); // 950-1000 (frequent perfect)
        if (chance < 75) return 850 + random.nextInt(101); // 850-950 (excellent)
        if (chance < 95) return 700 + random.nextInt(151); // 700-850 (very good)
        return 500 + random.nextInt(201); // 500-700 (rare bad day)
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

    // Pro player names
    'ProSpin_Elite', 'WheelMaster_Pro', 'SpinLegend', 'TargetPro_X', 'MomentumGod',
    'SpinKing_2024', 'WheelChamp', 'PrecisionLord', 'SpinDeity', 'WheelEmperor',
  ];

  // SUPER COMPETITIVE distribution - many more good players
  static MomentumBotDifficulty _getRandomDifficulty() {
    final rand = _random.nextInt(100);
    if (rand < 25) return MomentumBotDifficulty.rookie;   // 25% - poor (2000-4000)
    if (rand < 55) return MomentumBotDifficulty.amateur;  // 30% - below avg (3500-5500)
    if (rand < 80) return MomentumBotDifficulty.skilled;  // 25% - average-good (5000-7000)
    if (rand < 95) return MomentumBotDifficulty.expert;   // 15% - good-excellent (6500-8500)
    return MomentumBotDifficulty.master;                  // 5% - elite (8000-9500+)
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
      print('🎯 Successfully added ${bots.length} SUPER COMPETITIVE bots to momentum tournament $tourneyId');

      // IMMEDIATELY submit bot results to ensure they participate
      await submitBotResults(tourneyId, bots);

      return bots;

    } catch (e) {
      print('🎯 Error adding bots to momentum tournament: $e');
      return [];
    }
  }

  // Submit bot results for momentum tournament - FASTER SUBMISSION
  static Future<void> submitBotResults(String tourneyId, List<MomentumBotPlayer> bots) async {
    try {
      print('🎯 Submitting SUPER COMPETITIVE momentum results for ${bots.length} bots');

      // Also submit results for ALL existing bots in tournament (in case they haven't)
      final existingBots = await getTournamentBots(tourneyId);
      final allBots = [...bots, ...existingBots];
      print('🎯 Total bots to submit: ${allBots.length} (${bots.length} new + ${existingBots.length} existing)');

      // Submit bot results much faster (reduce delays)
      for (int i = 0; i < allBots.length; i++) {
        final bot = allBots[i];

        // Much faster submission delays (0.5-2 seconds instead of 2-6)
        final delay = 500 + (i * 30) + _random.nextInt(500); // Even faster

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

            // Generate bot performance (10 spins)
            final spinScores = bot.generateSpinScores();
            final totalScore = spinScores.fold<int>(0, (sum, score) => sum + score);

            // Calculate momentum multiplier based on performance (same as players)
            double momentum = 1.0;
            for (final score in spinScores) {
              if (score >= 950) {
                momentum *= 2.0; // More aggressive
              } else if (score >= 900) {
                momentum *= 1.7;
              } else if (score >= 800) {
                momentum *= 1.4;
              } else if (score >= 700) {
                momentum *= 1.2;
              } else if (score >= 500) {
                momentum *= 0.95;
              } else {
                momentum *= 0.8;
              }
              momentum = math.min(momentum, 20.0);
              momentum = math.max(momentum, 0.5);
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
              'maxSpeed': momentum, // Use maxSpeed like players
              'submittedAt': FieldValue.serverTimestamp(),
              'isBot': true,
              'botDifficulty': bot.difficulty.name,
            });

            print('🎯 COMPETITIVE Bot ${bot.name} (${bot.difficulty.name}) scored $totalScore '
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
            orElse: () => MomentumBotDifficulty.amateur,
          ),
        );
      }).toList();
    } catch (e) {
      print('🎯 Error getting momentum tournament bots: $e');
      return [];
    }
  }

  // Rest of methods stay the same...
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

  static int getAdvancingPlayers(int round, int currentPlayers) {
    if (round >= 6) return 1;
    final targetForNextRound = {
      1: 32, 2: 16, 3: 8, 4: 4, 5: 2,
    };
    return math.min(targetForNextRound[round] ?? 1, currentPlayers ~/ 2);
  }

  // Simulate bot performance for testing
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
      if (score >= 950) {
        momentum *= 2.0;
      } else if (score >= 900) {
        momentum *= 1.7;
      } else if (score >= 800) {
        momentum *= 1.4;
      } else if (score >= 700) {
        momentum *= 1.2;
      } else if (score >= 500) {
        momentum *= 0.95;
      } else {
        momentum *= 0.8;
      }
      momentum = math.min(momentum, 20.0);
      momentum = math.max(momentum, 0.5);
    }

    return {
      'difficulty': difficulty.name,
      'spinScores': spinScores,
      'totalScore': totalScore,
      'momentum': momentum.toStringAsFixed(1),
    };
  }
}