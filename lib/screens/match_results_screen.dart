// lib/screens/match_results_screen.dart - MULTI-ROUND TOURNAMENT SYSTEM
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import '../config/gradient_config.dart';
import 'game_selection_screen.dart';
import 'match_game_screen.dart';

class MatchResultsScreen extends StatefulWidget {
  final String tourneyId;
  final int playerTime; // in milliseconds
  final bool isPractice;

  const MatchResultsScreen({
    super.key,
    required this.tourneyId,
    required this.playerTime,
    this.isPractice = false,
  });

  @override
  State<MatchResultsScreen> createState() => _MatchResultsScreenState();
}

class _MatchResultsScreenState extends State<MatchResultsScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  static const int TOURNAMENT_SIZE = 64;

  // Tournament progression logic
  late final Map<int, int> _playersPerRound = {
    1: 64, // Round 1: 64 players
    2: 32, // Round 2: 32 players
    3: 16, // Round 3: 16 players
    4: 8,  // Round 4: 8 players
    5: 4,  // Round 5: 4 players
    6: 2,  // Round 6: 2 players (FINAL)
  };

  // OPTIMIZED: Reduced animation controllers for better performance
  late AnimationController _primaryController;  // Combined background + rotation
  late AnimationController _pulsController;     // Pulsing effects only
  late AnimationController _scaleController;    // Result animation

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  bool _isLoading = true;
  int _playerRank = 0;
  int _totalPlayers = TOURNAMENT_SIZE;
  int _currentRound = 1;
  bool _playerAdvanced = false;
  bool _isChampion = false;
  List<Map<String, dynamic>> _allResults = [];
  int _penaltySeconds = 0;

  @override
  void initState() {
    super.initState();

    // Initialize OPTIMIZED psychedelic background using gradient config
    _currentColors = PsychedelicGradient.generateGradient(6);
    _nextColors = PsychedelicGradient.generateGradient(6);

    // OPTIMIZED: Single primary controller for background AND rotation
    _primaryController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = PsychedelicGradient.generateGradient(6);
        _primaryController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Only calculate results for tournament mode
    if (widget.isPractice) {
      _handlePracticeMode();
    } else {
      _calculateTournamentResults();
    }
  }

  void _handlePracticeMode() {
    // For practice mode, just show completion and allow restart
    setState(() {
      _isLoading = false;
      _playerRank = 1; // Always winner in practice
      _totalPlayers = 1;
    });

    _scaleController.forward();

    // Show completion dialog after a delay
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _showPracticeCompletionDialog();
      }
    });
  }

  Future<void> _calculateTournamentResults() async {
    try {
      print('Match Calculating tournament results for ${widget.tourneyId}');

      // Get current tournament state
      final tourneyDoc = await _db.collection('match_tournaments').doc(widget.tourneyId).get();

      if (!tourneyDoc.exists) {
        print('Match tournament document does not exist');
        setState(() => _isLoading = false);
        return;
      }

      final tourneyData = tourneyDoc.data();
      if (tourneyData == null) {
        print('Match tournament data is null');
        setState(() => _isLoading = false);
        return;
      }

      // Get current round from tournament data or derive from player count
      final currentPlayerCount = tourneyData['playerCount'] as int? ?? 64;
      _currentRound = _getRoundFromPlayerCount(currentPlayerCount);

      print('Match Current round: $_currentRound with $currentPlayerCount players');

      // Wait for results to come in
      int attempts = 0;
      int resultCount = 0;
      final expectedResults = math.min(currentPlayerCount, _playersPerRound[_currentRound] ?? 64);

      while (attempts < 15 && resultCount < (expectedResults * 0.8)) {
        await Future.delayed(const Duration(seconds: 1));

        final resultsSnapshot = await _db
            .collection('match_tournaments')
            .doc(widget.tourneyId)
            .collection('results')
            .get();

        resultCount = resultsSnapshot.docs.length;
        print('Match Attempt ${attempts + 1}: Found $resultCount / $expectedResults results');

        if (resultCount >= (expectedResults * 0.8)) break;
        attempts++;
      }

      // Get final results
      final resultsSnapshot = await _db
          .collection('match_tournaments')
          .doc(widget.tourneyId)
          .collection('results')
          .get();

      _allResults = resultsSnapshot.docs.map((doc) {
        try {
          final data = doc.data();
          final completionTimeMs = data['completionTimeMs'] as int? ?? 999999;
          final penaltySeconds = data['penaltySeconds'] as int? ?? 0;
          final isBot = data['isBot'] as bool? ?? false;

          return {
            'uid': data['uid'] as String? ?? doc.id,
            'completionTimeMs': completionTimeMs,
            'penaltySeconds': penaltySeconds,
            'isBot': isBot,
          };
        } catch (e) {
          return null;
        }
      }).where((result) => result != null).cast<Map<String, dynamic>>().toList();

      if (_allResults.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Sort by completion time (fastest to slowest)
      _allResults.sort((a, b) {
        final timeA = a['completionTimeMs'] as int;
        final timeB = b['completionTimeMs'] as int;
        return timeA.compareTo(timeB);
      });

      // Find player's rank and extract penalty data
      var playerRankAmongSubmissions = _allResults.indexWhere((result) => result['uid'] == _uid) + 1;

      if (playerRankAmongSubmissions == 0) {
        setState(() => _isLoading = false);
        return;
      }

      // Extract player's penalty seconds
      final playerResult = _allResults.firstWhere((result) => result['uid'] == _uid);
      _penaltySeconds = playerResult['penaltySeconds'] as int? ?? 0;

      _playerRank = playerRankAmongSubmissions;
      _totalPlayers = _allResults.length;

      // Determine advancement based on current round
      final playersAdvancing = _getAdvancingPlayers(_currentRound, _totalPlayers);
      _playerAdvanced = _playerRank <= playersAdvancing;
      _isChampion = (_currentRound == 6 && _playerRank == 1); // Champion if won final

      print('Match Player rank: $_playerRank/$_totalPlayers, Round: $_currentRound, Advanced: $_playerAdvanced, Champion: $_isChampion');

      setState(() {
        _isLoading = false;
      });

      _scaleController.forward();

      // Process advancement or completion
      await Future.delayed(const Duration(seconds: 3));
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
      print('Error calculating match results: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _getRoundFromPlayerCount(int playerCount) {
    // Determine current round based on player count
    if (playerCount > 32) return 1;
    if (playerCount > 16) return 2;
    if (playerCount > 8) return 3;
    if (playerCount > 4) return 4;
    if (playerCount > 2) return 5;
    return 6; // Final
  }

  int _getAdvancingPlayers(int round, int totalPlayers) {
    // Calculate how many players advance to next round
    if (round >= 6) return 1; // Final round - only 1 winner

    final nextRoundTarget = _playersPerRound[round + 1] ?? 1;
    return math.min(nextRoundTarget, totalPlayers ~/ 2);
  }

  Future<void> _processAdvancement() async {
    try {
      print('Match Processing advancement for round $_currentRound');

      // Get advancing players (top performers)
      final playersAdvancing = _getAdvancingPlayers(_currentRound, _totalPlayers);
      final advancingPlayerIds = _allResults
          .take(playersAdvancing)
          .map((result) => result['uid'] as String)
          .toList();

      print('Match $playersAdvancing players advancing to round ${_currentRound + 1}');

      // Clear results collection for next round
      final batch = _db.batch();
      final resultsCollection = _db
          .collection('match_tournaments')
          .doc(widget.tourneyId)
          .collection('results');

      final allResultDocs = await resultsCollection.get();
      for (final doc in allResultDocs.docs) {
        batch.delete(doc.reference);
      }

      // Get current tournament data to preserve bot info
      final tourneyDoc = await _db.collection('match_tournaments').doc(widget.tourneyId).get();
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
      batch.update(_db.collection('match_tournaments').doc(widget.tourneyId), {
        'players': advancingPlayerIds,
        'playerCount': advancingPlayerIds.length,
        'round': _currentRound + 1,
        'status': 'waiting', // Reset to waiting for next round
        'bots': advancingBots,
      });

      await batch.commit();

      print('Match Tournament updated for round ${_currentRound + 1}');

      // Navigate to next round
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MatchGameScreen(
                isPractice: false,
                tourneyId: widget.tourneyId,
              ),
            ),
          );
        }
      });

    } catch (e) {
      print('Error processing match advancement: $e');
    }
  }

  void _showPracticeCompletionDialog() {
    final timeInSeconds = (widget.playerTime / 1000).toStringAsFixed(1);

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
            'Match Complete!',
            style: GoogleFonts.creepster(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Text(
          'Completion Time: ${timeInSeconds}s\nPenalties: $_penaltySeconds\n\nAll cards matched successfully!',
          style: GoogleFonts.chicle(
            fontSize: 16,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
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
                Navigator.pop(context); // Return to match select screen
              },
              child: Text(
                'Try Again',
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
            'MATCH CHAMPION!',
            style: GoogleFonts.creepster(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Text(
          'You are the ultimate Card Master!\n\nDefeated ${TOURNAMENT_SIZE - 1} other players across 6 intense rounds!\n\nCompletion Time: ${(widget.playerTime / 1000).toStringAsFixed(1)}s\nPenalties: $_penaltySeconds',
          style: GoogleFonts.chicle(
            fontSize: 16,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
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
            'Match Challenge Complete',
            style: GoogleFonts.creepster(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Text(
          'Eliminated in $roundName\n\nFinal Position: $_playerRank out of $TOURNAMENT_SIZE players\n\nCompletion Time: ${(widget.playerTime / 1000).toStringAsFixed(1)}s\nPenalties: $_penaltySeconds\n\n${_getEncouragementMessage()}',
          style: GoogleFonts.chicle(
            fontSize: 16,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
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
      case 1: return 'Round of 64';
      case 2: return 'Round of 32';
      case 3: return 'Round of 16';
      case 4: return 'Quarterfinals';
      case 5: return 'Semifinals';
      case 6: return 'Finals';
      default: return 'Round $round';
    }
  }

  String _getEncouragementMessage() {
    if (_playerRank <= 8) return 'Outstanding performance!';
    if (_playerRank <= 16) return 'Great matching skills!';
    if (_playerRank <= 32) return 'Solid effort!';
    return 'Keep practicing!';
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _pulsController.dispose();
    _scaleController.dispose();
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
              // OPTIMIZED: Simplified background using gradient config
              Container(
                decoration: BoxDecoration(
                  gradient: PsychedelicGradient.getRadialGradient(interpolatedColors),
                ),
              ),

              // OPTIMIZED: Single rotating overlay using gradient config
              AnimatedBuilder(
                animation: _primaryController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: PsychedelicGradient.getOverlayGradient(
                        interpolatedColors,
                        _primaryController.value * 6.28,
                      ),
                    ),
                  );
                },
              ),

              // MAIN CONTENT
              SafeArea(
                child: Center(
                  child: _isLoading ? _buildLoadingWidget() : _buildResultWidget(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _primaryController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _primaryController.value * 2 * math.pi,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.purple, Colors.cyan, Colors.pink],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.style,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.purple, Colors.pink, Colors.cyan],
          ).createShader(bounds),
          child: Text(
            widget.isPractice ? 'Match Complete!' : 'Analyzing Match Results...',
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
          ),
        ),
        if (!widget.isPractice) ...[
          const SizedBox(height: 10),
          Text(
            'Calculating tournament standings...',
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
          ),
        ],
      ],
    );
  }

  Widget _buildResultWidget() {
    // For practice mode, show simple completion
    if (widget.isPractice) {
      return _buildPracticeResult();
    }

    // For tournament mode, show full ranking
    return _buildTournamentResult();
  }

  Widget _buildPracticeResult() {
    final timeInSeconds = (widget.playerTime / 1000).toStringAsFixed(1);

    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        final scale = _scaleController.value;
        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Practice completion icon
              AnimatedBuilder(
                animation: _pulsController,
                builder: (context, child) {
                  final pulseScale = 1.0 + (_pulsController.value * 0.2);
                  return Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.green.withOpacity(0.9),
                            Colors.lime.withOpacity(0.8),
                            Colors.cyan.withOpacity(0.7)
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.4),
                            blurRadius: 25,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Colors.green, Colors.lime, Colors.cyan],
                ).createShader(bounds),
                child: Text(
                  'PRACTICE COMPLETE!',
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
                ),
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(25),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.green.withOpacity(0.3),
                      Colors.cyan.withOpacity(0.2),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Your Time: ${timeInSeconds}s',
                      style: GoogleFonts.chicle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'All cards matched!\nReady for tournament?',
                      style: GoogleFonts.chicle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTournamentResult() {
    final isWinner = _isChampion;
    final isAdvancing = _playerAdvanced && !_isChampion;
    final isTopTen = _playerRank <= 10;
    final isTopHalf = _playerRank <= (TOURNAMENT_SIZE ~/ 2);
    final timeInSeconds = (widget.playerTime / 1000).toStringAsFixed(1);
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
              // PSYCHEDELIC result icon
              AnimatedBuilder(
                animation: _pulsController,
                builder: (context, child) {
                  final pulseScale = 1.0 + (_pulsController.value * 0.2);
                  return Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      width: 140,
                      height: 140,
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
                            color: Colors.white.withOpacity(0.4),
                            blurRadius: 25,
                            spreadRadius: 8,
                          ),
                          BoxShadow(
                            color: isWinner ? Colors.yellow.withOpacity(0.6) : Colors.purple.withOpacity(0.6),
                            blurRadius: 35,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        isWinner ? Icons.emoji_events :
                        isAdvancing ? Icons.arrow_upward : Icons.style,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // PSYCHEDELIC main result text
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: isWinner
                      ? [Colors.yellow, Colors.orange, Colors.red, Colors.pink]
                      : isAdvancing
                      ? [Colors.green, Colors.lime, Colors.cyan, Colors.blue]
                      : [Colors.purple, Colors.pink, Colors.cyan, Colors.blue],
                ).createShader(bounds),
                child: Text(
                  isWinner ? 'MATCH CHAMPION!' :
                  isAdvancing ? 'YOU ADVANCED!' : 'ELIMINATED',
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
                      Shadow(
                        color: isWinner ? Colors.yellow.withOpacity(0.7) : Colors.purple.withOpacity(0.7),
                        blurRadius: 16,
                        offset: const Offset(-3, -3),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Round and placement text
              Text(
                isWinner ? 'Ultimate Champion!' :
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
                '$_playerRank / $TOURNAMENT_SIZE',
                style: GoogleFonts.chicle(
                  fontSize: 24,
                  color: Colors.white.withOpacity(0.9),
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

              // PSYCHEDELIC performance details
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
                    Text(
                      'Completion Time: ${timeInSeconds}s',
                      style: GoogleFonts.chicle(
                        fontSize: 20,
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
                    const SizedBox(height: 10),
                    Text(
                      'Penalties: $_penaltySeconds',
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
                    ),
                    const SizedBox(height: 15),
                    Text(
                      isWinner
                          ? 'Perfect tarot mastery!\nDefeated ${TOURNAMENT_SIZE - 1} opponents across 6 rounds!'
                          : isAdvancing
                          ? 'Excellent matching skills!\nAdvancing to the next round!'
                          : isTopTen
                          ? 'Great card performance!\nTop ${(_playerRank / TOURNAMENT_SIZE * 100).round()}% finish!'
                          : isTopHalf
                          ? 'Solid effort!\nAbove average finish!'
                          : 'Good effort!\nRoom for improvement!',
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
                      ? 'Ultimate Card Champion!'
                      : isAdvancing
                      ? 'Next round starting soon...'
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