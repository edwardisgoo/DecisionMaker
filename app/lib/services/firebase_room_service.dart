import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseRoomService {
  FirebaseRoomService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

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
            'createdAt': FieldValue.serverTimestamp(),
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
}
