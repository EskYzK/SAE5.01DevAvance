import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'object_detection_service.dart';

import 'package:flutter/foundation.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  final ObjectDetectionService _objectDetectionService = ObjectDetectionService();
  bool _isBusy = false; // Pour éviter de surcharger le processeur
  List<DetectedObject> _detectedObjects = [];
  Size? _imageSize; // Taille réelle de l'image caméra pour la mise à l'échelle

  @override
  void initState() {
    super.initState();
    _startCamera();
    _objectDetectionService.initialize();
  }

  Future<void> _startCamera() async {
    // Demander la permission caméra
    var status = await Permission.camera.request();
    if (status.isDenied) return;

    final cameras = await availableCameras();
    // Utiliser la caméra arrière par défaut
    final firstCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium, // Une résolution moyenne suffit pour l'IA et est plus rapide
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 // Format standard Android pour ML Kit
          : ImageFormatGroup.bgra8888, // Format standard iOS
    );

    await _controller!.initialize();
    
    // Commencer le flux d'images
    _controller!.startImageStream((CameraImage image) {
      if (!_isBusy) {
        _isBusy = true;
        _processFrame(image);
      }
    });

    setState(() {});
  }

  Future<void> _processFrame(CameraImage image) async {
    // Convertir l'image de la caméra au format ML Kit InputImage
    // Note: C'est une simplification. Pour un code de prod robuste, 
    // il faut gérer la rotation et les métadonnées plus finement.
    
    final InputImage inputImage = _convertCameraImage(image);
    
    final objects = await _objectDetectionService.processImage(inputImage);

    if (mounted) {
      setState(() {
        _detectedObjects = objects;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        _isBusy = false;
      });
    }
  }
  
  // NOTE: Cette fonction de conversion est cruciale. 
  // Dans un vrai projet, elle est souvent plus complexe pour gérer Android/iOS parfaitement.
  // Voici une version simplifiée pour tester rapidement.
  InputImage _convertCameraImage(CameraImage image) {
      // Pour ce test rapide, on suppose une rotation standard (portrait)
      // Dans l'idéal, utilisez les helpers de google_mlkit_commons
      final allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final InputImageRotation imageRotation = InputImageRotation.rotation90deg;
      final InputImageFormat inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      // ATTENTION: La gestion des métadonnées est simplifiée ici
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
    _controller?.dispose();
    _objectDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Détection d'Objets Scolaires")),
      body: Stack(
        children: [
          // 1. Le flux Caméra
          CameraPreview(_controller!),
          
          // 2. Les boîtes dessinées par-dessus
          if (_imageSize != null)
            CustomPaint(
              painter: ObjectPainter(_detectedObjects, _imageSize!, MediaQuery.of(context).size),
              child: Container(),
            ),
        ],
      ),
    );
  }
}

// Le peintre qui dessine les rectangles rouges
class ObjectPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Size imageSize;
  final Size widgetSize;

  ObjectPainter(this.objects, this.imageSize, this.widgetSize);

  @override
  // Dans lib/camera_screen.dart, trouvez et modifiez la méthode paint de ObjectPainter

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
      // Mise à l'échelle des coordonnées (inchangé)
      final double scaleX = widgetSize.width / imageSize.height; 
      final double scaleY = widgetSize.height / imageSize.width;

      final Rect scaledRect = Rect.fromLTRB(
        object.boundingBox.left * scaleX,
        object.boundingBox.top * scaleY,
        object.boundingBox.right * scaleX,
        object.boundingBox.bottom * scaleY,
      );

      canvas.drawRect(scaledRect, paint);

      // --- CORRECTION DU LABEL ---
      String labelText = "Objet Détecté"; 

      // Si le modèle temporaire renvoyait des labels, il les utiliserait ici.
      // Dans notre cas, il utilisera "Objet Détecté".
      if (object.labels.isNotEmpty) {
        final label = "${object.labels.first.text} ${(object.labels.first.confidence * 100).toStringAsFixed(0)}%";
        labelText = label;
      } 

      const textStyle = TextStyle(color: Colors.white, fontSize: 16);
      final textSpan = TextSpan(text: labelText, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();

      // Position Y du texte : on prend le haut du rectangle + 5px pour le forcer à l'intérieur
      // C'est plus sûr quand la boîte est au bord de l'écran.
      final double textY = scaledRect.top + 5; 
      
      // On dessine le fond noir du texte
      canvas.drawRect(
        Rect.fromLTWH(scaledRect.left, textY, textPainter.width + 10, textPainter.height + 5), 
        textBgPaint
      );
      // On dessine le texte par-dessus
      textPainter.paint(canvas, Offset(scaledRect.left + 5, textY + 2));
    }
}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

