// lib/repositories/tournament_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Abstract interface - swap implementations easily later
abstract class TournamentRepository {
  Future<TournamentJoinResult> joinTournament(GameType gameType);
  Future<Tournament?> getTournament(String tourneyId);
  Future<List<TournamentResult>> getTournamentResults(String tourneyId);
  Stream<Tournament> watchTournament(String tourneyId);
  Future<void> submitResult(String tourneyId, GameResult result);
}

// Current implementation using Cloud Functions
class CloudFunctionsTournamentRepository implements TournamentRepository {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Future<TournamentJoinResult> joinTournament(GameType gameType) async {
    try {
      print('🎮 Joining tournament queue for ${gameType.name}');

      final callable = _functions.httpsCallable('joinTournamentQueue');
      final result = await callable.call({
        'gameType': gameType.name,
        'userId': _userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final data = result.data as Map<String, dynamic>;

      return TournamentJoinResult(
        success: data['success'] ?? false,
        tourneyId: data['tourneyId'],
        position: data['queuePosition'],
        estimatedWaitTime: data['estimatedWaitTime'],
        message: data['message'],
      );
    } catch (e) {
      print('❌ Error joining tournament: $e');
      return TournamentJoinResult(
        success: false,
        message: 'Failed to join tournament: ${e.toString()}',
      );
    }
  }

  @override
  Future<Tournament?> getTournament(String tourneyId) async {
    try {
      // Try getting from appropriate shard
      final shardId = _getShardId(tourneyId);
      final doc = await _firestore
          .collection('tournaments_$shardId')
          .doc(tourneyId)
          .get();

      if (!doc.exists) return null;

      return Tournament.fromFirestore(doc);
    } catch (e) {
      print('❌ Error getting tournament: $e');
      return null;
    }
  }

  @override
  Stream<Tournament> watchTournament(String tourneyId) {
    final shardId = _getShardId(tourneyId);
    return _firestore
        .collection('tournaments_$shardId')
        .doc(tourneyId)
        .snapshots()
        .map((doc) => Tournament.fromFirestore(doc));
  }

  @override
  Future<void> submitResult(String tourneyId, GameResult result) async {
    try {
      final callable = _functions.httpsCallable('submitTournamentResult');
      await callable.call({
        'tourneyId': tourneyId,
        'userId': _userId,
        'result': result.toMap(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ Result submitted for tournament $tourneyId');
    } catch (e) {
      print('❌ Error submitting result: $e');
      rethrow;
    }
  }

  @override
  Future<List<TournamentResult>> getTournamentResults(String tourneyId) async {
    try {
      final callable = _functions.httpsCallable('getTournamentResults');
      final result = await callable.call({
        'tourneyId': tourneyId,
        'userId': _userId,
      });

      final data = result.data as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>;

      return results
          .map((r) => TournamentResult.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting results: $e');
      return [];
    }
  }

  // Simple sharding based on tournament ID
  String _getShardId(String tourneyId) {
    final hash = tourneyId.hashCode.abs();
    return (hash % 50).toString(); // 10 shards for now
  }
}

// Data models
enum GameType { timing, memory }

class TournamentJoinResult {
  final bool success;
  final String? tourneyId;
  final int? position;
  final int? estimatedWaitTime;
  final String? message;

  TournamentJoinResult({
    required this.success,
    this.tourneyId,
    this.position,
    this.estimatedWaitTime,
    this.message,
  });
}

class Tournament {
  final String id;
  final GameType gameType;
  final TournamentStatus status;
  final List<String> players;
  final int playerCount;
  final int maxPlayers;
  final DateTime createdAt;
  final int? currentRound;
  final Map<String, dynamic> metadata;

  Tournament({
    required this.id,
    required this.gameType,
    required this.status,
    required this.players,
    required this.playerCount,
    required this.maxPlayers,
    required this.createdAt,
    this.currentRound,
    this.metadata = const {},
  });

  factory Tournament.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tournament(
      id: doc.id,
      gameType: GameType.values.firstWhere(
            (type) => type.name == data['gameType'],
        orElse: () => GameType.timing,
      ),
      status: TournamentStatus.values.firstWhere(
            (status) => status.name == data['status'],
        orElse: () => TournamentStatus.waiting,
      ),
      players: List<String>.from(data['players'] ?? []),
      playerCount: data['playerCount'] ?? 0,
      maxPlayers: data['maxPlayers'] ?? 64,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentRound: data['currentRound'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameType': gameType.name,
      'status': status.name,
      'players': players,
      'playerCount': playerCount,
      'maxPlayers': maxPlayers,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentRound': currentRound,
      'metadata': metadata,
    };
  }
}

enum TournamentStatus { waiting, active, completed }

abstract class GameResult {
  Map<String, dynamic> toMap();
}

class TimingResult extends GameResult {
  final int errorMs;
  final int targetMs;
  final DateTime timestamp;

  TimingResult({
    required this.errorMs,
    required this.targetMs,
    required this.timestamp,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'timing',
      'errorMs': errorMs,
      'targetMs': targetMs,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class MemoryResult extends GameResult {
  final int level;
  final int completionTimeMs;
  final DateTime timestamp;

  MemoryResult({
    required this.level,
    required this.completionTimeMs,
    required this.timestamp,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'memory',
      'level': level,
      'completionTimeMs': completionTimeMs,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class TournamentResult {
  final String userId;
  final int rank;
  final GameResult result;
  final bool isBot;

  TournamentResult({
    required this.userId,
    required this.rank,
    required this.result,
    required this.isBot,
  });

  factory TournamentResult.fromMap(Map<String, dynamic> map) {
    GameResult result;
    final resultType = map['result']['type'] as String;

    if (resultType == 'timing') {
      result = TimingResult(
        errorMs: map['result']['errorMs'],
        targetMs: map['result']['targetMs'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['result']['timestamp']),
      );
    } else {
      result = MemoryResult(
        level: map['result']['level'],
        completionTimeMs: map['result']['completionTimeMs'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['result']['timestamp']),
      );
    }

    return TournamentResult(
      userId: map['userId'],
      rank: map['rank'],
      result: result,
      isBot: map['isBot'] ?? false,
    );
  }
}

// Singleton service for easy access
class TournamentService {
  static TournamentRepository? _repository;

  static TournamentRepository get instance {
    _repository ??= CloudFunctionsTournamentRepository();
    return _repository!;
  }

  // Easy to swap implementations later
  static void setRepository(TournamentRepository repository) {
    _repository = repository;
  }
}