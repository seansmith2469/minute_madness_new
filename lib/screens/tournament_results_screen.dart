// lib/screens/tournament_results_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration, targetDuration;
import 'precision_tap_screen.dart';
import 'duration_select_screen.dart';

class TournamentResultsScreen extends StatefulWidget {
  final String tourneyId;
  final int round;
  final Duration playerTime;
  final Duration playerError;

  const TournamentResultsScreen({
    super.key,
    required this.tourneyId,
    required this.round,
    required this.playerTime,
    required this.playerError,
  });

  @override
  State<TournamentResultsScreen> createState() => _TournamentResultsScreenState();
}

class _TournamentResultsScreenState extends State<TournamentResultsScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _scaleController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  bool _isLoading = true;
  int _playerRank = 0;
  int _totalPlayers = 0;
  bool _advanced = false;
  List<Map<String, dynamic>> _allResults = [];

  @override
  void initState() {
    super.initState();

    // Initialize psychedelic background
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    // Animations
    _backgroundController = AnimationController(
      vsync: this,
      duration: backgroundSwapDuration,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _backgroundController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _calculateResults();
  }

  List<Color> _generateGradient() {
    final random = Random();
    return List.generate(
        4, (_) => psychedelicPalette[random.nextInt(psychedelicPalette.length)]);
  }

  Future<void> _calculateResults() async {
    try {
      print('Calculating results for tournament ${widget.tourneyId}, round ${widget.round}');

      // Get expected player count from tournament document
      final tourneyDoc = await _db.collection('tournaments').doc(widget.tourneyId).get();

      if (!tourneyDoc.exists) {
        print('Tournament document does not exist');
        setState(() => _isLoading = false);
        return;
      }

      final tourneyData = tourneyDoc.data();
      if (tourneyData == null) {
        print('Tournament data is null');
        setState(() => _isLoading = false);
        return;
      }

      final expectedPlayerCount = tourneyData['playerCount'] as int? ?? 0;

      if (expectedPlayerCount == 0) {
        print('No players expected in tournament');
        setState(() => _isLoading = false);
        return;
      }

      print('Expected $expectedPlayerCount players in this round');

      // Wait for results to come in, checking every second
      int attempts = 0;
      int resultCount = 0;

      while (attempts < 25 && resultCount < expectedPlayerCount) {
        await Future.delayed(const Duration(seconds: 1));

        final resultsSnapshot = await _db
            .collection('tournaments')
            .doc(widget.tourneyId)
            .collection('rounds')
            .doc('round_${widget.round}')
            .collection('results')
            .get();

        resultCount = resultsSnapshot.docs.length;
        print('Attempt ${attempts + 1}: Found $resultCount / $expectedPlayerCount results');

        // If we have at least 90% of expected results, proceed
        if (resultCount >= (expectedPlayerCount * 0.9).ceil()) {
          print('Have enough results ($resultCount), proceeding...');
          break;
        }
        attempts++;
      }

      // Get final results
      final resultsSnapshot = await _db
          .collection('tournaments')
          .doc(widget.tourneyId)
          .collection('rounds')
          .doc('round_${widget.round}')
          .collection('results')
          .get();

      print('Final count: ${resultsSnapshot.docs.length} total results');

      _allResults = resultsSnapshot.docs.map((doc) {
        try {
          final data = doc.data();
          final errorMs = data['errorMs'] as int? ?? 0;
          final isBot = data['isBot'] as bool? ?? false;

          return {
            'uid': data['uid'] as String? ?? doc.id,
            'errorMs': errorMs,
            'absErrorMs': errorMs.abs(),
            'isBot': isBot,
          };
        } catch (e) {
          print('Error parsing result for ${doc.id}: $e');
          return null;
        }
      }).where((result) => result != null).cast<Map<String, dynamic>>().toList();

      if (_allResults.isEmpty) {
        print('No valid results found');
        setState(() => _isLoading = false);
        return;
      }

      // Sort by absolute error (best to worst)
      _allResults.sort((a, b) =>
          (a['absErrorMs'] as int).compareTo(b['absErrorMs'] as int));

      // Find player's rank
      _playerRank = _allResults.indexWhere((result) => result['uid'] == _uid) + 1;
      _totalPlayers = _allResults.length;

      if (_playerRank == 0) {
        print('Player not found in results');
        setState(() => _isLoading = false);
        return;
      }

      print('Player rank: $_playerRank out of $_totalPlayers');

      // Determine if player advanced
      final playersAdvancing = _totalPlayers ~/ 2;
      _advanced = _playerRank <= playersAdvancing;

      print('Player ${_advanced ? 'ADVANCED' : 'ELIMINATED'} (top $playersAdvancing advance)');

      setState(() {
        _isLoading = false;
      });

      // Start result animation
      _scaleController.forward();

      // Process tournament advancement
      if (_advanced) {
        _processAdvancement();
      } else {
        // Tournament over for this player
        _endTournamentForPlayer();
      }

    } catch (e) {
      print('Error calculating results: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processAdvancement() async {
    try {
      // Get top half of players who advance
      final playersAdvancing = _totalPlayers ~/ 2;
      final advancingPlayerIds = _allResults
          .take(playersAdvancing)
          .map((result) => result['uid'] as String)
          .toList();

      print('Advancing ${advancingPlayerIds.length} players to next round');

      // Get current tournament data to preserve bot info
      final tourneyDoc = await _db.collection('tournaments').doc(widget.tourneyId).get();
      final tourneyData = tourneyDoc.data() as Map<String, dynamic>;
      final currentBots = tourneyData['bots'] as Map<String, dynamic>? ?? {};

      // Filter bots to only include advancing ones
      final advancingBots = <String, dynamic>{};
      for (String playerId in advancingPlayerIds) {
        if (currentBots.containsKey(playerId)) {
          advancingBots[playerId] = currentBots[playerId];
        }
      }

      // Update tournament with advancing players
      await _db.collection('tournaments').doc(widget.tourneyId).update({
        'players': advancingPlayerIds,
        'playerCount': advancingPlayerIds.length,
        'round': widget.round + 1,
        'status': 'round', // Keep status as 'round' for next round
        'bots': advancingBots, // Only keep advancing bots
      });

      print('Updated tournament: ${advancingPlayerIds.length} players advancing to round ${widget.round + 1}');

      // Check if this was the final
      if (playersAdvancing == 1) {
        _showChampionDialog();
      } else {
        // Wait then start next round
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          _startNextRound();
        }
      }
    } catch (e) {
      print('Error processing advancement: $e');
    }
  }

  Future<void> _endTournamentForPlayer() async {
    // Player is eliminated - show final result
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      _showFinalResult();
    }
  }

  void _startNextRound() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PrecisionTapScreen(
          target: targetDuration,
          tourneyId: widget.tourneyId,
          round: widget.round + 1,
        ),
      ),
    );
  }

  void _showChampionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.purple.shade900,
        title: Text(
          'CHAMPION!',
          style: GoogleFonts.chicle(
            fontSize: 24,
            color: Colors.yellow,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'You are the Tournament Champion!\n\nCongratulations!',
          style: GoogleFonts.chicle(
            fontSize: 18,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DurationSelectScreen()),
                    (route) => false,
              );
            },
            child: Text(
              'Return to Main Menu',
              style: GoogleFonts.chicle(color: Colors.yellow),
            ),
          ),
        ],
      ),
    );
  }

  void _showFinalResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.purple.shade900,
        title: Text(
          'Tournament Complete',
          style: GoogleFonts.chicle(
            fontSize: 20,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'You finished $_playerRank out of $_totalPlayers players.\n\nGreat effort!',
          style: GoogleFonts.chicle(
            fontSize: 16,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DurationSelectScreen()),
                    (route) => false,
              );
            },
            child: Text(
              'Return to Main Menu',
              style: GoogleFonts.chicle(color: Colors.cyan),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulsController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          final t = _backgroundController.value;
          final interpolatedColors = <Color>[];

          for (int i = 0; i < _currentColors.length; i++) {
            interpolatedColors.add(
                Color.lerp(_currentColors[i], _nextColors[i], t) ?? _currentColors[i]
            );
          }

          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: interpolatedColors,
                center: Alignment.center,
                radius: 1.5,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: _isLoading ? _buildLoadingWidget() : _buildResultWidget(),
              ),
            ),
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
          animation: _pulsController,
          builder: (context, child) {
            final scale = 1.0 + (_pulsController.value * 0.2);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.cyan],
                  ),
                ),
                child: const Icon(
                  Icons.calculate,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        Text(
          'Calculating Results...',
          style: GoogleFonts.chicle(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildResultWidget() {
    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        final scale = _scaleController.value;
        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _advanced
                        ? [Colors.green, Colors.lime]
                        : [Colors.orange, Colors.red],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _advanced ? Icons.arrow_upward : Icons.sports_score,
                  size: 60,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 40),

              // Main result text
              Text(
                _advanced ? 'YOU ADVANCED!' : 'YOU FINISHED',
                style: GoogleFonts.chicle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: _advanced ? Colors.green : Colors.orange,
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Placement text
              Text(
                _advanced
                    ? 'Top $_playerRank out of $_totalPlayers players'
                    : '$_playerRank / $_totalPlayers',
                style: GoogleFonts.chicle(
                  fontSize: 24,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),

              const SizedBox(height: 30),

              // Performance details
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withOpacity(0.3),
                ),
                child: Column(
                  children: [
                    Text(
                      'Your Time: ${_formatDuration(widget.playerTime)}',
                      style: GoogleFonts.chicle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      'Error: ${widget.playerError.inMilliseconds > 0 ? '+' : ''}${widget.playerError.inMilliseconds}ms',
                      style: GoogleFonts.chicle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              if (_advanced && _totalPlayers > 2) ...[
                const SizedBox(height: 40),
                Text(
                  'Next round starting soon...',
                  style: GoogleFonts.chicle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final milliseconds = duration.inMilliseconds % 1000;
    return '${seconds}.${milliseconds.toString().padLeft(3, '0')}s';
  }
}