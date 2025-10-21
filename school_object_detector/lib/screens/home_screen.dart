import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:school_object_detector/screens/camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                const Icon(
                  Icons.photo_camera_outlined,
                  size: 90,
                  color: Colors.white,
                ),
                const SizedBox(height: 25),
                const Text(
                  "Object Detector",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Analysez vos images instantanément",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                _glassButton(
                  context,
                  label: "Détection en temps réel",
                  icon: Icons.videocam_outlined,
                  onTap: () async {
                    final imagePath = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CameraScreen()),
                    );
                    if (imagePath != null) {
                      // Affiche le chemin de l'image capturée
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Photo capturée : $imagePath')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
                _glassButton(
                  context,
                  label: "Analyser une image enregistrée",
                  icon: Icons.image_outlined,
                  onTap: () => Navigator.pushNamed(context, '/gallery'),
                ),
                const SizedBox(height: 20),
                _outlineButton(
                  context,
                  label: "Voir l’historique",
                  icon: Icons.history_outlined,
                  onTap: () => Navigator.pushNamed(context, '/history'),
                ),
                const Spacer(),
                const Text(
                  "v1.0 • Flutter Dev Team",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🌫️ Bouton glass effect
  static Widget _glassButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ⚪ Bouton outline
  static Widget _outlineButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white, width: 1.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}