import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/participant.dart';
import '../models/room_state.dart';
import '../models/room_phase.dart';

class Room {
  final String code;
  final String title;
  final DateTime createdAt;
  final List<Participant> participants;
  final RoomState state;

  Room({
    required this.code,
    required this.title,
    List<Participant>? participants,
    RoomState? state,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       participants = participants ?? [],
       state = state ?? const RoomState(phase: RoomPhase.lobby);
}

class RoomStore extends ChangeNotifier {
  final Map<String, Room> _roomsByCode = {};

  UnmodifiableListView<Room> get rooms => UnmodifiableListView(
    _roomsByCode.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  Room? getByCode(String code) => _roomsByCode[code];

  void add(Room room) {
    _roomsByCode[room.code] = room;
    notifyListeners();
  }

  void clear() {
    _roomsByCode.clear();
    notifyListeners();
  }

  void updateRoomState(String code, RoomState newState) {
    final room = _roomsByCode[code];
    if (room == null) return;

    _roomsByCode[code] = Room(
      code: room.code,
      title: room.title,
      participants: room.participants,
      createdAt: room.createdAt,
      state: newState,
    );

    notifyListeners();
  }
}
