import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ObjectDetectionService {
  late FlutterVision _vision;
  bool _isLoaded = false;

  // Le nom que l'on donnera au fichier mis à jour
  static const String customModelName = "updated_model.tflite";

  Future<void> initialize() async {
    _vision = FlutterVision();
    await _loadModel();
  }

  Future<void> _loadModel() async {
    // 1. On détermine quel fichier charger
    String modelPathToLoad = 'assets/ml/model.tflite'; // Par défaut (Usine)
    bool isCustom = false;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final customModelFile = File('${directory.path}/$customModelName');

      // 2. Si un modèle mis à jour existe, on le prend !
      if (await customModelFile.exists()) {
        print("🚀 CHARGEMENT DU MODÈLE MIS À JOUR : ${customModelFile.path}");
        modelPathToLoad = customModelFile.path;
        isCustom = true;
      } else {
        print("📦 CHARGEMENT DU MODÈLE D'USINE (Assets)");
      }

      // 3. Chargement
      await _vision.loadYoloModel(
        modelPath: modelPathToLoad,
        labels: 'assets/ml/labels.txt', // On garde les mêmes labels
        modelVersion: "yolov8",
        numThreads: 2,
        useGpu: true,
        quantization: false,
      );
      
      _isLoaded = true;

    } catch (e) {
      print("Erreur chargement modèle: $e");
      // Fallback : si le custom plante, on essaie de charger l'asset de base
      if (isCustom) {
        print("⚠️ Le modèle custom a échoué, retour à l'usine.");
        await _vision.loadYoloModel(
          modelPath: 'assets/ml/model.tflite',
          labels: 'assets/ml/labels.txt',
          modelVersion: "yolov8",
          numThreads: 2,
          useGpu: true,
          quantization: false,
        );
        _isLoaded = true;
      }
    }
  }

  // Fonction pour forcer le rechargement (utile après un import)
  Future<void> reloadModel() async {
    if (_isLoaded) {
      await _vision.closeYoloModel();
      _isLoaded = false;
    }
    await _loadModel();
  }

  Future<List<Map<String, dynamic>>> processFrame(CameraImage cameraImage) async {
    if (!_isLoaded) return [];

    try {
      final result = await _vision.yoloOnFrame(
        bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        iouThreshold: 0.4,
        confThreshold: 0.5,
        classThreshold: 0.5,
      );
      return result;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> processImage(Uint8List imageBytes, int width, int height) async {
    if (!_isLoaded) return [];

    try {
      final result = await _vision.yoloOnImage(
        bytesList: imageBytes,
        imageHeight: height,
        imageWidth: width,
        iouThreshold: 0.4,
        confThreshold: 0.5,
        classThreshold: 0.5,
      );
      return result;
    } catch (e) {
      return [];
    }
  }

  void dispose() async {
    if (_isLoaded) {
      await _vision.closeYoloModel();
      _isLoaded = false;
    }
  }
}