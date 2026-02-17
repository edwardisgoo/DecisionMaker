import 'package:flutter/material.dart';
import 'room_lobby_screen.dart';
import '../services/firebase_room_service.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _codeController = TextEditingController();
  final _svc = FirebaseRoomService.instance;
  bool _loading = false;

  String _normalize(String input) =>
      input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  bool _isValidCode(String code) =>
      RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code);

  Future<void> _join() async {
    final code = _normalize(_codeController.text);

    if (!_isValidCode(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That room code is invalid.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _svc.joinRoom(code: code, name: 'Member');
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomLobbyScreen(roomCode: code)),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Join failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Room')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter room code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '6-character code',
                hintText: 'e.g., K7P3XZ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _join,
              child: Text(_loading ? 'Joining…' : 'Join'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tip: codes don’t use 0/O/I/1 to avoid human suffering.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
