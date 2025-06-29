// lib/screens/match_lobby_screen.dart - ADDED 15 SECOND AD COUNTDOWN TO ORIGINAL
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import '../services/match_bot_service.dart';
import 'match_game_screen.dart';

class MatchLobbyScreen extends StatefulWidget {
  const MatchLobbyScreen({super.key});

  @override
  State<MatchLobbyScreen> createState() => _MatchLobbyScreenState();
}

class _MatchLobbyScreenState extends State<MatchLobbyScreen>
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
  List<MatchBotPlayer> _tournamentBots = [];
  int _displayedPlayerCount = 0;
  int _actualPlayerCount = 0;
  int _realPlayerCount = 1;

  // ADDED: Ad countdown functionality
  int _adCountdown = 0;
  bool _isShowingAd = false;
  bool _isFilling = false;
  int _startingPlayerCount = 0; // Random starting count to simulate ongoing tournament

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
      print('Match Starting _joinOrCreate for match tournament (TOURNAMENT_SIZE: $TOURNAMENT_SIZE)');

      final snap = await _db
          .collection('match_tournaments')
          .where('status', isEqualTo: 'waiting')
          .where('realPlayerCount', isLessThan: TOURNAMENT_SIZE)
          .limit(1)
          .get();

      DocumentReference doc;
      if (snap.docs.isEmpty) {
        print('Match Creating new match tournament');

        // REALISTIC: Start with random player count (10-50) to simulate ongoing tournament
        final random = math.Random();
        _startingPlayerCount = 10 + random.nextInt(41); // 10-50 players

        doc = await _db.collection('match_tournaments').add({
          'status': 'waiting',
          'players': [_uid],
          'playerCount': _startingPlayerCount + 1, // Include the real player
          'realPlayers': [_uid],
          'realPlayerCount': 1,
          'maxPlayers': TOURNAMENT_SIZE,
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'match_madness',
          'bots': <String, dynamic>{},
        });
        _tournamentCreatedTime = DateTime.now();
        print('Match Created tournament with ID: ${doc.id}, starting with ${_startingPlayerCount + 1} players');
        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = _startingPlayerCount + 1;
            _displayedPlayerCount = _startingPlayerCount + 1;
            _realPlayerCount = 1;
          });
        }
        _startRealisticTournamentFill();
      } else {
        print('Match Joining existing match tournament');
        doc = snap.docs.first.reference;

        final tournamentData = snap.docs.first.data() as Map<String, dynamic>;
        final realPlayerCount = tournamentData['realPlayerCount'] as int? ?? 1;
        final totalPlayerCount = tournamentData['playerCount'] as int? ?? 1;

        if (realPlayerCount >= TOURNAMENT_SIZE) {
          print('Match Tournament has max real players, creating new one');
          // Create new tournament with random starting count
          final random = math.Random();
          _startingPlayerCount = 10 + random.nextInt(41);

          doc = await _db.collection('match_tournaments').add({
            'status': 'waiting',
            'players': [_uid],
            'playerCount': _startingPlayerCount + 1,
            'realPlayers': [_uid],
            'realPlayerCount': 1,
            'maxPlayers': TOURNAMENT_SIZE,
            'createdAt': FieldValue.serverTimestamp(),
            'gameType': 'match_madness',
            'bots': <String, dynamic>{},
          });
          _tournamentCreatedTime = DateTime.now();
          if (mounted) {
            setState(() {
              _tourneyId = doc.id;
              _actualPlayerCount = _startingPlayerCount + 1;
              _displayedPlayerCount = _startingPlayerCount + 1;
              _realPlayerCount = 1;
            });
          }
          _startRealisticTournamentFill();
          return;
        }

        // Join existing tournament
        await doc.update({
          'players': FieldValue.arrayUnion([_uid]),
          'playerCount': FieldValue.increment(1),
          'realPlayers': FieldValue.arrayUnion([_uid]),
          'realPlayerCount': FieldValue.increment(1),
        });

        if (tournamentData.containsKey('createdAt') && tournamentData['createdAt'] != null) {
          final timestamp = tournamentData['createdAt'] as Timestamp;
          _tournamentCreatedTime = timestamp.toDate();
        } else {
          _tournamentCreatedTime = DateTime.now();
        }

        print('Match Joined tournament ${doc.id} with ${totalPlayerCount + 1} total players (${realPlayerCount + 1} real)');

        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = totalPlayerCount + 1;
            _displayedPlayerCount = totalPlayerCount + 1;
            _realPlayerCount = realPlayerCount + 1;
          });
        }

        _startRealisticTournamentFill();
      }
    } catch (e) {
      print('Match Error joining/creating match tournament: $e');
      try {
        // Fallback
        final random = math.Random();
        _startingPlayerCount = 10 + random.nextInt(41);

        final doc = await _db.collection('match_tournaments').add({
          'status': 'waiting',
          'players': [_uid],
          'playerCount': _startingPlayerCount + 1,
          'realPlayers': [_uid],
          'realPlayerCount': 1,
          'maxPlayers': TOURNAMENT_SIZE,
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'match_madness',
          'bots': <String, dynamic>{},
        });
        _tournamentCreatedTime = DateTime.now();
        print('Match Created fallback tournament: ${doc.id} with ${_startingPlayerCount + 1} players');
        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = _startingPlayerCount + 1;
            _displayedPlayerCount = _startingPlayerCount + 1;
            _realPlayerCount = 1;
          });
        }
        _startRealisticTournamentFill();
      } catch (e2) {
        print('Match Failed to create fallback tournament: $e2');
      }
    }
  }

  // REALISTIC: Simulate tournament filling up naturally
  void _startRealisticTournamentFill() {
    if (_tournamentCreatedTime == null) return;

    print('Match Starting realistic tournament fill simulation');
    _isFilling = true;

    // Gradual counter increase to 64
    _fillTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_displayedPlayerCount < TOURNAMENT_SIZE) {
        setState(() {
          final remaining = TOURNAMENT_SIZE - _displayedPlayerCount;
          // Faster increase as we get closer to full
          final increment = remaining > 30 ? math.Random().nextInt(3) + 1 :
          remaining > 10 ? math.Random().nextInt(2) + 1 : 1;
          _displayedPlayerCount = math.min(_displayedPlayerCount + increment, TOURNAMENT_SIZE);
        });
      }

      if (_displayedPlayerCount >= TOURNAMENT_SIZE) {
        timer.cancel();
        _fillComplete();
      }
    });

    // Backup timer in case we need to force completion
    Timer(const Duration(seconds: 15), () {
      if (_displayedPlayerCount < TOURNAMENT_SIZE) {
        setState(() {
          _displayedPlayerCount = TOURNAMENT_SIZE;
        });
        _fillComplete();
      }
    });
  }

  // When tournament is full, add bots silently and show ad
  Future<void> _fillComplete() async {
    if (_tourneyId == null) return;

    try {
      _isFilling = false;

      // Silently add bots to match the displayed count
      final tournamentDoc = await _db.collection('match_tournaments').doc(_tourneyId!).get();
      final data = tournamentDoc.data();
      if (data == null) return;

      final currentTotalCount = data['playerCount'] as int? ?? 0;

      // Add bots to reach exactly 64 (silently, no mention of bots)
      if (currentTotalCount < TOURNAMENT_SIZE) {
        final botsNeeded = TOURNAMENT_SIZE - currentTotalCount;
        print('Match Silently adding $botsNeeded participants to reach $TOURNAMENT_SIZE total');

        final newBots = await MatchBotService.addBotsToTournament(_tourneyId!, botsNeeded);
        _tournamentBots.addAll(newBots);

        if (mounted) {
          setState(() {
            _actualPlayerCount = TOURNAMENT_SIZE;
          });
        }
      }

      // Show ad countdown
      await _showAdCountdown();

      // Start the tournament
      await _startTournament();

    } catch (e) {
      print('Match Error completing tournament fill: $e');
    }
  }

  Future<void> _showAdCountdown() async {
    print('Match Starting 15-second ad countdown');

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
    if (_tourneyId == null) return;

    print('Match Starting tournament with 64 participants');

    await _db.collection('match_tournaments').doc(_tourneyId!).update({
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
      'finalPlayerCount': TOURNAMENT_SIZE,
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
      print('Match No tournament ID or creation time');
      return;
    }

    final waitTime = DateTime.now().difference(_tournamentCreatedTime!);
    final secondsElapsed = waitTime.inSeconds;
    print('Match Wait time: $secondsElapsed seconds');

    final tourneyDoc = await _db.collection('match_tournaments').doc(_tourneyId!).get();
    final data = tourneyDoc.data();
    if (data == null) {
      print('Match No tournament data found');
      return;
    }

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    print('Match Current count: $currentCount/$TOURNAMENT_SIZE, Status: $status');

    if (status != 'waiting' || currentCount >= TOURNAMENT_SIZE) {
      print('Match Tournament not waiting or already full');
      return;
    }

    int targetCount = currentCount;

    if (secondsElapsed <= 10) {
      final progressRatio = secondsElapsed / 10.0;
      targetCount = math.max(currentCount, (TOURNAMENT_SIZE * progressRatio).round());

      // UPDATED: Ensure we hit key milestones but never go below current count
      if (secondsElapsed >= 2 && targetCount < 16) targetCount = math.max(currentCount, 16);
      if (secondsElapsed >= 4 && targetCount < 32) targetCount = math.max(currentCount, 32);
      if (secondsElapsed >= 6 && targetCount < 48) targetCount = math.max(currentCount, 48);
      if (secondsElapsed >= 8 && targetCount < 56) targetCount = math.max(currentCount, 56);
      if (secondsElapsed >= 10) targetCount = TOURNAMENT_SIZE;

      print('Match ${secondsElapsed}s: Target $targetCount players (progress: ${(progressRatio * 100).toInt()}%)');
    }

    if (targetCount > currentCount && currentCount < TOURNAMENT_SIZE) {
      final botsToAdd = math.min(targetCount - currentCount, TOURNAMENT_SIZE - currentCount);
      print('Match Adding $botsToAdd bots to reach $targetCount (current: $currentCount)');
      try {
        final newBots = await MatchBotService.addBotsToTournament(_tourneyId!, botsToAdd);
        _tournamentBots.addAll(newBots);
        print('Match Successfully added ${newBots.length} bots');

        if (mounted) {
          setState(() {
            _actualPlayerCount = math.min(targetCount, TOURNAMENT_SIZE);
          });
        }
      } catch (e) {
        print('Match Error adding bots: $e');
      }
    } else {
      print('Match No bots needed - at target or full ($currentCount >= $targetCount or $currentCount >= $TOURNAMENT_SIZE)');
    }
  }

  Future<void> _forceStartTournament() async {
    if (_tourneyId == null) return;

    final tourneyDoc = await _db.collection('match_tournaments').doc(_tourneyId!).get();
    final data = tourneyDoc.data();
    if (data == null) return;

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    if (status != 'waiting') return;

    if (currentCount < TOURNAMENT_SIZE) {
      final botsToAdd = TOURNAMENT_SIZE - currentCount;
      print('Match Force filling with $botsToAdd bots to reach exactly $TOURNAMENT_SIZE players');
      final newBots = await MatchBotService.addBotsToTournament(_tourneyId!, botsToAdd);
      _tournamentBots.addAll(newBots);
    }

    final finalDoc = await _db.collection('match_tournaments').doc(_tourneyId!).get();
    final finalData = finalDoc.data();
    final finalCount = finalData?['playerCount'] as int? ?? 0;

    print('Match Final verification: $finalCount players before starting tournament');

    await _db.collection('match_tournaments').doc(_tourneyId!).update({
      'status': 'active',
      'finalPlayerCount': finalCount,
    });
  }

  void _navigateToGame() {
    if (_isNavigating || !mounted) return;

    _isNavigating = true;

    print('Match Navigating to match game with tournament ID: $_tourneyId');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MatchGameScreen(
          isPractice: false,
          tourneyId: _tourneyId ?? 'match_tournament',
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

  @override
  Widget build(BuildContext context) {
    print('Match lobby build called, tourneyId: $_tourneyId');

    if (_tourneyId == null) {
      print('Match Tournament ID is null, showing loading screen');
      return _buildPsychedelicLoadingScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('match_tournaments').doc(_tourneyId!).snapshots(),
      builder: (ctx, snap) {
        print('Match StreamBuilder update - hasData: ${snap.hasData}');

        if (!snap.hasData) {
          print('Match No snapshot data, showing loading screen');
          return _buildPsychedelicLoadingScreen();
        }

        final data = snap.data!.data();
        if (data == null) {
          print('Match Snapshot data is null, showing error screen');
          return _buildErrorScreen();
        }

        final tournamentData = data as Map<String, dynamic>;
        final status = tournamentData['status'] as String? ?? 'waiting';
        final count = tournamentData['playerCount'] as int? ?? 0;

        print('Match Tournament status: $status, displayed players: $_displayedPlayerCount/$TOURNAMENT_SIZE');

        switch (status) {
          case 'waiting':
            if (_isShowingAd || _adCountdown > 0) {
              return _buildAdCountdownScreen();
            }
            return _buildWaitingScreen(math.min(_displayedPlayerCount, TOURNAMENT_SIZE));

          case 'active':
            print('Match Status is active, navigating to game');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateToGame();
            });
            return _buildStartingScreen();

          default:
            print('Match Unknown status: $status, showing error screen');
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
                    stops: [0.0, 0.3, 0.6, 1.0],
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
                                  width: 120,
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
                                      Icons.style,
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
                              'JOINING TOURNAMENT',
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
                          children: List.generate(4, (index) {
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
                                'MATCH TOURNAMENT',
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

                      // PLAYER COUNTER - Now shows all players as "CARD READERS"
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
                                    interpolatedColors[4 % interpolatedColors.length].withOpacity(0.75),
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
                                    color: interpolatedColors[3 % interpolatedColors.length].withOpacity(0.6),
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
                                    '$cappedCount/$TOURNAMENT_SIZE CARD READERS',
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
                              'Last Card Reader Standing',
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
                              '🔮 64-player tarot elimination tournament\n'
                                  '🃏 Match the mystical card combinations\n'
                                  '✨ Read the cards before time runs out\n'
                                  '💀 Fail a reading and you\'re banished!\n'
                                  '🏆 Last reader standing wins the magic',
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
                    '64 card readers ready for the tarot challenge!',
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
                        interpolatedColors[3 % interpolatedColors.length].withOpacity(0.2),
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
                              Icons.style,
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
                      'The 64-player tarot tournament begins...',
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
                'Card chaos detected...',
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