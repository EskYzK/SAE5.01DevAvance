import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
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
  List<DetectedObject> _detectedObjects = [];
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

  // Gestion du cycle de vie (quand on quitte l'app ou tourne l'écran de manière forcée)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // CRUCIAL : On retire le contrôleur de l'UI avant de le dispose pour éviter le crash
      setState(() {
        _controller = null;
      });
      cameraController.dispose();
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

    final camera = _cameras[_selectedCameraIndex];

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 
          : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      
      // On vérifie si le widget est toujours monté avant d'appliquer le state
      if (!mounted) {
        return;
      }
      
      controller.startImageStream((CameraImage image) {
        if (!_isBusy) {
          _isBusy = true;
          _processFrame(image);
        }
      });

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      debugPrint("Erreur init caméra: $e");
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    // 1. On capture l'ancien contrôleur pour le fermer proprement
    final oldController = _controller;

    // 2. On met immédiatement à null dans le state pour que l'UI affiche l'écran noir
    // au lieu d'essayer d'afficher une caméra détruite.
    setState(() {
      _controller = null; 
      _isBusy = true; 
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    // 3. On dispose l'ancien
    await oldController?.stopImageStream();
    await oldController?.dispose();
    
    // Petite pause pour la stabilité
    await Future.delayed(const Duration(milliseconds: 200));

    // 4. On relance
    await _initCamera();
    
    if (mounted) {
      setState(() {
        _isBusy = false;
      });
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    // Sécurité maximale
    if (_controller == null || !_controller!.value.isInitialized || !mounted) {
       _isBusy = false;
       return;
    }

    try {
      final InputImage inputImage = _convertCameraImage(image);
      final objects = await _objectDetectionService.processImage(inputImage);

      if (mounted) {
        setState(() {
          _detectedObjects = objects;
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
          _isBusy = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur processing: $e");
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
  
  InputImage _convertCameraImage(CameraImage image) {
      final allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final InputImageRotation imageRotation = InputImageRotation.rotation90deg;
      final InputImageFormat inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.stopImageStream();
    _controller?.dispose();
    _objectDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si pas de contrôleur valide, on affiche un fond noir
    if (_controller == null || 
        !_controller!.value.isInitialized || 
        _controller!.value.previewSize == null) {
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
          Center(
            child: CameraPreview(_controller!),
          ),
          
          if (_imageSize != null)
            CustomPaint(
              painter: ObjectPainter(
                _detectedObjects, 
                _imageSize!, 
                _controller!.value.previewSize!, 
                _cameras.isNotEmpty ? _cameras[_selectedCameraIndex].lensDirection : CameraLensDirection.back
              ),
            ),
            
          Positioned(
            top: 50,
            left: 20,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text("Retour", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A11CB).withOpacity(0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),

          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'SwitchCamera',
              backgroundColor: Colors.white.withOpacity(0.9),
              onPressed: _switchCamera,
              child: const Icon(Icons.cameraswitch, color: Color(0xFF6A11CB)),
            ),
          ),
        ],
      ),
    );
  }
}

class ObjectPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Size imageSize;
  final Size widgetSize; 
  final CameraLensDirection lensDirection;

  ObjectPainter(this.objects, this.imageSize, this.widgetSize, this.lensDirection);

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
      final double scaleX = size.width / imageSize.height; 
      final double scaleY = size.height / imageSize.width;

      double left = object.boundingBox.left * scaleX;
      double top = object.boundingBox.top * scaleY;
      double right = object.boundingBox.right * scaleX;
      double bottom = object.boundingBox.bottom * scaleY;

      if (lensDirection == CameraLensDirection.front) {
        final double centerX = size.width / 2;
        left = centerX + (centerX - left);
        right = centerX + (centerX - right);
        final temp = left; left = right; right = temp;
      }

      final Rect scaledRect = Rect.fromLTRB(left, top, right, bottom);

      canvas.drawRect(scaledRect, paint);

      String labelText = "Objet"; 
      if (object.labels.isNotEmpty) {
        final label = object.labels.first;
        labelText = "${label.text} ${(label.confidence * 100).toStringAsFixed(0)}%";
      } 

      const textStyle = TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold);
      final textSpan = TextSpan(text: labelText, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();

      final double textY = scaledRect.top - textPainter.height - 6; 
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(scaledRect.left, textY, textPainter.width + 12, textPainter.height + 4),
          const Radius.circular(4)
        ), 
        textBgPaint
      );
      
      textPainter.paint(canvas, Offset(scaledRect.left + 6, textY + 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}