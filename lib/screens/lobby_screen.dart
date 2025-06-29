// lib/screens/lobby_screen.dart - FIXED NAVIGATION
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/tournament_setup_screen.dart';
import '../main.dart' show targetDuration;
import '../services/bot_service.dart';
import '../config/gradient_config.dart';
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
  Timer? _botTimer;
  Timer? _lockTimer;
  DateTime? _tournamentCreatedTime;
  List<BotPlayer> _tournamentBots = [];
  int _displayedPlayerCount = 0;
  int _actualPlayerCount = 0;
  int _realPlayerCount = 1;

  // ADDED: Ad countdown functionality
  int _adCountdown = 0;
  bool _isShowingAd = false;
  bool _isLocked = false; // Tournament locked after 15 seconds
  int _startingPlayerCount = 0;
  bool _botsSubmitted = false; // FIXED: Track if bots are already submitted

  // ADDED: Track tournament status separately
  String _currentStatus = 'waiting';
  int _currentRound = 0;

  // Animation controllers for INTENSE psychedelic effects
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  // ADDED: Listener reference for cleanup
  StreamSubscription<DocumentSnapshot>? _tournamentListener;

  @override
  void initState() {
    super.initState();

    // Initialize INTENSE psychedelic background using gradient config
    _currentColors = PsychedelicGradient.generateGradient(6);
    _nextColors = PsychedelicGradient.generateGradient(6);

    // FASTER, more intense background animation
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Faster like main screen
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = PsychedelicGradient.generateGradient(6);
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

  Future<void> _joinOrCreate() async {
    try {
      print('Starting _joinOrCreate for tournament (TOURNAMENT_SIZE: $TOURNAMENT_SIZE)');

      final snap = await _db
          .collection('tournaments')
          .where('status', isEqualTo: 'waiting')
          .where('realPlayerCount', isLessThan: TOURNAMENT_SIZE)
          .limit(1)
          .get();

      DocumentReference doc;
      if (snap.docs.isEmpty) {
        print('Creating new tournament (max $TOURNAMENT_SIZE players)');

        // SIMPLE: Start with just the real player
        doc = await _db.collection('tournaments').add({
          'status': 'waiting',
          'round': 0,
          'players': [_uid],
          'playerCount': 1, // Start with just the real player
          'realPlayers': [_uid],
          'realPlayerCount': 1,
          'maxPlayers': TOURNAMENT_SIZE,
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'precision_tap',
          'bots': <String, dynamic>{},
          'botsSubmitted': false,
        });
        _tournamentCreatedTime = DateTime.now();
        print('Created tournament with ID: ${doc.id}, starting with 1 player');
        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = 1;
            _displayedPlayerCount = 1;
            _realPlayerCount = 1;
          });
        }

        // Start the 15-second human join window immediately
        _startHumanJoinWindow();

        // ADDED: Set up tournament listener
        _setupTournamentListener();
      } else {
        print('Joining existing tournament');
        doc = snap.docs.first.reference;

        final tourneyData = snap.docs.first.data() as Map<String, dynamic>;
        final realPlayerCount = tourneyData['realPlayerCount'] as int? ?? 1;
        final totalPlayerCount = tourneyData['playerCount'] as int? ?? 1;

        // Double-check we won't exceed limit
        if (realPlayerCount >= TOURNAMENT_SIZE) {
          print('Tournament has max real players, creating new one instead');

          doc = await _db.collection('tournaments').add({
            'status': 'waiting',
            'round': 0,
            'players': [_uid],
            'playerCount': 1,
            'realPlayers': [_uid],
            'realPlayerCount': 1,
            'maxPlayers': TOURNAMENT_SIZE,
            'createdAt': FieldValue.serverTimestamp(),
            'gameType': 'precision_tap',
            'bots': <String, dynamic>{},
            'botsSubmitted': false,
          });
          _tournamentCreatedTime = DateTime.now();
          if (mounted) {
            setState(() {
              _tourneyId = doc.id;
              _actualPlayerCount = 1;
              _displayedPlayerCount = 1;
              _realPlayerCount = 1;
            });
          }
          _startHumanJoinWindow();
          _setupTournamentListener();
          return;
        }

        // Join existing tournament
        await doc.update({
          'players': FieldValue.arrayUnion([_uid]),
          'playerCount': FieldValue.increment(1),
          'realPlayers': FieldValue.arrayUnion([_uid]),
          'realPlayerCount': FieldValue.increment(1),
        });

        if (tourneyData.containsKey('createdAt') && tourneyData['createdAt'] != null) {
          final timestamp = tourneyData['createdAt'] as Timestamp;
          _tournamentCreatedTime = timestamp.toDate();
        } else {
          _tournamentCreatedTime = DateTime.now();
        }

        print('Joined tournament ${doc.id} with ${totalPlayerCount + 1} total players (${realPlayerCount + 1} real)');

        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = totalPlayerCount + 1;
            _displayedPlayerCount = totalPlayerCount + 1;
            _realPlayerCount = realPlayerCount + 1;
          });
        }

        // Continue with existing tournament timing
        _startHumanJoinWindow();

        // ADDED: Set up tournament listener
        _setupTournamentListener();
      }
    } catch (e) {
      print('Error joining/creating tournament: $e');
      try {
        final doc = await _db.collection('tournaments').add({
          'status': 'waiting',
          'round': 0,
          'players': [_uid],
          'playerCount': 1,
          'realPlayers': [_uid],
          'realPlayerCount': 1,
          'maxPlayers': TOURNAMENT_SIZE,
          'createdAt': FieldValue.serverTimestamp(),
          'gameType': 'precision_tap',
          'bots': <String, dynamic>{},
          'botsSubmitted': false,
        });
        _tournamentCreatedTime = DateTime.now();
        print('Created fallback tournament: ${doc.id} with 1 player');
        if (mounted) {
          setState(() {
            _tourneyId = doc.id;
            _actualPlayerCount = 1;
            _displayedPlayerCount = 1;
            _realPlayerCount = 1;
          });
        }
        _startHumanJoinWindow();
        _setupTournamentListener();
      } catch (e2) {
        print('Failed to create fallback tournament: $e2');
      }
    }
  }

  // ADDED: Setup tournament listener
  void _setupTournamentListener() {
    if (_tourneyId == null) return;

    print('Setting up tournament listener for $_tourneyId');
    _tournamentListener = _db.collection('tournaments').doc(_tourneyId!).snapshots().listen((snap) {
      if (!mounted) return;

      final data = snap.data();
      if (data == null) return;

      final status = data['status'] as String? ?? 'waiting';
      final round = data['round'] as int? ?? 0;
      final playerCount = data['playerCount'] as int? ?? 0;

      print('Tournament update - Status: $status, Round: $round, Players: $playerCount');

      // Update local state
      setState(() {
        _currentStatus = status;
        _currentRound = round;
        _actualPlayerCount = playerCount;
        _displayedPlayerCount = playerCount;
      });

      // Handle status changes
      if (status == 'round' && round > 0 && !_isNavigating) {
        print('🎮 Tournament started! Navigating to game...');
        // Add a small delay to ensure UI updates first
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isNavigating) {
            _navigateToGame(round);
          }
        });
      }
    }, onError: (error) {
      print('❌ Error in tournament listener: $error');
    });
  }

  // Start 15-second window for humans to join
  void _startHumanJoinWindow() {
    if (_tournamentCreatedTime == null) return;

    print('Starting 15-second human join window');

    // Check for new players and add bots every 500ms
    _botTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _checkAndAddBots();
    });

    // Lock tournament after 15 seconds
    _lockTimer = Timer(const Duration(seconds: 15), () {
      print('15 seconds elapsed - locking tournament and filling to 64 players');
      _lockTournamentAndFill();
    });
  }

  Future<void> _checkAndAddBots() async {
    if (_tourneyId == null || _tournamentCreatedTime == null || _isLocked) {
      return;
    }

    final waitTime = DateTime.now().difference(_tournamentCreatedTime!);
    final secondsElapsed = waitTime.inSeconds;

    final tourneyDoc = await _db.collection('tournaments').doc(_tourneyId!).get();
    final data = tourneyDoc.data();
    if (data == null) return;

    final currentCount = data['playerCount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'waiting';

    if (status != 'waiting' || currentCount >= TOURNAMENT_SIZE) {
      return;
    }

    // Gradual bot addition over 15 seconds to simulate natural joining
    int targetCount = currentCount;

    if (secondsElapsed <= 15) {
      // Progressive bot addition: reach about 45-55 players by 15 seconds
      final baseTarget = 3 + (secondsElapsed * 3); // About 3 players per second
      final randomVariation = math.Random().nextInt(5); // Add some randomness
      targetCount = math.min(currentCount + randomVariation + 1, baseTarget);
      targetCount = math.min(targetCount, 55); // Cap at 55 before final fill
    }

    // Add bots if we're below target, but never exceed 64 total
    if (targetCount > currentCount && currentCount < TOURNAMENT_SIZE) {
      final botsToAdd = math.min(targetCount - currentCount, TOURNAMENT_SIZE - currentCount);
      // CRITICAL: Ensure we never exceed 64 total players
      final finalTarget = math.min(currentCount + botsToAdd, TOURNAMENT_SIZE);
      final actualBotsToAdd = finalTarget - currentCount;

      if (actualBotsToAdd > 0) {
        print('Adding $actualBotsToAdd bots to reach $finalTarget (current: $currentCount)');
        try {
          final newBots = await BotService.addBotsToTournament(_tourneyId!, actualBotsToAdd);
          _tournamentBots.addAll(newBots);
          print('Successfully added ${newBots.length} bots');

          if (mounted) {
            setState(() {
              _actualPlayerCount = finalTarget;
              _displayedPlayerCount = finalTarget;
            });
          }
        } catch (e) {
          print('Error adding bots: $e');
        }
      }
    }
  }

  // Lock tournament and fill to exactly 64 players
  Future<void> _lockTournamentAndFill() async {
    if (_tourneyId == null || _isLocked) return;

    _isLocked = true;
    _botTimer?.cancel();

    try {
      final tourneyDoc = await _db.collection('tournaments').doc(_tourneyId!).get();
      final data = tourneyDoc.data();
      if (data == null) return;

      final currentTotalCount = data['playerCount'] as int? ?? 0;

      // Fill to exactly 64 players
      if (currentTotalCount < TOURNAMENT_SIZE) {
        final botsNeeded = TOURNAMENT_SIZE - currentTotalCount;
        print('Final fill: adding $botsNeeded bots to reach exactly $TOURNAMENT_SIZE players');

        final newBots = await BotService.addBotsToTournament(_tourneyId!, botsNeeded);
        _tournamentBots.addAll(newBots);

        if (mounted) {
          setState(() {
            _actualPlayerCount = TOURNAMENT_SIZE;
            _displayedPlayerCount = TOURNAMENT_SIZE;
          });
        }
      }

      // Show ad countdown
      await _showAdCountdown();

      // FIXED: Submit bot results BEFORE starting tournament
      print('🤖 Pre-submitting bot results before tournament start...');
      await _submitAllBotResults(1);
      _botsSubmitted = true;

      // Start the tournament
      await _startTournament();

    } catch (e) {
      print('Error locking and filling tournament: $e');
    }
  }

  Future<void> _showAdCountdown() async {
    print('Starting 15-second ad countdown');

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

    print('🏁 Starting tournament with 64 participants...');

    try {
      // FIXED: Use transaction to ensure atomicity
      await _db.runTransaction((transaction) async {
        final tourneyRef = _db.collection('tournaments').doc(_tourneyId!);

        transaction.update(tourneyRef, {
          'status': 'round',
          'round': 1,
          'startedAt': FieldValue.serverTimestamp(),
          'finalPlayerCount': TOURNAMENT_SIZE,
          'botsSubmitted': true, // Track that bots are submitted
        });
      });

      print('✅ Tournament status updated successfully - should trigger navigation via listener');

      // The navigation will happen via the listener when it detects the status change
    } catch (e) {
      print('❌ Error starting tournament: $e');
      rethrow;
    }
  }

  void _navigateToGame(int round) {
    print('🎮 _navigateToGame called - Round: $round, isNavigating: $_isNavigating, mounted: $mounted');

    if (_isNavigating) {
      print('🚫 Already navigating, skipping...');
      return;
    }

    if (!mounted) {
      print('🚫 Widget not mounted, skipping...');
      return;
    }

    print('🔄 Setting navigation flag...');
    setState(() {
      _isNavigating = true;
    });

    // Cancel the tournament listener to prevent multiple navigation attempts
    _tournamentListener?.cancel();

    // Small delay to ensure state is updated
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        print('🚫 Widget unmounted during navigation delay');
        return;
      }

      print('🚀 Pushing to PrecisionTapScreen...');
      print('📋 Parameters: tourneyId=$_tourneyId, round=$round, target=$targetDuration');

      try {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              print('🎯 Building PrecisionTapScreen with target: $targetDuration, tourneyId: $_tourneyId, round: $round');
              return PrecisionTapScreen(
                target: targetDuration,
                tourneyId: _tourneyId!,
                round: round,
                onUltimateComplete: null, // EXPLICITLY NULL for regular tournament
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        ).then((_) {
          print('✅ Navigation completed successfully!');
        }).catchError((error) {
          print('❌ Navigation error: $error');
          if (mounted) {
            setState(() {
              _isNavigating = false;
            });
          }
        });
      } catch (e) {
        print('❌ Navigation exception: $e');
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
        }
      }
    });
  }

  Future<void> _submitAllBotResults(int round) async {
    print('🤖 Submitting bot results for round $round...');
    try {
      final tourneyDoc = await _db.collection('tournaments').doc(_tourneyId!).get();
      final data = tourneyDoc.data();
      if (data == null || !data.containsKey('bots')) {
        print('🤖 No bot data found');
        return;
      }

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
        print('🤖 Submitting results for ${allBots.length} bots...');
        await BotService.submitBotResults(_tourneyId!, round, allBots, targetDuration);
        print('🤖 Bot results submitted successfully');
      } else {
        print('🤖 No bots to submit results for');
      }
    } catch (e) {
      print('❌ Error getting tournament bots: $e');
      rethrow; // Re-throw so the calling method knows there was an error
    }
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _lockTimer?.cancel();
    _tournamentListener?.cancel(); // ADDED: Cancel tournament listener
    _backgroundController.dispose();
    _pulsController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Lobby build called, tourneyId: $_tourneyId, status: $_currentStatus');

    if (_tourneyId == null) {
      print('Tournament ID is null, showing loading screen');
      return _buildPsychedelicLoadingScreen();
    }

    // Use local state instead of StreamBuilder to avoid rebuild loops
    if (_isShowingAd || _adCountdown > 0) {
      print('🎬 Showing ad countdown screen (adCountdown: $_adCountdown)');
      return _buildAdCountdownScreen();
    }

    switch (_currentStatus) {
      case 'waiting':
        print('⏳ Status is waiting, showing waiting screen with $_displayedPlayerCount players');
        return _buildWaitingScreen(math.min(_displayedPlayerCount, TOURNAMENT_SIZE));

      case 'round':
        print('🎮 Status is ROUND! Showing starting screen...');
        return _buildStartingScreen();

      default:
        print('❌ Unknown status: $_currentStatus, showing error screen');
        return _buildErrorScreen();
    }
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
              // PRIMARY PSYCHEDELIC BACKGROUND - Using gradient config
              Container(
                decoration: BoxDecoration(
                  gradient: PsychedelicGradient.getRadialGradient(
                    interpolatedColors,
                    radius: 2.0,
                  ),
                ),
              ),

              // ROTATING OVERLAY 1 - Using gradient config
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: PsychedelicGradient.getOverlayGradient(
                        interpolatedColors,
                        _rotationController.value * 6.28,
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
                      gradient: PsychedelicGradient.getOverlayGradient(
                        interpolatedColors.reversed.toList(),
                        -_rotationController.value * 4.28,
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
                                      colors: PsychedelicGradient.getPsychedelicPalette(),
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
                              colors: PsychedelicGradient.getPsychedelicPalette(),
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
              // PRIMARY PSYCHEDELIC BACKGROUND - Using gradient config
              Container(
                decoration: BoxDecoration(
                  gradient: PsychedelicGradient.getRadialGradient(
                    interpolatedColors,
                    radius: 2.0,
                  ),
                ),
              ),

              // TRIPLE ROTATING OVERLAYS FOR MAXIMUM PSYCHEDELIA
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: PsychedelicGradient.getOverlayGradient(
                        interpolatedColors,
                        _rotationController.value * 6.28,
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
                      gradient: PsychedelicGradient.getOverlayGradient(
                        interpolatedColors.reversed.toList(),
                        -_rotationController.value * 4.28,
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
                                colors: PsychedelicGradient.getPsychedelicPalette(),
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                transform: GradientRotation(_rotationController.value * 2.0),
                              ).createShader(bounds),
                              child: Text(
                                'MINUTE MADNESS',
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
                          final scale = 1.0 + (_pulsController.value * 0.4);
                          final glowIntensity = 0.6 + (_pulsController.value * 0.6);

                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 25),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(35),
                                gradient: PsychedelicGradient.getRadialGradient(
                                  interpolatedColors,
                                  radius: 1.0,
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
                                    '$cappedCount/$TOURNAMENT_SIZE PLAYERS',
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
                                    _isLocked ? 'Tournament locked - finalizing...' : 'Players can join for ${15 - (DateTime.now().difference(_tournamentCreatedTime ?? DateTime.now()).inSeconds)} more seconds',
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
                              'Last Player Standing',
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
                              '⚡ 64-player elimination tournament\n'
                                  '🎯 6 rounds of precision timing challenges\n'
                                  '⏱️ Hit the perfect timing window\n'
                                  '💥 Miss the target and you\'re eliminated!\n'
                                  '🏆 Last player standing wins the madness',
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
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
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
              gradient: PsychedelicGradient.getRadialGradient(
                interpolatedColors,
                radius: 2.0,
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
                    '64 players ready for MINUTE MADNESS!',
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
    // Add a timer to navigate after showing this screen briefly
    Timer(const Duration(seconds: 1), () {
      if (mounted && !_isNavigating && _currentStatus == 'round' && _currentRound > 0) {
        print('🎮 Auto-navigating from starting screen after delay');
        _navigateToGame(_currentRound);
      }
    });

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
              gradient: PsychedelicGradient.getRadialGradient(
                interpolatedColors,
                radius: 2.0,
              ),
            ),
            child: AnimatedBuilder(
              animation: _scaleController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: PsychedelicGradient.getOverlayGradient(
                      interpolatedColors,
                      _scaleController.value * 6.28,
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
                              Icons.psychology,
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
                      'The 64-player precision tournament begins...',
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
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
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
                child: const Text('Return to Reality'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}