const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

exports.createTournament = functions.https.onCall(async (data, context) => {
  const { tournamentName } = data;

  if (!tournamentName) {
    throw new functions.https.HttpsError("invalid-argument", "Tournament name is required.");
  }

  // Create a tournament document
  const tournamentRef = await db.collection("tournaments").add({
    name: tournamentName,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Generate 64 mock players
  const players = [];
  for (let i = 1; i <= 64; i++) {
    players.push({
      name: `Player ${i}`,
      seed: i,
      score: null,
      roundEliminated: null,
    });
  }

  // Write players in a batch
  const batch = db.batch();
  const playersCollection = tournamentRef.collection("players");

  players.forEach((player) => {
    const docRef = playersCollection.doc();
    batch.set(docRef, player);
  });

  await batch.commit();

  return { tournamentId: tournamentRef.id, message: "Tournament created with 64 players." };
});
