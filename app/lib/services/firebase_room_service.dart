import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseRoomService {
  FirebaseRoomService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  static final instance = FirebaseRoomService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String get uid => _auth.currentUser!.uid;

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> createRoom({
    required String title,
    String hostName = 'Host',
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('title is empty');

    for (int attempt = 0; attempt < 5; attempt++) {
      final code = _generateRoomCode();
      final roomRef = _db.collection('rooms').doc(code);

      try {
        // Create participant FIRST so isParticipant() passes for subsequent reads.
        await roomRef.collection('participants').doc(uid).set({
          'name': hostName,
          'isHost': true,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        // Now create the room doc. If the code already exists, this will be
        // evaluated as an 'update' and the security rules will reject it
        // (only the existing host can update), causing a retry.
        await roomRef.set({
          'title': cleanTitle,
          'hostUid': uid,
          'phase': 'lobby',
          'voteRound': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
        });

        return code;
      } catch (_) {
        // collision or transient issue, retry
      }
    }

    throw StateError('Failed to create room');
  }

  Future<void> joinRoom({required String code, String name = 'Member'}) async {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final roomRef = _db.collection('rooms').doc(normalized);

    // Create participant FIRST so isParticipant() passes for the room read.
    await roomRef.collection('participants').doc(uid).set({
      'name': name,
      'isHost': false,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Now we can read the room (isParticipant check passes).
    final snap = await roomRef.get();
    if (!snap.exists) throw StateError('Room not found');

    await roomRef.update({
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> roomStream(String code) {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return _db.collection('rooms').doc(normalized).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> participantsStream(String code) {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return _db
        .collection('rooms')
        .doc(normalized)
        .collection('participants')
        .orderBy('joinedAt')
        .snapshots();
  }

  Future<void> updateRoomPhase(String code, String phase) async {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final roomRef = _db.collection('rooms').doc(normalized);
    await roomRef.update({
      'phase': phase,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitProposal({
    required String code,
    required String proposalText,
    required String authorName,
  }) async {
    final cleanText = proposalText.trim();
    if (cleanText.isEmpty) throw ArgumentError('Proposal text is empty');

    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final proposalRef = _db
        .collection('rooms')
        .doc(normalized)
        .collection('proposals')
        .doc(uid);

    await proposalRef.set({
      'text': cleanText,
      'authorUid': uid,
      'authorName': authorName,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> proposalsStream(String code) {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return _db
        .collection('rooms')
        .doc(normalized)
        .collection('proposals')
        .snapshots();
  }

  int calculateVoteQuota(int participantCount) {
    if (participantCount <= 4) return 1;
    if (participantCount <= 10) return 2;
    if (participantCount <= 16) return 3;
    return 4;
  }

  Future<void> submitVotes({
    required String code,
    required List<String> votedProposalIds,
    required int round,
  }) async {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final voteRef = _db
        .collection('rooms')
        .doc(normalized)
        .collection('votes')
        .doc(uid);

    await voteRef.set({
      'votedProposalIds': votedProposalIds,
      'hasConfirmed': true,
      'round': round,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> votesStream(String code) {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return _db
        .collection('rooms')
        .doc(normalized)
        .collection('votes')
        .snapshots();
  }

  /// Tally votes from vote documents for a specific round.
  /// Returns { proposalId: voteCount }.
  Map<String, int> tallyVotes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> voteDocs,
    int round,
  ) {
    final tally = <String, int>{};
    for (final doc in voteDocs) {
      final docRound = (doc.data()['round'] ?? 1) as int;
      if (docRound != round) continue;
      final ids = List<String>.from(doc.data()['votedProposalIds'] ?? []);
      for (final id in ids) {
        tally[id] = (tally[id] ?? 0) + 1;
      }
    }
    return tally;
  }

  /// Submit a tie-breaker choice ('revote' or 'random').
  Future<void> submitTieBreakerChoice(String code, String choice) async {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    await _db
        .collection('rooms')
        .doc(normalized)
        .collection('tiebreaker')
        .doc(uid)
        .set({
          'choice': choice,
          'submittedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Stream tie-breaker choices.
  Stream<QuerySnapshot<Map<String, dynamic>>> tieBreakerStream(String code) {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return _db
        .collection('rooms')
        .doc(normalized)
        .collection('tiebreaker')
        .snapshots();
  }

  /// Set up a revote with only the tied candidates.
  /// Increments voteRound so old votes are ignored (no deletes needed).
  Future<void> startRevote(
    String code,
    List<String> tiedProposalIds,
  ) async {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final roomRef = _db.collection('rooms').doc(normalized);

    // Read current round to increment it
    final roomSnap = await roomRef.get();
    final currentRound = (roomSnap.data()?['voteRound'] ?? 1) as int;

    await roomRef.update({
      'revoteCandidateIds': tiedProposalIds,
      'voteRound': currentRound + 1,
      'phase': 'voting',
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  /// Persist the randomly selected winner.
  Future<void> setRandomWinner(String code, String winnerProposalId) async {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    await _db.collection('rooms').doc(normalized).update({
      'randomWinnerId': winnerProposalId,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }
}
