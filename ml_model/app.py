from flask import Flask, request, jsonify
from ultralytics import YOLO
import cv2
import numpy as np
import base64
import io
from PIL import Image
from pathlib import Path
import os

app = Flask(__name__)

# Debug: log incoming requests to help diagnose 404s from the mobile app
@app.before_request
def log_request_info():
    try:
        print(f"[FLASK] Incoming request: {request.method} {request.path} from {request.remote_addr}")
        # print headers useful for debugging
        headers = {k: v for k, v in request.headers.items()}
        print(f"[FLASK] Headers: {headers}")
    except Exception as e:
        print(f"[FLASK] Failed to log request info: {e}")

# Cherche automatiquement le meilleur modèle dans un dossier `runs` (quel que soit son emplacement)
def find_best_model(start_path: Path = Path(__file__).parent) -> Path | None:
    # Cherche dans le dossier courant et jusqu'aux parents un répertoire "runs"
    cur = start_path.resolve()
    root = cur
    # remonte jusqu'à la racine du disque
    while True:
        runs_dir = root / "runs"
        if runs_dir.exists() and runs_dir.is_dir():
            # cherche un fichier best.pt sous runs/**/weights/best.pt ou runs/**/best.pt
            for candidate in runs_dir.rglob("**/weights/best.pt"):
                return candidate
            for candidate in runs_dir.rglob("**/best.pt"):
                return candidate
        if root.parent == root:
            break
        root = root.parent
    return None


best_path = find_best_model()
if best_path is None:
    raise RuntimeError("Impossible de trouver le fichier du modèle best.pt dans un dossier 'runs'.\n" \
                       "Place ton modèle dans 'ml_model/runs/...' ou à la racine 'runs/...', ou modifie le chemin dans app.py.")

print(f"[FLASK] Chargement du modèle depuis: {best_path}")
model = YOLO(str(best_path))

@app.route("/detect", methods=["POST"])
def detect():
    try:
        # Récupération de l'image encodée en base64 depuis Flutter
        # Supporte plusieurs clés possibles envoyées par le client
        data = request.get_json(silent=True) or {}
        image_b64 = None
        if isinstance(data, dict):
            image_b64 = data.get("image") or data.get("image_base64")
            image_bytes = None
            # cas 1: payload contient une string base64
            if image_b64:
                try:
                    image_bytes = base64.b64decode(image_b64)
                except Exception:
                    # si ce n'est pas du base64 valide, essayer d'utiliser l'encodage brut
                    image_bytes = image_b64.encode()

            # cas 2: multipart/form-data avec fichier uploadé
            if image_bytes is None and request.files:
                # prendre le premier fichier uploadé
                file_storage = next(iter(request.files.values()))
                # read() renvoie des bytes
                image_bytes = file_storage.read()

            if not image_bytes:
                return jsonify({"error": "no image found in request; expected JSON key 'image' or 'image_base64', form field, or multipart file."}), 400

            image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
            frame = np.array(image)

        # Exécution du modèle YOLO
        results = model.predict(source=frame, conf=0.5, verbose=False)

        # Extraction des prédictions
        # Permettre au client d'envoyer une liste de labels 'targets' dans le JSON pour marquer accepted
        targets = None
        if isinstance(data, dict):
            t = data.get("targets")
            if isinstance(t, list):
                targets = {str(x).lower() for x in t}
            elif isinstance(t, str):
                targets = {x.strip().lower() for x in t.split(',') if x.strip()}
        # valeur par défaut (inclut traductions courantes et noms anglais fréquents)
        if targets is None:
            targets = {"stylo", "gomme", "regle", "pen", "eraser", "ruler"}

        # image dimensions for normalization
        img_h, img_w = frame.shape[0], frame.shape[1]
        detections = []
        for box in results[0].boxes:
            cls_id = int(box.cls[0])
            label = model.names[cls_id]
            conf = float(box.conf[0])

            # obtenir bbox xyxy (x1,y1,x2,y2)
            xyxy = None
            try:
                # ultralytics Box may exposer .xyxy as tensor-like
                xyxy = box.xyxy[0].tolist()
            except Exception:
                try:
                    xyxy = box.xyxy.tolist()[0]
                except Exception:
                    # fallback: try to coerce to list of floats
                    try:
                        xyxy = [float(v) for v in box.xyxy]
                    except Exception:
                        xyxy = [0, 0, 0, 0]

            x1_px, y1_px, x2_px, y2_px = [int(round(float(v))) for v in xyxy]
            # normalized coordinates (0..1)
            try:
                x1 = float(x1_px) / img_w
                y1 = float(y1_px) / img_h
                x2 = float(x2_px) / img_w
                y2 = float(y2_px) / img_h
            except Exception:
                x1, y1, x2, y2 = 0.0, 0.0, 0.0, 0.0
            accepted = str(label).lower() in targets
            detections.append({
                "label": label,
                "confidence": round(conf, 2),
                # bbox = normalized coords (0..1) — plus adapté pour affichage UI mobile
                "bbox": {"x1": round(x1, 4), "y1": round(y1, 4), "x2": round(x2, 4), "y2": round(y2, 4)},
                # bbox_px conserves les coordonnées en pixels pour compatibilité
                "bbox_px": {"x1": x1_px, "y1": y1_px, "x2": x2_px, "y2": y2_px},
                "accepted": accepted
            })

        return jsonify({"detections": detections})

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# Provide a /predict alias for clients that use that path
@app.route("/predict", methods=["POST"])
def predict():
    # reuse the detect() handler
    return detect()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
