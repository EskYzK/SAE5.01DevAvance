import tensorflow as tf
from tensorflow import keras

# Chargement du dataset MNIST (chiffres manuscrits 0–9)
(x_train, y_train), (x_test, y_test) = keras.datasets.mnist.load_data()

# Normalisation
x_train = x_train / 255.0
x_test = x_test / 255.0

# Création du modèle
model = keras.Sequential([
    keras.layers.Flatten(input_shape=(28, 28)),
    keras.layers.Dense(128, activation='relu'),
    keras.layers.Dropout(0.2),
    keras.layers.Dense(10, activation='softmax')
])

# Compilation et entraînement
model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

model.fit(x_train, y_train, epochs=5)
model.evaluate(x_test, y_test)

# Sauvegarde du modèle
model.save("digit_model.h5")
print("✅ Modèle entraîné et sauvegardé avec succès !")
