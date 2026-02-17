import 'room_phase.dart';

class RoomState {
  final RoomPhase phase;
  final int round;

  const RoomState({required this.phase, this.round = 1});

  RoomState copyWith({RoomPhase? phase, int? round}) {
    return RoomState(phase: phase ?? this.phase, round: round ?? this.round);
  }
}
