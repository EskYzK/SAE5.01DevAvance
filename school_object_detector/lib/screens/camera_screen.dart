import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imgLib;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  bool _isRearCamera = true;
  bool _isInitialized = false;
  bool _isStreaming = false;
  bool _isProcessing = false;

  // Isolate pour convertir YUV -> JPEG (Android)
  Isolate? _workerIsolate;
  SendPort? _isolateSendPort;
  bool _isolateReady = false;

  List<Map<String, dynamic>> _detections = [];

  // Throttle des frames envoyées
  int _minFrameIntervalMs = 400;
  int _lastProcessedAt = 0;

  int _jpegQuality = 70;
  ResolutionPreset _resolution = ResolutionPreset.medium;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      final initialCamera = _cameras!.first;

      _controller = CameraController(
        initialCamera,
        _resolution,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _isInitialized = true);

      // Isolate utile surtout pour Android (YUV)
      await _startWorkerIsolate();
      _startImageStream();
    } catch (e) {
      debugPrint('Erreur initialisation : $e');
    }
  }

  Future<void> _startWorkerIsolate() async {
    if (_isolateReady) return;

    final rp = ReceivePort();
    _workerIsolate = await Isolate.spawn(
      _isolateMain,
      rp.sendPort,
      onError: rp.sendPort,
      onExit: rp.sendPort,
    );

    final completer = Completer<SendPort>();
    StreamSubscription? sub;

    sub = rp.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
        _isolateReady = true;
        completer.complete(message);
        sub?.cancel();
        rp.close();
      }
    });

    await completer.future;
  }

  void _stopWorkerIsolate() {
    if (_workerIsolate != null) {
      _workerIsolate!.kill(priority: Isolate.immediate);
      _workerIsolate = null;
      _isolateSendPort = null;
      _isolateReady = false;
    }
  }

  void _startImageStream() {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isStreaming) {
      return;
    }

    _isStreaming = true;

    _controller!.startImageStream((CameraImage image) async {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastProcessedAt < _minFrameIntervalMs) return;
        _lastProcessedAt = now;

        if (_isProcessing) return;
        _isProcessing = true;

        final Uint8List jpeg = await _convertCameraImageToJpeg(image);
        await _sendJpegBytes(jpeg);
      } catch (e) {
        debugPrint('Stream error: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<Uint8List> _convertCameraImageToJpeg(CameraImage image) async {
    final bool isYuv420 = image.format.group == ImageFormatGroup.yuv420;

    // 🔹 Isolate uniquement pour YUV420 (Android)
    if (isYuv420 &&
        _isolateReady &&
        _isolateSendPort != null &&
        image.planes.length == 3) {
      final rp = ReceivePort();

      final planesTtd = image.planes
          .map((p) => TransferableTypedData.fromList([p.bytes]))
          .toList();

      final payload = {
        'planes': planesTtd,
        'width': image.width,
        'height': image.height,
        'rowStrides': image.planes.map((p) => p.bytesPerRow).toList(),
        'pixelStrides': image.planes.map((p) => p.bytesPerPixel ?? 1).toList(),
        'quality': _jpegQuality,
      };

      _isolateSendPort!.send([rp.sendPort, payload]);

      final resp = await rp.first;
      rp.close();

      if (resp is TransferableTypedData) {
        return resp.materialize().asUint8List();
      }
      if (resp is Uint8List) {
        return resp;
      }

      // En cas d'erreur dans l'isolate, on retombe sur la version locale
      debugPrint('Isolate response invalide, fallback local: $resp');
    }

    // 🔹 Conversion locale (fallback) – gère YUV (Android) et BGRA (iOS)
    final int width = image.width;
    final int height = image.height;
    final imgLib.Image img =
        imgLib.Image(width: width, height: height, numChannels: 3);

    if (isYuv420 && image.planes.length == 3) {
      // --- YUV420 ---
      final planeY = image.planes[0];
      final planeU = image.planes[1];
      final planeV = image.planes[2];

      final Uint8List y = planeY.bytes;
      final Uint8List u = planeU.bytes;
      final Uint8List v = planeV.bytes;

      final int uvRowStride = planeU.bytesPerRow;
      final int uvPixelStride = planeU.bytesPerPixel ?? 1;

      for (int h = 0; h < height; h++) {
        final int yRow = planeY.bytesPerRow * h;
        for (int w = 0; w < width; w++) {
          final int yIndex = yRow + w;
          final int uvIndex =
              (w ~/ 2) * uvPixelStride + (h ~/ 2) * uvRowStride;

          final int Y = y[yIndex];
          final int U = u[uvIndex];
          final int V = v[uvIndex];

          int r = (Y + 1.370705 * (V - 128)).round();
          int g =
              (Y - 0.337633 * (U - 128) - 0.698001 * (V - 128)).round();
          int b = (Y + 1.732446 * (U - 128)).round();

          img.setPixelRgba(
            w,
            h,
            r.clamp(0, 255),
            g.clamp(0, 255),
            b.clamp(0, 255),
            255,
          );
        }
      }
    } else if (image.format.group == ImageFormatGroup.bgra8888 &&
        image.planes.length == 1) {
      // --- BGRA8888 (iOS) ---
      final plane = image.planes[0];
      final Uint8List bytes = plane.bytes;
      final int bytesPerRow = plane.bytesPerRow;

      for (int y = 0; y < height; y++) {
        final int rowStart = y * bytesPerRow;
        for (int x = 0; x < width; x++) {
          final int pixelIndex = rowStart + x * 4;
          if (pixelIndex + 3 >= bytes.length) continue;

          final int b = bytes[pixelIndex];
          final int g = bytes[pixelIndex + 1];
          final int r = bytes[pixelIndex + 2];
          final int a = bytes[pixelIndex + 3];

          img.setPixelRgba(x, y, r, g, b, a);
        }
      }
    } else {
      throw UnsupportedError(
        'Format caméra non supporté: ${image.format.group}, planes: ${image.planes.length}',
      );
    }

    final jpg = imgLib.encodeJpg(img, quality: _jpegQuality);
    return Uint8List.fromList(jpg);
  }

  Future<void> _sendJpegBytes(Uint8List bytes) async {
    try {
      final uri = Uri.parse('http://172.20.10.9:5001/predict');

      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: 'frame.jpg',
          ),
        );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List ds = data['detections'] ?? [];

        if (mounted) {
          setState(() {
            _detections =
                ds.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      } else {
        debugPrint('Serveur erreur: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur envoi frame: $e');
    }
  }

  Future<void> _stopImageStream() async {
    if (!_isStreaming || _controller == null) return;

    _isStreaming = false;
    try {
      await _controller!.stopImageStream();
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() => _isInitialized = false);
    _isRearCamera = !_isRearCamera;

    await _stopImageStream();
    await _controller?.dispose();

    final newCamera = _isRearCamera ? _cameras!.first : _cameras!.last;

    _controller = CameraController(
      newCamera,
      _resolution,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() => _isInitialized = true);
    _startImageStream();
  }

  @override
  void dispose() {
    try {
      if (_isStreaming) _stopImageStream();
      _stopWorkerIsolate();
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
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.previewSize?.height ?? 0,
              height: _controller!.value.previewSize?.width ?? 0,
              child: CameraPreview(_controller!),
            ),
          ),

          // Bouton retour
          Positioned(
            top: 40,
            left: 20,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text(
                "Retour",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A11CB).withOpacity(0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),

          // Switch caméra
          Positioned(
            top: 40,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'SwitchCamera',
              backgroundColor: Colors.white.withOpacity(0.9),
              onPressed: _switchCamera,
              child: const Icon(
                Icons.cameraswitch,
                color: Color(0xFF6A11CB),
              ),
            ),
          ),

          // Overlay des détections
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DetectionsPainter(_detections, _controller),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Isolate pour la conversion YUV420 -> JPEG (Android uniquement)
void _isolateMain(SendPort initialReply) {
  final port = ReceivePort();
  initialReply.send(port.sendPort);

  port.listen((msg) {
    try {
      if (msg is List && msg.length == 2) {
        final SendPort replyTo = msg[0] as SendPort;
        final Map payload = msg[1] as Map;

        final planes = (payload['planes'] as List)
            .map((p) => (p as TransferableTypedData).materialize().asUint8List())
            .toList();

        final int width = payload['width'] as int;
        final int height = payload['height'] as int;

        final List<int> rowStrides =
            (payload['rowStrides'] as List).cast<int>();
        final List<int> pixelStrides =
            (payload['pixelStrides'] as List).cast<int>();

        final int quality = payload['quality'] ?? 70;

        final imgLib.Image img =
            imgLib.Image(width: width, height: height, numChannels: 3);

        final Uint8List y = planes[0];
        final Uint8List u = planes[1];
        final Uint8List v = planes[2];

        final int uvRowStride = rowStrides[1];
        final int uvPixelStride = pixelStrides[1];

        for (int h = 0; h < height; h++) {
          final int yRow = rowStrides[0] * h;
          for (int w = 0; w < width; w++) {
            final int yIndex = yRow + w;
            final int uvIndex =
                (w ~/ 2) * uvPixelStride + (h ~/ 2) * uvRowStride;

            final int Y = y[yIndex];
            final int U = u[uvIndex];
            final int V = v[uvIndex];

            final int r =
                (Y + 1.370705 * (V - 128)).clamp(0, 255).toInt();
            final int g =
                (Y - 0.337633 * (U - 128) - 0.698001 * (V - 128))
                    .clamp(0, 255)
                    .toInt();
            final int b =
                (Y + 1.732446 * (U - 128)).clamp(0, 255).toInt();

            img.setPixelRgba(w, h, r, g, b, 255);
          }
        }

        final jpg = imgLib.encodeJpg(img, quality: quality);
        replyTo.send(
          TransferableTypedData.fromList([Uint8List.fromList(jpg)]),
        );
      }
    } catch (e) {
      try {
        final SendPort replyTo = (msg as List)[0] as SendPort;
        replyTo.send({'error': e.toString()});
      } catch (_) {}
    }
  });
}

class _DetectionsPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final CameraController? controller;

  _DetectionsPainter(this.detections, this.controller);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textStyle = const TextStyle(color: Colors.white, fontSize: 12);

    final double pw = size.width; // Largeur du Canvas (écran)
    final double ph = size.height; // Hauteur du Canvas (écran)

    // Dimensions de l'image brute (souvent inversées si le téléphone est en mode portrait)
    final double? imageWidth = controller?.value.previewSize?.height;
    final double? imageHeight = controller?.value.previewSize?.width;

    if (imageWidth == null || imageHeight == null || imageWidth == 0 || imageHeight == 0) {
      return;
    }

    // Le facteur d'échelle est inversé car la CameraPreview inverse width et height.
    // final double scaleX = pw / imageWidth; // Largeur du Canvas / Hauteur de la Preview
    // final double scaleY = ph / imageHeight; // Hauteur du Canvas / Largeur de la Preview
    
    // Le ratio d'aspect est conservé grâce au FittedBox(fit: BoxFit.cover). 
    // Nous prenons le facteur d'échelle le plus petit pour ne pas déborder (bien que BoxFit.cover s'en charge).
    // final double scale = scaleX < scaleY ? scaleX : scaleY; 

    // Ajustement de la translation si le mode est BoxFit.cover et l'image ne couvre pas parfaitement
    // Puisque vous utilisez FittedBox(fit: BoxFit.cover), cela n'est pas nécessaire ici.
    
    final bool isFront =
        controller?.description.lensDirection == CameraLensDirection.front;

    for (final d in detections) {
      try {
        final bbox = Map<String, dynamic>.from(d['bbox'] ?? {});
        final bool accepted = d['accepted'] == true;

        paint.color = accepted ? Colors.green : Colors.red;

        double x1 = (bbox['x1'] ?? 0).toDouble();
        double y1 = (bbox['y1'] ?? 0).toDouble();
        double x2 = (bbox['x2'] ?? 0).toDouble();
        double y2 = (bbox['y2'] ?? 0).toDouble();

        // 🔹 Réduire légèrement les boîtes pour mieux ajuster les objets (votre logique conservée)
        final double boxWidth = x2 - x1;
        final double boxHeight = y2 - y1;
        final double shrinkFactor = 0.15;
        x1 += boxWidth * shrinkFactor / 2;
        y1 += boxHeight * shrinkFactor / 2;
        x2 -= boxWidth * shrinkFactor / 2;
        y2 -= boxHeight * shrinkFactor / 2;

        // 1. Inversion sur l'axe X pour la caméra frontale (Mirroring)
        if (isFront) {
          final double nx1 = 1.0 - x2;
          final double nx2 = 1.0 - x1;
          x1 = nx1;
          x2 = nx2;
        }

        // 2. Application de la mise à l'échelle et de la rotation :
        // Les coordonnées normalisées (0-1) sont multipliées par la dimension opposée de l'écran.
        // C'est la clé de la correction.
        final double left = y1 * pw; // y1 de l'image * Largeur de l'écran
        final double top = x1 * ph; // x1 de l'image * Hauteur de l'écran
        final double width = (y2 - y1) * pw;
        final double height = (x2 - x1) * ph;
        
        // 3. Dessin de la boîte
        canvas.drawRect(Rect.fromLTWH(left, top, width, height), paint);

        final String label = d['label']?.toString() ?? '';
        final String conf = d['confidence']?.toString() ?? '';

        final tp = TextPainter(
          text: TextSpan(
            text: '$label $conf',
            style: textStyle.copyWith(color: paint.color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(canvas, Offset(left, (top - 16).clamp(0, ph - 10)));
      } catch (_) {}
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}