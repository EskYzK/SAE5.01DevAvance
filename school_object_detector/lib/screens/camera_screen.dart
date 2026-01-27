import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../service/object_detection_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import '../service/sharing_service.dart';
import '../service/history_service.dart';
import './history_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  late ObjectDetectionService _objectDetectionService;
  
  bool _isBusy = false;
  bool _isCapturing = false;
  List<Map<String, dynamic>> _detectedObjects = []; 
  Size? _imageSize;
  
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  DateTime? _lastDetectionTime;

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
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      
      controller.startImageStream((image) {
        final now = DateTime.now();
        if (!_isBusy) {
          if (_lastDetectionTime == null || 
              now.difference(_lastDetectionTime!) > const Duration(milliseconds: 300)) {
            
            _lastDetectionTime = now;
            _isBusy = true;
            _processFrame(image);
          }
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

    final objects = await _objectDetectionService.processFrame(image);

    if (mounted) {
      setState(() {
        _detectedObjects = objects;
        _imageSize = Size(image.height.toDouble(), image.width.toDouble());
        _isBusy = false;
      });
    }
  }

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
    await Future.delayed(const Duration(milliseconds: 300));
    await _initCamera();
    
    if (mounted) setState(() => _isBusy = false);
  }

  Future<void> _takePictureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      await _controller!.stopImageStream();
      
      final XFile photo = await _controller!.takePicture();
      final File photoFile = File(photo.path);
      final rawBytes = await photoFile.readAsBytes();

      img.Image? originalImage = img.decodeImage(rawBytes);
      if (originalImage != null) {
        img.Image fixedImage = img.bakeOrientation(originalImage);
        final fixedBytes = img.encodeJpg(fixedImage);

        final detections = await _objectDetectionService.processImage(
          fixedBytes, 
          fixedImage.width, 
          fixedImage.height
        );

        if (detections.isNotEmpty) {
          // Dessin des boîtes sur l'image
          for (var detection in detections) {
            final box = detection["box"];
            final x1 = (box[0] as double).toInt();
            final y1 = (box[1] as double).toInt();
            final x2 = (box[2] as double).toInt();
            final y2 = (box[3] as double).toInt();

            img.drawRect(
              fixedImage, 
              x1: x1, y1: y1, x2: x2, y2: y2, 
              color: img.ColorRgb8(255, 0, 0), 
              thickness: 4
            );

            final label = "${detection['tag']} ${(box[4] * 100).toStringAsFixed(0)}%";
            img.drawString(
              fixedImage, 
              label, 
              font: img.arial24, 
              x: x1 + 5, y: y1 + 5, 
              color: img.ColorRgb8(255, 0, 0)
            );
          }

          final directory = await getApplicationDocumentsDirectory();
          final fileName = 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final savedPath = p.join(directory.path, fileName);
          
          await File(savedPath).writeAsBytes(img.encodeJpg(fixedImage, quality: 80));
          
          final prefs = await SharedPreferences.getInstance();
          List<String> history = prefs.getStringList('history_images') ?? [];
          history.add(savedPath);
          await prefs.setStringList('history_images', history);

          if (mounted) {
            _askToShare(File(savedPath), detections);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Aucun objet détecté, photo non sauvegardée.")),
            );
          }
        }
      }

    } catch (e) {
      debugPrint("Erreur photo: $e");
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
        await _controller!.startImageStream((image) {
          if (!_isBusy) {
            _isBusy = true;
            _processFrame(image);
          }
        });
      }
    }
  }

  Future<void> _askToShare(File imageFile, List<Map<String, dynamic>> detections) async {
    if (!mounted) return;

    String label = "Objet inconnu";
    double confidence = 0.0;
    
    if (detections.isNotEmpty) {
      label = detections[0]['tag'];
      confidence = detections[0]['box'][4];
    }

    showDialog(
      context: context,
      barrierDismissible: false, // On force le choix
      builder: (ctx) => AlertDialog(
        title: const Text("Sauvegarder ?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(imageFile, height: 150),
            const SizedBox(height: 10),
            Text("Objet détecté : $label"),
            const SizedBox(height: 5),
            const Text("Où voulez-vous envoyer cette image ?", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveToHistory(imageFile, label, confidence);
            },
            child: const Text("Privé (Cloud)", style: TextStyle(color: Colors.grey)),
          ),
          
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _shareToCommunity(imageFile, label, confidence);
            },
            
            child: const Text("Public (Communauté)"),
          ),

          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Envoi partout...")));
              await _saveToHistory(imageFile, label, confidence);
              await _shareToCommunity(imageFile, label, confidence);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB), foregroundColor: Colors.white),
            child: const Text("Les deux"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToHistory(File imageFile, String label, double confidence) async {
    try {
      await HistoryService().saveDetection(
        imageFile: imageFile,
        label: label,
        confidence: confidence,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Sauvegardé dans votre historique !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Erreur history: $e");
    }
  }

  Future<void> _shareToCommunity(File imageFile, String label, double confidence) async {
    try {
      await SharingService().shareDetection(
        imageFile: imageFile,
        label: label,
        confidence: confidence,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Partagé avec la communauté !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Erreur share: $e");
    }
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
            
          Positioned(
            top: 50, left: 20,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text("Retour", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A11CB).withOpacity(0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),

          Positioned(
            top: 50, right: 20,
            child: FloatingActionButton(
              heroTag: 'SwitchCam',
              backgroundColor: Colors.white,
              onPressed: _switchCamera,
              child: const Icon(Icons.cameraswitch, color: Color(0xFF6A11CB)),
            ),
          ),
          
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 80,
                height: 80,
                child: FloatingActionButton(
                  heroTag: 'TakePhoto',
                  backgroundColor: const Color(0xFF6A11CB),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  onPressed: _takePictureAndAnalyze,
                  shape: const CircleBorder(),
                  child: _isCapturing 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.camera_alt, size: 36),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 112,
            right: 40, 
            child: FloatingActionButton(
              heroTag: 'GoToHistory',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6A11CB),
              onPressed: () {
                _isBusy = true; 
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                ).then((_) {
                  if (mounted) {
                    setState(() => _isBusy = false);
                  }
                });
              },
              child: const Icon(Icons.history, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

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
      final box = object["box"]; 
      
      final double x1 = box[0];
      final double y1 = box[1];
      final double x2 = box[2];
      final double y2 = box[3];
      
      final double scaleX = size.width / imageSize.width;
      final double scaleY = size.height / imageSize.height;

      double left = x1 * scaleX;
      double top = y1 * scaleY;
      double right = x2 * scaleX;
      double bottom = y2 * scaleY;

      if (lensDirection == CameraLensDirection.front) {
        double temp = left;
        left = size.width - right;
        right = size.width - temp;
      }

      final Rect rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, paint);

      final String label = "${object['tag']} ${(box[4] * 100).toStringAsFixed(0)}%";
      
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();

      double textY = top - 24;
      if (textY < 0) textY = top + 4;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, textY, textPainter.width + 12, 24),
          const Radius.circular(4),
        ),
        textBgPaint,
      );

      textPainter.paint(canvas, Offset(left + 6, textY + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}