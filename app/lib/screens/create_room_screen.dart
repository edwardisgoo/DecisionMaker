import 'package:flutter/material.dart';
import 'dart:math';
import '../services/room_scope.dart';
import '../services/room_store.dart';
import '../models/participant.dart';
import 'room_lobby_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController _titleController = TextEditingController();
  String? _roomCode;

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/I/1 nonsense
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  void _createRoom() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your room a title, genius.')),
      );
      return;
    }

    final store = RoomScope.of(context);
    final code = _generateRoomCode();

    store.add(
      Room(
        code: code,
        title: title,
        participants: [
          Participant(
            id: 'host-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Host',
            isHost: true,
          ),
        ],
      ),
    );

    setState(() {
      _roomCode = code;
    });

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RoomLobbyScreen(roomCode: code)));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'What are we deciding?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Room title (e.g., “Dinner”, “Hangout”, “Trip”)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _createRoom,
              child: const Text('Create Room'),
            ),
            const SizedBox(height: 24),
            if (_roomCode != null) ...[
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Share this code with your friends:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Center(
                child: SelectableText(
                  _roomCode!,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Later this will actually mean something. For now, it’s a promise in six letters.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
