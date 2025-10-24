import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

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

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
      _startImageStream();
    } catch (e) {
      debugPrint('Erreur initialisation : $e');
    }
  }

  void _startImageStream() {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isStreaming)
      return;

    _isStreaming = true;
    _controller!.startImageStream((CameraImage image) async {
      if (_isProcessing) return;
      _isProcessing = true;

      try {
        // Traitement IA plus tard
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<void> _stopImageStream() async {
    if (!_isStreaming || _controller == null) return;
    _isStreaming = false;
    await _controller!.stopImageStream();
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
    if (mounted) setState(() => _isInitialized = true);
    _startImageStream();
  }

  @override
  void dispose() {
    try {
      if (_isStreaming) _stopImageStream();
    } catch (_) {}
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

            //  Bouton retour
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
                  backgroundColor: const Color(
                    0xFF6A11CB,
                  ).withValues(alpha: 0.7),
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

            //  Bouton switch caméra
            Positioned(
              top: 40,
              right: 20,
              child: FloatingActionButton(
                heroTag: 'SwitchCamera',
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                onPressed: _switchCamera,
                child: const Icon(Icons.cameraswitch, color: Color(0xFF6A11CB)),
              ),
            ),

            // Bouton capture d'image avec effet flash
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton(
                  heroTag: 'CaptureButton',
                  backgroundColor: const Color(0xFF6A11CB),
                  onPressed: () async {
                    if (_controller != null && _controller!.value.isInitialized) {
                      final picture = await _controller!.takePicture();
                      OverlayEntry? flashOverlay;
                      flashOverlay = OverlayEntry(
                        builder: (context) => Container(
                          color: Colors.white.withValues(alpha: .6),
                        ),
                      );
                      Overlay.of(context).insert(flashOverlay);
                      await Future.delayed(const Duration(milliseconds: 150));
                      flashOverlay.remove();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Image capturée : ${picture.path}'),
                            backgroundColor: const Color(0xFF6A11CB),
                          ),
                        );
                      }
                    }
                  },
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
