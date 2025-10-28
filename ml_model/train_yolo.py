from ultralytics import YOLO

# Charger un modèle pré-entraîné (plus rapide à adapter)
model = YOLO("yolov8n.pt")  # n = nano, petit et rapide

# Entraîner le modèle sur ton dataset
model.train(
    data="dataset/data.yaml",  # chemin vers ton fichier yaml
    epochs=50,                 # nombre d'époques d'entraînement
    imgsz=640,                 # taille des images
    batch=8,                   # taille du batch (tu peux augmenter selon ta RAM)
    name="school_objects_yolov8"
)
