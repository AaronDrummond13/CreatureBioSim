import 'package:flutter/material.dart';

import 'simulation_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          color: const Color(0xFF556688),
          child: const SimulationScreen(),
        ),
      ),
    );
  }
}
