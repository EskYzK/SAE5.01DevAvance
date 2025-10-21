import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const platform = MethodChannel('com.example.camera');

  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isRearCamera = true;
  bool _isInitialized = false;
  bool _isStreaming = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Handler pour recevoir les événements de Kotlin
    platform.setMethodCallHandler((call) async {
      if (call.method == "cameraUnavailable") {
        _handleCameraError(); // ta fonction existante
      }
    });

    _initCameras();
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      // Ajouter un listener pour les erreurs
      _controller!.addListener(() {
        final controllerValue = _controller!.value;
        if (controllerValue.hasError) {
          debugPrint('Erreur caméra détectée : ${controllerValue.errorDescription}');
          _handleCameraError();
        }
      });

      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);

      _startImageStream();
    }
  }

  void _handleCameraError() async {
    if (_isStreaming) {
      await _stopImageStream();
    }

    try {
      await _controller?.dispose();
    } catch (e) {
      debugPrint('Erreur lors de la fermeture du controller : $e');
    }

    setState(() {
      _controller = null;
      _isInitialized = false;
    });

    // Optionnel : afficher un message à l’utilisateur
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La caméra a été fermée ou rencontre une erreur')),
      );
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() => _isInitialized = false); // désactive temporairement l'affichage

    _isRearCamera = !_isRearCamera;
    final newCamera = _isRearCamera ? _cameras!.first : _cameras!.last;

    // Disposer de l'ancien controller
    await _stopImageStream(); // Arrêter le streaming si actif
    await _controller?.dispose();

    _controller = CameraController(
      newCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
      _startImageStream();
    } catch (e) {
      debugPrint('Erreur initialisation caméra : $e');
      _handleCameraError();
    }
  }

  Future<String?> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;

    final Directory extDir = await getTemporaryDirectory();
    final String dirPath = path.join(extDir.path, 'Pictures', 'school_object_detector');
    await Directory(dirPath).create(recursive: true);
    final String filePath = path.join(dirPath, '${DateTime.now().millisecondsSinceEpoch}.jpg');

    try {
      final XFile file = await _controller!.takePicture();
      await file.saveTo(filePath);
      return filePath;
    } catch (e) {
      debugPrint('Erreur lors de la capture : $e');
      return null;
    }
  }


  void _startImageStream() {
    if (_controller == null || !_controller!.value.isInitialized || _isStreaming) return;

    _isStreaming = true;

    _controller!.startImageStream((CameraImage image) async {
      if (_isProcessing) {
        // Ignorer cette image si une autre est déjà en cours de traitement
        return;
      }

      _isProcessing = true;

      try {
        // TODO: traiter l’image ici (ex: ML Kit)
        // Si conversion en InputImage, fermer les buffers pour éviter BufferQueue error
        // image.close();

      } finally {
        // Libérer le buffer après traitement
        _isProcessing = false;
        // Pas besoin de fermer image explicitement pour CameraImage
        // sauf si tu convertis en InputImage pour ML Kit
      }
    });
  }

  Future<void> _stopImageStream() async {
    if (!_isStreaming || _controller == null) return;

    _isStreaming = false;
    await _controller!.stopImageStream();
  }


  @override
  void dispose() {
    try {
      if (_isStreaming) {
        _stopImageStream();
      }
    } catch (_) {}

    _controller?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Positioned(
            top: 40,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'SwitchCamera', // <- ici tu mets un tag unique
              backgroundColor: Colors.white70,
              child: Icon(_isRearCamera ? Icons.cameraswitch_outlined : Icons.cameraswitch_sharp, color: Colors.black87),
              onPressed: _switchCamera,
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                heroTag: 'CaptureImage', // <- ici tu mets un tag unique
                backgroundColor: Colors.white,
                child: const Icon(Icons.camera_alt, color: Colors.black87),
                onPressed: () async {
                  final imagePath = await _takePicture();
                  if (imagePath != null) {
                    Navigator.pop(context, imagePath);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}