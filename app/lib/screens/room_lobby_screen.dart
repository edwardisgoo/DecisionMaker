import 'package:flutter/material.dart';
import '../services/room_scope.dart';
import '../services/room_store.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/room_phase.dart';

class RoomLobbyScreen extends StatelessWidget {
  final String roomCode;

  const RoomLobbyScreen({super.key, required this.roomCode});

  @override
  Widget build(BuildContext context) {
    final store = RoomScope.of(context);
    final room = store.getByCode(roomCode);

    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room')),
        body: const Center(child: Text('Room vanished into the void.')),
      );
    }

    final isHost =
        room.participants.isNotEmpty && room.participants.first.isHost;

    return Scaffold(
      appBar: AppBar(title: Text(room.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Room Code: ${room.code}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${room.state.phase.label}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Participants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: room.participants.length,
                itemBuilder: (context, index) {
                  final p = room.participants[index];
                  return ListTile(
                    leading: Icon(
                      p.isHost ? FontAwesomeIcons.crown : Icons.person,
                      color: p.isHost ? Colors.amber : null,
                    ),
                    title: Text(p.name),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  (isHost && room.state.phase == RoomPhase.lobby)
                      ? () {
                        store.updateRoomState(
                          room.code,
                          room.state.copyWith(
                            phase: RoomPhase.submitCandidates,
                          ),
                        );
                      }
                      : null,
              child: Text(
                room.state.phase == RoomPhase.lobby
                    ? 'Start Phase 1'
                    : 'Waiting…',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
