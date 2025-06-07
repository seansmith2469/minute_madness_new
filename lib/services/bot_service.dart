// lib/services/bot_service.dart
import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

enum BotDifficulty { easy, medium, hard, veryHard }

class BotPlayer {
  final String id;
  final String name;
  final BotDifficulty difficulty;

  BotPlayer({
    required this.id,
    required this.name,
    required this.difficulty,
  });

  Duration generateTiming(Duration target) {
    final random = Random();
    int errorRange;

    switch (difficulty) {
      case BotDifficulty.easy:
        errorRange = 300 + random.nextInt(200); // 300-500ms error
      case BotDifficulty.medium:
        errorRange = 150 + random.nextInt(150); // 150-300ms error
      case BotDifficulty.hard:
        errorRange = 50 + random.nextInt(100);  // 50-150ms error
      case BotDifficulty.veryHard:
        errorRange = 10 + random.nextInt(40);   // 10-50ms error
    }

    // Random positive/negative error
    final error = random.nextBool() ? errorRange : -errorRange;
    return target + Duration(milliseconds: error);
  }
}

class BotService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Random _random = Random();

  // Massive list of realistic bot names
  static final List<String> _botNames = [
    // Gaming style names
    'TimeMaster42', 'PrecisionPro', 'QuickReflexes', 'SpeedDemon99', 'ClockWatcher',
    'ReactFast', 'TimingGuru', 'FastFingers', 'PerfectTiming', 'QuickClick',
    'TimeBender', 'SwiftReaction', 'AccurateAim', 'RapidResponse', 'TimingChamp',
    'SpeedRunner', 'QuickDraw', 'FastTrack', 'TimingWiz', 'SwiftStrike',

    // Regular human-style names
    'Alex_2024', 'Sarah_Timer', 'Mike_Pro', 'Emma_Fast', 'David_Quick',
    'Lisa_Sharp', 'Tom_Precise', 'Amy_Swift', 'Jake_Speed', 'Nina_Flash',
    'Ryan_Click', 'Maya_Time', 'Luke_Fast', 'Zoe_Quick', 'Evan_Pro',
    'Aria_Sharp', 'Cole_Speed', 'Luna_Swift', 'Max_Timer', 'Ivy_Flash',

    // Cool gaming tags
    'ShadowTimer', 'NeonClicker', 'CyberSpeed', 'QuantumClick', 'LaserFocus',
    'TurboTap', 'NitroClick', 'BlazeFast', 'VelocityPro', 'UltraQuick',
    'MegaTime', 'SuperSwift', 'HyperClick', 'TurboTime', 'RocketSpeed',
    'FlashClick', 'BoltTimer', 'ThunderTap', 'LightningFast', 'SonicClick',

    // More realistic usernames
    'TimingExpert', 'ClickMaster', 'ReactionKing', 'SpeedQueen', 'TimePro',
    'QuickShot', 'FastHand', 'SwiftClick', 'RapidTap', 'QuickTime',
    'SpeedStar', 'TimingAce', 'ClickChamp', 'FastPace', 'QuickMove',
    'SwiftHit', 'RapidFire', 'QuickStrike', 'FastBeat', 'SpeedTap',

    // Username variations
    'Player_123', 'User_456', 'Gamer_789', 'Timer_321', 'Click_654',
    'Speed_987', 'Quick_147', 'Fast_258', 'Swift_369', 'Rapid_741',
    'Timing_852', 'React_963', 'Precise_159', 'Accurate_753', 'Sharp_486',

    // More creative names
    'PixelPerfect', 'DigitalSpeed', 'ByteClick', 'CodeTimer', 'TechSpeed',
    'DataClick', 'NetSpeed', 'CyberTap', 'WebTimer', 'CloudClick',
    'StreamSpeed', 'FlowTimer', 'WaveClick', 'PulseSpeed', 'EchoTimer',
    'VibeClick', 'ZoneSpeed', 'FluxTimer', 'CoreClick', 'EdgeSpeed',

    // International feel
    'SpeedNinja', 'TimingSamurai', 'ClickWarrior', 'FastPhantom', 'QuickGhost',
    'SwiftShadow', 'RapidRaven', 'TimingTiger', 'ClickCobra', 'SpeedSpirit',
    'QuickQuasar', 'FastFalcon', 'SwiftStorm', 'RapidRocket', 'TimingThunder',

    // Simple and clean
    'Timer01', 'Clicker02', 'Speedy03', 'Quick04', 'Fast05',
    'Swift06', 'Rapid07', 'Sharp08', 'Precise09', 'Accurate10',
    'Focus11', 'Reflex12', 'React13', 'Strike14', 'Hit15',

    // More variations to reach 100+
    'TimeKeeper', 'ClickCounter', 'SpeedTracker', 'QuickMeter', 'FastGauge',
    'SwiftScale', 'RapidRate', 'TimingTool', 'ClickCalc', 'SpeedSensor',
    'QuickQuant', 'FastFactor', 'SwiftStat', 'RapidRatio', 'TimingTest',
    'ClickCheck', 'SpeedScore', 'QuickQuiz', 'FastForm', 'SwiftSystem',
    'RapidRun', 'TimingTrack', 'ClickCourse', 'SpeedSprint', 'QuickQuest',
  ];

  // Get difficulty distribution (50% easy, 30% medium, 10% hard, 10% very hard)
  static BotDifficulty _getRandomDifficulty() {
    final rand = _random.nextInt(100);
    if (rand < 50) return BotDifficulty.easy;
    if (rand < 80) return BotDifficulty.medium;
    if (rand < 90) return BotDifficulty.hard;
    return BotDifficulty.veryHard;
  }

  // Generate unique bot
  static BotPlayer _generateBot() {
    final botId = 'bot_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}';
    final botName = _botNames[_random.nextInt(_botNames.length)];
    final difficulty = _getRandomDifficulty();

    return BotPlayer(
      id: botId,
      name: botName,
      difficulty: difficulty,
    );
  }

  // Add bots to tournament
  static Future<List<BotPlayer>> addBotsToTournament(String tourneyId, int count) async {
    final bots = <BotPlayer>[];
    final batch = _db.batch();

    for (int i = 0; i < count; i++) {
      final bot = _generateBot();
      bots.add(bot);

      // Add bot to tournament players list
      final tourneyRef = _db.collection('tournaments').doc(tourneyId);
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

  // Submit bot results for a round
  static Future<void> submitBotResults(
      String tourneyId,
      int round,
      List<BotPlayer> bots,
      Duration targetDuration,
      ) async {
    print('🤖 Submitting results for ${bots.length} bots in round $round');

    // Submit results with realistic but faster timing to ensure completion
    for (int i = 0; i < bots.length; i++) {
      final bot = bots[i];
      final timing = bot.generateTiming(targetDuration);
      final errorMs = timing.inMilliseconds - targetDuration.inMilliseconds;

      // Faster, more predictable delays (500ms to 3 seconds, spread evenly)
      final delay = 500 + (i * 50) + _random.nextInt(1000); // 0.5-4 seconds, staggered

      Timer(Duration(milliseconds: delay), () async {
        try {
          await _db
              .collection('tournaments')
              .doc(tourneyId)
              .collection('rounds')
              .doc('round_$round')
              .collection('results')
              .doc(bot.id)
              .set({
            'uid': bot.id,
            'errorMs': errorMs,
            'submittedAt': FieldValue.serverTimestamp(),
            'isBot': true,
          });

          print('🤖 Bot ${bot.name} submitted: ${errorMs}ms error');
        } catch (e) {
          print('🤖 Error submitting bot result: $e');
        }
      });
    }
  }

  // Get tournament bots
  static Future<List<BotPlayer>> getTournamentBots(String tourneyId) async {
    final doc = await _db.collection('tournaments').doc(tourneyId).get();
    final data = doc.data();
    if (data == null || !data.containsKey('bots')) return [];

    final botsData = data['bots'] as Map<String, dynamic>;
    return botsData.entries.map((entry) {
      final botData = entry.value as Map<String, dynamic>;
      return BotPlayer(
        id: entry.key,
        name: botData['name'],
        difficulty: BotDifficulty.values.firstWhere(
              (d) => d.name == botData['difficulty'],
        ),
      );
    }).toList();
  }
}