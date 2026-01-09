# 🎒 School Object Detector (SAE 5.01)

> Application mobile de reconnaissance et de classement de matériel scolaire en temps réel avec apprentissage actif.

## 📖 À propos du projet

Ce projet a été réalisé dans le cadre de la **SAE 5.01 - Développement Avancé**. L'objectif est de développer une application mobile capable de détecter, identifier et classer des objets du monde réel (ici, du matériel scolaire) en temps réel via la caméra du smartphone.

La particularité de cette application est son cycle d'**Apprentissage Actif (Active Learning)** : les utilisateurs peuvent capturer des images d'objets mal détectés pour ré-entraîner l'IA et améliorer ses performances au fil du temps.

### 👥 L'Équipe

| Membre | Rôle |
| --- | --- |
| **CHOLLET Thomas** | Développeur |
| **AIT BAHA Said** | Développeur |
| **MORINON Lilian** | Développeur |
| **KERBER Alexandre** | Développeur |


## ✨ Fonctionnalités Principales

* **🕵️ Détection en Temps Réel :** Identification instantanée des objets (stylos, règles, gommes, etc.) via le flux caméra grâce à un modèle YOLOv8 embarqué (TFLite).
* **📸 Collecte de Données :** Interface dédiée pour prendre des photos d'objets spécifiques, générer des datasets et les exporter (ZIP) pour l'amélioration du modèle.
* **🧠 Mise à jour du Modèle :** Possibilité d'importer un nouveau modèle `.tflite` mis à jour directement depuis l'application sans réinstallation.
* **☁️ Cloud & Historique :** Intégration avec Firebase pour le stockage et historique des détections.
* **📤 Partage :** Export facile des datasets vers Google Drive ou par email.


## 🛠️ Stack Technique

### Mobile (Flutter)

* **Framework :** Flutter (Dart)
* **Vision par ordinateur :** `flutter_vision` (YOLOv8), `camera`
* **Backend & Data :** Firebase (Core, Firestore, Storage)
* **Utilitaires :** `archive` (Zip), `share_plus`, `path_provider`

### Intelligence Artificielle (Kaggle / Python)

* **Modèle :** YOLOv8 (Ultralytics)
* **Format Mobile :** TensorFlow Lite (Float32)
* **Entraînement :** Scripts Python exécutés sur Kaggle (GPU T4 x2)


## 🚀 Installation et Démarrage

### Prérequis

* Flutter SDK (v3.9.2 ou supérieur)
* Un appareil Android (Les émulateurs ne supportent pas la détection par IA)

### Étapes

1. **Cloner le dépôt :**
```bash
git clone https://github.com/votre-repo/SAE5.01DevAvance.git
cd SAE5.01DevAvance/school_object_detector
```


2. **Installer les dépendances :**
```bash
flutter pub get
```


3. **Configuration Firebase :**
* Assurez-vous que le fichier `google-services.json` est bien présent dans `android/app/` (déjà inclus dans le dépôt, mais à vérifier si vous changez de projet Firebase).


4. **Lancer l'application :**
```bash
flutter run
```


## 🔄 Cycle de Ré-entraînement (Active Learning)

Ce projet inclut une procédure complète pour permettre à l'utilisateur d'améliorer l'IA. Voir le guide complet ici : [📄 Procédure de Ré-entraînement](R%C3%A9-entrainement/Proc%C3%A9dure.md).

**En résumé :**

1. **Collecte :** Dans l'app, menu "Collecte de données" > Prendre des photos > Exporter le ZIP.
2. **Entraînement :** Sur Kaggle, uploader le `base.zip` (historique) + `new_data.zip` (nouvelles photos) et lancer le script fourni.
3. **Déploiement :** Récupérer le `updated_model.tflite` généré et l'importer dans l'application via le menu "Importer modèle".


## 📂 Architecture du Projet

```
SAE5.01DevAvance/
├── Comptes-rendus/          # Suivi de projet (PDF)
├── Ré-entrainement/         # Scripts et documentation IA
│   └── Procédure.md         # Tutoriel de mise à jour du modèle
├── school_object_detector/  # Code source de l'application Flutter
│   ├── android/             # Configuration native Android
│   ├── assets/
│   │   └── ml/              # Modèles TFLite et labels
│   ├── lib/
│   │   ├── screens/         # Écrans (Camera, Home, Collection...)
│   │   ├── service/         # Services (Partage, Détection...)
│   │   └── main.dart        # Point d'entrée
│   └── pubspec.yaml         # Dépendances
└── README.md                # Ce fichier
```


## 🤝 Contribution & Workflow Git

Pour travailler sur le projet, merci de respecter le flux suivant :

1. Toujours partir de `main` : `git checkout main && git pull`
2. Créer sa branche : `git checkout -b feature/ma-fonctionnalite`
3. Commit avec des emojis explicites (ex: `:sparkles:`, `:bug:`)
4. Push et créer une **Pull Request** pour validation.