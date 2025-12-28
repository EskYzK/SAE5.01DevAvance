import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ObjectDetectionService {
  ObjectDetector? _objectDetector;

  Future<void> initialize() async {
    final modelPath = await _copyAssetToLocal('assets/ml/model.tflite');
    
    final options = LocalObjectDetectorOptions(
      mode: DetectionMode.stream,
      modelPath: modelPath,
      classifyObjects: true, 
      multipleObjects: true, 
      confidenceThreshold: 0.5,
    );

    _objectDetector = ObjectDetector(options: options);
    print("Modèle IA chargé avec succès !");
  }

  Future<String> _copyAssetToLocal(String assetPath) async {
    final path = '${(await getApplicationSupportDirectory()).path}/${basename(assetPath)}';
    final file = File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return path;
  }

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