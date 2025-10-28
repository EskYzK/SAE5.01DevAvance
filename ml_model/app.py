from flask import Flask, jsonify
from ultralytics import YOLO
import cv2

app = Flask(__name__)

# Charger le modèle YOLOv8
model = YOLO("runs/detect/school_objects_yolov8/weights/best.pt")

@app.route("/detect", methods=["GET"])
def detect_objects():
    cap = cv2.VideoCapture(0)
    ret, frame = cap.read()
    cap.release()

    if not ret:
        return jsonify({"error": "Impossible de capturer une image."}), 500

    # Détection
    results = model(frame)

    detected_objects = []
    for box in results[0].boxes:
        cls = int(box.cls[0])
        label = model.names[cls]
        conf = float(box.conf[0])
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        detected_objects.append({
            "label": label,
            "confidence": round(conf, 2),
            "bbox": [x1, y1, x2, y2]
        })

    return jsonify({
        "nb_objets": len(detected_objects),
        "objets": detected_objects
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
