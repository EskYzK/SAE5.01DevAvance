import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Fonction pour importer un nouveau fichier .tflite
  static Future<void> _importNewModel(BuildContext context) async {
    try {
      // 1. Ouvrir le sélecteur de fichiers
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tflite'],
      );

      if (result != null && result.files.single.path != null) {
        File sourceFile = File(result.files.single.path!);
        
        // 2. Copier vers le dossier documents en renommant
        final directory = await getApplicationDocumentsDirectory();
        final String newPath = '${directory.path}/updated_model.tflite';
        final File targetFile = File(newPath);

        // On supprime l'ancien s'il existe
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        
        await sourceFile.copy(newPath);
        
        // 3. Feedback
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Cerveau mis à jour ! Redémarrez l'application."),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Erreur import: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
                const SizedBox(height: 25),

                const Text(
                  "Reconnaissance d’objets scolaires",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Identifiez instantanément les objets du quotidien en classe",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 70),

                _mainButton(
                  context,
                  label: "Détection en temps réel",
                  icon: Icons.videocam_outlined,
                  color: Colors.white,
                  textColor: const Color(0xFF6A11CB),
                  onTap: () => Navigator.pushNamed(context, '/camera'),
                ),
                const SizedBox(height: 20),

                _mainButton(
                  context,
                  label: "Analyser une image enregistrée",
                  icon: Icons.image_outlined,
                  color: Colors.white,
                  textColor: const Color(0xFF2575FC),
                  onTap: () => Navigator.pushNamed(context, '/gallery'),
                ),
                
                const SizedBox(height: 20),

                // NOUVEAU : Le menu déroulant remplace les deux boutons précédents
                _menuDropdownButton(context),

                const Spacer(),

                const Text(
                  "v1.0 • Équipe Flutter | Université de Lorraine",
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

  // Widget principal (inchangé)
  static Widget _mainButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center, 
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NOUVEAU : Widget pour le menu déroulant stylisé
  static Widget _menuDropdownButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.8),
      ),
      child: Theme(
        // Force le style sombre pour le menu popup
        data: Theme.of(context).copyWith(
          popupMenuTheme: PopupMenuThemeData(
            color: const Color(0xFF2575FC), // Fond bleu du menu
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            textStyle: const TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        child: PopupMenuButton<String>(
          offset: const Offset(0, 60), // Fait apparaître le menu sous le bouton
          onSelected: (value) {
            if (value == 'history') {
              Navigator.pushNamed(context, '/history');
            } else if (value == 'community') {
              Navigator.pushNamed(context, '/community');
            } else if (value == 'training') {
              Navigator.pushNamed(context, '/training');
            } else if (value == 'import_model') {
              _importNewModel(context);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'history',
              child: Row(
                children: [
                  Icon(Icons.history_outlined, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Voir l’historique', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              enabled: false,        // Rend l'item non-cliquable
              height: 1,             // Force la hauteur de l'item au minimum
              padding: EdgeInsets.zero, // Enlève les marges par défaut
              child: Divider(
                color: Colors.white30, // Une couleur blanche légèrement transparente
                thickness: 0.5,        // Un trait fin et élégant
                height: 1,             // La hauteur du conteneur du trait
              ),
            ),
            const PopupMenuItem<String>(
              value: 'community',
              child: Row(
                children: [
                  Icon(Icons.public, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Communauté', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              enabled: false,
              height: 1,
              padding: EdgeInsets.zero,
              child: Divider(
                color: Colors.white30,
                thickness: 0.5,
                height: 1,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'training',
              child: Row(
                children: [
                  Icon(Icons.dataset_outlined, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Collecte de données', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              enabled: false,        // Rend l'item non-cliquable
              height: 1,             // Force la hauteur de l'item au minimum
              padding: EdgeInsets.zero, // Enlève les marges par défaut
              child: Divider(
                color: Colors.white30, // Une couleur blanche légèrement transparente
                thickness: 0.5,        // Un trait fin et élégant
                height: 1,             // La hauteur du conteneur du trait
              ),
            ),
            const PopupMenuItem<String>(
              value: 'import_model',
              child: Row(
                children: [
                  Icon(Icons.download_for_offline, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Importer Modèle', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ],
          // L'apparence du bouton "fermé"
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text(
                  "Plus d'options",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(), // Pousse la flèche vers la droite pour équilibrer
                Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}