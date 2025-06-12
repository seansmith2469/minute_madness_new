// lib/screens/lobby_screen.dart - FIXED 10 SECOND COUNTER TO 64
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/tournament_setup_screen.dart';
import '../main.dart' show targetDuration, psychedelicPalette, backgroundSwapDuration;
import '../services/bot_service.dart';
import 'precision_tap_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  String? _tourneyId;
  bool _isNavigating = false;

  // FIXED: Enforce exactly 64 players always
  static const int TOURNAMENT_SIZE = 64;

  // Bot management
  Timer? _fillTimer;
  Timer? _displayTimer;
  DateTime? _tournamentCreatedTime;
  List<BotPlayer> _tournamentBots = [];
  int _displayedPlayerCount = 0;
  int _actualPlayerCount = 0;

  // Animation controllers for INTENSE psychedelic effects
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  @override
  void initState() {
    super.initState();

    // Initialize INTENSE psychedelic background
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    // FASTER, more intense background animation
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

    // More intense pulsing
    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Faster pulse
    )..repeat(reverse: true);

    // Faster rotation for more intensity
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Faster rotation
    )..repeat();

    // Scale animation for elements
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinOrCreate();
    });
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    // INTENSIFIED: More vibrant, saturated colors
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
      Colors.deepOrange.shade700,
      Colors.deepPurple.shade700,
    ];

    return List.generate(
        6, (_) => vibrantColors[random.nextInt(vibrantColors.length)]); // More colors for complexity
  }

  Future<void> _joinOrCreate() async {
    try {
      print('Starting _joinOrCreate for tournament (TOURNAMENT_SIZE: $TOURNAMENT_SIZE)');

      final snap = await _db
          .collection('tournaments')
          .where('status', isEqualTo: 'waiting')
          .where('playerCount', isLessThan: TOURNAMENT_SIZE)
          .limit(1)
          .get();

      DocumentReference doc;
      if (snap.docs.isEmpty) {
        print('Creating new tournament (max $TOURNAMENT_SIZE players)');
        doc = await _db.collection('tournaments').add({
          'status': 'waiting',
          'round': 0,
          'players': [_uid],
          'playerCount': 1,
          'maxPlayers': TOURNAMENT_SIZE, // Store max for consistency
          'createdAt': FieldValue.serverTimestamp(),
          'bots': <String, dynamic>{},
        });
        _tournamentCreatedTime = DateTime.now();
        print('Created tournament with ID: ${doc.id}');
        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = 1;
            _displayedPlayerCount = 1;
          });
        }
        _startAutoFillTimer();
      } else {
        print('Joining existing tournament');
        doc = snap.docs.first.reference;

        final tourneyData = snap.docs.first.data() as Map<String, dynamic>;
        final currentCount = tourneyData['playerCount'] as int? ?? 1;

        // Double-check we won't exceed limit
        if (currentCount >= TOURNAMENT_SIZE) {
          print('Tournament is full, creating new one instead');
          doc = await _db.collection('tournaments').add({
            'status': 'waiting',
            'round': 0,
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

        print('Joined tournament ${doc.id} with ${currentCount + 1} players');

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
      print('Error joining/creating tournament: $e');
      try {
        final doc = await _db.collection('tournaments').add({
          'status': 'waiting',
          'round': 0,
          'players': [_uid],
          'playerCount': 1,
          'maxPlayers': TOURNAMENT_SIZE,
          'createdAt': FieldValue.serverTimestamp(),
          'bots': <String, dynamic>{},
        });
        _tournamentCreatedTime = DateTime.now();
        print('Created fallback tournament: ${doc.id}');
        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = 1;
            _displayedPlayerCount = 1;
          });
        }
        _startAutoFillTimer();
      } catch (e2) {
        print('Failed to create fallback tournament: $e2');
      }
    }
  }

  void _startAutoFillTimer() {
    if (_tournamentCreatedTime == null) return;

    print('Starting auto-fill timer for tournament $_tourneyId (max $TOURNAMENT_SIZE)');

    // FIXED: Much more aggressive bot filling to reach 64 in 10 seconds
    _fillTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) { // Every 0.5 seconds
      print('Checking if bots needed...');
      _checkAndAddBots();
    });

    _startGradualDisplay();

    // FIXED: 20-second timer (10 for players + 10 for ad)
    Timer(const Duration(seconds: 20), () {
      print('20 seconds reached - force starting tournament');
      _forceStartTournament();
    });
  }

  void _startGradualDisplay() {
    // FIXED: Display updates every 0.2 seconds for smooth counting
    _displayTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_displayedPlayerCount < _actualPlayerCount) {
        setState(() {
          final remaining = _actualPlayerCount - _displayedPlayerCount;
          // More aggressive increment to reach 64 in 10 seconds
          final increment = remaining > 30 ? 3 : remaining > 10 ? 2 : 1;
          _displayedPlayerCount = math.min(_displayedPlayerCount + increment, _actualPlayerCount);
        });
      }
    });
  }

  Future<void> _checkAndAddBots() async {
    if (_tourneyId == null || _tournamentCreatedTime == null) {
      print('No tournament ID or creation time');
      return;
    }

    final waitTime = DateTime.now().difference(_tournamentCreatedTime!);
    final secondsElapsed = waitTime.inSeconds;
    print('Wait time: $secondsElapsed seconds');

    final tourneyDoc = await _db.collection('tournaments').doc(_tourneyId!).get();
    final data = tourneyDoc.data();
    if (data == null) {
      print('No tournament data found');
      return;
    }

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    print('Current count: $currentCount/$TOURNAMENT_SIZE, Status: $status');

    if (status != 'waiting' || currentCount >= TOURNAMENT_SIZE) {
      print('Tournament not waiting or already full');
      return;
    }

    // FIXED: Aggressive progression to reach 64 players in exactly 10 seconds
    int targetCount = currentCount; // Never reduce

    if (secondsElapsed <= 10) {
      // Linear progression to 64 over 10 seconds
      final progressRatio = secondsElapsed / 10.0;
      targetCount = math.max(currentCount, (TOURNAMENT_SIZE * progressRatio).round());

      // Ensure we hit key milestones
      if (secondsElapsed >= 2 && targetCount < 16) targetCount = 16;   // 16 by 2 seconds
      if (secondsElapsed >= 4 && targetCount < 32) targetCount = 32;   // 32 by 4 seconds
      if (secondsElapsed >= 6 && targetCount < 48) targetCount = 48;   // 48 by 6 seconds
      if (secondsElapsed >= 8 && targetCount < 56) targetCount = 56;   // 56 by 8 seconds
      if (secondsElapsed >= 10) targetCount = TOURNAMENT_SIZE;         // 64 by 10 seconds

      print('${secondsElapsed}s: Target $targetCount players (progress: ${(progressRatio * 100).toInt()}%)');
    }

    // Add bots if we're below target and below max
    if (targetCount > currentCount && currentCount < TOURNAMENT_SIZE) {
      final botsToAdd = math.min(targetCount - currentCount, TOURNAMENT_SIZE - currentCount);
      print('Adding $botsToAdd bots to reach $targetCount (current: $currentCount)');
      try {
        final newBots = await BotService.addBotsToTournament(_tourneyId!, botsToAdd);
        _tournamentBots.addAll(newBots);
        print('Successfully added ${newBots.length} bots');

        if (mounted) {
          setState(() {
            _actualPlayerCount = math.min(targetCount, TOURNAMENT_SIZE);
          });
        }
      } catch (e) {
        print('Error adding bots: $e');
      }
    } else {
      print('No bots needed - at target or full ($currentCount >= $targetCount or $currentCount >= $TOURNAMENT_SIZE)');
    }
  }

  Future<void> _forceStartTournament() async {
    if (_tourneyId == null) return;

    final tourneyDoc = await _db.collection('tournaments').doc(_tourneyId!).get();
    final data = tourneyDoc.data();
    if (data == null) return;

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    if (status != 'waiting') return;

    // FIXED: Ensure exactly TOURNAMENT_SIZE players before starting
    if (currentCount < TOURNAMENT_SIZE) {
      final botsToAdd = TOURNAMENT_SIZE - currentCount;
      print('Force filling with $botsToAdd bots to reach exactly $TOURNAMENT_SIZE players');
      final newBots = await BotService.addBotsToTournament(_tourneyId!, botsToAdd);
      _tournamentBots.addAll(newBots);
    }

    // Verify final count before starting
    final finalDoc = await _db.collection('tournaments').doc(_tourneyId!).get();
    final finalData = finalDoc.data();
    final finalCount = finalData?['playerCount'] as int? ?? 0;

    print('Final verification: $finalCount players before starting tournament');

    await _db.collection('tournaments').doc(_tourneyId!).update({
      'status': 'round',
      'round': 1,
      'finalPlayerCount': finalCount, // Store final count for results
    });
  }

  void _navigateToGame(int round) {
    if (_isNavigating || !mounted) return;

    _isNavigating = true;
    _submitAllBotResults(round);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PrecisionTapScreen(
          target: targetDuration,
          tourneyId: _tourneyId ?? 'test_tourney_id',
          round: round,
        ),
      ),
    );
  }

  Future<void> _submitAllBotResults(int round) async {
    try {
      final tourneyDoc = await _db.collection('tournaments').doc(_tourneyId!).get();
      final data = tourneyDoc.data();
      if (data == null || !data.containsKey('bots')) return;

      final botsData = data['bots'] as Map<String, dynamic>;
      final allBots = botsData.entries.map((entry) {
        final botData = entry.value as Map<String, dynamic>;
        return BotPlayer(
          id: entry.key,
          name: botData['name'],
          difficulty: BotDifficulty.values.firstWhere(
                (d) => d.name == botData['difficulty'],
          ),
        );
      }).toList();

      if (allBots.isNotEmpty) {
        BotService.submitBotResults(_tourneyId!, round, allBots, targetDuration);
      }
    } catch (e) {
      print('Error getting tournament bots: $e');
    }
  }

  @override
  void dispose() {
    _fillTimer?.cancel();
    _displayTimer?.cancel();
    _backgroundController.dispose();
    _pulsController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Lobby build called, tourneyId: $_tourneyId');

    if (_tourneyId == null) {
      print('Tournament ID is null, showing loading screen');
      return _buildPsychedelicLoadingScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('tournaments').doc(_tourneyId!).snapshots(),
      builder: (ctx, snap) {
        print('StreamBuilder update - hasData: ${snap.hasData}');

        if (!snap.hasData) {
          print('No snapshot data, showing loading screen');
          return _buildPsychedelicLoadingScreen();
        }

        final data = snap.data!.data();
        if (data == null) {
          print('Snapshot data is null, showing error screen');
          return _buildErrorScreen();
        }

        final tournamentData = data as Map<String, dynamic>;
        final status = tournamentData['status'] as String? ?? 'waiting';
        final count = tournamentData['playerCount'] as int? ?? 0;

        print('Tournament status: $status, count: $count/$TOURNAMENT_SIZE');

        // Update actual count without setState during build
        if (_actualPlayerCount != count) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _actualPlayerCount = math.min(count, TOURNAMENT_SIZE); // Cap at TOURNAMENT_SIZE
              });
            }
          });
        }

        switch (status) {
          case 'waiting':
            print('Status is waiting, showing waiting screen with $_displayedPlayerCount players');
            return _buildWaitingScreen(math.min(_displayedPlayerCount, TOURNAMENT_SIZE));

          case 'round':
            final round = tournamentData['round'] as int? ?? 1;
            print('Status is round, navigating to game');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateToGame(round);
            });
            return _buildStartingScreen();

          default:
            print('Unknown status: $status, showing error screen');
            return _buildErrorScreen();
        }
      },
    );
  }

  Widget _buildPsychedelicLoadingScreen() {
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
              // PRIMARY PSYCHEDELIC BACKGROUND
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

              // ROTATING OVERLAY 1 - More intense
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[1].withOpacity(0.6),
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

              // COUNTER-ROTATING OVERLAY 2
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

              // PULSING OVERLAY
              AnimatedBuilder(
                animation: _pulsController,
                builder: (context, child) {
                  final intensity = 0.4 + (_pulsController.value * 0.4);
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          interpolatedColors[0].withOpacity(intensity),
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(intensity * 0.7),
                          Colors.transparent,
                          interpolatedColors[4].withOpacity(intensity * 0.5),
                        ],
                        center: Alignment.center,
                        radius: 1.5 + (_pulsController.value * 0.5),
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
                    // MEGA PSYCHEDELIC SPINNING ICON
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
                                      Icons.psychology,
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

                    // PSYCHEDELIC LOADING TEXT WITH EFFECTS
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
                              'LOADING TOURNAMENT',
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
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // ANIMATED DOTS
                    AnimatedBuilder(
                      animation: _pulsController,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final delay = index * 0.2;
                            final opacity = (0.3 +
                                (math.sin((_pulsController.value * 2 * math.pi) + delay) + 1) / 2 * 0.7);

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: interpolatedColors[index % interpolatedColors.length]
                                    .withOpacity(opacity),
                                boxShadow: [
                                  BoxShadow(
                                    color: interpolatedColors[index % interpolatedColors.length]
                                        .withOpacity(opacity * 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
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
    // FIXED: Always show out of TOURNAMENT_SIZE
    final cappedCount = math.min(count, TOURNAMENT_SIZE);

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
              // PRIMARY PSYCHEDELIC BACKGROUND
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

              // TRIPLE ROTATING OVERLAYS FOR MAXIMUM PSYCHEDELIA
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

              AnimatedBuilder(
                animation: _scaleController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[0].withOpacity(0.3),
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(0.25),
                          Colors.transparent,
                          interpolatedColors[4].withOpacity(0.2),
                          Colors.transparent,
                        ],
                        center: Alignment.center,
                        transform: GradientRotation(_scaleController.value * 3.14),
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
                      // PSYCHEDELIC TITLE WITH INTENSE EFFECTS
                      AnimatedBuilder(
                        animation: _scaleController,
                        builder: (context, child) {
                          final titleScale = 1.0 + (_scaleController.value * 0.1);
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
                                'TOURNAMENT LOBBY',
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

                      // ULTRA INTENSE PULSING PLAYER COUNTER
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulsController.value * 0.4); // More intense pulse
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
                                      '$cappedCount',
                                      style: GoogleFonts.chicle(
                                        fontSize: 72, // Even bigger
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
                                    '$cappedCount/$TOURNAMENT_SIZE JOINED',
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

                      const SizedBox(height: 50),

                      // PSYCHEDELIC LOADING INDICATOR
                      AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(7, (index) {
                              final delay = index * 0.3;
                              final rotationOffset = (_rotationController.value + delay) % 1.0;
                              final scale = 0.5 + (math.sin(rotationOffset * 2 * math.pi) + 1) / 2 * 0.8;

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                child: Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          interpolatedColors[index % interpolatedColors.length].withOpacity(0.9),
                                          interpolatedColors[index % interpolatedColors.length].withOpacity(0.5),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: interpolatedColors[index % interpolatedColors.length].withOpacity(0.6),
                                          blurRadius: 12,
                                          spreadRadius: 3,
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

                      const SizedBox(height: 30),

                      // STATUS TEXT WITH PSYCHEDELIC EFFECTS
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final textOpacity = 0.7 + (_pulsController.value * 0.3);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.4),
                                  Colors.purple.withOpacity(0.3),
                                  Colors.black.withOpacity(0.4),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Players joining the tournament...',
                              style: GoogleFonts.chicle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(textOpacity),
                                shadows: [
                                  Shadow(
                                    color: Colors.purple.withOpacity(0.8),
                                    blurRadius: 8,
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
              animation: _scaleController,
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
                      transform: GradientRotation(_scaleController.value * 6.28),
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
                        final scale = 1.0 + (_pulsController.value * 0.4); // More intense
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.orange.withOpacity(0.9),
                                  Colors.red.withOpacity(0.8),
                                  Colors.yellow.withOpacity(0.7),
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
                              Icons.rocket_launch,
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
                          Colors.orange,
                          Colors.red,
                          Colors.yellow,
                          Colors.pink,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'BLAST OFF!',
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
                      'The tournament begins...',
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
                'Cosmic interference detected...',
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