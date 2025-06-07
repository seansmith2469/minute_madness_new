import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TournamentSetupScreen extends StatefulWidget {
  const TournamentSetupScreen({super.key});

  @override
  State<TournamentSetupScreen> createState() => _TournamentSetupScreenState();
}

class _TournamentSetupScreenState extends State<TournamentSetupScreen> {
  final TextEditingController _tourneyIdController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

  @override
  void dispose() {
    _tourneyIdController.dispose();
    super.dispose();
  }

  Future<void> _createTournament(String tourneyId) async {
    if (_isCreating) return; // Prevent double-tap

    setState(() {
      _isCreating = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      final tournamentRef = FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tourneyId);

      // Check if tournament already exists
      final existingDoc = await tournamentRef.get();
      if (existingDoc.exists) {
        throw Exception('Tournament ID already exists');
      }

      // Create tournament with more comprehensive data
      await tournamentRef.set({
        'id': tourneyId,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting', // waiting, active, completed
        'currentRound': 1,
        'totalPlayers': 64,
        'playersRemaining': 64,
        'players': <String>[], // List of player UIDs
        'playerCount': 0,
        'maxPlayers': 64,
        'targetDuration': 3000, // 3 seconds in milliseconds
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tournament "$tourneyId" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back or to tournament lobby
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating tournament: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  String? _validateTournamentId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Tournament ID is required';
    }

    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Tournament ID must be at least 3 characters';
    }

    if (trimmed.length > 20) {
      return 'Tournament ID must be less than 20 characters';
    }

    // Check for valid characters (alphanumeric and underscores)
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      return 'Only letters, numbers, and underscores allowed';
    }

    return null;
  }

  void _generateRandomId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomId = 'tournament_$timestamp';
    _tourneyIdController.text = randomId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tournament'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tournament Settings',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _tourneyIdController,
                        validator: _validateTournamentId,
                        decoration: InputDecoration(
                          labelText: 'Tournament ID',
                          hintText: 'Enter unique ID (e.g., tourney_123)',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.shuffle),
                            onPressed: _generateRandomId,
                            tooltip: 'Generate random ID',
                          ),
                        ),
                        enabled: !_isCreating,
                      ),

                      const SizedBox(height: 16),

                      // Tournament info
                      const _TournamentInfo(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isCreating ? null : () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    final id = _tourneyIdController.text.trim();
                    await _createTournament(id);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isCreating
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Creating Tournament...'),
                  ],
                )
                    : const Text(
                  'Create Tournament',
                  style: TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 16),

              OutlinedButton(
                onPressed: _isCreating ? null : () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Separate widget for tournament info to avoid rebuilds
class _TournamentInfo extends StatelessWidget {
  const _TournamentInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tournament Details:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const _InfoRow(label: 'Max Players:', value: '64'),
          const _InfoRow(label: 'Target Time:', value: '3.000 seconds'),
          const _InfoRow(label: 'Format:', value: 'Single Elimination'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}