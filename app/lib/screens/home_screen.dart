import 'package:flutter/material.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decision Maker')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kill the “where?” loop.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a room, invite friends, force a decision.',
              style: TextStyle(fontSize: 16),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
                );
              },
              child: const Text('Create Room'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                );
              },
              child: const Text('Join Room'),
            ),
          ],
        ),
      ),
    );
  }
}
