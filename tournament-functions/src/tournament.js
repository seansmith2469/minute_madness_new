// tournament-functions/src/tournament.js - SIMPLE VERSION
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Configuration
const TOURNAMENT_CONFIG = {
  MAX_PLAYERS: 64,
  SHARD_COUNT: 50,
  AUTO_START_DELAY_MS: 20000, // 20 seconds
};

// ====================================================================
// MAIN TOURNAMENT FUNCTIONS
// ====================================================================

/**
 * Join tournament queue - handles all the complexity
 */
exports.joinTournamentQueue = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { gameType, userId } = data;
  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  try {
    console.log(`🎮 User ${userId} joining ${gameType} tournament queue`);

    // Add to queue with atomic transaction
    const queueResult = await db.runTransaction(async (transaction) => {
      // Check if user is already in a tournament
      const existingTournament = await findUserActiveTournament(userId, transaction);
      if (existingTournament) {
        return {
          success: true,
          tourneyId: existingTournament.id,
          message: 'Already in active tournament',
          queuePosition: 0,
        };
      }

      // Add to queue
      const queueRef = db.collection('tournament_queue').doc();
      transaction.set(queueRef, {
        userId,
        gameType,
        timestamp,
        status: 'waiting',
      });

      // Get current queue position
      const queueSnapshot = await db
        .collection('tournament_queue')
        .where('gameType', '==', gameType)
        .where('status', '==', 'waiting')
        .orderBy('timestamp')
        .get();

      const queuePosition = queueSnapshot.size;

      return {
        success: true,
        queuePosition,
        estimatedWaitTime: Math.max(0, (queuePosition - TOURNAMENT_CONFIG.MAX_PLAYERS) * 1000),
      };
    });

    // Try to create tournament if queue is ready
    await tryCreateTournamentFromQueue(gameType);

    return queueResult;
  } catch (error) {
    console.error('❌ Error joining tournament queue:', error);
    throw new functions.https.HttpsError('internal', 'Failed to join tournament');
  }
});

/**
 * Submit tournament result
 */
exports.submitTournamentResult = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { tourneyId, userId, result } = data;

  try {
    const shardId = getShardId(tourneyId);
    const tournamentRef = db.collection(`tournaments_${shardId}`).doc(tourneyId);

    await db.runTransaction(async (transaction) => {
      const tournamentDoc = await transaction.get(tournamentRef);

      if (!tournamentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Tournament not found');
      }

      const tournament = tournamentDoc.data();

      if (!tournament.players.includes(userId)) {
        throw new functions.https.HttpsError('permission-denied', 'Not in this tournament');
      }

      // Submit result
      const resultRef = tournamentRef.collection('results').doc(userId);
      transaction.set(resultRef, {
        userId,
        result,
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        isBot: false,
      });

      console.log(`✅ Result submitted for user ${userId} in tournament ${tourneyId}`);
    });

    return { success: true };
  } catch (error) {
    console.error('❌ Error submitting result:', error);
    throw new functions.https.HttpsError('internal', 'Failed to submit result');
  }
});

/**
 * Get tournament results with ranking
 */
exports.getTournamentResults = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { tourneyId } = data;

  try {
    const shardId = getShardId(tourneyId);
    const resultsSnapshot = await db
      .collection(`tournaments_${shardId}`)
      .doc(tourneyId)
      .collection('results')
      .get();

    const results = [];
    resultsSnapshot.forEach(doc => {
      results.push({
        userId: doc.id,
        ...doc.data(),
      });
    });

    // Sort results based on game type
    const tournament = await db
      .collection(`tournaments_${shardId}`)
      .doc(tourneyId)
      .get();

    const tournamentData = tournament.data();

    if (tournamentData.gameType === 'timing') {
      // Sort by absolute error (best timing first)
      results.sort((a, b) => {
        const errorA = Math.abs(a.result.errorMs);
        const errorB = Math.abs(b.result.errorMs);
        return errorA - errorB;
      });
    } else if (tournamentData.gameType === 'memory') {
      // Sort by level (highest first), then by completion time (fastest first)
      results.sort((a, b) => {
        if (a.result.level !== b.result.level) {
          return b.result.level - a.result.level;
        }
        return a.result.completionTimeMs - b.result.completionTimeMs;
      });
    }

    // Add rankings
    const rankedResults = results.map((result, index) => ({
      ...result,
      rank: index + 1,
    }));

    return {
      success: true,
      results: rankedResults,
    };
  } catch (error) {
    console.error('❌ Error getting tournament results:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get results');
  }
});

/**
 * Manual trigger to create tournaments (called by app when needed)
 */
exports.createTournamentFromQueue = functions.https.onCall(async (data, context) => {
  const { gameType } = data;

  try {
    const tournamentId = await tryCreateTournamentFromQueue(gameType);
    return {
      success: true,
      tournamentId,
      message: tournamentId ? 'Tournament created' : 'Not enough players in queue',
    };
  } catch (error) {
    console.error('❌ Error creating tournament:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create tournament');
  }
});

// ====================================================================
// HELPER FUNCTIONS
// ====================================================================

/**
 * Try to create tournament from queue
 */
async function tryCreateTournamentFromQueue(gameType) {
  const queueSnapshot = await db
    .collection('tournament_queue')
    .where('gameType', '==', gameType)
    .where('status', '==', 'waiting')
    .orderBy('timestamp')
    .limit(TOURNAMENT_CONFIG.MAX_PLAYERS)
    .get();

  if (queueSnapshot.size < TOURNAMENT_CONFIG.MAX_PLAYERS) {
    console.log(`⏳ Queue for ${gameType}: ${queueSnapshot.size}/${TOURNAMENT_CONFIG.MAX_PLAYERS} players`);
    return null;
  }

  console.log(`🎯 Creating ${gameType} tournament with ${queueSnapshot.size} players`);

  // Create tournament with atomic transaction
  const tournamentId = await db.runTransaction(async (transaction) => {
    // Double-check queue hasn't changed
    const freshQueueSnapshot = await transaction.get(
      db.collection('tournament_queue')
        .where('gameType', '==', gameType)
        .where('status', '==', 'waiting')
        .orderBy('timestamp')
        .limit(TOURNAMENT_CONFIG.MAX_PLAYERS)
    );

    if (freshQueueSnapshot.size < TOURNAMENT_CONFIG.MAX_PLAYERS) {
      return null; // Someone else grabbed players
    }

    // Get player IDs
    const playerIds = freshQueueSnapshot.docs.map(doc => doc.data().userId);

    // Create tournament
    const tournamentRef = db.collection(`tournaments_${getShardId()}`).doc();
    transaction.set(tournamentRef, {
      gameType,
      status: 'waiting',
      players: playerIds,
      playerCount: playerIds.length,
      maxPlayers: TOURNAMENT_CONFIG.MAX_PLAYERS,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        hasRealPlayers: true,
        autoFillWithBots: true,
      },
    });

    // Mark queue entries as processed
    freshQueueSnapshot.docs.forEach(doc => {
      transaction.update(doc.ref, { status: 'assigned', tourneyId: tournamentRef.id });
    });

    return tournamentRef.id;
  });

  if (tournamentId) {
    console.log(`✅ Created tournament ${tournamentId} for ${gameType}`);

    // Add bots asynchronously (don't block)
    addBotsToTournament(tournamentId, gameType).catch(console.error);

    // Auto-start tournament after delay
    setTimeout(() => {
      startTournament(tournamentId).catch(console.error);
    }, TOURNAMENT_CONFIG.AUTO_START_DELAY_MS);
  }

  return tournamentId;
}

/**
 * Start a tournament
 */
async function startTournament(tournamentId) {
  try {
    const shardId = getShardId(tournamentId);
    await db.collection(`tournaments_${shardId}`).doc(tournamentId).update({
      status: 'active',
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`🚀 Started tournament ${tournamentId}`);
  } catch (error) {
    console.error(`❌ Error starting tournament ${tournamentId}:`, error);
  }
}

/**
 * Add bots to tournament
 */
async function addBotsToTournament(tournamentId, gameType) {
  const shardId = getShardId(tournamentId);
  const tournamentRef = db.collection(`tournaments_${shardId}`).doc(tournamentId);

  try {
    // Generate bots for this tournament
    const botIds = [];
    const batch = db.batch();

    for (let i = 0; i < TOURNAMENT_CONFIG.MAX_PLAYERS - 1; i++) {
      const botRef = db.collection('tournament_bots').doc();
      const botData = generateBot(gameType);

      batch.set(botRef, {
        ...botData,
        tourneyId: tournamentId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      botIds.push(botRef.id);
    }

    // Update tournament with bots
    batch.update(tournamentRef, {
      players: admin.firestore.FieldValue.arrayUnion(...botIds),
      playerCount: admin.firestore.FieldValue.increment(botIds.length),
    });

    await batch.commit();
    console.log(`🤖 Added ${botIds.length} bots to tournament ${tournamentId}`);

    // Submit bot results after a delay
    setTimeout(() => {
      submitBotResults(tournamentId, gameType, botIds).catch(console.error);
    }, 5000);

  } catch (error) {
    console.error('❌ Error adding bots:', error);
  }
}

/**
 * Submit bot results
 */
async function submitBotResults(tournamentId, gameType, botIds) {
  const shardId = getShardId(tournamentId);
  const tournamentRef = db.collection(`tournaments_${shardId}`).doc(tournamentId);

  for (const botId of botIds) {
    // Stagger bot submissions
    setTimeout(async () => {
      try {
        let result;
        if (gameType === 'timing') {
          result = generateTimingResult();
        } else {
          result = generateMemoryResult();
        }

        await tournamentRef.collection('results').doc(botId).set({
          userId: botId,
          result,
          submittedAt: admin.firestore.FieldValue.serverTimestamp(),
          isBot: true,
        });

        console.log(`🤖 Bot ${botId} submitted result for ${gameType} tournament`);
      } catch (error) {
        console.error(`❌ Error submitting bot result for ${botId}:`, error);
      }
    }, Math.random() * 10000); // Random delay 0-10 seconds
  }
}

// Utility functions
function getShardId(input = null) {
  if (input) {
    const hash = hashCode(input);
    return Math.abs(hash) % TOURNAMENT_CONFIG.SHARD_COUNT;
  }
  return Math.floor(Math.random() * TOURNAMENT_CONFIG.SHARD_COUNT);
}

function generateBot(gameType) {
  const botNames = [
    'TimeMaster42', 'PrecisionPro', 'QuickReflexes', 'SpeedDemon99',
    'MemoryMaster', 'BrainBox', 'RecallPro', 'MindPalace', 'NeuralNet',
  ];

  const difficulties = ['easy', 'medium', 'hard', 'veryHard'];

  return {
    name: `${botNames[Math.floor(Math.random() * botNames.length)]}_${Math.floor(Math.random() * 1000)}`,
    gameType,
    difficulty: difficulties[Math.floor(Math.random() * difficulties.length)],
    isBot: true,
  };
}

function generateTimingResult() {
  const targetMs = 3000;
  const errorRange = 50 + Math.random() * 400; // 50-450ms error
  const error = Math.random() > 0.5 ? errorRange : -errorRange;

  return {
    type: 'timing',
    errorMs: Math.round(error),
    targetMs,
    timestamp: Date.now(),
  };
}

function generateMemoryResult() {
  const level = 1 + Math.floor(Math.random() * 15); // 1-15 levels
  const baseTime = level * 8000; // 8 seconds per level base
  const completionTimeMs = baseTime + Math.random() * 5000; // Add some variance

  return {
    type: 'memory',
    level,
    completionTimeMs: Math.round(completionTimeMs),
    timestamp: Date.now(),
  };
}

async function findUserActiveTournament(userId, transaction) {
  // Check all shards for active tournaments with this user
  for (let i = 0; i < TOURNAMENT_CONFIG.SHARD_COUNT; i++) {
    const snapshot = await transaction.get(
      db.collection(`tournaments_${i}`)
        .where('players', 'array-contains', userId)
        .where('status', 'in', ['waiting', 'active'])
        .limit(1)
    );

    if (!snapshot.empty) {
      return snapshot.docs[0];
    }
  }
  return null;
}

// Hash function for sharding
function hashCode(str) {
  let hash = 0;
  if (str.length === 0) return hash;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return hash;
}