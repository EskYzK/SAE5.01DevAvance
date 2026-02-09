import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // Ajout pour la cohérence
import '../service/sharing_service.dart';
import '../models/annotation.dart';
import '../widgets/annotation_editor.dart';

class DatasetCollectionScreen extends StatefulWidget {
  const DatasetCollectionScreen({super.key});

  @override
  State<DatasetCollectionScreen> createState() => _DatasetCollectionScreenState();
}

class _DatasetCollectionScreenState extends State<DatasetCollectionScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = []; // Stockage interne
  bool _isBusy = false;
  int _photoCount = 0;
  XFile? _tempImage;
  DateTime? _lastFrameTime;
  
  final SharingService _sharingService = SharingService();
  
  // Les classes pour l'annotation
  final List<String> _classes = [
    'eraser', 'glue_stick', 'highlighter', 'pen', 'pencil', 
    'ruler', 'scissors', 'sharpener', 'stapler'
  ];

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

      // --- LIMITEUR D'IPS ---
      await controller.startImageStream((image) {
        final now = DateTime.now();
        
        // On définit ici la limite : 200 millisecondes = 5 images par seconde (FPS)
        // Cela suffit largement pour garder le flux "actif" sans tuer l'émulateur.
        if (_lastFrameTime != null && 
            now.difference(_lastFrameTime!) < const Duration(milliseconds: 200)) {
          // On ignore cette image (on retourne immédiatement)
          return;
        }
        
        _lastFrameTime = now;
        
        // (Ici, l'image est "consommée" mais on n'en fait rien sur cette page, 
        // ce qui libère le buffer pour la suivante).
      });
      // -------------------------

      if (!mounted) return;

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      debugPrint("Erreur init caméra: $e");
    }
  }

  // Étape 1 : Juste prendre la photo (sans sauvegarder)
  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isBusy) return;
    
    try {
      final XFile photo = await _controller!.takePicture();
      setState(() {
        _tempImage = photo; // On passe en mode "Annotation"
      });
    } catch (e) {
      debugPrint("Erreur capture: $e");
    }
  }

  // Étape 2 : Sauvegarder après validation dans l'éditeur
  Future<void> _saveData(List<Annotation> annotations, Size displaySize) async {
    if (_tempImage == null) return;
    setState(() => _isBusy = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Nom du fichier basé sur la première annotation (ou 'empty' si rien)
      String primaryClass = annotations.isNotEmpty ? annotations.first.label : "empty";
      final String imgName = 'train_${timestamp}_$primaryClass.jpg';
      final String imgPath = '${directory.path}/$imgName';

      // 1. Sauvegarde de l'image
      await _tempImage!.saveTo(imgPath);

      // 2. Génération du contenu YOLO
      StringBuffer yoloContent = StringBuffer();
      
      for (var annotation in annotations) {
        // Normalisation (Conversion Pixels -> 0.0 à 1.0)
        // x_center, y_center, width, height
        double w = annotation.rect.width / displaySize.width;
        double h = annotation.rect.height / displaySize.height;
        double x = (annotation.rect.left + annotation.rect.width / 2) / displaySize.width;
        double y = (annotation.rect.top + annotation.rect.height / 2) / displaySize.height;

        // Clamp pour éviter les erreurs d'arrondi (ex: 1.000001)
        x = x.clamp(0.0, 1.0);
        y = y.clamp(0.0, 1.0);
        w = w.clamp(0.0, 1.0);
        h = h.clamp(0.0, 1.0);

        yoloContent.writeln("${annotation.classId} $x $y $w $h");
      }

      // 3. Sauvegarde du fichier texte
      final String txtName = 'train_${timestamp}_$primaryClass.txt';
      final File txtFile = File('${directory.path}/$txtName');
      await txtFile.writeAsString(yoloContent.toString());

      await _countExistingPhotos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Sauvegardé (${annotations.length} objets) !"),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur sauvegarde: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la sauvegarde")));
      }
    } finally {
      setState(() {
        _tempImage = null; // Retour à la caméra
        _isBusy = false;
      });
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
    // 1. Si on a une image en attente ⮕ Mode Annotation
    if (_tempImage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("Annoter l'image"),
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _tempImage = null), // Annuler et revenir caméra
          ),
        ),
        body: AnnotationEditor(
          imageFile: _tempImage!,
          classes: _classes,
          onValidated: _saveData, // C'est ici qu'on branche la sauvegarde
        ),
      );
    }

    // 2. Sinon ⮕ Mode Caméra (classique)
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Studio d'Entraînement 🧠"),
        backgroundColor: const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: "Gérer les photos",
            onPressed: _showGallery,
          ),
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
            child: CameraPreview(_controller!),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
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
                    onPressed: !_isBusy ? _takePhoto : null,
                    icon: _isBusy 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.camera_alt),
                    label: const Text("CAPTURER"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A11CB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}