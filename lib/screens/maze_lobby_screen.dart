// lib/screens/maze_lobby_screen.dart - FIXED MAZE MADNESS LOBBY
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import '../services/maze_bot_service.dart';
import 'maze_game_screen.dart';

class MazeLobbyScreen extends StatefulWidget {
  const MazeLobbyScreen({super.key});

  @override
  State<MazeLobbyScreen> createState() => _MazeLobbyScreenState();
}

class _MazeLobbyScreenState extends State<MazeLobbyScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  String? _survivalId;
  bool _isNavigating = false;

  // SURVIVAL CONSTANTS
  static const int MAX_PLAYERS = 64; // Maximum allowed

  // Bot management
  Timer? _fillTimer;
  Timer? _displayTimer;
  DateTime? _survivalCreatedTime;
  List<MazeBotPlayer> _survivalBots = [];
  int _displayedPlayerCount = 0;
  int _actualPlayerCount = 0;

  // Animation controllers for INTENSE psychedelic effects
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _rotationController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  @override
  void initState() {
    super.initState();

    // Initialize INTENSE psychedelic background
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _backgroundController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinOrCreateSurvival();
    });
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    final mazeColors = [
      Colors.purple.shade800,
      Colors.pink.shade600,
      Colors.indigo.shade700,
      Colors.blue.shade700,
      Colors.cyan.shade500,
      Colors.teal.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.red.shade700,
      Colors.deepPurple.shade700,
    ];

    return List.generate(
        6, (_) => mazeColors[random.nextInt(mazeColors.length)]);
  }

  Future<void> _joinOrCreateSurvival() async {
    try {
      print('🧩 Starting _joinOrCreateSurvival for maze survival (MAX_PLAYERS: $MAX_PLAYERS)');

      final snap = await _db
          .collection('maze_survival')
          .where('status', isEqualTo: 'waiting')
          .where('playerCount', isLessThan: MAX_PLAYERS)
          .limit(1)
          .get();

      DocumentReference doc;
      if (snap.docs.isEmpty) {
        print('🧩 Creating new maze survival (max $MAX_PLAYERS players)');
        doc = await _db.collection('maze_survival').add({
          'status': 'waiting',
          'round': 0,
          'players': [_uid],
          'playerCount': 1,
          'maxPlayers': MAX_PLAYERS,
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'maze_madness',
          'bots': <String, dynamic>{},
        });
        _survivalCreatedTime = DateTime.now();
        print('🧩 Created survival with ID: ${doc.id}');
        if (mounted) {
          setState(() {
            _survivalId = doc.id;
            _actualPlayerCount = 1;
            _displayedPlayerCount = 1;
          });
        }
        _startAutoFillTimer();
      } else {
        print('🧩 Joining existing maze survival');
        doc = snap.docs.first.reference;

        final survivalData = snap.docs.first.data() as Map<String, dynamic>;
        final currentCount = survivalData['playerCount'] as int? ?? 1;

        if (currentCount >= MAX_PLAYERS) {
          print('🧩 Survival is full, creating new one instead');
          doc = await _db.collection('maze_survival').add({
            'status': 'waiting',
            'round': 0,
            'players': [_uid],
            'playerCount': 1,
            'maxPlayers': MAX_PLAYERS,
            'createdAt': FieldValue.serverTimestamp(),
            'gameType': 'maze_madness',
            'bots': <String, dynamic>{},
          });
          _survivalCreatedTime = DateTime.now();
          if (mounted) {
            setState(() {
              _survivalId = doc.id;
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

        if (survivalData.containsKey('createdAt') && survivalData['createdAt'] != null) {
          final timestamp = survivalData['createdAt'] as Timestamp;
          _survivalCreatedTime = timestamp.toDate();
        } else {
          _survivalCreatedTime = DateTime.now();
        }

        print('🧩 Joined survival ${doc.id} with ${currentCount + 1} players');

        if (mounted) {
          setState(() {
            _survivalId = doc.id;
            _actualPlayerCount = currentCount + 1;
            _displayedPlayerCount = currentCount + 1;
          });
        }

        _startAutoFillTimer();
      }
    } catch (e) {
      print('🧩 Error joining/creating maze survival: $e');
      try {
        final doc = await _db.collection('maze_survival').add({
          'status': 'waiting',
          'round': 0,
          'players': [_uid],
          'playerCount': 1,
          'maxPlayers': MAX_PLAYERS,
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'maze_madness',
          'bots': <String, dynamic>{},
        });
        _survivalCreatedTime = DateTime.now();
        print('🧩 Created fallback survival: ${doc.id}');
        if (mounted) {
          setState(() {
            _survivalId = doc.id;
            _actualPlayerCount = 1;
            _displayedPlayerCount = 1;
          });
        }
        _startAutoFillTimer();
      } catch (e2) {
        print('🧩 Failed to create fallback survival: $e2');
      }
    }
  }

  void _startAutoFillTimer() {
    if (_survivalCreatedTime == null) return;

    print('🧩 Starting auto-fill timer for maze survival $_survivalId (max $MAX_PLAYERS)');

    _fillTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _checkAndAddBots();
    });

    _startGradualDisplay();

    Timer(const Duration(seconds: 20), () {
      print('🧩 20 seconds reached - force starting survival');
      _forceStartSurvival();
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
    if (_survivalId == null || _survivalCreatedTime == null) {
      print('🧩 No survival ID or creation time');
      return;
    }

    final waitTime = DateTime.now().difference(_survivalCreatedTime!);
    final secondsElapsed = waitTime.inSeconds;

    final survivalDoc = await _db.collection('maze_survival').doc(_survivalId!).get();
    final data = survivalDoc.data();
    if (data == null) {
      print('🧩 No survival data found');
      return;
    }

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    print('🧩 Current count: $currentCount/$MAX_PLAYERS, Status: $status, Elapsed: ${secondsElapsed}s');

    if (status != 'waiting' || currentCount >= MAX_PLAYERS) {
      print('🧩 Survival not waiting or already full');
      return;
    }

    int targetCount = currentCount;

    if (secondsElapsed <= 10) {
      final progressRatio = secondsElapsed / 10.0;
      targetCount = math.max(currentCount, (MAX_PLAYERS * progressRatio).round());

      if (secondsElapsed >= 2 && targetCount < 16) targetCount = 16;
      if (secondsElapsed >= 4 && targetCount < 32) targetCount = 32;
      if (secondsElapsed >= 6 && targetCount < 48) targetCount = 48;
      if (secondsElapsed >= 8 && targetCount < 56) targetCount = 56;
      if (secondsElapsed >= 10) targetCount = MAX_PLAYERS;

      print('🧩 ${secondsElapsed}s: Target $targetCount players (progress: ${(progressRatio * 100).toInt()}%)');
    }

    if (targetCount > currentCount && currentCount < MAX_PLAYERS) {
      final botsToAdd = math.min(targetCount - currentCount, MAX_PLAYERS - currentCount);
      print('🧩 Adding $botsToAdd bots to reach $targetCount (current: $currentCount)');
      try {
        final newBots = await MazeBotService.addBotsToSurvival(_survivalId!, botsToAdd);
        _survivalBots.addAll(newBots);
        print('🧩 Successfully added ${newBots.length} bots');

        if (mounted) {
          setState(() {
            _actualPlayerCount = math.min(targetCount, MAX_PLAYERS);
          });
        }
      } catch (e) {
        print('🧩 Error adding bots: $e');
      }
    }
  }

  Future<void> _forceStartSurvival() async {
    if (_survivalId == null) return;

    final survivalDoc = await _db.collection('maze_survival').doc(_survivalId!).get();
    final data = survivalDoc.data();
    if (data == null) return;

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    if (status != 'waiting') return;

    if (currentCount < MAX_PLAYERS) {
      final botsToAdd = MAX_PLAYERS - currentCount;
      print('🧩 Force filling with $botsToAdd bots to reach exactly $MAX_PLAYERS players');
      final newBots = await MazeBotService.addBotsToSurvival(_survivalId!, botsToAdd);
      _survivalBots.addAll(newBots);
    }

    final finalDoc = await _db.collection('maze_survival').doc(_survivalId!).get();
    final finalData = finalDoc.data();
    final finalCount = finalData?['playerCount'] as int? ?? 0;

    print('🧩 Final verification: $finalCount players before starting survival');

    await _db.collection('maze_survival').doc(_survivalId!).update({
      'status': 'round',
      'round': 1,
      'finalPlayerCount': finalCount,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  void _navigateToGame(int round) {
    if (_isNavigating || !mounted) return;

    _isNavigating = true;

    print('🧩 Navigating to maze game with survival ID: $_survivalId, round: $round');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MazeGameScreen(
          isPractice: false,
          survivalId: _survivalId ?? 'maze_survival',
          round: round,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fillTimer?.cancel();
    _displayTimer?.cancel();
    _backgroundController.dispose();
    _pulsController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🧩 Maze lobby build called, survivalId: $_survivalId');

    if (_survivalId == null) {
      print('🧩 Survival ID is null, showing loading screen');
      return _buildLoadingScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('maze_survival').doc(_survivalId!).snapshots(),
      builder: (ctx, snap) {
        print('🧩 StreamBuilder update - hasData: ${snap.hasData}');

        if (!snap.hasData) {
          print('🧩 No snapshot data, showing loading screen');
          return _buildLoadingScreen();
        }

        final data = snap.data!.data();
        if (data == null) {
          print('🧩 Snapshot data is null, showing error screen');
          return _buildErrorScreen();
        }

        final survivalData = data as Map<String, dynamic>;
        final status = survivalData['status'] as String? ?? 'waiting';
        final count = survivalData['playerCount'] as int? ?? 0;
        final round = survivalData['round'] as int? ?? 0;

        print('🧩 Survival status: $status, count: $count/$MAX_PLAYERS, round: $round');

        if (_actualPlayerCount != count) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _actualPlayerCount = math.min(count, MAX_PLAYERS);
              });
            }
          });
        }

        switch (status) {
          case 'waiting':
            print('🧩 Status is waiting, showing waiting screen with $_displayedPlayerCount players');
            return _buildWaitingScreen(math.min(_displayedPlayerCount, MAX_PLAYERS));

          case 'round':
            print('🧩 Status is round, navigating to game (round $round)');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateToGame(round);
            });
            return _buildStartingScreen();

          default:
            print('🧩 Unknown status: $status, showing error screen');
            return _buildErrorScreen();
        }
      },
    );
  }

  Widget _buildLoadingScreen() {
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

          return Stack(
            children: [
              // PSYCHEDELIC BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 2.0,
                    stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // ROTATING OVERLAY
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(0.3),
                          Colors.transparent,
                          interpolatedColors[4].withOpacity(0.2),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_rotationController.value * 6.28),
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
                    // SPINNING MAZE ICON
                    AnimatedBuilder(
                      animation: _rotationController,
                      builder: (context, child) {
                        return AnimatedBuilder(
                          animation: _pulsController,
                          builder: (context, child) {
                            final scale = 1.0 + (_pulsController.value * 0.3);
                            final rotation = _rotationController.value * 2 * math.pi;

                            return Transform.scale(
                              scale: scale,
                              child: Transform.rotate(
                                angle: rotation,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        Colors.red.withOpacity(0.9),
                                        Colors.orange.withOpacity(0.9),
                                        Colors.yellow.withOpacity(0.9),
                                        Colors.green.withOpacity(0.9),
                                        Colors.blue.withOpacity(0.9),
                                        Colors.indigo.withOpacity(0.9),
                                        Colors.purple.withOpacity(0.9),
                                        Colors.pink.withOpacity(0.9),
                                        Colors.red.withOpacity(0.9),
                                      ],
                                      transform: GradientRotation(rotation),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.6),
                                        blurRadius: 30,
                                        spreadRadius: 10,
                                      ),
                                      BoxShadow(
                                        color: interpolatedColors[1].withOpacity(0.8),
                                        blurRadius: 50,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(15),
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
                                      Icons.explore,
                                      size: 80,
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

                    const SizedBox(height: 40),

                    // LOADING TEXT
                    AnimatedBuilder(
                      animation: _pulsController,
                      builder: (context, child) {
                        final textScale = 1.0 + (_pulsController.value * 0.1);
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
                                Colors.indigo,
                                Colors.purple,
                                Colors.pink,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              transform: GradientRotation(_rotationController.value * 3.14),
                            ).createShader(bounds),
                            child: Text(
                              'CREATING MAZE SURVIVAL',
                              style: GoogleFonts.creepster(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.9),
                                    blurRadius: 15,
                                    offset: const Offset(4, 4),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // BACK BUTTON
              Positioned(
                top: 40,
                left: 20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWaitingScreen(int count) {
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

          return Stack(
            children: [
              // PSYCHEDELIC BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 2.0,
                    stops: [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // MULTIPLE ROTATING OVERLAYS
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[1].withOpacity(0.5),
                          Colors.transparent,
                          interpolatedColors[3].withOpacity(0.4),
                          Colors.transparent,
                          interpolatedColors[5].withOpacity(0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_rotationController.value * 6.28),
                      ),
                    ),
                  );
                },
              ),

              // COUNTER-ROTATING OVERLAY
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(0.4),
                          Colors.transparent,
                          interpolatedColors[4].withOpacity(0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        transform: GradientRotation(-_rotationController.value * 4.28),
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
                      // PSYCHEDELIC TITLE
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final titleScale = 1.0 + (_pulsController.value * 0.1);
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
                                  Colors.indigo,
                                  Colors.purple,
                                  Colors.pink,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                transform: GradientRotation(_rotationController.value * 2.0),
                              ).createShader(bounds),
                              child: Text(
                                'MAZE SURVIVAL',
                                style: GoogleFonts.creepster(
                                  fontSize: 36,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.9),
                                      blurRadius: 15,
                                      offset: const Offset(4, 4),
                                    ),
                                    Shadow(
                                      color: Colors.purple.withOpacity(0.8),
                                      blurRadius: 25,
                                      offset: const Offset(-3, -3),
                                    ),
                                    Shadow(
                                      color: Colors.cyan.withOpacity(0.6),
                                      blurRadius: 35,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 50),

                      // PLAYER COUNTER
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulsController.value * 0.4);
                          final glowIntensity = 0.6 + (_pulsController.value * 0.6);

                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 25),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(35),
                                gradient: RadialGradient(
                                  colors: [
                                    interpolatedColors[0].withOpacity(0.95),
                                    interpolatedColors[2].withOpacity(0.85),
                                    interpolatedColors[4].withOpacity(0.75),
                                    interpolatedColors[1].withOpacity(0.65),
                                  ],
                                  stops: [0.0, 0.3, 0.6, 1.0],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(glowIntensity),
                                    blurRadius: 35,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: interpolatedColors[1].withOpacity(0.8),
                                    blurRadius: 50,
                                    spreadRadius: 5,
                                  ),
                                  BoxShadow(
                                    color: interpolatedColors[3].withOpacity(0.6),
                                    blurRadius: 70,
                                    spreadRadius: 3,
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
                                        Colors.red,
                                      ],
                                    ).createShader(bounds),
                                    child: Text(
                                      '$count',
                                      style: GoogleFonts.chicle(
                                        fontSize: 72,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
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
                                  const SizedBox(height: 10),
                                  Text(
                                    '$count/$MAX_PLAYERS EXPLORERS',
                                    style: GoogleFonts.chicle(
                                      fontSize: 22,
                                      color: Colors.white.withOpacity(0.95),
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // GAME INFO
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 30),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: RadialGradient(
                            colors: interpolatedColors.map((c) => c.withOpacity(0.3)).toList(),
                            center: Alignment.center,
                            radius: 1.0,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Last Explorer Standing',
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
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '🔮 6 rounds of increasingly complex mazes\n'
                                  '👁️ Brief study phase to memorize the layout\n'
                                  '🌑 Navigate blind through the psychedelic maze\n'
                                  '⚡ Fail a round and you\'re eliminated!\n'
                                  '🏆 Last explorer standing wins the madness',
                              style: GoogleFonts.chicle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.7),
                                    blurRadius: 3,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // BACK BUTTON
              Positioned(
                top: 40,
                left: 20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
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
                radius: 2.0,
                stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
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
                        interpolatedColors[1].withOpacity(0.4),
                        Colors.transparent,
                        interpolatedColors[3].withOpacity(0.3),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      transform: GradientRotation(_pulsController.value * 6.28),
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
                        final scale = 1.0 + (_pulsController.value * 0.4);
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
                                  color: Colors.white.withOpacity(0.6),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.explore,
                              size: 100,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
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
                        'ENTERING THE MAZE!',
                        style: GoogleFonts.creepster(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.9),
                              blurRadius: 15,
                              offset: const Offset(4, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'The maze survival begins...',
                      style: GoogleFonts.chicle(
                        fontSize: 20,
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 6,
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
                'Maze portal malfunction...',
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