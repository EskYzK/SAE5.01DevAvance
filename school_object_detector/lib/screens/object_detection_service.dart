import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'dart:typed_data';

class ObjectDetectionService {
  late FlutterVision _vision;
  bool _isLoaded = false;

  Future<void> initialize() async {
    _vision = FlutterVision();
    
    // Chargement du modèle YOLOv8 et des étiquettes
    await _vision.loadYoloModel(
      modelPath: 'assets/ml/model.tflite',
      labels: 'assets/ml/labels.txt', 
      modelVersion: "yolov8", // Indispensable pour que la librairie comprenne le format
      numThreads: 2, 
      useGpu: true, // Active l'accélération graphique si possible
      quantization: false, // false car tu as exporté en float32
    );
    
    _isLoaded = true;
    print("Modèle YOLOv8 chargé avec succès via flutter_vision !");
  }

  // Traitement optimisé pour le flux vidéo (CameraImage)
  Future<List<Map<String, dynamic>>> processFrame(CameraImage cameraImage) async {
    if (!_isLoaded) return [];

    try {
      final result = await _vision.yoloOnFrame(
        bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        iouThreshold: 0.4, // Fusionne les rectangles qui se chevauchent trop
        confThreshold: 0.5, // Ne garde que ce qui est sûr à 50% minimum
        classThreshold: 0.5,
      );
      return result;
    } catch (e) {
      print('Erreur détection YOLO: $e');
      return [];
    }
  }

  // Traitement d'une image statique (depuis la galerie ou photo prise)
  Future<List<Map<String, dynamic>>> processImage(Uint8List imageBytes) async {
    if (!_isLoaded) return [];

    try {
      final result = await _vision.yoloOnImage(
        bytesList: imageBytes,
        imageHeight: 1280, // YOLO redimensionnera, mais il faut des valeurs par défaut
        imageWidth: 720,
        iouThreshold: 0.4,
        confThreshold: 0.2,
        classThreshold: 0.2,
      );
      return result;
    } catch (e) {
      print('Erreur détection image fixe: $e');
      return [];
    }
  }

  void dispose() async {
    // Nettoyage de la mémoire
    if (_isLoaded) {
      await _vision.closeYoloModel();
    }
  }
}