enum RoomPhase { lobby, submitCandidates, vote, tieBreak, objection, done }

extension RoomPhaseLabel on RoomPhase {
  String get label {
    switch (this) {
      case RoomPhase.lobby:
        return 'Lobby';
      case RoomPhase.submitCandidates:
        return 'Phase 1: Candidates';
      case RoomPhase.vote:
        return 'Phase 2: Voting';
      case RoomPhase.tieBreak:
        return 'Phase 3: Random Selection';
      case RoomPhase.objection:
        return 'Phase 4: Objections';
      case RoomPhase.done:
        return 'Finished';
    }
  }
}
