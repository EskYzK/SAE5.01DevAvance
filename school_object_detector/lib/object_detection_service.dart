import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ObjectDetectionService {
  ObjectDetector? _objectDetector;

  Future<void> initialize() async {
    // 1. Copier le modèle des assets vers le stockage local de l'appareil
    // ML Kit a besoin d'un chemin de fichier absolu, pas d'un asset direct.
    final modelPath = await _copyAssetToLocal('assets/ml/model.tflite');
    
    // 2. Configurer le détecteur avec ton modèle personnalisé
    final options = LocalObjectDetectorOptions(
      mode: DetectionMode.stream, // Mode optimisé pour la vidéo en temps réel
      modelPath: modelPath,
      classifyObjects: true,     // Demander les labels (ex: "person", "chair")
      multipleObjects: true,     // Détecter plusieurs objets à la fois
      confidenceThreshold: 0.5,  // Seuil de confiance (50%)
    );

    _objectDetector = ObjectDetector(options: options);
    print("Modèle IA chargé avec succès !");
  }

  // Fonction utilitaire pour copier l'asset
  Future<String> _copyAssetToLocal(String assetPath) async {
    final path = '${(await getApplicationSupportDirectory()).path}/${basename(assetPath)}';
    final file = File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return path;
  }

  // Fonction pour analyser une image (InputImage provient de la caméra)
  Future<List<DetectedObject>> processImage(InputImage inputImage) async {
    if (_objectDetector == null) return [];
    try {
      return await _objectDetector!.processImage(inputImage);
    } catch (e) {
      print('Erreur de détection: $e');
      return [];
    }
  }

  void dispose() {
    _objectDetector?.close();
  }
}