// lib/services/memory_bot_service.dart
import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MemoryBotDifficulty { poor, average, good, excellent }

class MemoryBotPlayer {
  final String id;
  final String name;
  final MemoryBotDifficulty difficulty;

  MemoryBotPlayer({
    required this.id,
    required this.name,
    required this.difficulty,
  });

  // COMPLETELY RECALIBRATED: Much more realistic performance
  int generateMemoryLevel() {
    final random = Random();

    switch (difficulty) {
      case MemoryBotDifficulty.poor:
      // Poor bots: Everyone gets 1-2, most fail at 3-4
      // Level 1 (3 arrows): 100% pass - ABSOLUTELY EVERYONE
      // Level 2 (4 arrows): 95% pass
      // Level 3 (5 arrows): 60% pass
      // Level 4 (7 arrows): 25% pass
        final chance = random.nextInt(100);
        if (chance < 25) return 4;  // 25% reach level 4
        if (chance < 60) return 3;  // 35% reach level 3
        if (chance < 95) return 2;  // 35% reach level 2
        return 1;  // 5% reach only level 1 (very rare timeout cases)

      case MemoryBotDifficulty.average:
      // Average bots: Everyone gets 2-3, good distribution through mid-levels
        final chance = random.nextInt(100);
        if (chance < 5) return 7;   // 5% reach level 7 (colors)
        if (chance < 15) return 6;  // 10% reach level 6
        if (chance < 35) return 5;  // 20% reach level 5
        if (chance < 65) return 4;  // 30% reach level 4
        if (chance < 90) return 3;  // 25% reach level 3
        return 2;  // 10% reach level 2 minimum

      case MemoryBotDifficulty.good:
      // Good bots: Everyone gets to at least level 3, most reach 5-7
        final chance = random.nextInt(100);
        if (chance < 10) return 10 + random.nextInt(3); // 10% reach 10-12
        if (chance < 25) return 8 + random.nextInt(2);  // 15% reach 8-9
        if (chance < 50) return 7;  // 25% reach level 7 (colors)
        if (chance < 75) return 6;  // 25% reach level 6
        if (chance < 90) return 5;  // 15% reach level 5
        return 4;  // 10% reach level 4 minimum

      case MemoryBotDifficulty.excellent:
      // Excellent bots: Everyone gets to at least level 5, most go very high
        final chance = random.nextInt(100);
        if (chance < 20) return 15 + random.nextInt(8); // 20% reach 15-22
        if (chance < 45) return 12 + random.nextInt(3); // 25% reach 12-14
        if (chance < 70) return 9 + random.nextInt(3);  // 25% reach 9-11
        if (chance < 90) return 7 + random.nextInt(2);  // 20% reach 7-8
        return 5 + random.nextInt(2);  // 10% reach 5-6 minimum
    }
  }

  // Generate realistic completion time based on level and difficulty
  int generateCompletionTime(int level) {
    final random = Random();

    // Base time estimate for each level (in milliseconds)
    int baseTime;
    if (level <= 2) baseTime = 8000;       // ~8 seconds for easy levels
    else if (level <= 4) baseTime = 15000; // ~15 seconds for medium levels
    else if (level <= 6) baseTime = 25000; // ~25 seconds for hard levels
    else baseTime = 40000;                 // ~40+ seconds for very hard levels

    // Adjust based on bot difficulty
    double multiplier;
    switch (difficulty) {
      case MemoryBotDifficulty.poor:
        multiplier = 1.3 + (random.nextDouble() * 0.4); // 1.3-1.7x slower
      case MemoryBotDifficulty.average:
        multiplier = 1.0 + (random.nextDouble() * 0.3); // 1.0-1.3x
      case MemoryBotDifficulty.good:
        multiplier = 0.8 + (random.nextDouble() * 0.3); // 0.8-1.1x
      case MemoryBotDifficulty.excellent:
        multiplier = 0.6 + (random.nextDouble() * 0.3); // 0.6-0.9x faster
    }

    return (baseTime * multiplier * level).round();
  }
}

class MemoryBotService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Random _random = Random();

  // Realistic memory-themed bot names
  static final List<String> _memoryBotNames = [
    // Memory/Brain themed
    'MemoryMaster', 'BrainBox', 'RecallPro', 'MindPalace', 'NeuralNet',
    'SynapseSpeed', 'CortexKing', 'MemoryBank', 'RecallRocket', 'BrainWave',
    'MindReader', 'PatternPro', 'SequenceStar', 'MemoryMachine', 'BrainBoost',
    'RecallRanger', 'MindMapper', 'NeuronNinja', 'CognitiveCrush', 'BrainBlitz',

    // Pattern/Sequence themed
    'PatternPilot', 'SequenceSlayer', 'ArrowAce', 'DirectionDemon', 'PathPro',
    'RouteRocket', 'NavigatorNinja', 'CompassCrush', 'VectorViking', 'TrailTracker',
    'WayFinder', 'PathMaster', 'RouteRunner', 'DirectionDynamo', 'ArrowExpert',
    'SequenceSpecialist', 'PatternPunisher', 'OrderExpert', 'FlowFollower', 'ChainChamp',

    // Gaming style names
    'QuickMind42', 'FastBrain99', 'MemoryGuru', 'RecallRex', 'BrainBender',
    'MindMelt', 'SynapticStorm', 'NeuralNuke', 'CortexCracker', 'MemoryMayhem',
    'BrainBurst', 'RecallRush', 'MindMania', 'PatternPanic', 'SequenceShock',
    'ArrowAnarchy', 'DirectionDoom', 'PathPandemonium', 'RouteRage', 'VectorVenom',

    // Human-like usernames
    'Alex_Memory', 'Sarah_Recall', 'Mike_Pattern', 'Emma_Sequence', 'David_Brain',
    'Lisa_Neural', 'Tom_Synapse', 'Amy_Cortex', 'Jake_Neuron', 'Nina_Cognitive',
    'Ryan_Pattern', 'Maya_Sequence', 'Luke_Memory', 'Zoe_Recall', 'Evan_Brain',
    'Aria_Neural', 'Cole_Synapse', 'Luna_Mind', 'Max_Cortex', 'Ivy_Neuron',

    // Tech/Cyber themed
    'CyberMind', 'DigitalBrain', 'DataRecall', 'ByteMemory', 'CodePattern',
    'NetNeural', 'WebSynapse', 'CloudCortex', 'StreamMind', 'FlowBrain',
    'PulseMind', 'WaveRecall', 'EchoBrain', 'SignalSynapse', 'FreqNeural',
    'AmpCortex', 'VoltMind', 'CircuitBrain', 'ChipMemory', 'ProcessorPro',

    // Abstract/Cool names
    'ZenMemory', 'FlowState', 'MindZone', 'BrainFlow', 'RecallRealm',
    'MemoryMatrix', 'PatternPortal', 'SequenceSphere', 'NeuralNexus', 'CortexCore',
    'SynapticSoul', 'MindfulMaster', 'AwarenessPro', 'ConsciousCrush', 'AlertAce',
    'FocusedFire', 'AttentiveArrow', 'MindfulMight', 'ClearCognition', 'SharpSynapse',

    // Simple numbered variants
    'Memory_01', 'Brain_02', 'Recall_03', 'Pattern_04', 'Sequence_05',
    'Neural_06', 'Synapse_07', 'Cortex_08', 'Mind_09', 'Neuron_10',
    'Cognitive_11', 'Arrow_12', 'Direction_13', 'Path_14', 'Route_15',
  ];

  // FIXED: Better distribution for more realistic tournament
  // 50% poor, 35% average, 12% good, 3% excellent
  static MemoryBotDifficulty _getRandomDifficulty() {
    final rand = _random.nextInt(100);
    if (rand < 50) return MemoryBotDifficulty.poor;     // 50% - mostly eliminated by levels 3-4
    if (rand < 85) return MemoryBotDifficulty.average;  // 35% - reach mid levels
    if (rand < 97) return MemoryBotDifficulty.good;     // 12% - reach higher levels
    return MemoryBotDifficulty.excellent;               // 3% - go very high
  }

  // Generate unique memory bot
  static MemoryBotPlayer _generateBot() {
    final botId = 'memory_bot_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}';
    final botName = _memoryBotNames[_random.nextInt(_memoryBotNames.length)];
    final difficulty = _getRandomDifficulty();

    return MemoryBotPlayer(
      id: botId,
      name: botName,
      difficulty: difficulty,
    );
  }

  // Add bots to memory tournament
  static Future<List<MemoryBotPlayer>> addBotsToTournament(String tourneyId, int count) async {
    final bots = <MemoryBotPlayer>[];
    final batch = _db.batch();

    for (int i = 0; i < count; i++) {
      final bot = _generateBot();
      bots.add(bot);

      final tourneyRef = _db.collection('memory_tournaments').doc(tourneyId);
      batch.update(tourneyRef, {
        'players': FieldValue.arrayUnion([bot.id]),
        'playerCount': FieldValue.increment(1),
        'bots.${bot.id}': {
          'name': bot.name,
          'difficulty': bot.difficulty.name,
          'isBot': true,
        }
      });
    }

    await batch.commit();
    return bots;
  }

  // Submit bot results for memory tournament (single submission per bot)
  static Future<void> submitBotResults(
      String tourneyId,
      List<MemoryBotPlayer> bots,
      ) async {
    print('🧠 Submitting memory results for ${bots.length} bots (single tournament)');

    // Submit each bot result once only
    for (int i = 0; i < bots.length; i++) {
      final bot = bots[i];
      final level = bot.generateMemoryLevel();

      // Realistic submission delays (1-5 seconds, spread out)
      final delay = 1000 + (i * 200) + _random.nextInt(2000);

      Timer(Duration(milliseconds: delay), () async {
        try {
          // Check if this bot already submitted to prevent duplicates
          final existingResult = await _db
              .collection('memory_tournaments')
              .doc(tourneyId)
              .collection('results')
              .doc(bot.id)
              .get();

          if (existingResult.exists) {
            print('🧠 Bot ${bot.name} already submitted - skipping');
            return;
          }

          await _db
              .collection('memory_tournaments')
              .doc(tourneyId)
              .collection('results')
              .doc(bot.id)
              .set({
            'uid': bot.id,
            'level': level,
            'completionTimeMs': bot.generateCompletionTime(level), // ADDED: Bot completion time
            'submittedAt': FieldValue.serverTimestamp(),
            'isBot': true,
          });

          print('🧠 Memory bot ${bot.name} (${bot.difficulty.name}) reached level $level in ${bot.generateCompletionTime(level)}ms');
        } catch (e) {
          print('🧠 Error submitting memory bot result: $e');
        }
      });
    }
  }

  // Get tournament bots
  static Future<List<MemoryBotPlayer>> getTournamentBots(String tourneyId) async {
    try {
      final doc = await _db.collection('memory_tournaments').doc(tourneyId).get();
      final data = doc.data();
      if (data == null || !data.containsKey('bots')) return [];

      final botsData = data['bots'] as Map<String, dynamic>;
      return botsData.entries.map((entry) {
        final botData = entry.value as Map<String, dynamic>;
        return MemoryBotPlayer(
          id: entry.key,
          name: botData['name'],
          difficulty: MemoryBotDifficulty.values.firstWhere(
                (d) => d.name == botData['difficulty'],
          ),
        );
      }).toList();
    } catch (e) {
      print('🧠 Error getting tournament bots: $e');
      return [];
    }
  }
}