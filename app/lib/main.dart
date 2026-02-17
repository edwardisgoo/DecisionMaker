import 'package:flutter/material.dart';
import 'app.dart';
import 'services/room_scope.dart';
import 'services/room_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RoomScope(store: RoomStore(), child: const DecisionMakerApp()));
}
