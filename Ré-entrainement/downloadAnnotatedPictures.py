import firebase_admin
from firebase_admin import credentials, storage
import os
import zipfile

# Initialisation (Remplacer "schoolobjectdetector" par le nom de votre projet Firebase)
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred, {
    'storageBucket': 'schoolobjectdetector.firebasestorage.app'
})

bucket = storage.bucket()

def downloadAnnotatedPictures():
    local_dir = "temp_dataset"
    zip_name = "new_data.zip"
    
    if not os.path.exists(local_dir):
        os.makedirs(local_dir)

    print("🚀 Récupération de la liste des fichiers...")
    # On récupère tous les fichiers dans le dossier 'annotated_pictures'
    blobs_iterator = bucket.list_blobs(prefix="annotated_pictures/")
    blobs = list(blobs_iterator)

    # Vérification si le dossier est vide (en ignorant le préfixe lui-même)
    actual_files = [b for b in blobs if b.name != "annotated_pictures/"]

    if not actual_files:
        print("📭 Aucun fichier à télécharger dans 'annotated_pictures/'.")
        if os.path.exists(local_dir):
            os.rmdir(local_dir)
        return

    print(f"📦 {len(actual_files)} fichiers trouvés. Début du transfert...")

    with zipfile.ZipFile(zip_name, 'w') as zipf:
        for blob in actual_files:
            if blob.name == "annotated_pictures/": continue # Skip le dossier lui-même
            
            filename = os.path.basename(blob.name)
            local_path = os.path.join(local_dir, filename)
            
            print(f"📥 Téléchargement de {filename}...")
            blob.download_to_filename(local_path)
            
            # Ajout au ZIP et suppression du fichier local pour rester propre
            zipf.write(local_path, filename)
            os.remove(local_path)

            print(f"🗑️  Suppression de {filename} sur Firebase...")
            blob.delete()

    print(f"\n✅ Terminé !")
    print(f"📦 Archive créée : {zip_name}")
    print(f"🧹 Dossier 'annotated_pictures' vidé sur Firebase.")
    if os.path.exists(local_dir):
        os.rmdir(local_dir)

if __name__ == "__main__":
    downloadAnnotatedPictures()