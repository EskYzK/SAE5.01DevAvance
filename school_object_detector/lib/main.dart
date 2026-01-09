// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';
import 'screens/home_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/history_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/community_screen.dart';
import 'screens/dataset_collection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ObjectDetectorApp());
}

class ObjectDetectorApp extends StatelessWidget {
  const ObjectDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'School Object Detector',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/camera': (context) => const CameraScreen(),
        '/gallery': (context) => const GalleryScreen(),
        '/history': (context) => const HistoryScreen(),
        '/community': (context) => const CommunityScreen(),
        '/training': (context) => const DatasetCollectionScreen(),
      },
    );
  }
}
