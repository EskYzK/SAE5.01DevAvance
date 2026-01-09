# 🔄 Procédure de Ré-entraînement et Mise à Jour de l'IA

Ce document décrit le protocole complet pour améliorer les performances du modèle de détection d'objets (YOLOv8) via l'application mobile et un serveur de calcul (Kaggle).


## 📋 Prérequis

1. **Mobile :** Application installée.
2. **PC :**
* Une archive nommée **`base.zip`** contenant l'historique (Modèle `.pt` + Dossiers `train`/`valid`). Elle se trouve dans les Releases du Git.
* Accès à **Kaggle** avec GPU activé (T4 x2 recommandé).
3. **Connexion :** Google Drive pour le transfert de fichiers.


## 1️⃣ Phase de Collecte (Sur le Téléphone) 📸

L'objectif est de capturer des images d'un objet mal détecté pour enrichir le dataset.

1. Ouvrir l'application **School Object Detector**.
2. Aller dans **Plus d'options** > **Collecte de données**.
3. **Sélectionner la classe** de l'objet à améliorer (ex: `ruler`, `pen`).
4. **Placer l'objet** dans le viseur vert (Overlay).
5. Prendre **10 à 15 photos** environ en variant légèrement :
* L'angle de vue.
* La rotation de l'objet.
6. Cliquer sur le bouton **📦 ZIP**.
7. Enregistrer le fichier **`new_data.zip`** sur votre **Google Drive (Mon Drive)**.


## 2️⃣ Phase de Transfert (Mobile vers PC) 📲

1. Récupérer le fichier `new_data.zip` avec votre ordinateur depuis votre Google Drive.
2. Le placer sur le Bureau du PC à côté de l'archive `base.zip`.


## 3️⃣ Phase d'Entraînement (Sur Kaggle) 🧠

1. Ouvrir un nouveau Notebook Kaggle.
2. Dans la section **Input** (colonne de droite), cliquer sur **Upload** > **New Dataset**, et uploader les deux fichiers :
* `base.zip` (La mémoire à long terme).
* `new_data.zip` (Les nouvelles données fraîches).
3. Nommer ce dataset : `dataset-X`, où X est le numéro que vous souhaitez donner à votre dataset. Si c'est le premier ré-entrainement que vous faites, vous pouvez le nommer `dataset-1`.
4. Créer ce dataset.
5. En haut à gauche, aller dans **Settings** > **Accelerator** > **GPU T4 x2** ⚠️.
6. Lancer le **Script d'Entraînement Automatique**.
* *Le script va fusionner les datasets, configurer YOLO, et lancer le ré-entrainement sur 30 epochs.*
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
    'epochs': 30,
    'imgsz': 960,
    'batch': 16,
    'mosaic': 1.0,
    'lr0': 0.0001,
    'lrf': 0.01,
    'verbose': True
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

    print(f"🧠 Entraînement sur {HYPER_PARAMS['epochs']} epochs...")
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


7. Attendre la fin de l'exécution (~135 minutes).
8. Dans la section **Output**, recharger le dossier `/kaggle/working`, et télécharger les deux fichiers générés :
* 📄 **`updated_model.tflite`** : Le modèle optimisé pour Android.
* 📄 **`new_base.zip`** : Le nouveau fichier de base (pour la prochaine fois).


## 4️⃣ Phase de Déploiement (PC vers Mobile) 🚀

1. Transférer le fichier **`updated_model.tflite`** vers votre **Google Drive (Mon Drive)**.
2. Ouvrir l'application mobile.
3. Aller dans le **Plus d'options** > **Importer modèle**.
4. Sélectionner le fichier `updated_model.tflite` depuis votre Google Drive.
5. Attendre la confirmation : *"✅ Cerveau mis à jour !"*.
6. Redémarrer l'application.


## 5️⃣ Prochaine fois ⌚

*Cette étape est cruciale pour ne pas perdre l'apprentissage lors de la prochaine session.*

1. Au lieu d'utiliser `base.zip` pour le ré-entrainement, il faudra utiliser `new_base.zip`.
2. Le système est prêt pour le prochain cycle.