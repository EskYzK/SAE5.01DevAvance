from flask import Flask, request, jsonify
from ultralytics import YOLO
import cv2
import numpy as np
import base64
import io
from PIL import Image

app = Flask(__name__)

# Chargement du modèle entraîné
model = YOLO("../runs/detect/school_objects_yolov8/weights/best.pt")  # ton modèle YOLO entraîné

@app.route("/detect", methods=["POST"])
def detect():
    try:
        # Récupération de l'image encodée en base64 depuis Flutter
        data = request.json
        image_b64 = data["image"]
        image_bytes = base64.b64decode(image_b64)
        image = Image.open(io.BytesIO(image_bytes))
        frame = np.array(image)

        # Exécution du modèle YOLO
        results = model.predict(source=frame, conf=0.5, verbose=False)

        # Extraction des prédictions
        detections = []
        for box in results[0].boxes:
            cls_id = int(box.cls[0])
            label = model.names[cls_id]
            conf = float(box.conf[0])
            detections.append({
                "label": label,
                "confidence": round(conf, 2)
            })

        return jsonify({"detections": detections})

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
