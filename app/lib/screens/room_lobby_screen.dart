import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_room_service.dart';
import 'proposal_screen.dart';
import 'voting_screen.dart';

class RoomLobbyScreen extends StatefulWidget {
  final String roomCode;

  const RoomLobbyScreen({super.key, required this.roomCode});

  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  final _svc = FirebaseRoomService.instance;
  String? _lastPhase;

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Room Lobby')),
      body: StreamBuilder(
        stream: _svc.roomStream(widget.roomCode),
        builder: (context, roomSnap) {
          if (roomSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!roomSnap.hasData || !(roomSnap.data?.exists ?? false)) {
            return const Center(child: Text('Room not found.'));
          }

          final data = roomSnap.data!.data()!;
          final title = (data['title'] ?? '') as String;
          final hostUid = (data['hostUid'] ?? '') as String;
          final phase = (data['phase'] ?? 'lobby') as String;
          final isMeHost = myUid == hostUid;

          // Handle phase transitions
          if (phase != 'lobby' && phase != _lastPhase) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (phase == 'proposal') {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ProposalScreen(roomCode: widget.roomCode),
                    ),
                  );
                } else if (phase == 'voting') {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => VotingScreen(roomCode: widget.roomCode),
                    ),
                  );
                }
              }
            });
            _lastPhase = phase;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Room Code: ${widget.roomCode}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Participants',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder(
                    stream: _svc.participantsStream(widget.roomCode),
                    builder: (context, partSnap) {
                      if (partSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = partSnap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No participants yet.'),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final p = docs[index].data();
                          final uid = docs[index].id;
                          final name = (p['name'] ?? 'Someone') as String;
                          final isHost = (p['isHost'] ?? false) as bool;

                          return ListTile(
                            leading: Icon(
                              isHost ? Icons.star : Icons.person,
                              color: isHost ? Colors.amber : null,
                            ),
                            title: Text(name),
                            subtitle: Text(uid == myUid ? 'You' : ''),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: isMeHost
                      ? () async {
                          try {
                            await _svc.updateRoomPhase(
                              widget.roomCode,
                              'proposal',
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to start: $e')),
                              );
                            }
                          }
                        }
                      : null,
                  child: Text(
                    isMeHost ? 'Host: Start (next)' : 'Waiting for host…',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
