// lib/screens/maze_lobby_screen.dart - REALISTIC TOURNAMENT LOBBY
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
  static const int MAX_PLAYERS = 64;

  // Player tracking - REALISTIC TOURNAMENT SIMULATION
  Timer? _fillTimer;
  Timer? _displayTimer;
  DateTime? _survivalCreatedTime;
  List<MazeBotPlayer> _survivalBots = [];
  int _displayedPlayerCount = 0;
  int _actualPlayerCount = 0;
  int _realPlayerCount = 1;
  int _adCountdown = 0;
  bool _isShowingAd = false;
  bool _isFilling = false;
  int _startingPlayerCount = 0; // Random starting count to simulate ongoing tournament

  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _rotationController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  @override
  void initState() {
    super.initState();

    // Initialize psychedelic background
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
          .where('realPlayerCount', isLessThan: MAX_PLAYERS)
          .limit(1)
          .get();

      DocumentReference doc;
      if (snap.docs.isEmpty) {
        print('🧩 Creating new maze survival');

        // REALISTIC: Start with random player count (10-50) to simulate ongoing tournament
        final random = math.Random();
        _startingPlayerCount = 10 + random.nextInt(41); // 10-50 players

        doc = await _db.collection('maze_survival').add({
          'status': 'waiting',
          'round': 0,
          'players': [_uid],
          'playerCount': _startingPlayerCount + 1, // Include the real player
          'realPlayers': [_uid],
          'realPlayerCount': 1,
          'maxPlayers': MAX_PLAYERS,
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'maze_madness',
          'bots': <String, dynamic>{},
        });
        _survivalCreatedTime = DateTime.now();

        print('🧩 Created survival with ID: ${doc.id}, simulating ${_startingPlayerCount + 1} players');
        if (mounted) {
          setState(() {
            _survivalId = doc.id;
            _actualPlayerCount = _startingPlayerCount + 1;
            _displayedPlayerCount = _startingPlayerCount + 1;
            _realPlayerCount = 1;
          });
        }
        _startRealisticTournamentFill();
      } else {
        print('🧩 Joining existing maze survival');
        doc = snap.docs.first.reference;

        final survivalData = snap.docs.first.data() as Map<String, dynamic>;
        final realPlayerCount = survivalData['realPlayerCount'] as int? ?? 1;
        final totalPlayerCount = survivalData['playerCount'] as int? ?? 1;

        if (realPlayerCount >= MAX_PLAYERS) {
          print('🧩 Survival has max real players, creating new one');
          // Create new survival with random starting count
          final random = math.Random();
          _startingPlayerCount = 10 + random.nextInt(41);

          doc = await _db.collection('maze_survival').add({
            'status': 'waiting',
            'round': 0,
            'players': [_uid],
            'playerCount': _startingPlayerCount + 1,
            'realPlayers': [_uid],
            'realPlayerCount': 1,
            'maxPlayers': MAX_PLAYERS,
            'createdAt': FieldValue.serverTimestamp(),
            'gameType': 'maze_madness',
            'bots': <String, dynamic>{},
          });
          _survivalCreatedTime = DateTime.now();
          if (mounted) {
            setState(() {
              _survivalId = doc.id;
              _actualPlayerCount = _startingPlayerCount + 1;
              _displayedPlayerCount = _startingPlayerCount + 1;
              _realPlayerCount = 1;
            });
          }
          _startRealisticTournamentFill();
          return;
        }

        // Join existing survival
        await doc.update({
          'players': FieldValue.arrayUnion([_uid]),
          'playerCount': FieldValue.increment(1),
          'realPlayers': FieldValue.arrayUnion([_uid]),
          'realPlayerCount': FieldValue.increment(1),
        });

        if (survivalData.containsKey('createdAt') && survivalData['createdAt'] != null) {
          final timestamp = survivalData['createdAt'] as Timestamp;
          _survivalCreatedTime = timestamp.toDate();
        } else {
          _survivalCreatedTime = DateTime.now();
        }

        print('🧩 Joined survival ${doc.id} with ${totalPlayerCount + 1} total players (${realPlayerCount + 1} real)');

        if (mounted) {
          setState(() {
            _survivalId = doc.id;
            _actualPlayerCount = totalPlayerCount + 1;
            _displayedPlayerCount = totalPlayerCount + 1;
            _realPlayerCount = realPlayerCount + 1;
          });
        }

        _startRealisticTournamentFill();
      }
    } catch (e) {
      print('🧩 Error joining/creating maze survival: $e');
      // Fallback
      try {
        final random = math.Random();
        _startingPlayerCount = 10 + random.nextInt(41);

        final doc = await _db.collection('maze_survival').add({
          'status': 'waiting',
          'round': 0,
          'players': [_uid],
          'playerCount': _startingPlayerCount + 1,
          'realPlayers': [_uid],
          'realPlayerCount': 1,
          'maxPlayers': MAX_PLAYERS,
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'maze_madness',
          'bots': <String, dynamic>{},
        });
        _survivalCreatedTime = DateTime.now();
        print('🧩 Created fallback survival: ${doc.id} with ${_startingPlayerCount + 1} players');
        if (mounted) {
          setState(() {
            _survivalId = doc.id;
            _actualPlayerCount = _startingPlayerCount + 1;
            _displayedPlayerCount = _startingPlayerCount + 1;
            _realPlayerCount = 1;
          });
        }
        _startRealisticTournamentFill();
      } catch (e2) {
        print('🧩 Failed to create fallback survival: $e2');
      }
    }
  }

  // REALISTIC: Simulate tournament filling up naturally
  void _startRealisticTournamentFill() {
    if (_survivalCreatedTime == null) return;

    print('🧩 Starting realistic tournament fill simulation');
    _isFilling = true;

    // Gradual counter increase to 64
    _fillTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_displayedPlayerCount < MAX_PLAYERS) {
        setState(() {
          final remaining = MAX_PLAYERS - _displayedPlayerCount;
          // Faster increase as we get closer to full
          final increment = remaining > 30 ? math.Random().nextInt(3) + 1 :
          remaining > 10 ? math.Random().nextInt(2) + 1 : 1;
          _displayedPlayerCount = math.min(_displayedPlayerCount + increment, MAX_PLAYERS);
        });
      }

      if (_displayedPlayerCount >= MAX_PLAYERS) {
        timer.cancel();
        _fillComplete();
      }
    });

    // Backup timer in case we need to force completion
    Timer(const Duration(seconds: 15), () {
      if (_displayedPlayerCount < MAX_PLAYERS) {
        setState(() {
          _displayedPlayerCount = MAX_PLAYERS;
        });
        _fillComplete();
      }
    });
  }

  // When tournament is full, add bots silently and show ad
  Future<void> _fillComplete() async {
    if (_survivalId == null) return;

    try {
      _isFilling = false;

      // Silently add bots to match the displayed count
      final survivalDoc = await _db.collection('maze_survival').doc(_survivalId!).get();
      final data = survivalDoc.data();
      if (data == null) return;

      final currentTotalCount = data['playerCount'] as int? ?? 0;

      // Add bots to reach exactly 64 (silently, no mention of bots)
      if (currentTotalCount < MAX_PLAYERS) {
        final botsNeeded = MAX_PLAYERS - currentTotalCount;
        print('🧩 Silently adding $botsNeeded participants to reach $MAX_PLAYERS total');

        final newBots = await MazeBotService.addBotsToSurvival(_survivalId!, botsNeeded);
        _survivalBots.addAll(newBots);

        if (mounted) {
          setState(() {
            _actualPlayerCount = MAX_PLAYERS;
          });
        }
      }

      // Show ad countdown
      await _showAdCountdown();

      // Start the tournament
      await _startTournament();

    } catch (e) {
      print('🧩 Error completing tournament fill: $e');
    }
  }

  Future<void> _showAdCountdown() async {
    print('🧩 Starting 15-second ad countdown');

    if (mounted) {
      setState(() {
        _isShowingAd = true;
        _adCountdown = 15;
      });
    }

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _adCountdown--;
        });
      }

      if (_adCountdown <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isShowingAd = false;
          });
        }
      }
    });

    await Future.delayed(const Duration(seconds: 15));
  }

  Future<void> _startTournament() async {
    if (_survivalId == null) return;

    print('🧩 Starting tournament with 64 participants');

    await _db.collection('maze_survival').doc(_survivalId!).update({
      'status': 'round',
      'round': 1,
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
          return _buildLoadingScreen();
        }

        final data = snap.data!.data();
        if (data == null) {
          return _buildErrorScreen();
        }

        final survivalData = data as Map<String, dynamic>;
        final status = survivalData['status'] as String? ?? 'waiting';
        final round = survivalData['round'] as int? ?? 0;

        print('🧩 Survival status: $status, displayed players: $_displayedPlayerCount/$MAX_PLAYERS, round: $round');

        switch (status) {
          case 'waiting':
            if (_isShowingAd || _adCountdown > 0) {
              return _buildAdCountdownScreen();
            }
            return _buildWaitingScreen(_displayedPlayerCount);

          case 'round':
            print('🧩 Status is round, navigating to game (round $round)');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateToGame(round);
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
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                              'JOINING TOURNAMENT',
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

  Widget _buildWaitingScreen(int playerCount) {
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
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                                'MAZE TOURNAMENT',
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

                      // PLAYER COUNTER - Now shows all players as "EXPLORERS"
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
                                      '$playerCount',
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
                                    '$playerCount/$MAX_PLAYERS EXPLORERS',
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
                                  const SizedBox(height: 5),
                                  Text(
                                    _isFilling ? 'Tournament filling up...' : 'Waiting for tournament to fill...',
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
                              '🔮 64-player elimination tournament\n'
                                  '🧠 6 rounds of increasingly complex mazes\n'
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

  Widget _buildAdCountdownScreen() {
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 300,
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.withOpacity(0.9),
                          Colors.pink.withOpacity(0.8),
                          Colors.cyan.withOpacity(0.7),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 3),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_outline, size: 60, color: Colors.white),
                          const SizedBox(height: 10),
                          Text(
                            'Advertisement',
                            style: GoogleFonts.chicle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  AnimatedBuilder(
                    animation: _pulsController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulsController.value * 0.2);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.withOpacity(0.9),
                                Colors.red.withOpacity(0.7),
                              ],
                            ),
                            border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                          ),
                          child: Text(
                            'Tournament starts in $_adCountdown seconds...',
                            style: GoogleFonts.creepster(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  Text(
                    '64 explorers ready for the maze challenge!',
                    style: GoogleFonts.chicle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
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
                      'ENTERING THE TOURNAMENT!',
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
                    'The 64-player maze tournament begins...',
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
                'Tournament connection failed...',
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
                child: const Text('Return to Menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}