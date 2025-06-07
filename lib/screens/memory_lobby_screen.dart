// lib/screens/memory_lobby_screen.dart - OPTIMIZED PART 1 (Lines 1-300)
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import '../services/memory_bot_service.dart';
import 'memory_game_screen.dart';

class MemoryLobbyScreen extends StatefulWidget {
  const MemoryLobbyScreen({super.key});

  @override
  State<MemoryLobbyScreen> createState() => _MemoryLobbyScreenState();
}

class _MemoryLobbyScreenState extends State<MemoryLobbyScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  String? _tourneyId;
  bool _isNavigating = false;

  static const int TOURNAMENT_SIZE = 64;

  // Bot management
  Timer? _fillTimer;
  Timer? _displayTimer;
  DateTime? _tournamentCreatedTime;
  List<MemoryBotPlayer> _tournamentBots = [];
  int _displayedPlayerCount = 0;
  int _actualPlayerCount = 0;

  // OPTIMIZED: Reduced animation controllers for better performance
  late AnimationController _primaryController;  // Combined background + rotation
  late AnimationController _pulsController;     // Pulsing effects only

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  @override
  void initState() {
    super.initState();

    // Initialize INTENSE but OPTIMIZED psychedelic background
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    // OPTIMIZED: Single primary controller for background AND rotation
    _primaryController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _primaryController.forward(from: 0);
      }
    })..forward();

    // Keep pulsing separate for different timing
    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinOrCreate();
    });
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    // OPTIMIZED: Reduced color count for better performance
    final vibrantColors = [
      Colors.red.shade700,
      Colors.orange.shade600,
      Colors.yellow.shade500,
      Colors.green.shade600,
      Colors.blue.shade700,
      Colors.indigo.shade600,
      Colors.purple.shade700,
      Colors.pink.shade600,
      Colors.cyan.shade500,
      Colors.lime.shade600,
    ];

    // OPTIMIZED: Reduced from 6 to 4 colors for better performance
    return List.generate(
        4, (_) => vibrantColors[random.nextInt(vibrantColors.length)]);
  }

  Future<void> _joinOrCreate() async {
    try {
      print('Memory Starting _joinOrCreate for memory tournament (TOURNAMENT_SIZE: $TOURNAMENT_SIZE)');

      final snap = await _db
          .collection('memory_tournaments')
          .where('status', isEqualTo: 'waiting')
          .where('playerCount', isLessThan: TOURNAMENT_SIZE)
          .limit(1)
          .get();

      DocumentReference doc;
      if (snap.docs.isEmpty) {
        print('Memory Creating new memory tournament (max $TOURNAMENT_SIZE players)');
        doc = await _db.collection('memory_tournaments').add({
          'status': 'waiting',
          'players': [_uid],
          'playerCount': 1,
          'maxPlayers': TOURNAMENT_SIZE,
          'createdAt': FieldValue.serverTimestamp(),
          'bots': <String, dynamic>{},
        });
        _tournamentCreatedTime = DateTime.now();
        print('Memory Created tournament with ID: ${doc.id}');
        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = 1;
            _displayedPlayerCount = 1;
          });
        }
        _startAutoFillTimer();
      } else {
        print('Memory Joining existing memory tournament');
        doc = snap.docs.first.reference;

        final tourneyData = snap.docs.first.data() as Map<String, dynamic>;
        final currentCount = tourneyData['playerCount'] as int? ?? 1;

        if (currentCount >= TOURNAMENT_SIZE) {
          print('Memory Tournament is full, creating new one instead');
          doc = await _db.collection('memory_tournaments').add({
            'status': 'waiting',
            'players': [_uid],
            'playerCount': 1,
            'maxPlayers': TOURNAMENT_SIZE,
            'createdAt': FieldValue.serverTimestamp(),
            'bots': <String, dynamic>{},
          });
          _tournamentCreatedTime = DateTime.now();
          if (mounted) {
            setState(() {
              _tourneyId = doc.id;
              _actualPlayerCount = 1;
              _displayedPlayerCount = 1;
            });
          }
          _startAutoFillTimer();
          return;
        }

        await doc.update({
          'players': FieldValue.arrayUnion([_uid]),
          'playerCount': FieldValue.increment(1),
        });

        if (tourneyData.containsKey('createdAt') && tourneyData['createdAt'] != null) {
          final timestamp = tourneyData['createdAt'] as Timestamp;
          _tournamentCreatedTime = timestamp.toDate();
        } else {
          _tournamentCreatedTime = DateTime.now();
        }

        print('Memory Joined tournament ${doc.id} with ${currentCount + 1} players');

        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = currentCount + 1;
            _displayedPlayerCount = currentCount + 1;
          });
        }

        _startAutoFillTimer();
      }
    } catch (e) {
      print('Memory Error joining/creating memory tournament: $e');
      try {
        final doc = await _db.collection('memory_tournaments').add({
          'status': 'waiting',
          'players': [_uid],
          'playerCount': 1,
          'maxPlayers': TOURNAMENT_SIZE,
          'createdAt': FieldValue.serverTimestamp(),
          'bots': <String, dynamic>{},
        });
        _tournamentCreatedTime = DateTime.now();
        print('Memory Created fallback tournament: ${doc.id}');
        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = 1;
            _displayedPlayerCount = 1;
          });
        }
        _startAutoFillTimer();
      } catch (e2) {
        print('Memory Failed to create fallback tournament: $e2');
      }
    }
  }

  void _startAutoFillTimer() {
    if (_tournamentCreatedTime == null) return;

    print('Memory Starting auto-fill timer for memory tournament $_tourneyId (max $TOURNAMENT_SIZE)');

    _fillTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      print('Memory Checking if bots needed...');
      _checkAndAddBots();
    });

    _startGradualDisplay();

    Timer(const Duration(seconds: 20), () {
      print('Memory 20 seconds reached - force starting tournament');
      _forceStartTournament();
    });
  }

  void _startGradualDisplay() {
    _displayTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_displayedPlayerCount < _actualPlayerCount) {
        setState(() {
          final remaining = _actualPlayerCount - _displayedPlayerCount;
          final increment = remaining > 30 ? 3 : remaining > 10 ? 2 : 1;
          _displayedPlayerCount = math.min(_displayedPlayerCount + increment, _actualPlayerCount);
        });
      }
    });
  }

  Future<void> _checkAndAddBots() async {
    if (_tourneyId == null || _tournamentCreatedTime == null) {
      print('Memory No tournament ID or creation time');
      return;
    }

    final waitTime = DateTime.now().difference(_tournamentCreatedTime!);
    final secondsElapsed = waitTime.inSeconds;
    print('Memory Wait time: $secondsElapsed seconds');

    final tourneyDoc = await _db.collection('memory_tournaments').doc(_tourneyId!).get();
    final data = tourneyDoc.data();
    if (data == null) {
      print('Memory No tournament data found');
      return;
    }

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    print('Memory Current count: $currentCount/$TOURNAMENT_SIZE, Status: $status');

    if (status != 'waiting' || currentCount >= TOURNAMENT_SIZE) {
      print('Memory Tournament not waiting or already full');
      return;
    }

    int targetCount = currentCount;

    if (secondsElapsed <= 10) {
      final progressRatio = secondsElapsed / 10.0;
      targetCount = math.max(currentCount, (TOURNAMENT_SIZE * progressRatio).round());

      if (secondsElapsed >= 2 && targetCount < 16) targetCount = 16;
      if (secondsElapsed >= 4 && targetCount < 32) targetCount = 32;
      if (secondsElapsed >= 6 && targetCount < 48) targetCount = 48;
      if (secondsElapsed >= 8 && targetCount < 56) targetCount = 56;
      if (secondsElapsed >= 10) targetCount = TOURNAMENT_SIZE;

      print('Memory ${secondsElapsed}s: Target $targetCount players (progress: ${(progressRatio * 100).toInt()}%)');
    }

    if (targetCount > currentCount && currentCount < TOURNAMENT_SIZE) {
      final botsToAdd = math.min(targetCount - currentCount, TOURNAMENT_SIZE - currentCount);
      print('Memory Adding $botsToAdd bots to reach $targetCount (current: $currentCount)');
      try {
        final newBots = await MemoryBotService.addBotsToTournament(_tourneyId!, botsToAdd);
        _tournamentBots.addAll(newBots);
        print('Memory Successfully added ${newBots.length} bots');

        if (mounted) {
          setState(() {
            _actualPlayerCount = math.min(targetCount, TOURNAMENT_SIZE);
          });
        }
      } catch (e) {
        print('Memory Error adding bots: $e');
      }
    } else {
      print('Memory No bots needed - at target or full ($currentCount >= $targetCount or $currentCount >= $TOURNAMENT_SIZE)');
    }
  }

  Future<void> _forceStartTournament() async {
    if (_tourneyId == null) return;

    final tourneyDoc = await _db.collection('memory_tournaments').doc(_tourneyId!).get();
    final data = tourneyDoc.data();
    if (data == null) return;

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    if (status != 'waiting') return;

    if (currentCount < TOURNAMENT_SIZE) {
      final botsToAdd = TOURNAMENT_SIZE - currentCount;
      print('Memory Force filling with $botsToAdd bots to reach exactly $TOURNAMENT_SIZE players');
      final newBots = await MemoryBotService.addBotsToTournament(_tourneyId!, botsToAdd);
      _tournamentBots.addAll(newBots);
    }

    final finalDoc = await _db.collection('memory_tournaments').doc(_tourneyId!).get();
    final finalData = finalDoc.data();
    final finalCount = finalData?['playerCount'] as int? ?? 0;

    print('Memory Final verification: $finalCount players before starting tournament');

    await _db.collection('memory_tournaments').doc(_tourneyId!).update({
      'status': 'active',
      'finalPlayerCount': finalCount,
    });
  }

  void _navigateToGame() {
    if (_isNavigating || !mounted) return;

    _isNavigating = true;

    print('Memory Navigating to memory game with tournament ID: $_tourneyId');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MemoryGameScreen(
          isPractice: false,
          tourneyId: _tourneyId ?? 'memory_tournament',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fillTimer?.cancel();
    _displayTimer?.cancel();
    _primaryController.dispose();
    _pulsController.dispose();
    super.dispose();
  }

  // lib/screens/memory_lobby_screen.dart - OPTIMIZED PART 2 (Lines 301+)

  @override
  Widget build(BuildContext context) {
    print('Memory lobby build called, tourneyId: $_tourneyId');

    if (_tourneyId == null) {
      print('Memory Tournament ID is null, showing loading screen');
      return _buildPsychedelicLoadingScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('memory_tournaments').doc(_tourneyId!).snapshots(),
      builder: (ctx, snap) {
        print('Memory StreamBuilder update - hasData: ${snap.hasData}');

        if (!snap.hasData) {
          print('Memory No snapshot data, showing loading screen');
          return _buildPsychedelicLoadingScreen();
        }

        final data = snap.data!.data();
        if (data == null) {
          print('Memory Snapshot data is null, showing error screen');
          return _buildErrorScreen();
        }

        final tournamentData = data as Map<String, dynamic>;
        final status = tournamentData['status'] as String? ?? 'waiting';
        final count = tournamentData['playerCount'] as int? ?? 0;

        print('Memory Tournament status: $status, count: $count/$TOURNAMENT_SIZE');

        if (_actualPlayerCount != count) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _actualPlayerCount = math.min(count, TOURNAMENT_SIZE);
              });
            }
          });
        }

        switch (status) {
          case 'waiting':
            print('Memory Status is waiting, showing waiting screen with $_displayedPlayerCount players');
            return _buildWaitingScreen(math.min(_displayedPlayerCount, TOURNAMENT_SIZE));

          case 'active':
            print('Memory Status is active, navigating to game');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateToGame();
            });
            return _buildStartingScreen();

          default:
            print('Memory Unknown status: $status, showing error screen');
            return _buildErrorScreen();
        }
      },
    );
  }

  Widget _buildPsychedelicLoadingScreen() {
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
              // OPTIMIZED: Simplified background
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 1.5,
                    stops: [0.0, 0.3, 0.6, 1.0], // REDUCED stops for better performance
                  ),
                ),
              ),

              // OPTIMIZED: Single rotating overlay using primary controller
              AnimatedBuilder(
                animation: _primaryController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[1].withOpacity(0.4),
                          Colors.transparent,
                          interpolatedColors[3].withOpacity(0.3),
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

              // OPTIMIZED: Simpler pulsing overlay
              AnimatedBuilder(
                animation: _pulsController,
                builder: (context, child) {
                  final intensity = 0.3 + (_pulsController.value * 0.3);
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          interpolatedColors[0].withOpacity(intensity),
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(intensity * 0.5),
                        ],
                        center: Alignment.center,
                        radius: 1.2 + (_pulsController.value * 0.3),
                      ),
                    ),
                  );
                },
              ),

              // MAIN CONTENT
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // OPTIMIZED: Simpler spinning icon
                    AnimatedBuilder(
                      animation: _primaryController,
                      builder: (context, child) {
                        return AnimatedBuilder(
                          animation: _pulsController,
                          builder: (context, child) {
                            final scale = 1.0 + (_pulsController.value * 0.2);
                            final rotation = _primaryController.value * 2 * math.pi;

                            return Transform.scale(
                              scale: scale,
                              child: Transform.rotate(
                                angle: rotation,
                                child: Container(
                                  width: 120, // REDUCED size
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        Colors.red.withOpacity(0.9),
                                        Colors.orange.withOpacity(0.9),
                                        Colors.yellow.withOpacity(0.9),
                                        Colors.green.withOpacity(0.9),
                                        Colors.blue.withOpacity(0.9),
                                        Colors.purple.withOpacity(0.9),
                                        Colors.red.withOpacity(0.9),
                                      ],
                                      transform: GradientRotation(rotation),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.9),
                                          Colors.cyan.withOpacity(0.7),
                                          Colors.purple.withOpacity(0.5),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.psychology,
                                      size: 60,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // OPTIMIZED: Simpler text animation
                    AnimatedBuilder(
                      animation: _pulsController,
                      builder: (context, child) {
                        final textScale = 1.0 + (_pulsController.value * 0.05);
                        return Transform.scale(
                          scale: textScale,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.red,
                                Colors.orange,
                                Colors.yellow,
                                Colors.green,
                                Colors.blue,
                                Colors.purple,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              transform: GradientRotation(_primaryController.value * 2.0),
                            ).createShader(bounds),
                            child: Text(
                              'LOADING MEMORY TOURNAMENT',
                              style: GoogleFonts.creepster(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.8),
                                    blurRadius: 10,
                                    offset: const Offset(3, 3),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // OPTIMIZED: Simpler animated dots
                    AnimatedBuilder(
                      animation: _pulsController,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) { // REDUCED from 5 to 4
                            final delay = index * 0.25;
                            final opacity = (0.3 +
                                (math.sin((_pulsController.value * 2 * math.pi) + delay) + 1) / 2 * 0.6);

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: interpolatedColors[index % interpolatedColors.length]
                                    .withOpacity(opacity),
                                boxShadow: [
                                  BoxShadow(
                                    color: interpolatedColors[index % interpolatedColors.length]
                                        .withOpacity(opacity * 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWaitingScreen(int count) {
    final cappedCount = math.min(count, TOURNAMENT_SIZE);

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
              // OPTIMIZED: Simplified background
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 1.5,
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),

              // OPTIMIZED: Single overlay instead of multiple
              AnimatedBuilder(
                animation: _primaryController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[1].withOpacity(0.4),
                          Colors.transparent,
                          interpolatedColors[3].withOpacity(0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_primaryController.value * 4.0),
                      ),
                    ),
                  );
                },
              ),

              // MAIN CONTENT
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // OPTIMIZED: Simpler title animation
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final titleScale = 1.0 + (_pulsController.value * 0.05);
                          return Transform.scale(
                            scale: titleScale,
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  Colors.red,
                                  Colors.orange,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.purple,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                transform: GradientRotation(_primaryController.value * 1.5),
                              ).createShader(bounds),
                              child: Text(
                                'MEMORY TOURNAMENT LOBBY',
                                style: GoogleFonts.creepster(
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.8),
                                      blurRadius: 10,
                                      offset: const Offset(3, 3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // OPTIMIZED: Simpler counter with less intense effects
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulsController.value * 0.2);
                          final glowIntensity = 0.5 + (_pulsController.value * 0.3);

                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: RadialGradient(
                                  colors: [
                                    interpolatedColors[0].withOpacity(0.8),
                                    interpolatedColors[2].withOpacity(0.6),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.7),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(glowIntensity * 0.6),
                                    blurRadius: 20,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [
                                        Colors.white,
                                        Colors.yellow,
                                        Colors.orange,
                                      ],
                                    ).createShader(bounds),
                                    child: Text(
                                      '$cappedCount',
                                      style: GoogleFonts.chicle(
                                        fontSize: 60,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.8),
                                            blurRadius: 8,
                                            offset: const Offset(3, 3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$cappedCount/$TOURNAMENT_SIZE JOINED',
                                    style: GoogleFonts.chicle(
                                      fontSize: 18,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.7),
                                          blurRadius: 4,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // OPTIMIZED: Simpler loading indicator
                      AnimatedBuilder(
                        animation: _primaryController,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final delay = index * 0.2;
                              final rotationOffset = (_primaryController.value + delay) % 1.0;
                              final scale = 0.6 + (math.sin(rotationOffset * 2 * math.pi) + 1) / 2 * 0.6;

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                child: Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          interpolatedColors[index % interpolatedColors.length].withOpacity(0.8),
                                          interpolatedColors[index % interpolatedColors.length].withOpacity(0.4),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: interpolatedColors[index % interpolatedColors.length].withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      const SizedBox(height: 25),

                      // OPTIMIZED: Simpler status text
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final textOpacity = 0.7 + (_pulsController.value * 0.2);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.purple.withOpacity(0.2),
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Memory warriors joining the mental battle...',
                              style: GoogleFonts.chicle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(textOpacity),
                                shadows: [
                                  Shadow(
                                    color: Colors.purple.withOpacity(0.6),
                                    blurRadius: 6,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStartingScreen() {
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

          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: interpolatedColors,
                center: Alignment.center,
                radius: 1.5,
                stops: [0.0, 0.4, 0.8, 1.0],
              ),
            ),
            child: AnimatedBuilder(
              animation: _pulsController,
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
                      transform: GradientRotation(_pulsController.value * 4.0),
                    ),
                  ),
                  child: child,
                );
              },
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulsController,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulsController.value * 0.3);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.purple.withOpacity(0.9),
                                  Colors.pink.withOpacity(0.8),
                                  Colors.cyan.withOpacity(0.7),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.psychology,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 25),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.purple,
                          Colors.pink,
                          Colors.cyan,
                          Colors.blue,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'MEMORY MADNESS BEGINS!',
                        style: GoogleFonts.creepster(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.8),
                              blurRadius: 10,
                              offset: const Offset(3, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Test your mental limits...',
                      style: GoogleFonts.chicle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [Colors.red.shade700, Colors.purple.shade900, Colors.black],
            radius: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Memory circuit overload...',
                style: GoogleFonts.chicle(
                  fontSize: 24,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.red.withOpacity(0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.8),
                ),
                child: const Text('Return to Reality'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add this closing bracket to the end of the main memory_lobby_screen.dart file