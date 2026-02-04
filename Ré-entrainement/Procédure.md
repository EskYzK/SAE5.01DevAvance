# 🔄 Procédure de Ré-entraînement et Mise à Jour de l'IA

Ce document décrit le protocole complet pour améliorer les performances du modèle de détection d'objets (YOLOv8) via la collecte communautaire Firebase et un serveur de calcul (Kaggle).


## 📋 Prérequis

1. **Mobile :** Application installée.
2. **PC :**
    * Le script Python **`downloadAnnotatedPictures.py`** configuré avec sa clé **`serviceAccountKey.json`** dans le même dossier.
        - La clé `serviceAccountKey.json` peut être obtenue dans les **paramètres de votre projet Firebase** > **Comptes de service** > **SDK Admin Firebase** > **Générer une nouvelle clé privée**.
    * Une archive nommée **`base.zip`** contenant l'historique (Modèle `.pt` + Dossiers `train`/`valid`). Elle se trouve dans les Releases du Git.
    * Accès à **Kaggle** avec GPU activé (T4 x2 recommandé).
3. **Connexion :** Accès à la **console Firebase** du projet pour la gestion du Storage (dossiers `annotated_pictures` et `models`, accès aux paramètres du projet afin de pouvoir récupérer la clé `serviceAccountKey.json`).


## 1️⃣ Phase de Collecte (Sur le Téléphone) 📸

L'objectif est de capturer des images d'objets scolaires mal détectés pour enrichir le dataset communautaire.

1. Ouvrir l'application **Scolarize**.
2. Aller dans **Plus d'options** > **Collecte de données**.
3. **Sélectionner la classe** de l'objet à améliorer (ex: `ruler`, `pen`).
4. **Placer l'objet** dans le viseur vert (Overlay).
5. Prendre **10 à 20 photos** environ en variant légèrement :
    * L'angle de vue.
    * La rotation de l'objet.
6. Cliquer sur le bouton **Exporter** :
    * L'application envoie les images et leur annotation YOLO vers le dossier `annotated_pictures` de Firebase Storage.
    * *Note : Les fichiers locaux sont automatiquement supprimés après l'envoi pour libérer de l'espace sur le téléphone.*


## 2️⃣ Phase de Centralisation (Sur PC) 📲

1. Sur votre ordinateur, ouvrir un terminal dans le dossier `Ré-entrainement`, contenant le script `downloadAnnotatedPictures.py` et votre clé `serviceAccountKey.json`.
2. Lancer le script de téléchargement avec la commande :
```
python downloadAnnotatedPictures.py
```
3. Actions du script :
    - Il télécharge toutes les nouvelles photos et annotations depuis Firebase.
    - Il crée une archive nommée `new_data.zip` sur votre PC, dans le dossier `Ré-entrainement`.
    - Il vide automatiquement le dossier `annotated_pictures` sur Firebase pour éviter les doublons lors du prochain ré-entraînement.
4. Vérifier que `new_data.zip` soit bien sur votre PC, dans le même dossier que l'archive `base.zip`.


## 3️⃣ Phase d'Entraînement (Sur Kaggle) 🧠

1. Aller sur Kaggle, ajouter un numéro de téléphone et le vérifier (nécessaire pour accéder aux GPU T4).
2. Ouvrir un nouveau Notebook Kaggle.
3. Dans la section **Input** (colonne de droite), cliquer sur **Upload** > **New Dataset**, et uploader les deux fichiers :
    * `base.zip` (L'historique de toutes les sessions précédentes).
    * `new_data.zip` (Les nouvelles données issues de la collecte communautaire, et récupérées par votre script Python).
4. Nommer ce dataset : `dataset-X`, où X est le numéro que vous souhaitez donner à votre dataset. Si c'est le premier ré-entrainement que vous faites, vous pouvez le nommer `dataset-1`.
5. Créer ce dataset.
6. En haut à gauche, aller dans **Settings** > **Accelerator** > **GPU T4 x2** ⚠️.
7. Dans le script ci-dessous, ajuster les constantes `PATH_DIR_BASE` et `PATH_DIR_MOBILE` (si c'est votre second ré-entrainement, il faut alors que les variables valent respectivement `'/kaggle/input/dataset-2/new_base'`, et `'/kaggle/input/dataset-2/new_data'`).  
8. Copier et coller le **Script d'Entraînement Automatique** ci-dessous dans une cellule, et le lancer.
    * *Le script va fusionner les datasets, configurer YOLO, et lancer le ré-entrainement sur 150 epochs, avec une patience de 50 epochs.*
    * *Vous pourrez ensuite récupérer le nouveau modèle ainsi que la nouvelle base de ré-entrainement.*
```
# ==============================================================================
# 🛠️ INSTALLATION DES DÉPENDANCES
# ==============================================================================
!pip install ultralytics

# ==============================================================================
# 📦 IMPORTS
# ==============================================================================
import os   
import shutil
import yaml
from ultralytics import YOLO

# ==============================================================================
# 🎛️ CONFIGURATION
# ==============================================================================
# Chemins (Vérifie bien ces chemins dans ta colonne de droite sur Kaggle)
PATH_DIR_BASE   = '/kaggle/input/dataset-1/base'
PATH_DIR_MOBILE = '/kaggle/input/dataset-1/new_data'

CLASSES = [
    'eraser', 'glue_stick', 'highlighter', 'pen', 'pencil', 'ruler', 'scissors', 'sharpener', 'stapler'
]

HYPER_PARAMS = {
    'epochs': 150,
    'imgsz': 960,
    'batch': 16,
    'mosaic': 1.0,
    'lr0': 0.0001,
    'lrf': 0.01,
    'verbose': True,
    'patience': 50
}
# ==============================================================================

def run_training_cycle():
    print("🚀 DÉMARRAGE DU CYCLE D'AUTO-AMÉLIORATION...")
    
    work_dir = '/kaggle/working'
    dataset_dir = f'{work_dir}/dataset_complet'
    
    # Nettoyage
    if os.path.exists(dataset_dir): shutil.rmtree(dataset_dir)
    
    # Création structure YOLO
    for split in ['train', 'valid']:
        os.makedirs(f'{dataset_dir}/{split}/images', exist_ok=True)
        os.makedirs(f'{dataset_dir}/{split}/labels', exist_ok=True)
        
    # --- 1. FUSION (BASE + MOBILE) ---
    print("📦 Reconstruction du Dataset...")
    
    # Récupération intelligente des fichiers
    model_path = 'yolov8s.pt' # Fallback par défaut
    
    # Fonction locale pour déplacer les fichiers
    def collect_files(source_folder, source_type='base'):
        count = 0
        if not os.path.exists(source_folder):
            print(f"⚠️ Dossier introuvable : {source_folder}")
            return 0
        
        for root, dirs, files in os.walk(source_folder):
            for file in files:
                src = os.path.join(root, file)
                
                # Le modèle .pt (seulement s'il vient de la base)
                if file.endswith('.pt') and source_type == 'base':
                    shutil.copy(src, f'{work_dir}/start_model.pt')
                    nonlocal model_path
                    model_path = f'{work_dir}/start_model.pt'
                    print(f"   -> Reprise de l'entraînement depuis : {file}")
                
                # Les images (jpg, png...)
                elif file.lower().endswith(('.jpg', '.jpeg', '.png')):
                    # Si c'est du mobile -> Toujours train
                    # Si c'est de la base -> On respecte valid si présent
                    target_split = 'train'
                    if source_type == 'base' and 'valid' in root: target_split = 'valid'
                    
                    shutil.copy(src, f'{dataset_dir}/{target_split}/images/{file}')
                    count += 1
                
                # Les labels txt
                elif file.endswith('.txt') and 'classes' not in file:
                    target_split = 'train'
                    if source_type == 'base' and 'valid' in root: target_split = 'valid'
                    shutil.copy(src, f'{dataset_dir}/{target_split}/labels/{file}')
        return count

    print("   -> Traitement de l'historique...")
    # On appelle direct sur le dossier Kaggle Input
    c_base = collect_files(PATH_DIR_BASE, 'base')
    
    print("   -> Traitement des nouveautés...")
    c_mob = collect_files(PATH_DIR_MOBILE, 'mobile')
    
    print(f"✅ Dataset prêt : {c_base + c_mob} images ({c_base} anciennes + {c_mob} nouvelles).")

    # --- 2. CONFIG & TRAIN ---
    yaml_content = {
        'path': dataset_dir,
        'train': 'train/images',
        'val': 'valid/images', 
        'nc': len(CLASSES),
        'names': CLASSES
    }
    # Sécurité dossier valid vide
    if len(os.listdir(f'{dataset_dir}/valid/images')) == 0:
        print("ℹ️ Validation vide : bascule sur train pour la validation.")
        yaml_content['val'] = 'train/images'

    with open(f'{work_dir}/data.yaml', 'w') as f:
        yaml.dump(yaml_content, f)

    print(f"🧠 Entraînement sur {HYPER_PARAMS['epochs']} epochs, avec une patience de {HYPER_PARAMS['patience']}...")
    model = YOLO(model_path)
    model.train(data=f'{work_dir}/data.yaml', project=work_dir, name='run_cycle', **HYPER_PARAMS)
    
    # --- 3. EXPORTATION FINALE ---
    print("💾 Génération des fichiers de sortie...")
    
    # A. TFLite pour le téléphone
    try:
        model.export(format='tflite', imgsz=HYPER_PARAMS['imgsz'])
        
        # Recherche CIBLÉE du float32
        tflite_found = False
        for root, dirs, files in os.walk(f'{work_dir}/run_cycle'):
            for f in files:
                # On ajoute la condition 'float32' pour être sûr à 100%
                if f.endswith('.tflite') and 'float32' in f:
                    shutil.copy(os.path.join(root, f), f'{work_dir}/updated_model.tflite')
                    print(f"📱 CORRECT : {f} -> updated_model.tflite")
                    tflite_found = True
                    break # On arrête de chercher dès qu'on a le bon !
            if tflite_found: break
        
        if not tflite_found:
            print("⚠️ AVERTISSEMENT : Aucun fichier 'float32.tflite' trouvé. Vérifiez les logs d'export.")
            
    except Exception as e:
        print(f"❌ Erreur export TFLite: {e}")

    # B. Création du new_base.zip (Le futur base.zip)
    print("📦 Création du pack pour le prochain cycle...")
    
    # 1. On met le nouveau cerveau dans le dossier dataset
    shutil.copy(f'{work_dir}/run_cycle/weights/best.pt', f'{dataset_dir}/last_best.pt')
    
    # 2. On zippe tout le dossier dataset_complet
    output_zip = f'{work_dir}/new_base' # shutil rajoute .zip tout seul
    shutil.make_archive(output_zip, 'zip', dataset_dir)
    print("💻 new_base.zip -> PRÊT")

if __name__ == '__main__':
    run_training_cycle()
```


9. Attendre la fin de l'exécution (~675 minutes, ne pas fermer la page Kaggle, vérifier que l'ordinateur est bien branché sur secteur, possède une connexion internet fiable, et dans les options de "délai d'expiration de l'écran, de la veille, et de la mise en veille prolongée", que les paramètres "Désactiver l'écran" et "Mettre mon appareil en veille après" soient définis sur "Jamais").
10. Dans la section **Output**, recharger le dossier `/kaggle/working`, et télécharger les deux fichiers générés :
* 📄 **`updated_model.tflite`** : Le modèle optimisé pour Android.
* 📄 **`new_base.zip`** : Le nouveau fichier de base (pour la prochaine fois).


## 4️⃣ Phase de Déploiement (Admin vers Firebase) 🚀
L'objectif est de mettre à disposition le nouveau modèle pour tous les utilisateurs de l'application.

1. Sur la Console Firebase :
    * Accéder à la section **Storage** > **dossier `models`**.
    * *Conseil : Renommer le fichier de manière explicite (ex: model_2026_02_20.tflite) pour que les utilisateurs puissent l'identifier facilement.*
    * Importer le fichier `updated_model.tflite` généré par Kaggle.
2. Sur l'Application Mobile :
    * Ouvrir l'application Scolarize.
    * Aller dans **Plus d'options** > **Importer un modèle**.
    * Sélectionner le nouveau modèle dans la liste récupérée depuis Firebase.
    * Attendre le message de confirmation.
3. Redémarrer l'application pour activer la nouvelle version de l'IA.


## 5️⃣ Prochaine fois ⌚

*Cette étape est cruciale pour ne pas perdre l'apprentissage lors de la prochaine session de ré-entrainement.*

1. Sauvegarde de la base : Le fichier `new_base.zip` téléchargé depuis Kaggle contient désormais l'intégralité du dataset (Ancien + Nouveau) ainsi que le dernier modèle `.pt`.
2. Cycle suivant : 
    * Utiliser `new_base.zip` à la place de l'ancien `base.zip` pour le ré-entrainement.
    * Récupérer les nouvelles photos avec le script `downloadAnnotatedPictures.py` pour créer un nouveau `new_data.zip`.
3. Le système est prêt pour une amélioration continue et collaborative !