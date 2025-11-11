import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  // Isolate for conversion (persistent)
  Isolate? _workerIsolate;
  SendPort? _isolateSendPort;
  bool _isolateReady = false;

  List<Map<String, dynamic>> _detections = [];

  // Throttle: minimum milliseconds between processed frames
  int _minFrameIntervalMs = 400;
  int _lastProcessedAt = 0;

  // JPEG quality for encoding (0..100)
  int _jpegQuality = 70;
  // current resolution preset
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

      await _startWorkerIsolate();
      _startImageStream();
    } catch (e) {
      debugPrint('Erreur initialisation : $e');
    }
  }

  Future<void> _startWorkerIsolate() async {
    if (_isolateReady) return;
    final rp = ReceivePort();
    _workerIsolate = await Isolate.spawn(_isolateMain, rp.sendPort,
        onError: rp.sendPort, onExit: rp.sendPort);

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
    if (_controller == null || !_controller!.value.isInitialized || _isStreaming) {
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
        debugPrint('Stream process erreur: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<Uint8List> _convertCameraImageToJpeg(CameraImage image) async {
    // If isolate ready, send TransferableTypedData to worker and await JPEG
    if (_isolateReady && _isolateSendPort != null) {
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

      if (resp is TransferableTypedData) return resp.materialize().asUint8List();
      if (resp is Uint8List) return resp;
      if (resp is Map && resp['error'] != null) throw Exception('Isolate error: ${resp['error']}');
      throw Exception('Unexpected isolate response: $resp');
    }

    // Fallback inline conversion
    final int width = image.width;
    final int height = image.height;
    final imgLib.Image img = imgLib.Image(width, height);

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
        final int uvIndex = (w ~/ 2) * uvPixelStride + (h ~/ 2) * uvRowStride;

        final int Y = y[yIndex];
        final int U = u[uvIndex];
        final int V = v[uvIndex];

        int r = (Y + 1.370705 * (V - 128)).round();
        int g = (Y - 0.337633 * (U - 128) - 0.698001 * (V - 128)).round();
        int b = (Y + 1.732446 * (U - 128)).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        imgLib.setPixel(img, w, h, imgLib.getColor(r, g, b));
      }
    }

    final jpg = imgLib.encodeJpg(img, quality: _jpegQuality);
    return Uint8List.fromList(jpg);
  }

  Future<void> _sendJpegBytes(Uint8List bytes) async {
    try {
      final uri = Uri.parse('http://192.168.1.186:5001/predict');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes('image', bytes, filename: 'frame.jpg'));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List ds = data['detections'] ?? [];
        if (mounted) {
          setState(() {
            _detections = ds.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      } else {
        debugPrint('Serveur erreur (stream): ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur send frame: $e');
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

  Future<void> _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      await _stopImageStream();

      final XFile picture = await _controller!.takePicture();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image capturée : ${picture.path}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      final uri = Uri.parse('http://192.168.1.186:5001/predict');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', picture.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List ds = data['detections'] ?? [];
        if (mounted) {
          setState(() {
            _detections = ds.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      } else {
        debugPrint('Serveur erreur: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur analyse: $e');
    } finally {
      _isProcessing = false;
      _startImageStream();
    }
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

  // UI helpers to change settings
  Future<void> _setResolution(ResolutionPreset r) async {
    if (_resolution == r) return;
    _resolution = r;
    await _stopImageStream();
    await _controller?.dispose();
    await _initCameras();
  }

  void _changeThrottle(int deltaMs) {
    setState(() {
      _minFrameIntervalMs = (_minFrameIntervalMs + deltaMs).clamp(100, 5000);
    });
  }

  void _changeQuality(int delta) {
    setState(() {
      _jpegQuality = (_jpegQuality + delta).clamp(10, 95);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
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

            // Retour
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  elevation: 3,
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
                child: const Icon(Icons.cameraswitch, color: Color(0xFF6A11CB)),
              ),
            ),

            // Settings buttons (throttle / quality / resolution)
            Positioned(
              right: 20,
              top: 110,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: 'ThrottleMinus',
                    mini: true,
                    onPressed: () => _changeThrottle(100),
                    child: const Icon(Icons.exposure_minus_1),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'ThrottlePlus',
                    mini: true,
                    onPressed: () => _changeThrottle(-100),
                    child: const Icon(Icons.exposure_plus_1),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'QualityMinus',
                    mini: true,
                    onPressed: () => _changeQuality(-5),
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'QualityPlus',
                    mini: true,
                    onPressed: () => _changeQuality(5),
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'ResolutionToggle',
                    mini: true,
                    onPressed: () async {
                      final next = _resolution == ResolutionPreset.low
                          ? ResolutionPreset.medium
                          : _resolution == ResolutionPreset.medium
                              ? ResolutionPreset.high
                              : ResolutionPreset.low;
                      await _setResolution(next);
                    },
                    child: const Icon(Icons.high_quality),
                  ),
                ],
              ),
            ),

            // Overlay for detections
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DetectionsPainter(_detections, _controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Top-level isolate entry point. Receives the main isolate's SendPort, then
// listens for messages [SendPort replyTo, Map payload] where payload contains
// planes (List<TransferableTypedData>), width, height, rowStrides, pixelStrides, quality.
void _isolateMain(SendPort initialReply) {
  final port = ReceivePort();
  initialReply.send(port.sendPort);

  port.listen((dynamic message) {
    try {
      if (message is List && message.length == 2) {
        final SendPort replyTo = message[0] as SendPort;
        final Map payload = message[1] as Map;

        final List<dynamic> planesDyn = payload['planes'] as List<dynamic>;
        final List<Uint8List> planes = planesDyn
            .map((p) => (p as TransferableTypedData).materialize().asUint8List())
            .toList();

        final int width = payload['width'] as int;
        final int height = payload['height'] as int;
        final List<dynamic> rowStridesDyn = payload['rowStrides'] as List<dynamic>;
        final List<int> rowStrides = rowStridesDyn.cast<int>();
        final List<dynamic> pixelStridesDyn = payload['pixelStrides'] as List<dynamic>;
        final List<int> pixelStrides = pixelStridesDyn.cast<int>();
        final int quality = payload['quality'] as int? ?? 70;

        final imgLib.Image img = imgLib.Image(width, height);

        final Uint8List y = planes[0];
        final Uint8List u = planes[1];
        final Uint8List v = planes[2];

        final int uvRowStride = rowStrides[1];
        final int uvPixelStride = pixelStrides[1];

        for (int h = 0; h < height; h++) {
          final int yRow = rowStrides[0] * h;
          for (int w = 0; w < width; w++) {
            final int yIndex = yRow + w;
            final int uvIndex = (w ~/ 2) * uvPixelStride + (h ~/ 2) * uvRowStride;

            final int Y = y[yIndex];
            final int U = u[uvIndex];
            final int V = v[uvIndex];

            int r = (Y + 1.370705 * (V - 128)).round();
            int g = (Y - 0.337633 * (U - 128) - 0.698001 * (V - 128)).round();
            int b = (Y + 1.732446 * (U - 128)).round();

            r = r.clamp(0, 255);
            g = g.clamp(0, 255);
            b = b.clamp(0, 255);

            imgLib.setPixel(img, w, h, imgLib.getColor(r, g, b));
          }
        }

        final jpg = imgLib.encodeJpg(img, quality: quality);
        replyTo.send(TransferableTypedData.fromList([Uint8List.fromList(jpg)]));
      }
    } catch (e) {
      try {
        if (message is List && message.length == 2) {
          final SendPort replyTo = message[0] as SendPort;
          replyTo.send({'error': e.toString()});
        }
      } catch (_) {}
    }
  });
}

// Painter to draw detection boxes returned by the server.
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

    final pw = size.width;
    final ph = size.height;

    final isFront = controller?.description.lensDirection == CameraLensDirection.front;

    for (final d in detections) {
      try {
        final bbox = Map<String, dynamic>.from(d['bbox'] ?? {});
        final accepted = d['accepted'] == true;
        paint.color = accepted ? Colors.green : Colors.red;

        double x1 = (bbox['x1'] as num).toDouble();
        double y1 = (bbox['y1'] as num).toDouble();
        double x2 = (bbox['x2'] as num).toDouble();
        double y2 = (bbox['y2'] as num).toDouble();

        // Mirror horizontally for front camera preview
        if (isFront) {
          final nx1 = 1.0 - x2;
          final nx2 = 1.0 - x1;
          x1 = nx1;
          x2 = nx2;
        }

        final x = x1 * pw;
        final y = y1 * ph;
        final w = (x2 - x1) * pw;
        final h = (y2 - y1) * ph;

        canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);

        final label = d['label'] ?? '';
        final conf = d['confidence'] ?? '';
        final textPainter = TextPainter(
          text: TextSpan(text: '$label ${conf}', style: textStyle.copyWith(color: paint.color)),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(x, (y - 16).clamp(0.0, ph - 10)));
      } catch (_) {}
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imgLib;

class CameraScreen extends StatefulWidget {
    _isStreaming = true;
    _controller!.startImageStream((CameraImage image) async {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastProcessedAt < _minFrameIntervalMs) return;
        _lastProcessedAt = now;

        if (_isProcessing) return;
        _isProcessing = true;

        // Convert frame to JPEG bytes (uses isolate if ready)
        final Uint8List jpeg = await _convertCameraImageToJpeg(image);

        // Send to server and update detections
        await _sendJpegBytes(jpeg);
      } catch (e) {
        debugPrint('Stream process erreur: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<void> _startWorkerIsolate() async {
    if (_isolateReady) return;
    final rp = ReceivePort();
    _workerIsolate = await Isolate.spawn(_isolateMain, rp.sendPort,
        onError: rp.sendPort, onExit: rp.sendPort);

    // wait for the worker sendPort
    final completer = Completer<SendPort>();
    StreamSubscription? sub;
    sub = rp.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
        _isolateReady = true;
        completer.complete(message);
        sub?.cancel();
        rp.close();
      } else {
        // ignore other messages
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

  Future<Uint8List> _convertCameraImageToJpeg(CameraImage image) async {
    // If isolate ready, send TransferableTypedData to worker and await JPEG
    if (_isolateReady && _isolateSendPort != null) {
      final rp = ReceivePort();

      // create TransferableTypedData for each plane
      final planesTtd = image.planes
          .map((p) => TransferableTypedData.fromList([p.bytes]))
          .toList();

      final payload = {
        'planes': planesTtd,
        'width': image.width,
        'height': image.height,
        'rowStrides': image.planes.map((p) => p.bytesPerRow).toList(),
        'pixelStrides': image.planes.map((p) => p.bytesPerPixel ?? 1).toList(),
        'quality': 70,
      };

      _isolateSendPort!.send([rp.sendPort, payload]);
      final resp = await rp.first;
      rp.close();

      if (resp is TransferableTypedData) {
        return resp.materialize().asUint8List();
      } else if (resp is Uint8List) {
        return resp;
      } else if (resp is Map && resp['error'] != null) {
        throw Exception('Isolate error: ${resp['error']}');
      } else {
        throw Exception('Unexpected isolate response: $resp');
      }
    }

    // Fallback: inline conversion (slower)
    final int width = image.width;
    final int height = image.height;
    final imgLib.Image img = imgLib.Image(width, height);

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
        final int uvIndex = (w ~/ 2) * uvPixelStride + (h ~/ 2) * uvRowStride;

        final int Y = y[yIndex];
        final int U = u[uvIndex];
        final int V = v[uvIndex];

        int r = (Y + 1.370705 * (V - 128)).round();
        int g = (Y - 0.337633 * (U - 128) - 0.698001 * (V - 128)).round();
        int b = (Y + 1.732446 * (U - 128)).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        imgLib.setPixel(img, w, h, imgLib.getColor(r, g, b));
      }
    }

    final jpg = imgLib.encodeJpg(img, quality: 70);
    return Uint8List.fromList(jpg);
  }

  // Top-level isolate entry for conversion used by compute().
  Uint8List _yuv420ToJpegIsolate(Map<String, dynamic> params) {
    final int width = params['width'] as int;
    final int height = params['height'] as int;
    final List<dynamic> planesDyn = params['planes'] as List<dynamic>;
    final List<Uint8List> planes = planesDyn.cast<Uint8List>();
    final List<dynamic> rowStridesDyn = params['rowStrides'] as List<dynamic>;
    final List<int> rowStrides = rowStridesDyn.cast<int>();
    final List<dynamic> pixelStridesDyn = params['pixelStrides'] as List<dynamic>;
    final List<int> pixelStrides = pixelStridesDyn.cast<int>();
    final int quality = params['quality'] as int? ?? 70;

    final imgLib.Image img = imgLib.Image(width, height);

    final Uint8List y = planes[0];
    final Uint8List u = planes[1];
    final Uint8List v = planes[2];

    final int uvRowStride = rowStrides[1];
    final int uvPixelStride = pixelStrides[1];

    for (int h = 0; h < height; h++) {
      final int yRow = rowStrides[0] * h;
      for (int w = 0; w < width; w++) {
        final int yIndex = yRow + w;
        final int uvIndex = (w ~/ 2) * uvPixelStride + (h ~/ 2) * uvRowStride;

        final int Y = y[yIndex];
        final int U = u[uvIndex];
        final int V = v[uvIndex];

        int r = (Y + 1.370705 * (V - 128)).round();
        int g = (Y - 0.337633 * (U - 128) - 0.698001 * (V - 128)).round();
        int b = (Y + 1.732446 * (U - 128)).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        imgLib.setPixel(img, w, h, imgLib.getColor(r, g, b));
      }
    }

    final jpg = imgLib.encodeJpg(img, quality: quality);
    return Uint8List.fromList(jpg);
  }

        imgLib.setPixel(img, w, h, imgLib.getColor(r, g, b));
      }
    }

    final jpg = imgLib.encodeJpg(img, quality: 70);
    return Uint8List.fromList(jpg);
  }

  Future<void> _sendJpegBytes(Uint8List bytes) async {
    try {
      final uri = Uri.parse('http://192.168.1.186:5001/predict');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes('image', bytes,
            filename: 'frame.jpg'));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List ds = data['detections'] ?? [];
        if (mounted) {
          setState(() {
            _detections = ds.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      } else {
        debugPrint('Serveur erreur (stream): ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur send frame: $e');
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
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() => _isInitialized = true);
    _startImageStream();
  }

  Future<void> _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isProcessing) return;

    _isProcessing = true;
    // optional: brief indicator suppressed to avoid UI spam

    try {
      // On stoppe le flux pour éviter les conflits avec takePicture
      await _stopImageStream();

      final XFile picture = await _controller!.takePicture();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image capturée : ${picture.path}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // ---- Requête HTTP Multipart vers le backend Flask ----
      final uri = Uri.parse('http://192.168.1.186:5001/predict'); // ton Flask
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath('image', picture.path),
        );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List ds = data['detections'] ?? [];
        if (mounted) {
          setState(() {
            _detections = ds.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      } else {
        debugPrint('Serveur erreur: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erreur analyse: $e');
      debugPrint('Erreur analyse (caught): $e');
    } finally {
      _isProcessing = false;
      // On relance le flux après la capture
      _startImageStream();
    }
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
      body: SizedBox.expand(
        child: Stack(
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
                  backgroundColor:
                      const Color(0xFF6A11CB).withValues(alpha: 0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  elevation: 3,
                ),
              ),
            ),

            // Switch caméra
            Positioned(
              top: 40,
              right: 20,
              child: FloatingActionButton(
                heroTag: 'SwitchCamera',
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                onPressed: _switchCamera,
                child:
                    const Icon(Icons.cameraswitch, color: Color(0xFF6A11CB)),
              ),
            ),

            // Overlay for detections
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DetectionsPainter(_detections, _controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 
// Top-level isolate entry point. Receives the main isolate's SendPort, then
// listens for messages [SendPort replyTo, Map payload] where payload contains
// planes (List<TransferableTypedData>), width, height, rowStrides, pixelStrides, quality.
void _isolateMain(SendPort initialReply) {
  final port = ReceivePort();
  // send the worker SendPort back to the main isolate
  initialReply.send(port.sendPort);

  port.listen((dynamic message) {
    try {
      if (message is List && message.length == 2) {
        final SendPort replyTo = message[0] as SendPort;
        final Map payload = message[1] as Map;

        final List<dynamic> planesDyn = payload['planes'] as List<dynamic>;
        final List<Uint8List> planes = planesDyn
            .map((p) => (p as TransferableTypedData).materialize().asUint8List())
            .toList();

        final int width = payload['width'] as int;
        final int height = payload['height'] as int;
        final List<dynamic> rowStridesDyn = payload['rowStrides'] as List<dynamic>;
        final List<int> rowStrides = rowStridesDyn.cast<int>();
        final List<dynamic> pixelStridesDyn = payload['pixelStrides'] as List<dynamic>;
        final List<int> pixelStrides = pixelStridesDyn.cast<int>();
        final int quality = payload['quality'] as int? ?? 70;

        // convert YUV420 -> RGB -> JPEG using package:image
        final imgLib.Image img = imgLib.Image(width, height);

        final Uint8List y = planes[0];
        final Uint8List u = planes[1];
        final Uint8List v = planes[2];

        final int uvRowStride = rowStrides[1];
        final int uvPixelStride = pixelStrides[1];

        for (int h = 0; h < height; h++) {
          final int yRow = rowStrides[0] * h;
          for (int w = 0; w < width; w++) {
            final int yIndex = yRow + w;
            final int uvIndex = (w ~/ 2) * uvPixelStride + (h ~/ 2) * uvRowStride;

            final int Y = y[yIndex];
            final int U = u[uvIndex];
            final int V = v[uvIndex];

            int r = (Y + 1.370705 * (V - 128)).round();
            int g = (Y - 0.337633 * (U - 128) - 0.698001 * (V - 128)).round();
            int b = (Y + 1.732446 * (U - 128)).round();

            r = r.clamp(0, 255);
            g = g.clamp(0, 255);
            b = b.clamp(0, 255);

            imgLib.setPixel(img, w, h, imgLib.getColor(r, g, b));
          }
        }

        final jpg = imgLib.encodeJpg(img, quality: quality);
        // send back as TransferableTypedData for zero-copy transfer
        replyTo.send(TransferableTypedData.fromList([Uint8List.fromList(jpg)]));
      }
    } catch (e) {
      try {
        if (message is List && message.length == 2) {
          final SendPort replyTo = message[0] as SendPort;
          replyTo.send({'error': e.toString()});
        }
      } catch (_) {}
    }
  });
}

// Painter to draw detection boxes returned by the server.
class _DetectionsPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final CameraController? controller;

  _DetectionsPainter(this.detections, this.controller);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textStyle = TextStyle(color: Colors.white, fontSize: 12);

    // Preview size may be rotated; we assume normalized bbox already corresponds to preview
    final pw = size.width;
    final ph = size.height;

    for (final d in detections) {
      try {
        final bbox = Map<String, dynamic>.from(d['bbox'] ?? {});
        final accepted = d['accepted'] == true;
        paint.color = accepted ? Colors.green : Colors.red;

        final x = (bbox['x1'] as num).toDouble() * pw;
        final y = (bbox['y1'] as num).toDouble() * ph;
        final w = ((bbox['x2'] as num).toDouble() - (bbox['x1'] as num).toDouble()) * pw;
        final h = ((bbox['y2'] as num).toDouble() - (bbox['y1'] as num).toDouble()) * ph;

        canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);

        final label = d['label'] ?? '';
        final conf = d['confidence'] ?? '';
        final textPainter = TextPainter(
          text: TextSpan(text: '$label ${conf}', style: textStyle.copyWith(color: paint.color)),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(x, (y - 16).clamp(0.0, ph - 10)));
      } catch (_) {}
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
