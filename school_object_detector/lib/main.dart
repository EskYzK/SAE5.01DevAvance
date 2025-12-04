// lib/main.dart
import 'package:flutter/material.dart';
import 'camera_screen.dart'; // Importe ton nouvel écran

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Important pour les plugins
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Object Detector',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CameraScreen(), // Lance directement la caméra
    );
  }
}