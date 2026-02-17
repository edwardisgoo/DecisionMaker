import 'package:flutter/widgets.dart';
import 'room_store.dart';

class RoomScope extends InheritedNotifier<RoomStore> {
  const RoomScope({super.key, required RoomStore store, required Widget child})
    : super(notifier: store, child: child);

  static RoomStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RoomScope>();
    assert(scope != null, 'RoomScope not found. Wrap your app with RoomScope.');
    return scope!.notifier!;
  }
}
