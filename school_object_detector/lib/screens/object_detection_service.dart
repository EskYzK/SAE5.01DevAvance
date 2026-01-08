import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'dart:typed_data';

class ObjectDetectionService {
  late FlutterVision _vision;
  bool _isLoaded = false;

  Future<void> initialize() async {
    _vision = FlutterVision();
    
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
    }
  }
}