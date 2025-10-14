import tensorflow as tf

# Chargement du modèle entraîné
model = tf.keras.models.load_model("digit_model.h5")

# Conversion en TensorFlow Lite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

# Sauvegarde du modèle converti
with open("digit_model.tflite", "wb") as f:
    f.write(tflite_model)

print("✅ Conversion en .tflite terminée avec succès !")
