// lib/screens/memory_results_screen.dart - NO EMOJIS VERSION
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import 'game_selection_screen.dart';

class MemoryResultsScreen extends StatefulWidget {
  final String tourneyId;
  final int playerLevel;

  const MemoryResultsScreen({
    super.key,
    required this.tourneyId,
    required this.playerLevel,
  });

  @override
  State<MemoryResultsScreen> createState() => _MemoryResultsScreenState();
}

class _MemoryResultsScreenState extends State<MemoryResultsScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  static const int TOURNAMENT_SIZE = 64;

  // INTENSE animation controllers
  late AnimationController _backgroundController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _pulsController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  bool _isLoading = true;
  int _playerRank = 0;
  int _totalPlayers = TOURNAMENT_SIZE;
  List<Map<String, dynamic>> _allResults = [];

  @override
  void initState() {
    super.initState();

    // Initialize INTENSE psychedelic background
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Faster like main screen
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _backgroundController.forward(from: 0);
      }
    })..forward();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _calculateResults();
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    // INTENSIFIED: More vibrant colors for results
    final vibrantColors = [
      Colors.purple.shade700,
      Colors.pink.shade600,
      Colors.indigo.shade700,
      Colors.blue.shade700,
      Colors.cyan.shade500,
      Colors.teal.shade600,
      Colors.green.shade600,
      Colors.lime.shade500,
      Colors.deepPurple.shade700,
      Colors.deepOrange.shade600,
      Colors.red.shade700,
      Colors.orange.shade600,
    ];

    return List.generate(
        6, (_) => vibrantColors[random.nextInt(vibrantColors.length)]);
  }

  Future<void> _calculateResults() async {
    try {
      // [Keep existing calculation logic]
      final tourneyDoc = await _db.collection('memory_tournaments').doc(widget.tourneyId).get();
      final tourneyData = tourneyDoc.data();

      if (tourneyData != null) {
        final actualPlayerCount = tourneyData['playerCount'] as int? ?? TOURNAMENT_SIZE;
        final finalPlayerCount = tourneyData['finalPlayerCount'] as int? ?? actualPlayerCount;
      }

      int attempts = 0;
      int resultCount = 0;

      while (attempts < 15 && resultCount < (TOURNAMENT_SIZE * 0.8)) {
        await Future.delayed(const Duration(seconds: 1));

        final resultsSnapshot = await _db
            .collection('memory_tournaments')
            .doc(widget.tourneyId)
            .collection('results')
            .get();

        resultCount = resultsSnapshot.docs.length;

        if (resultCount >= (TOURNAMENT_SIZE * 0.8)) break;
        attempts++;
      }

      final resultsSnapshot = await _db
          .collection('memory_tournaments')
          .doc(widget.tourneyId)
          .collection('results')
          .get();

      _allResults = resultsSnapshot.docs.map((doc) {
        try {
          final data = doc.data();
          final level = data['level'] as int? ?? 0;
          final isBot = data['isBot'] as bool? ?? false;
          final completionTimeMs = data['completionTimeMs'] as int? ?? 999999;

          return {
            'uid': data['uid'] as String? ?? doc.id,
            'level': level,
            'completionTimeMs': completionTimeMs,
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

      _allResults.sort((a, b) {
        final levelA = a['level'] as int;
        final levelB = b['level'] as int;

        if (levelA != levelB) {
          return levelB.compareTo(levelA);
        }

        final timeA = a['completionTimeMs'] as int;
        final timeB = b['completionTimeMs'] as int;
        return timeA.compareTo(timeB);
      });

      var playerRankAmongSubmissions = _allResults.indexWhere((result) => result['uid'] == _uid) + 1;

      if (playerRankAmongSubmissions == 0) {
        setState(() => _isLoading = false);
        return;
      }

      _playerRank = playerRankAmongSubmissions;

      final levelReached = widget.playerLevel;
      int estimatedSurvivors;

      if (levelReached <= 1) estimatedSurvivors = 64;
      else if (levelReached <= 2) estimatedSurvivors = 45;
      else if (levelReached <= 3) estimatedSurvivors = 25;
      else if (levelReached <= 4) estimatedSurvivors = 12;
      else if (levelReached <= 5) estimatedSurvivors = 6;
      else if (levelReached <= 6) estimatedSurvivors = 4;
      else if (levelReached <= 7) estimatedSurvivors = 3;
      else if (levelReached <= 10) estimatedSurvivors = 2;
      else estimatedSurvivors = 1;

      _totalPlayers = math.max(estimatedSurvivors, _allResults.length);

      if (_playerRank > estimatedSurvivors) {
        _playerRank = estimatedSurvivors;
      }

      setState(() {
        _isLoading = false;
      });

      _scaleController.forward();

      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        _showFinalDialog();
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFinalDialog() {
    final isWinner = _playerRank == 1;
    final isTopTen = _playerRank <= 10;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.purple.shade900.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isWinner
                ? [Colors.yellow, Colors.orange, Colors.red]
                : [Colors.purple, Colors.pink, Colors.cyan],
          ).createShader(bounds),
          child: Text(
            isWinner ? 'MEMORY CHAMPION!' : 'Memory Challenge Complete',
            style: GoogleFonts.creepster(
              fontSize: 18,
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
        content: Text(
          isWinner
              ? 'You are the ultimate Memory Master!\n\nLevel ${widget.playerLevel} reached!\n\nDefeated ${TOURNAMENT_SIZE - 1} other players!'
              : 'You finished $_playerRank out of $TOURNAMENT_SIZE players.\n\nLevel ${widget.playerLevel} reached!\n\n${isTopTen ? 'Excellent memory skills!' : 'Great effort!'}',
          style: GoogleFonts.chicle(
            fontSize: 16,
            color: Colors.white,
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

  @override
  void dispose() {
    _backgroundController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _pulsController.dispose();
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
                stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
            // ADDED: Multiple animated overlays
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        interpolatedColors[1].withOpacity(0.3),
                        Colors.transparent,
                        interpolatedColors[3].withOpacity(0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      transform: GradientRotation(_rotationController.value * 6.28),
                    ),
                  ),
                  child: child,
                );
              },
              child: SafeArea(
                child: Center(
                  child: _isLoading ? _buildLoadingWidget() : _buildResultWidget(),
                ),
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
          animation: _rotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationController.value * 2 * math.pi,
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
                  Icons.psychology,
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
            'Analyzing Memory Results...',
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
        const SizedBox(height: 10),
        Text(
          'Calculating final rankings...',
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
    );
  }

  Widget _buildResultWidget() {
    final isWinner = _playerRank == 1;
    final isTopTen = _playerRank <= 10;
    final isTopHalf = _playerRank <= (TOURNAMENT_SIZE ~/ 2);

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
                              : isTopTen
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
                        isWinner ? Icons.emoji_events : Icons.psychology,
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
                      : [Colors.purple, Colors.pink, Colors.cyan, Colors.blue],
                ).createShader(bounds),
                child: Text(
                  isWinner ? 'MEMORY CHAMPION!' : 'YOU FINISHED',
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

              // Placement text
              if (!isWinner)
                Text(
                  '$_playerRank / $TOURNAMENT_SIZE',
                  style: GoogleFonts.chicle(
                    fontSize: 28,
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
                      'Level Reached: ${widget.playerLevel}',
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
                    const SizedBox(height: 15),
                    Text(
                      isWinner
                          ? 'Perfect memory mastery!\nDefeated ${TOURNAMENT_SIZE - 1} opponents!'
                          : isTopTen
                          ? 'Exceptional memory skills!\nTop ${(_playerRank / TOURNAMENT_SIZE * 100).round()}% finish!'
                          : isTopHalf
                          ? 'Great memory performance!\nAbove average finish!'
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

                    if (!isWinner) ...[
                      const SizedBox(height: 15),
                      Text(
                        'Tournament Size: $TOURNAMENT_SIZE players',
                        style: GoogleFonts.chicle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 2,
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // PSYCHEDELIC encouragement text
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
                      ? 'Ultimate Memory Champion!'
                      : isTopTen
                      ? 'Outstanding Performance!'
                      : isTopHalf
                      ? 'Well Done!'
                      : 'Keep Practicing!',
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