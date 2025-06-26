// lib/screens/ultimate_tournament_lobby_screen.dart - ULTIMATE TOURNAMENT OF TOURNAMENTS
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import '../services/ultimate_tournament_service.dart';
import 'ultimate_tournament_game_screen.dart';
import '../models/game_type.dart';


class UltimateTournamentLobbyScreen extends StatefulWidget {
  const UltimateTournamentLobbyScreen({super.key});

  @override
  State<UltimateTournamentLobbyScreen> createState() => _UltimateTournamentLobbyScreenState();
}

class _UltimateTournamentLobbyScreenState extends State<UltimateTournamentLobbyScreen>
    with TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  String? _tourneyId;
  bool _isNavigating = false;

  static const int TOURNAMENT_SIZE = 64;

  // Player tracking
  Timer? _fillTimer;
  Timer? _displayTimer;
  DateTime? _tournamentCreatedTime;
  int _displayedPlayerCount = 0;
  int _actualPlayerCount = 0;

  // Animation controllers
  late AnimationController _primaryController;
  late AnimationController _pulsController;
  late AnimationController _gameIconController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  // Game order display
  List<GameType> _gameOrder = [];

  @override
  void initState() {
    super.initState();

    // Initialize ULTIMATE psychedelic background
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _primaryController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // FASTER for ultimate intensity
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _primaryController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _gameIconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinOrCreateUltimateTournament();
    });
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    // ULTIMATE rainbow colors - all games represented
    final ultimateColors = [
      Colors.red.shade800,     // Precision
      Colors.orange.shade700,  // Momentum
      Colors.purple.shade800,  // Memory
      Colors.pink.shade700,    // Match
      Colors.blue.shade800,    // Maze
      Colors.green.shade700,
      Colors.cyan.shade600,
      Colors.yellow.shade600,
      Colors.indigo.shade700,
      Colors.lime.shade600,
    ];

    return List.generate(
        6, (_) => ultimateColors[random.nextInt(ultimateColors.length)]);
  }

  Future<void> _joinOrCreateUltimateTournament() async {
    try {
      print('🏆 Starting Ultimate Tournament creation/join');

      final snap = await _db
          .collection('ultimate_tournaments')
          .where('status', isEqualTo: 'waiting')
          .where('playerCount', isLessThan: TOURNAMENT_SIZE)
          .limit(1)
          .get();

      DocumentReference doc;
      if (snap.docs.isEmpty) {
        print('🏆 Creating new Ultimate Tournament');

        // Generate random game order for this tournament
        final gameOrder = _generateRandomGameOrder();

        // Random starting player count
        final random = math.Random();
        final randomStartCount = random.nextInt(TOURNAMENT_SIZE) + 1;

        doc = await _db.collection('ultimate_tournaments').add({
          'status': 'waiting',
          'players': [_uid],
          'playerCount': randomStartCount,
          'maxPlayers': TOURNAMENT_SIZE,
          'createdAt': FieldValue.serverTimestamp(),
          'gameOrder': gameOrder.map((g) => g.name).toList(),
          'currentGameIndex': 0,
          'totalGames': 5,
          'bots': <String, dynamic>{},
        });

        _tournamentCreatedTime = DateTime.now();

        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = randomStartCount;
            _displayedPlayerCount = randomStartCount;
            _gameOrder = gameOrder;
          });
        }

        _startAutoFillTimer();
      } else {
        print('🏆 Joining existing Ultimate Tournament');
        doc = snap.docs.first.reference;

        final tourneyData = snap.docs.first.data() as Map<String, dynamic>;
        final currentCount = tourneyData['playerCount'] as int? ?? 1;
        final gameOrderStrings = (tourneyData['gameOrder'] as List<dynamic>?)?.cast<String>() ?? [];

        if (currentCount >= TOURNAMENT_SIZE) {
          // Create new tournament if full
          final gameOrder = _generateRandomGameOrder();
          final random = math.Random();
          final randomStartCount = random.nextInt(TOURNAMENT_SIZE) + 1;

          doc = await _db.collection('ultimate_tournaments').add({
            'status': 'waiting',
            'players': [_uid],
            'playerCount': randomStartCount,
            'maxPlayers': TOURNAMENT_SIZE,
            'createdAt': FieldValue.serverTimestamp(),
            'gameOrder': gameOrder.map((g) => g.name).toList(),
            'currentGameIndex': 0,
            'totalGames': 5,
            'bots': <String, dynamic>{},
          });

          _tournamentCreatedTime = DateTime.now();

          if (mounted) {
            setState(() {
              _tourneyId = doc.id;
              _actualPlayerCount = randomStartCount;
              _displayedPlayerCount = randomStartCount;
              _gameOrder = gameOrder;
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

        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = currentCount + 1;
            _displayedPlayerCount = currentCount + 1;
            _gameOrder = gameOrderStrings.map((s) => GameType.values.firstWhere((e) => e.name == s)).toList();
          });
        }

        _startAutoFillTimer();
      }
    } catch (e) {
      print('🏆 Error joining/creating Ultimate Tournament: $e');
    }
  }

  List<GameType> _generateRandomGameOrder() {
    final games = [...GameType.values];
    games.shuffle();
    return games;
  }

  void _startAutoFillTimer() {
    if (_tournamentCreatedTime == null) return;

    print('🏆 Starting auto-fill timer for Ultimate Tournament');

    _fillTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      _checkAndAddPlayers();
    });

    _startGradualDisplay();

    Timer(const Duration(seconds: 25), () {
      print('🏆 25 seconds reached - starting Ultimate Tournament');
      _forceStartTournament();
    });
  }

  void _startGradualDisplay() {
    _displayTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_displayedPlayerCount < _actualPlayerCount) {
        setState(() {
          final remaining = _actualPlayerCount - _displayedPlayerCount;
          final increment = remaining > 30 ? 4 : remaining > 10 ? 2 : 1;
          _displayedPlayerCount = math.min(_displayedPlayerCount + increment, _actualPlayerCount);
        });
      }
    });
  }

  Future<void> _checkAndAddPlayers() async {
    if (_tourneyId == null || _tournamentCreatedTime == null) return;

    final waitTime = DateTime.now().difference(_tournamentCreatedTime!);
    final secondsElapsed = waitTime.inSeconds;

    final tourneyDoc = await _db.collection('ultimate_tournaments').doc(_tourneyId!).get();
    final data = tourneyDoc.data();
    if (data == null) return;

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    if (status != 'waiting' || currentCount >= TOURNAMENT_SIZE) return;

    int targetCount = currentCount;

    if (secondsElapsed <= 15) {
      final progressRatio = secondsElapsed / 15.0;
      targetCount = math.max(currentCount, (TOURNAMENT_SIZE * progressRatio).round());

      if (secondsElapsed >= 3 && targetCount < 16) targetCount = math.max(currentCount, 16);
      if (secondsElapsed >= 6 && targetCount < 32) targetCount = math.max(currentCount, 32);
      if (secondsElapsed >= 9 && targetCount < 48) targetCount = math.max(currentCount, 48);
      if (secondsElapsed >= 12 && targetCount < 56) targetCount = math.max(currentCount, 56);
      if (secondsElapsed >= 15) targetCount = TOURNAMENT_SIZE;
    }

    if (targetCount > currentCount && currentCount < TOURNAMENT_SIZE) {
      final botsToAdd = math.min(targetCount - currentCount, TOURNAMENT_SIZE - currentCount);
      try {
        await UltimateTournamentService.addBotsToTournament(_tourneyId!, botsToAdd);

        if (mounted) {
          setState(() {
            _actualPlayerCount = math.min(targetCount, TOURNAMENT_SIZE);
          });
        }
      } catch (e) {
        print('🏆 Error adding bots: $e');
      }
    }
  }

  Future<void> _forceStartTournament() async {
    if (_tourneyId == null) return;

    final tourneyDoc = await _db.collection('ultimate_tournaments').doc(_tourneyId!).get();
    final data = tourneyDoc.data();
    if (data == null) return;

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    if (status != 'waiting') return;

    if (currentCount < TOURNAMENT_SIZE) {
      final botsToAdd = TOURNAMENT_SIZE - currentCount;
      await UltimateTournamentService.addBotsToTournament(_tourneyId!, botsToAdd);
    }

    await _db.collection('ultimate_tournaments').doc(_tourneyId!).update({
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  void _navigateToGame() {
    if (_isNavigating || !mounted) return;

    _isNavigating = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UltimateTournamentGameScreen(
          tourneyId: _tourneyId!,
          gameOrder: _gameOrder,
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
    _gameIconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tourneyId == null) {
      return _buildLoadingScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('ultimate_tournaments').doc(_tourneyId!).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return _buildLoadingScreen();
        }

        final data = snap.data!.data();
        if (data == null) {
          return _buildErrorScreen();
        }

        final tournamentData = data as Map<String, dynamic>;
        final status = tournamentData['status'] as String? ?? 'waiting';
        final count = tournamentData['playerCount'] as int? ?? 0;

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
            return _buildWaitingScreen(math.min(_displayedPlayerCount, TOURNAMENT_SIZE));

          case 'active':
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateToGame();
            });
            return _buildStartingScreen();

          default:
            return _buildErrorScreen();
        }
      },
    );
  }

  Widget _buildLoadingScreen() {
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
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 2.5, // BIGGER for ultimate tournament
                    stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // Simpler overlay to avoid image errors
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      interpolatedColors[2].withOpacity(0.3),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ULTIMATE SPINNING ICON
                    AnimatedBuilder(
                      animation: _primaryController,
                      builder: (context, child) {
                        return AnimatedBuilder(
                          animation: _pulsController,
                          builder: (context, child) {
                            final scale = 1.0 + (_pulsController.value * 0.3);
                            final rotation = _primaryController.value * 4 * math.pi; // DOUBLE SPEED

                            return Transform.scale(
                              scale: scale,
                              child: Transform.rotate(
                                angle: rotation,
                                child: Container(
                                  width: 180, // BIGGER
                                  height: 180,
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
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.8),
                                        blurRadius: 40,
                                        spreadRadius: 15,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.9),
                                          Colors.amber.withOpacity(0.8),
                                          Colors.orange.withOpacity(0.6),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events,
                                      size: 100,
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

                    // Fixed centered title
                    AnimatedBuilder(
                      animation: _pulsController,
                      builder: (context, child) {
                        final textScale = 1.0 + (_pulsController.value * 0.1);
                        return Transform.scale(
                          scale: textScale,
                          child: Container(
                            alignment: Alignment.center, // Explicit center alignment
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
                                  Colors.red,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(bounds),
                              child: Text(
                                'LOADING ULTIMATE TOURNAMENT',
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
                          ),
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
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 2.5,
                    stops: [0.0, 0.15, 0.3, 0.45, 0.6, 1.0],
                  ),
                ),
              ),

              // Simpler overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      interpolatedColors[1].withOpacity(0.3),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ULTIMATE TITLE - FIXED CENTERING
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final titleScale = 1.0 + (_pulsController.value * 0.15);
                          return Transform.scale(
                            scale: titleScale,
                            child: Container(
                              alignment: Alignment.center, // Explicit center alignment
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
                                    Colors.red,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ).createShader(bounds),
                                child: Text(
                                  'ULTIMATE TOURNAMENT',
                                  style: GoogleFonts.creepster(
                                    fontSize: 42,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4.0,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.9),
                                        blurRadius: 20,
                                        offset: const Offset(6, 6),
                                      ),
                                      Shadow(
                                        color: Colors.purple.withOpacity(0.8),
                                        blurRadius: 30,
                                        offset: const Offset(-4, -4),
                                      ),
                                      Shadow(
                                        color: Colors.cyan.withOpacity(0.6),
                                        blurRadius: 40,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Subtitle
                      Text(
                        '5 Games • 1 Champion • Ultimate Glory',
                        style: GoogleFonts.chicle(
                          fontSize: 20,
                          color: Colors.white.withOpacity(0.9),
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

                      const SizedBox(height: 50),

                      // ULTIMATE PLAYER COUNTER
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulsController.value * 0.5);
                          final glowIntensity = 0.8 + (_pulsController.value * 0.8);

                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                                gradient: RadialGradient(
                                  colors: [
                                    interpolatedColors[0].withOpacity(0.95),
                                    interpolatedColors[2].withOpacity(0.9),
                                    interpolatedColors[4].withOpacity(0.8),
                                    interpolatedColors[1].withOpacity(0.7),
                                  ],
                                  stops: [0.0, 0.3, 0.6, 1.0],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.9),
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(glowIntensity),
                                    blurRadius: 50,
                                    spreadRadius: 15,
                                  ),
                                  BoxShadow(
                                    color: interpolatedColors[1].withOpacity(0.9),
                                    blurRadius: 70,
                                    spreadRadius: 10,
                                  ),
                                  BoxShadow(
                                    color: interpolatedColors[3].withOpacity(0.7),
                                    blurRadius: 90,
                                    spreadRadius: 5,
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
                                        Colors.white,
                                      ],
                                    ).createShader(bounds),
                                    child: Text(
                                      '$cappedCount',
                                      style: GoogleFonts.chicle(
                                        fontSize: 84, // MASSIVE
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.9),
                                            blurRadius: 15,
                                            offset: const Offset(5, 5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    '$cappedCount/$TOURNAMENT_SIZE ULTIMATE WARRIORS',
                                    style: GoogleFonts.chicle(
                                      fontSize: 24,
                                      color: Colors.white.withOpacity(0.95),
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 50),

                      // GAME ORDER PREVIEW
                      if (_gameOrder.isNotEmpty) _buildGameOrderPreview(),

                      const SizedBox(height: 40),

                      // STATUS TEXT
                      AnimatedBuilder(
                        animation: _pulsController,
                        builder: (context, child) {
                          final textOpacity = 0.8 + (_pulsController.value * 0.4);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.5),
                                  Colors.purple.withOpacity(0.4),
                                  Colors.black.withOpacity(0.5),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              'Warriors assembling for the ultimate challenge...\n\nOnly one can claim the crown across all 5 games!',
                              style: GoogleFonts.chicle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(textOpacity),
                                shadows: [
                                  Shadow(
                                    color: Colors.purple.withOpacity(0.8),
                                    blurRadius: 10,
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

  Widget _buildGameOrderPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: RadialGradient(
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.purple.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Game Order for This Tournament:',
            style: GoogleFonts.chicle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),

          // Game icons row
          AnimatedBuilder(
            animation: _gameIconController,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _gameOrder.asMap().entries.map((entry) {
                  final index = entry.key;
                  final game = entry.value;
                  final delay = index * 0.2;
                  final animationOffset = (_gameIconController.value + delay) % 1.0;
                  final scale = 1.0 + (math.sin(animationOffset * 2 * math.pi) * 0.2);

                  return Transform.scale(
                    scale: scale,
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _getGameColor(game).withOpacity(0.9),
                                _getGameColor(game).withOpacity(0.6),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.7),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getGameColor(game).withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _getGameIcon(game),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${index + 1}',
                          style: GoogleFonts.chicle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 15),

          // Game names
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: _gameOrder.map((game) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getGameColor(game).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getGameColor(game).withOpacity(0.6),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getGameName(game),
                  style: GoogleFonts.chicle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getGameColor(GameType game) {
    switch (game) {
      case GameType.precision:
        return Colors.red;
      case GameType.momentum:
        return Colors.orange;
      case GameType.memory:
        return Colors.purple;
      case GameType.match:
        return Colors.pink;
      case GameType.maze:
        return Colors.blue;
    }
  }

  IconData _getGameIcon(GameType game) {
    switch (game) {
      case GameType.precision:
        return Icons.timer;
      case GameType.momentum:
        return Icons.rotate_right;
      case GameType.memory:
        return Icons.psychology;
      case GameType.match:
        return Icons.style;
      case GameType.maze:
        return Icons.explore;
    }
  }

  String _getGameName(GameType game) {
    switch (game) {
      case GameType.precision:
        return 'Precision';
      case GameType.momentum:
        return 'Momentum';
      case GameType.memory:
        return 'Memory';
      case GameType.match:
        return 'Match';
      case GameType.maze:
        return 'Maze';
    }
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
                radius: 3.0, // MASSIVE for ultimate start
                stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulsController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulsController.value * 0.5);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.amber.withOpacity(0.9),
                                Colors.orange.withOpacity(0.8),
                                Colors.red.withOpacity(0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.8),
                                blurRadius: 50,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            size: 120,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  Container(
                    alignment: Alignment.center, // Fixed center alignment
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.amber,
                          Colors.orange,
                          Colors.red,
                          Colors.purple,
                          Colors.blue,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'THE ULTIMATE TOURNAMENT BEGINS!',
                        style: GoogleFonts.creepster(
                          fontSize: 44,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.9),
                              blurRadius: 20,
                              offset: const Offset(6, 6),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    '5 Games • 64 Warriors • 1 Ultimate Champion',
                    style: GoogleFonts.chicle(
                      fontSize: 22,
                      color: Colors.white.withOpacity(0.9),
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 8,
                          offset: const Offset(3, 3),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
                'Ultimate chaos detected...',
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