import tensorflow as tf
import numpy as np
from tensorflow import keras

# Chargement du modèle TFLite
interpreter = tf.lite.Interpreter(model_path="digit_model.tflite")
interpreter.allocate_tensors()

# Infos sur les entrées/sorties
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("✅ Modèle chargé : digit_model.tflite")
print("Entrée :", input_details[0])
print("Sortie :", output_details[0])

# Chargement de quelques images du dataset MNIST
(_, _), (x_test, y_test) = keras.datasets.mnist.load_data()
x_test = x_test.astype(np.float32) / 255.0

# Prend 5 images pour le test
num_samples = 5
for i in range(num_samples):
    img = x_test[i]
    label = y_test[i]

    # Reshape pour correspondre à l'entrée du modèle
    input_data = np.expand_dims(img, axis=0)

    # Envoi de l'image dans le modèle
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()

    # Récupération du résultat
    output_data = interpreter.get_tensor(output_details[0]['index'])
    predicted_label = np.argmax(output_data)

    print(f"🖼️  Image {i+1} : vrai={label} | prédit={predicted_label}")
