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
        await _db.runTransaction((tx) async {
          final roomSnap = await tx.get(roomRef);
          if (roomSnap.exists) throw StateError('Room code collision');

          tx.set(roomRef, {
            'title': cleanTitle,
            'hostUid': uid,
            'phase': 'lobby',
            'createdAt': FieldValue.serverTimestamp(),
            'lastActiveAt': FieldValue.serverTimestamp(),
          });

          tx.set(roomRef.collection('participants').doc(uid), {
            'name': hostName,
            'isHost': true,
            'joinedAt': FieldValue.serverTimestamp(),
          });
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

    final snap = await roomRef.get();
    if (!snap.exists) throw StateError('Room not found');

    await roomRef.update({
      'lastActiveAt': FieldValue.serverTimestamp(),
    });

    await roomRef.collection('participants').doc(uid).set({
      'name': name,
      'isHost': false,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
}
