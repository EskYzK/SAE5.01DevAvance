import tensorflow as tf
import numpy as np
import cv2
import os

# Liste des classes (doit correspondre aux sous-dossiers du dataset)
CLASSES = ["stylo", "crayon", "gomme", "ciseaux", "regle", "colle", "trousse", "livre", "cahier"]

# Chargement du modèle TFLite
interpreter = tf.lite.Interpreter(model_path="school_model.tflite")
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Test sur une image (à adapter selon ton dataset)
img_path = "dataset/stylo/example.jpg"  # mets ici une vraie image
img = cv2.imread(img_path)
img = cv2.resize(img, (224,224))
img = np.expand_dims(img / 255.0, axis=0).astype(np.float32)

# Inférence
interpreter.set_tensor(input_details[0]['index'], img)
interpreter.invoke()

output_data = interpreter.get_tensor(output_details[0]['index'])
pred_index = np.argmax(output_data)
pred_class = CLASSES[pred_index]

print(f"✅ Objet détecté : {pred_class} ({output_data[0][pred_index]:.2f} de confiance)")
