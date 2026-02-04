import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // Ajout pour la cohérence
import '../service/sharing_service.dart';

class DatasetCollectionScreen extends StatefulWidget {
  // Plus besoin de passer les caméras en paramètre !
  const DatasetCollectionScreen({super.key});

  @override
  State<DatasetCollectionScreen> createState() => _DatasetCollectionScreenState();
}

class _DatasetCollectionScreenState extends State<DatasetCollectionScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = []; // Stockage interne
  bool _isBusy = false;
  int _photoCount = 0;
  
  final SharingService _sharingService = SharingService();
  
  // Tes classes exactes (labels.txt)
  final List<String> _classes = [
    'eraser', 'glue_stick', 'highlighter', 'pen', 'pencil', 
    'ruler', 'scissors', 'sharpener', 'stapler'
  ];
  String _selectedClass = 'eraser';

  @override
  void initState() {
    super.initState();
    _initCamera(); 
    _countExistingPhotos();
  }

  // Supprime une image et son fichier texte associé
  Future<void> _deletePhoto(String imagePath) async {
    try {
      final imgFile = File(imagePath);
      final txtFile = File(imagePath.replaceAll('.jpg', '.txt'));

      if (await imgFile.exists()) await imgFile.delete();
      if (await txtFile.exists()) await txtFile.delete();

      // On rafraîchit le compteur
      await _countExistingPhotos();
      
      if (mounted) {
        Navigator.pop(context); // Ferme la liste pour rafraîchir (ou setState dans le modal)
        _showGallery(); // Rouvre la liste mise à jour
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Image supprimée"), duration: Duration(milliseconds: 500)),
        );
      }
    } catch (e) {
      debugPrint("Erreur suppression: $e");
    }
  }

  // Affiche la liste des photos prises dans un volet en bas
  Future<void> _showGallery() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync()
        .where((e) => e.path.contains('train_') && e.path.endsWith('.jpg'))
        .toList();
    
    // On trie pour avoir les plus récentes en haut
    files.sort((a, b) => b.path.compareTo(a.path));

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Photos de la session (${files.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: files.isEmpty 
              ? const Center(child: Text("Aucune photo prise."))
              : ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (ctx, i) {
                    final file = files[i];
                    final name = file.path.split('/').last;
                    // On extrait la classe du nom de fichier pour l'affichage
                    // Format : train_timestamp_classe.jpg
                    final parts = name.split('_');
                    String className = "Inconnu";
                    if (parts.length >= 3) {
                      className = parts.sublist(2).join('_').replaceAll('.jpg', '');
                    }

                    return ListTile(
                      leading: Image.file(File(file.path), width: 50, height: 50, fit: BoxFit.cover),
                      title: Text(className, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(name, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePhoto(file.path),
                      ),
                    );
                  },
                ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _countExistingPhotos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // On liste tous les fichiers du dossier
      final List<FileSystemEntity> files = directory.listSync();
      
      int count = 0;
      for (var file in files) {
        final filename = file.path.split(Platform.pathSeparator).last;
        // On compte ceux qui ressemblent à nos photos d'entraînement
        if (filename.startsWith('train_') && filename.endsWith('.jpg')) {
          count++;
        }
      }

      if (mounted) {
        setState(() {
          _photoCount = count;
        });
      }
    } catch (e) {
      debugPrint("Erreur comptage fichiers: $e");
    }
  }

  Future<void> _initCamera() async {
    // 1. Demande de permission (Comme dans ton CameraScreen)
    final status = await Permission.camera.request();
    if (status.isDenied) return;

    // 2. Récupération des caméras disponibles
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // 3. Init du contrôleur sur la première caméra
      final controller = CameraController(
        _cameras[0], 
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      debugPrint("Erreur init caméra: $e");
    }
  }

  Future<void> _captureAndAnnotate() async {
    if (_controller == null || !_controller!.value.isInitialized || _isBusy) return;
    setState(() => _isBusy = true);

    try {
      final XFile photo = await _controller!.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final String imgName = 'train_${timestamp}_$_selectedClass.jpg';
      final String imgPath = '${directory.path}/$imgName';
      await photo.saveTo(imgPath);

      int classId = _classes.indexOf(_selectedClass);
      if (classId == -1) classId = 0;

      String yoloContent = "$classId 0.5 0.5 0.5 0.5";
      final String txtName = 'train_${timestamp}_$_selectedClass.txt';
      final File txtFile = File('${directory.path}/$txtName');
      await txtFile.writeAsString(yoloContent);

      setState(() {
        _photoCount++;
        _isBusy = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                "📸 Photo enregistrée pour '$_selectedClass' !",
                textAlign: TextAlign.center, // Pour centrer si ça prend 2 lignes
                style: const TextStyle(fontWeight: FontWeight.bold), // Petit bonus style
              ),
            ),
            backgroundColor: Colors.green, // <--- On remet la couleur ici
            duration: const Duration(milliseconds: 800), // Et la durée courte
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur capture: $e");
      setState(() => _isBusy = false);
    }
  }

  Future<void> _syncDatasetToFirebase() async {
    setState(() => _isBusy = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> files = directory.listSync();
      
      // On filtre les images qui n'ont pas encore été envoyées
      final imageFiles = files.where((f) => f.path.contains('train_') && f.path.endsWith('.jpg')).toList();

      if (imageFiles.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rien à synchroniser !")));
        return;
      }

      int successCount = 0;
      for (var entity in imageFiles) {
        File imgFile = File(entity.path);
        File txtFile = File(entity.path.replaceAll('.jpg', '.txt'));

        if (await txtFile.exists()) {
          // Extraction du label depuis le nom du fichier
          final name = entity.path.split('/').last;
          final parts = name.split('_');
          String label = parts.length >= 3 ? parts.sublist(2).join('_').replaceAll('.jpg', '') : "unknown";

          await _sharingService.uploadToDataset(
            imageFile: imgFile,
            annotationFile: txtFile,
            label: label,
          );
          
          // Suppression locale après upload pour nettoyer
          await imgFile.delete();
          await txtFile.delete();
          successCount++;
        }
      }

      await _countExistingPhotos(); // Rafraîchir le compteur à 0
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🚀 $successCount photos envoyées à la communauté !"), backgroundColor: Colors.blue)
        );
      }
    } catch (e) {
      debugPrint("Erreur sync: $e");
    } finally {
      setState(() => _isBusy = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black, // Fond noir comme ton CameraScreen
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // Cohérence visuelle
      appBar: AppBar(
        title: const Text("Studio d'Entraînement 🧠"),
        backgroundColor: const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
        actions: [
          // NOUVEAU BOUTON : Galerie / Suppression
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: "Gérer les photos",
            onPressed: _showGallery,
          ),
          
          // Ton compteur existant
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                "$_photoCount", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
              )
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(_controller!),
                ColorFiltered(
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut),
                  child: Stack(
                    children: [
                      Container(decoration: const BoxDecoration(color: Colors.transparent, backgroundBlendMode: BlendMode.dstOut)),
                      Center(child: Container(width: 280, height: 280, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)))),
                    ],
                  ),
                ),
                Center(
                  child: Container(
                    width: 280, height: 280,
                    decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent, width: 3), borderRadius: BorderRadius.circular(20)),
                    child: const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text("Placez l'objet ICI", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, backgroundColor: Colors.black45)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Quel objet scannez-vous ?",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag, color: Color(0xFF6A11CB)),
                  ),
                  value: _selectedClass,
                  items: _classes.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (newValue) => setState(() => _selectedClass = newValue!),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: (_photoCount > 0 && !_isBusy) ? _syncDatasetToFirebase : null,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text("Exporter"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: !_isBusy ? _captureAndAnnotate : null,
                        icon: _isBusy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.camera_alt),
                        label: Text(_isBusy ? "..." : "CAPTURER"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A11CB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}