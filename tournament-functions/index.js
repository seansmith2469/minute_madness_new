const tournament = require('./src/tournament');

// Export all tournament functions
exports.joinTournamentQueue = tournament.joinTournamentQueue;
exports.submitTournamentResult = tournament.submitTournamentResult;
exports.getTournamentResults = tournament.getTournamentResults;
exports.createTournamentFromQueue = tournament.createTournamentFromQueue;