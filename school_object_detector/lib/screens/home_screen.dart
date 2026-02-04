import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Optionnel si vous voulez changer l'icône selon l'état

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static Future<void> _downloadModel(BuildContext context, Reference modelRef) async {
  try {
    // Afficher un indicateur de chargement
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Téléchargement du nouveau cerveau..."), duration: Duration(seconds: 2))
    );

    final directory = await getApplicationDocumentsDirectory();
    final File targetFile = File('${directory.path}/updated_model.tflite');

    // Téléchargement direct vers le fichier local utilisé par ObjectDetectionService
    await modelRef.writeToFile(targetFile);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Cerveau mis à jour ! Redémarrez l'application."),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    debugPrint("Erreur téléchargement: $e");
  }
}

  static Future<void> _importNewModel(BuildContext context) async {
    try {
      // 1. Lister les fichiers dans le dossier "models" de Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child("models");
      final listResult = await storageRef.listAll();

      if (listResult.items.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucun nouveau modèle disponible pour le moment."))
          );
        }
        return;
      }

      // 2. Afficher une boîte de dialogue de sélection
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Choisir un modèle"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: listResult.items.length,
                itemBuilder: (c, i) {
                  final item = listResult.items[i];
                  return ListTile(
                    leading: const Icon(Icons.psychology, color: Color(0xFF6A11CB)),
                    title: Text(item.name),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _downloadModel(context, item);
                    },
                  );
                },
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur liste modèles: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // AJOUT DE L'APPBAR ICI
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Fond transparent
        elevation: 0, // Pas d'ombre
        actions: [
          // Bouton Profil / Connexion
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2), // Petit fond semi-transparent
                ),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              onPressed: () {
                // Navigation vers la page d'authentification
                Navigator.pushNamed(context, '/auth');
              },
              tooltip: "Mon compte",
            ),
          ),
        ],
      ),
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
                // J'ai réduit le SizedBox initial car l'AppBar prend un peu de place visuelle
                const SizedBox(height: 20), 

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
                // ... (Le reste du code reste exactement le même) ...
                const SizedBox(height: 25),

                const Text(
                  "Scolarize",
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
                  "Identifiez instantanément les objets scolaires du quotidien",
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

  // ... (Garder _mainButton et _menuDropdownButton inchangés) ...
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
              color: Colors.black.withOpacity(0.2), // Note: withValues -> withOpacity pour compatibilité
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

  static Widget _menuDropdownButton(BuildContext context) {
      // Copier-coller votre code existant pour ce widget ici
      // J'ai remis le code pour être complet si besoin
      return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          popupMenuTheme: PopupMenuThemeData(
            color: const Color(0xFF2575FC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            textStyle: const TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        child: PopupMenuButton<String>(
          offset: const Offset(0, 60),
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
              enabled: false,
              height: 1,
              padding: EdgeInsets.zero,
              child: Divider(color: Colors.white30, thickness: 0.5, height: 1),
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
              child: Divider(color: Colors.white30, thickness: 0.5, height: 1),
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
              enabled: false,
              height: 1,
              padding: EdgeInsets.zero,
              child: Divider(color: Colors.white30, thickness: 0.5, height: 1),
            ),
            const PopupMenuItem<String>(
              value: 'import_model',
              child: Row(
                children: [
                  Icon(Icons.download_for_offline, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Importer un modèle', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ],
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
                Spacer(),
                Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}