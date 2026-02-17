import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class DecisionMakerApp extends StatelessWidget {
  const DecisionMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Decision Maker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}
