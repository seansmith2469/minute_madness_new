// lib/screens/momentum_results_screen.dart - OPTIMIZED VERSION (7 ROUNDS)
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import 'game_selection_screen.dart';
import 'momentum_game_screen.dart';

class MomentumResultsScreen extends StatefulWidget {
  final String tourneyId;
  final int playerScore;
  final List<int> spinScores;
  final bool isPractice;
  final List<String> achievements;
  final double momentumMultiplier;
  final int comebackBonuses;

  const MomentumResultsScreen({
    super.key,
    required this.tourneyId,
    required this.playerScore,
    required this.spinScores,
    this.isPractice = false,
    this.achievements = const [],
    this.momentumMultiplier = 1.0,
    this.comebackBonuses = 0,
  });

  @override
  State<MomentumResultsScreen> createState() => _MomentumResultsScreenState();
}

class _MomentumResultsScreenState extends State<MomentumResultsScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  // UPDATED: 7-round tournament structure (128 players total)
  static const int TOURNAMENT_SIZE = 128; // INCREASED from 64 to 128

  // UPDATED: 7-round tournament progression
  late final Map<int, int> _playersPerRound = {
    1: 128, // Round 1: 128 players
    2: 64,  // Round 2: 64 players
    3: 32,  // Round 3: 32 players
    4: 16,  // Round 4: 16 players
    5: 8,   // Round 5: 8 players
    6: 4,   // Round 6: 4 players
    7: 2,   // Round 7: 2 players (FINAL)
  };

  // ENHANCED ANIMATION CONTROLLERS
  late AnimationController _primaryController;
  late AnimationController _pulsController;
  late AnimationController _scaleController;
  late AnimationController _achievementController;
  late AnimationController _confettiController;
  late AnimationController _statController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  bool _isLoading = true;
  int _playerRank = 0;
  int _totalPlayers = TOURNAMENT_SIZE;
  int _currentRound = 1;
  bool _playerAdvanced = false;
  bool _isChampion = false;
  List<Map<String, dynamic>> _allResults = [];

  // Enhanced visual elements
  List<ConfettiParticle> _confetti = [];
  bool _showAchievements = false;
  int _animatedScore = 0;

  @override
  void initState() {
    super.initState();

    // Initialize enhanced psychedelic background
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    // Enhanced animation controllers
    _primaryController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.momentumMultiplier > 3.0 ? 1 : 2),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _primaryController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (1500 / math.max(1.0, widget.momentumMultiplier * 0.5)).round()),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _achievementController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _statController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Only calculate results for tournament mode
    if (widget.isPractice) {
      _handlePracticeMode();
    } else {
      _calculateTournamentResults();
    }
  }

  List<Color> _generateGradient() {
    final random = math.Random();

    // Enhanced colors based on performance
    List<Color> baseColors = widget.playerScore > 3500 // UPDATED threshold for 7 spins
        ? [Colors.amber.shade700, Colors.yellow.shade600, Colors.orange.shade700, Colors.red.shade700]
        : widget.playerScore > 2800 // UPDATED threshold for 7 spins
        ? [Colors.green.shade700, Colors.lime.shade600, Colors.cyan.shade600, Colors.blue.shade700]
        : [Colors.purple.shade700, Colors.pink.shade600, Colors.indigo.shade700, Colors.blue.shade800];

    return List.generate(
        4, (_) => baseColors[random.nextInt(baseColors.length)]);
  }

  void _handlePracticeMode() {
    setState(() {
      _isLoading = false;
      _playerRank = 1;
      _totalPlayers = 1;
    });

    _scaleController.forward();
    _animateScore();

    if (widget.achievements.isNotEmpty) {
      Timer(const Duration(seconds: 1), () {
        _showAchievementCelebration();
      });
    }

    // Haptic feedback for good performance - UPDATED thresholds for 7 spins
    if (widget.playerScore >= 3500) {
      HapticFeedback.heavyImpact();
    } else if (widget.playerScore >= 2800) {
      HapticFeedback.mediumImpact();
    }

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _showPracticeCompletionDialog();
      }
    });
  }

  void _animateScore() {
    const duration = Duration(milliseconds: 2000);
    const increment = 50;

    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        if (_animatedScore < widget.playerScore) {
          _animatedScore = math.min(_animatedScore + increment, widget.playerScore);
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _showAchievementCelebration() {
    setState(() {
      _showAchievements = true;
    });

    _achievementController.forward();
    _createConfetti();
    _confettiController.forward();

    // Achievement sound simulation with haptic
    for (int i = 0; i < widget.achievements.length; i++) {
      Timer(Duration(milliseconds: i * 500), () {
        HapticFeedback.selectionClick();
      });
    }
  }

  void _createConfetti() {
    final random = math.Random();
    _confetti.clear();

    for (int i = 0; i < 50; i++) {
      _confetti.add(ConfettiParticle(
        x: random.nextDouble() * 400,
        y: -20,
        dx: (random.nextDouble() - 0.5) * 4,
        dy: random.nextDouble() * 3 + 2,
        color: [Colors.yellow, Colors.orange, Colors.red, Colors.purple, Colors.cyan][
        random.nextInt(5)
        ],
        rotation: random.nextDouble() * 6.28,
        rotationSpeed: (random.nextDouble() - 0.5) * 0.2,
      ));
    }
  }

  Future<void> _calculateTournamentResults() async {
    try {
      print('Enhanced Momentum: Calculating tournament results for ${widget.tourneyId}');

      final tourneyDoc = await _db.collection('momentum_tournaments').doc(widget.tourneyId).get();

      if (!tourneyDoc.exists) {
        print('Enhanced Momentum: tournament document does not exist');
        setState(() => _isLoading = false);
        return;
      }

      final tourneyData = tourneyDoc.data();
      if (tourneyData == null) {
        print('Enhanced Momentum: tournament data is null');
        setState(() => _isLoading = false);
        return;
      }

      final currentPlayerCount = tourneyData['playerCount'] as int? ?? 128;
      _currentRound = _getRoundFromPlayerCount(currentPlayerCount);

      print('Enhanced Momentum: Current round: $_currentRound with $currentPlayerCount players');

      // Wait for results with enhanced loading
      int attempts = 0;
      int resultCount = 0;
      final expectedResults = math.min(currentPlayerCount, _playersPerRound[_currentRound] ?? 128);

      while (attempts < 15 && resultCount < (expectedResults * 0.8)) {
        await Future.delayed(const Duration(seconds: 1));

        final resultsSnapshot = await _db
            .collection('momentum_tournaments')
            .doc(widget.tourneyId)
            .collection('results')
            .get();

        resultCount = resultsSnapshot.docs.length;
        print('Enhanced Momentum: Attempt ${attempts + 1}: Found $resultCount / $expectedResults results');

        if (resultCount >= (expectedResults * 0.8)) break;
        attempts++;
      }

      // Get final results
      final resultsSnapshot = await _db
          .collection('momentum_tournaments')
          .doc(widget.tourneyId)
          .collection('results')
          .get();

      _allResults = resultsSnapshot.docs.map((doc) {
        try {
          final data = doc.data();
          final totalScore = data['totalScore'] as int? ?? 0;
          final spinScores = List<int>.from(data['spinScores'] as List? ?? []);
          final momentum = data['momentum'] as double? ?? 1.0;
          final isBot = data['isBot'] as bool? ?? false;
          final achievements = List<String>.from(data['achievements'] as List? ?? []);

          return {
            'uid': data['uid'] as String? ?? doc.id,
            'totalScore': totalScore,
            'spinScores': spinScores,
            'momentum': momentum,
            'isBot': isBot,
            'achievements': achievements,
          };
        } catch (e) {
          return null;
        }
      }).where((result) => result != null).cast<Map<String, dynamic>>().toList();

      if (_allResults.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Sort by total score (highest to lowest)
      _allResults.sort((a, b) {
        final scoreA = a['totalScore'] as int;
        final scoreB = b['totalScore'] as int;
        return scoreB.compareTo(scoreA);
      });

      // Find player's rank
      var playerRankAmongSubmissions = _allResults.indexWhere((result) => result['uid'] == _uid) + 1;

      if (playerRankAmongSubmissions == 0) {
        setState(() => _isLoading = false);
        return;
      }

      _playerRank = playerRankAmongSubmissions;
      _totalPlayers = _allResults.length;

      // Determine advancement
      final playersAdvancing = _getAdvancingPlayers(_currentRound, _totalPlayers);
      _playerAdvanced = _playerRank <= playersAdvancing;
      _isChampion = (_currentRound == 7 && _playerRank == 1); // UPDATED: Round 7 is final

      print('Enhanced Momentum: Player rank: $_playerRank/$_totalPlayers, Round: $_currentRound, Advanced: $_playerAdvanced, Champion: $_isChampion');

      setState(() {
        _isLoading = false;
      });

      _scaleController.forward();
      _animateScore();

      // Enhanced celebrations based on performance
      if (_isChampion) {
        HapticFeedback.heavyImpact();
        _createConfetti();
        _confettiController.forward();
      } else if (_playerAdvanced) {
        HapticFeedback.mediumImpact();
      }

      if (widget.achievements.isNotEmpty) {
        Timer(const Duration(seconds: 1), () {
          _showAchievementCelebration();
        });
      }

      await Future.delayed(const Duration(seconds: 4));
      if (mounted) {
        if (_isChampion) {
          _showChampionDialog();
        } else if (_playerAdvanced) {
          _processAdvancement();
        } else {
          _showEliminationDialog();
        }
      }

    } catch (e) {
      print('Error calculating enhanced momentum results: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _getRoundFromPlayerCount(int playerCount) {
    if (playerCount > 64) return 1;
    if (playerCount > 32) return 2;
    if (playerCount > 16) return 3;
    if (playerCount > 8) return 4;
    if (playerCount > 4) return 5;
    if (playerCount > 2) return 6;
    return 7;
  }

  int _getAdvancingPlayers(int round, int totalPlayers) {
    if (round >= 7) return 1;
    final nextRoundTarget = _playersPerRound[round + 1] ?? 1;
    return math.min(nextRoundTarget, totalPlayers ~/ 2);
  }

  Future<void> _processAdvancement() async {
    try {
      print('Enhanced Momentum: Processing advancement for round $_currentRound');

      final playersAdvancing = _getAdvancingPlayers(_currentRound, _totalPlayers);
      final advancingPlayerIds = _allResults
          .take(playersAdvancing)
          .map((result) => result['uid'] as String)
          .toList();

      print('Enhanced Momentum: $playersAdvancing players advancing to round ${_currentRound + 1}');

      final batch = _db.batch();
      final resultsCollection = _db
          .collection('momentum_tournaments')
          .doc(widget.tourneyId)
          .collection('results');

      final allResultDocs = await resultsCollection.get();
      for (final doc in allResultDocs.docs) {
        batch.delete(doc.reference);
      }

      // Get current tournament data to preserve bot info
      final tourneyDoc = await _db.collection('momentum_tournaments').doc(widget.tourneyId).get();
      final tourneyData = tourneyDoc.data() as Map<String, dynamic>;
      final currentBots = tourneyData['bots'] as Map<String, dynamic>? ?? {};

      // Filter bots to only include advancing ones
      final advancingBots = <String, dynamic>{};
      for (String playerId in advancingPlayerIds) {
        if (currentBots.containsKey(playerId)) {
          advancingBots[playerId] = currentBots[playerId];
        }
      }

      // Update tournament for next round
      batch.update(_db.collection('momentum_tournaments').doc(widget.tourneyId), {
        'players': advancingPlayerIds,
        'playerCount': advancingPlayerIds.length,
        'round': _currentRound + 1,
        'status': 'waiting',
        'bots': advancingBots,
      });

      await batch.commit();

      print('Enhanced Momentum: Tournament updated for round ${_currentRound + 1}');

      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MomentumGameScreen(
                isPractice: false,
                tourneyId: widget.tourneyId,
              ),
            ),
          );
        }
      });

    } catch (e) {
      print('Error processing enhanced momentum advancement: $e');
    }
  }

  void _showPracticeCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.purple.shade900.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.yellow, Colors.orange, Colors.red],
          ).createShader(bounds),
          child: Text(
            'Momentum Mastery!',
            style: GoogleFonts.creepster(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total Score: ${widget.playerScore}\nSpin Scores: ${widget.spinScores.join(", ")}\nMax Momentum: ${widget.momentumMultiplier.toStringAsFixed(1)}x',
              style: GoogleFonts.chicle(
                fontSize: 16,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.achievements.isNotEmpty) ...[
              const SizedBox(height: 15),
              Text(
                'Achievements Unlocked:',
                style: GoogleFonts.chicle(
                  fontSize: 14,
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.achievements.map((achievement) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.yellow.withOpacity(0.6)),
                  ),
                  child: Text(
                    '🏆 $achievement',
                    style: GoogleFonts.chicle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                )).toList(),
              ),
            ],
            if (widget.comebackBonuses > 0) ...[
              const SizedBox(height: 10),
              Text(
                '🔄 Comeback Bonuses: ${widget.comebackBonuses}',
                style: GoogleFonts.chicle(
                  fontSize: 14,
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: [Colors.cyan.withOpacity(0.8), Colors.blue.withOpacity(0.8)],
              ),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text(
                'Master More Momentum',
                style: GoogleFonts.chicle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChampionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.purple.shade900.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.yellow, Colors.orange, Colors.red],
          ).createShader(bounds),
          child: Text(
            'ULTIMATE MOMENTUM CHAMPION!',
            style: GoogleFonts.creepster(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You are the ultimate Momentum Master!\n\nDefeated ${TOURNAMENT_SIZE - 1} other players across 7 intense rounds!\n\nTotal Score: ${widget.playerScore}\nMax Momentum: ${widget.momentumMultiplier.toStringAsFixed(1)}x\nSpin Scores: ${widget.spinScores.join(", ")}',
              style: GoogleFonts.chicle(
                fontSize: 16,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.achievements.isNotEmpty) ...[
              const SizedBox(height: 15),
              Text(
                'Champion Achievements:',
                style: GoogleFonts.chicle(
                  fontSize: 14,
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: widget.achievements.map((achievement) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.yellow.withOpacity(0.6)),
                  ),
                  child: Text(
                    '🏆 $achievement',
                    style: GoogleFonts.chicle(
                      fontSize: 9,
                      color: Colors.white,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: [Colors.cyan.withOpacity(0.8), Colors.blue.withOpacity(0.8)],
              ),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const GameSelectionScreen()),
                      (route) => false,
                );
              },
              child: Text(
                'Return to Games',
                style: GoogleFonts.chicle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEliminationDialog() {
    final roundName = _getRoundName(_currentRound);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.purple.shade900.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.orange, Colors.red, Colors.purple],
          ).createShader(bounds),
          child: Text(
            'Momentum Challenge Complete',
            style: GoogleFonts.creepster(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Eliminated in $roundName\n\nFinal Position: $_playerRank out of $TOURNAMENT_SIZE players\n\nTotal Score: ${widget.playerScore}\nMax Momentum: ${widget.momentumMultiplier.toStringAsFixed(1)}x\nSpin Scores: ${widget.spinScores.join(", ")}\n\n${_getEncouragementMessage()}',
              style: GoogleFonts.chicle(
                fontSize: 16,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.achievements.isNotEmpty) ...[
              const SizedBox(height: 15),
              Text(
                'Achievements Earned:',
                style: GoogleFonts.chicle(
                  fontSize: 14,
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: widget.achievements.map((achievement) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.yellow.withOpacity(0.6)),
                  ),
                  child: Text(
                    '🏆 $achievement',
                    style: GoogleFonts.chicle(
                      fontSize: 9,
                      color: Colors.white,
                    ),
                  ),
                )).toList(),
              ),
            ],
            if (widget.comebackBonuses > 0) ...[
              const SizedBox(height: 10),
              Text(
                '🔄 Comeback Bonuses: ${widget.comebackBonuses}',
                style: GoogleFonts.chicle(
                  fontSize: 14,
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: [Colors.cyan.withOpacity(0.8), Colors.blue.withOpacity(0.8)],
              ),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const GameSelectionScreen()),
                      (route) => false,
                );
              },
              child: Text(
                'Return to Games',
                style: GoogleFonts.chicle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoundName(int round) {
    switch (round) {
      case 1: return 'Round of 128';
      case 2: return 'Round of 64';
      case 3: return 'Round of 32';
      case 4: return 'Round of 16';
      case 5: return 'Quarterfinals';
      case 6: return 'Semifinals';
      case 7: return 'Finals';
      default: return 'Round $round';
    }
  }

  String _getEncouragementMessage() {
    if (widget.playerScore >= 3500) return 'Legendary momentum control!'; // Updated for 7 spins
    if (widget.playerScore >= 2800) return 'Masterful spinning technique!'; // Updated for 7 spins
    if (_playerRank <= 8) return 'Outstanding spinning skills!';
    if (_playerRank <= 16) return 'Great momentum control!';
    if (_playerRank <= 32) return 'Solid wheel mastery!';
    return 'Keep practicing your timing!';
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _pulsController.dispose();
    _scaleController.dispose();
    _achievementController.dispose();
    _confettiController.dispose();
    _statController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _primaryController,
        builder: (context, child) {
          final t = _primaryController.value;
          final interpolatedColors = <Color>[];

          for (int i = 0; i < _currentColors.length; i++) {
            interpolatedColors.add(
                Color.lerp(_currentColors[i], _nextColors[i], t) ?? _currentColors[i]
            );
          }

          return Stack(
            children: [
              // ENHANCED PSYCHEDELIC BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 1.5 + (widget.momentumMultiplier * 0.2),
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),

              // MOMENTUM-RESPONSIVE ROTATING OVERLAY
              AnimatedBuilder(
                animation: _primaryController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[1].withOpacity(0.3 + widget.momentumMultiplier * 0.1),
                          Colors.transparent,
                          interpolatedColors[3].withOpacity(0.2 + widget.momentumMultiplier * 0.05),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_primaryController.value * 6.28),
                      ),
                    ),
                  );
                },
              ),

              // CONFETTI SYSTEM
              if (_confetti.isNotEmpty)
                AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ConfettiPainter(_confetti, _confettiController.value),
                      size: Size.infinite,
                    );
                  },
                ),

              // ACHIEVEMENT OVERLAY
              if (_showAchievements)
                AnimatedBuilder(
                  animation: _achievementController,
                  builder: (context, child) {
                    final fadeIn = _achievementController.value;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.yellow.withOpacity(0.3 * fadeIn),
                            Colors.orange.withOpacity(0.2 * fadeIn),
                            Colors.transparent,
                          ],
                          center: Alignment.center,
                          radius: 2.0 * fadeIn,
                        ),
                      ),
                    );
                  },
                ),

              // MAIN CONTENT
              SafeArea(
                child: Center(
                  child: _isLoading ? _buildEnhancedLoadingWidget() : _buildEnhancedResultWidget(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEnhancedLoadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _primaryController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _primaryController.value * 2 * math.pi * widget.momentumMultiplier,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.orange, Colors.red, Colors.yellow],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.4),
                      blurRadius: 20 + (widget.momentumMultiplier * 10),
                      spreadRadius: 5 + (widget.momentumMultiplier * 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.rotate_right,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.orange, Colors.red, Colors.yellow],
          ).createShader(bounds),
          child: Text(
            widget.isPractice ? 'Momentum Analysis Complete!' : 'Analyzing Tournament Results...',
            style: GoogleFonts.creepster(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 8,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (!widget.isPractice) ...[
          const SizedBox(height: 15),
          AnimatedBuilder(
            animation: _pulsController,
            builder: (context, child) {
              final pulse = 0.8 + (_pulsController.value * 0.2);
              return Transform.scale(
                scale: pulse,
                child: Text(
                  'Processing ${widget.momentumMultiplier.toStringAsFixed(1)}x momentum performance...',
                  style: GoogleFonts.chicle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.7),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildEnhancedResultWidget() {
    if (widget.isPractice) {
      return _buildEnhancedPracticeResult();
    }
    return _buildEnhancedTournamentResult();
  }

  Widget _buildEnhancedPracticeResult() {
    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        final scale = _scaleController.value;
        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Enhanced completion icon with momentum glow
              AnimatedBuilder(
                animation: _pulsController,
                builder: (context, child) {
                  final pulseScale = 1.0 + (_pulsController.value * 0.2);
                  final glowIntensity = 0.4 + (_pulsController.value * 0.6);

                  return Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: widget.playerScore >= 3500 // Updated threshold for 7 spins
                              ? [Colors.yellow.withOpacity(0.9), Colors.orange.withOpacity(0.8), Colors.red.withOpacity(0.7)]
                              : widget.playerScore >= 2800 // Updated threshold for 7 spins
                              ? [Colors.green.withOpacity(0.9), Colors.lime.withOpacity(0.8), Colors.cyan.withOpacity(0.7)]
                              : [Colors.blue.withOpacity(0.9), Colors.purple.withOpacity(0.8), Colors.indigo.withOpacity(0.7)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(glowIntensity),
                            blurRadius: 25 + (widget.momentumMultiplier * 10),
                            spreadRadius: 8 + (widget.momentumMultiplier * 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.playerScore >= 3500 ? Icons.emoji_events :
                        widget.playerScore >= 2800 ? Icons.star : Icons.check_circle,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Enhanced title with momentum indicators
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: widget.playerScore >= 3500 // Updated threshold for 7 spins
                      ? [Colors.yellow, Colors.orange, Colors.red]
                      : widget.playerScore >= 2800 // Updated threshold for 7 spins
                      ? [Colors.green, Colors.lime, Colors.cyan]
                      : [Colors.blue, Colors.purple, Colors.indigo],
                ).createShader(bounds),
                child: Text(
                  widget.playerScore >= 3500 ? 'MOMENTUM LEGEND!' :
                  widget.playerScore >= 2800 ? 'MOMENTUM MASTER!' : 'PRACTICE COMPLETE!',
                  style: GoogleFonts.creepster(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.9),
                        blurRadius: 12,
                        offset: const Offset(4, 4),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 30),

              // Enhanced stats container
              Container(
                padding: const EdgeInsets.all(25),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.purple.withOpacity(0.3),
                      Colors.cyan.withOpacity(0.2),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Animated score display
                    AnimatedBuilder(
                      animation: _statController,
                      builder: (context, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [Colors.yellow, Colors.orange],
                          ).createShader(bounds),
                          child: Text(
                            'Score: $_animatedScore',
                            style: GoogleFonts.chicle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.8),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 15),

                    // Enhanced momentum display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.speed,
                          color: Colors.cyan,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Max Momentum: ${widget.momentumMultiplier.toStringAsFixed(1)}x',
                          style: GoogleFonts.chicle(
                            fontSize: 18,
                            color: Colors.cyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Spin breakdown - OPTIMIZED for 7 spins
                    Text(
                      'Spins: ${widget.spinScores.join(" • ")}',
                      style: GoogleFonts.chicle(
                        fontSize: 14, // Reduced font size for 7 spins
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 3,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),

                    if (widget.comebackBonuses > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Comeback Bonuses: ${widget.comebackBonuses}',
                            style: GoogleFonts.chicle(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 15),

                    // Performance message - UPDATED for 7 spins
                    Text(
                      widget.playerScore >= 3500
                          ? 'Perfect momentum mastery!\nReady to dominate tournaments!'
                          : widget.playerScore >= 2800
                          ? 'Excellent control!\nTournament ready!'
                          : widget.playerScore >= 2100
                          ? 'Great improvement!\nKeep building momentum!'
                          : 'Good foundation!\nPractice makes perfect!',
                      style: GoogleFonts.chicle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 3,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Achievement display
              if (widget.achievements.isNotEmpty) ...[
                const SizedBox(height: 25),
                AnimatedBuilder(
                  animation: _achievementController,
                  builder: (context, child) {
                    final scale = 0.5 + (_achievementController.value * 0.5);
                    final opacity = _achievementController.value;

                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.symmetric(horizontal: 30),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.yellow.withOpacity(0.3),
                                Colors.orange.withOpacity(0.2),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.yellow.withOpacity(0.6),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '🏆 ACHIEVEMENTS UNLOCKED! 🏆',
                                style: GoogleFonts.creepster(
                                  fontSize: 18,
                                  color: Colors.yellow,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: widget.achievements.map((achievement) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.yellow.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    achievement,
                                    style: GoogleFonts.chicle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnhancedTournamentResult() {
    final isWinner = _isChampion;
    final isAdvancing = _playerAdvanced && !_isChampion;
    final isTopTen = _playerRank <= 10;
    final isTopHalf = _playerRank <= (TOURNAMENT_SIZE ~/ 2);
    final roundName = _getRoundName(_currentRound);

    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        final scale = _scaleController.value;
        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Enhanced result icon with momentum effects
              AnimatedBuilder(
                animation: _pulsController,
                builder: (context, child) {
                  final pulseScale = 1.0 + (_pulsController.value * 0.3);
                  final glowIntensity = 0.4 + (_pulsController.value * 0.6);

                  return Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: isWinner
                              ? [Colors.yellow.withOpacity(0.9), Colors.orange.withOpacity(0.8), Colors.red.withOpacity(0.7)]
                              : isAdvancing
                              ? [Colors.green.withOpacity(0.9), Colors.lime.withOpacity(0.8), Colors.cyan.withOpacity(0.7)]
                              : isTopHalf
                              ? [Colors.blue.withOpacity(0.9), Colors.cyan.withOpacity(0.8), Colors.purple.withOpacity(0.7)]
                              : [Colors.purple.withOpacity(0.9), Colors.pink.withOpacity(0.8), Colors.indigo.withOpacity(0.7)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(glowIntensity),
                            blurRadius: 25 + (widget.momentumMultiplier * 15),
                            spreadRadius: 8 + (widget.momentumMultiplier * 4),
                          ),
                          BoxShadow(
                            color: isWinner ? Colors.yellow.withOpacity(0.6) :
                            isAdvancing ? Colors.green.withOpacity(0.6) : Colors.purple.withOpacity(0.6),
                            blurRadius: 35 + (widget.momentumMultiplier * 20),
                            spreadRadius: 5 + (widget.momentumMultiplier * 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isWinner ? Icons.emoji_events :
                        isAdvancing ? Icons.arrow_upward :
                        isTopHalf ? Icons.star_half : Icons.rotate_right,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Enhanced main result text with momentum indicators
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: isWinner
                      ? [Colors.yellow, Colors.orange, Colors.red, Colors.pink]
                      : isAdvancing
                      ? [Colors.green, Colors.lime, Colors.cyan, Colors.blue]
                      : [Colors.purple, Colors.pink, Colors.cyan, Colors.blue],
                ).createShader(bounds),
                child: Text(
                  isWinner ? 'ULTIMATE MOMENTUM CHAMPION!' :
                  isAdvancing ? 'ADVANCED WITH MOMENTUM!' : 'MOMENTUM CHALLENGE COMPLETE',
                  style: GoogleFonts.creepster(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.9),
                        blurRadius: 12,
                        offset: const Offset(4, 4),
                      ),
                      Shadow(
                        color: isWinner ? Colors.yellow.withOpacity(0.7) : Colors.purple.withOpacity(0.7),
                        blurRadius: 16,
                        offset: const Offset(-3, -3),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              // Round and placement text
              Text(
                isWinner ? 'Perfect Momentum Mastery!' :
                isAdvancing ? 'Advancing to ${_getRoundName(_currentRound + 1)}' :
                'Eliminated in $roundName',
                style: GoogleFonts.chicle(
                  fontSize: 20,
                  color: Colors.white.withOpacity(0.9),
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 6,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                '$_playerRank / $TOURNAMENT_SIZE', // Shows rank out of 128 players
                style: GoogleFonts.chicle(
                  fontSize: 28,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 6,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Enhanced performance details with momentum stats
              Container(
                padding: const EdgeInsets.all(25),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.purple.withOpacity(0.3),
                      Colors.cyan.withOpacity(0.2),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Animated score
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.yellow, Colors.orange],
                      ).createShader(bounds),
                      child: Text(
                        'Score: $_animatedScore',
                        style: GoogleFonts.chicle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.8),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Enhanced momentum display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.speed,
                          color: widget.momentumMultiplier > 3.0 ? Colors.red :
                          widget.momentumMultiplier > 2.0 ? Colors.orange : Colors.cyan,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Peak Momentum: ${widget.momentumMultiplier.toStringAsFixed(1)}x',
                          style: GoogleFonts.chicle(
                            fontSize: 18,
                            color: widget.momentumMultiplier > 3.0 ? Colors.red :
                            widget.momentumMultiplier > 2.0 ? Colors.orange : Colors.cyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Spins: ${widget.spinScores.join(" • ")}',
                      style: GoogleFonts.chicle(
                        fontSize: 14, // Reduced for 7 spins
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 3,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),

                    if (widget.comebackBonuses > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Comeback Bonuses: ${widget.comebackBonuses}',
                            style: GoogleFonts.chicle(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 15),

                    Text(
                      isWinner
                          ? 'Perfect momentum mastery!\nDefeated ${TOURNAMENT_SIZE - 1} opponents across 7 rounds!\nMax Momentum: ${widget.momentumMultiplier.toStringAsFixed(1)}x achieved!'
                          : isAdvancing
                          ? 'Excellent momentum control!\nAdvancing with ${widget.momentumMultiplier.toStringAsFixed(1)}x peak momentum!'
                          : isTopTen
                          ? 'Outstanding performance!\nTop ${(_playerRank / TOURNAMENT_SIZE * 100).round()}% finish with ${widget.momentumMultiplier.toStringAsFixed(1)}x momentum!'
                          : isTopHalf
                          ? 'Solid momentum effort!\nAbove average finish!'
                          : 'Good momentum foundation!\nKeep building your skills!',
                      style: GoogleFonts.chicle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 3,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Achievement display for tournaments
              if (widget.achievements.isNotEmpty) ...[
                const SizedBox(height: 25),
                AnimatedBuilder(
                  animation: _achievementController,
                  builder: (context, child) {
                    final scale = 0.5 + (_achievementController.value * 0.5);
                    final opacity = _achievementController.value;

                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          margin: const EdgeInsets.symmetric(horizontal: 30),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.yellow.withOpacity(0.3),
                                Colors.orange.withOpacity(0.2),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.yellow.withOpacity(0.6),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '🏆 TOURNAMENT ACHIEVEMENTS 🏆',
                                style: GoogleFonts.creepster(
                                  fontSize: 16,
                                  color: Colors.yellow,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: widget.achievements.map((achievement) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.yellow.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    achievement,
                                    style: GoogleFonts.chicle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 30),

              // Next round or encouragement text
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.cyan.withOpacity(0.1),
                      Colors.purple.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  isWinner
                      ? 'Legendary Momentum Master!'
                      : isAdvancing
                      ? 'Momentum building... Next round incoming!'
                      : _getEncouragementMessage(),
                  style: GoogleFonts.chicle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.95),
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ConfettiParticle {
  double x, y, dx, dy, rotation, rotationSpeed;
  Color color;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> confetti;
  final double animation;

  ConfettiPainter(this.confetti, this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in confetti) {
      final currentX = particle.x + (particle.dx * animation * 200);
      final currentY = particle.y + (particle.dy * animation * 400);
      final currentRotation = particle.rotation + (particle.rotationSpeed * animation * 10);

      if (currentY > size.height + 20) continue;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRotation);

      final paint = Paint()
        ..color = particle.color.withOpacity(1.0 - (animation * 0.5))
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-6, -2, 12, 4),
          const Radius.circular(2),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}