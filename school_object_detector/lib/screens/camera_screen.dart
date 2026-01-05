import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'object_detection_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  late ObjectDetectionService _objectDetectionService;
  
  bool _isBusy = false;
  // 1. Changement de type : on stocke des Maps venant de YOLO
  List<Map<String, dynamic>> _detectedObjects = []; 
  Size? _imageSize;
  
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _objectDetectionService = ObjectDetectionService();
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      setState(() { _controller = null; });
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initialize() async {
    await _objectDetectionService.initialize();
    await _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied) return;

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    final controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      // Format d'image optimisé pour chaque plateforme
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      
      controller.startImageStream((image) {
        if (!_isBusy) {
          _isBusy = true;
          _processFrame(image);
        }
      });

      setState(() { _controller = controller; });
    } catch (e) {
      debugPrint("Erreur init caméra: $e");
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_controller == null || !mounted) {
       _isBusy = false;
       return;
    }

    // 2. Simplification : On passe l'image brute directement
    final objects = await _objectDetectionService.processFrame(image);

    if (mounted) {
      setState(() {
        _detectedObjects = objects;
        // On inverse largeur/hauteur car la caméra mobile est orientée à 90° (Portrait)
        _imageSize = Size(image.height.toDouble(), image.width.toDouble());
        _isBusy = false;
      });
    }
  }

  // La fonction de conversion _convertCameraImage a été supprimée (inutile)

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    
    final oldController = _controller;
    setState(() {
      _controller = null;
      _isBusy = true; 
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    await oldController?.stopImageStream();
    await oldController?.dispose();
    await Future.delayed(const Duration(milliseconds: 200));
    await _initCamera();
    
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _objectDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          
          if (_imageSize != null)
            CustomPaint(
              painter: ObjectPainter(
                _detectedObjects, 
                _imageSize!,
                _cameras[_selectedCameraIndex].lensDirection
              ),
            ),
            
          // Bouton Retour
          Positioned(
            top: 50, left: 20,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text("Retour", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB).withOpacity(0.7)),
            ),
          ),

          // Bouton Switch Caméra
          Positioned(
            top: 50, right: 20,
            child: FloatingActionButton(
              heroTag: 'SwitchCam',
              backgroundColor: Colors.white,
              onPressed: _switchCamera,
              child: const Icon(Icons.cameraswitch, color: Color(0xFF6A11CB)),
            ),
          ),
        ],
      ),
    );
  }
}

// 3. Le Peintre adapté au format YOLOv8
class ObjectPainter extends CustomPainter {
  final List<Map<String, dynamic>> objects;
  final Size imageSize;
  final CameraLensDirection lensDirection;

  ObjectPainter(this.objects, this.imageSize, this.lensDirection);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.red;

    final Paint textBgPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    for (var object in objects) {
      // YOLO renvoie : {'box': [x1, y1, x2, y2, prob], 'tag': 'label'}
      final box = object["box"]; 
      
      // Extraction des coordonnées brutes
      final double x1 = box[0];
      final double y1 = box[1];
      final double x2 = box[2];
      final double y2 = box[3];
      
      // Calcul du ratio d'échelle pour l'écran
      final double scaleX = size.width / imageSize.width;
      final double scaleY = size.height / imageSize.height;

      double left = x1 * scaleX;
      double top = y1 * scaleY;
      double right = x2 * scaleX;
      double bottom = y2 * scaleY;

      // Gestion du mode miroir pour la caméra selfie
      if (lensDirection == CameraLensDirection.front) {
        double temp = left;
        left = size.width - right;
        right = size.width - temp;
      }

      // Dessin du cadre
      final Rect rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, paint);

      // Préparation de l'étiquette (Nom + Confiance)
      final String label = "${object['tag']} ${(box[4] * 100).toStringAsFixed(0)}%";
      
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();

      // Dessin du fond de l'étiquette
      double textY = top - 24;
      if (textY < 0) textY = top + 4;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, textY, textPainter.width + 12, 24),
          const Radius.circular(4),
        ),
        textBgPaint,
      );

      // Dessin du texte
      textPainter.paint(canvas, Offset(left + 6, textY + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}