class Participant {
  final String id;
  final String name;
  final bool isHost;

  Participant({required this.id, required this.name, this.isHost = false});
}
