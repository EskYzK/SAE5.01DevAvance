import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras import layers, models

# Préparation du dataset
datagen = ImageDataGenerator(
    rescale=1./255,
    validation_split=0.2
)

train = datagen.flow_from_directory(
    'dataset',
    target_size=(224, 224),
    batch_size=32,
    subset='training'
)

val = datagen.flow_from_directory(
    'dataset',
    target_size=(224, 224),
    batch_size=32,
    subset='validation'
)

# Modèle basé sur MobileNetV2
base_model = MobileNetV2(weights='imagenet', include_top=False, input_shape=(224,224,3))
base_model.trainable = False  # on gèle les couches de base

model = models.Sequential([
    base_model,
    layers.GlobalAveragePooling2D(),
    layers.Dense(len(train.class_indices), activation='softmax')
])

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

# Entraînement
model.fit(train, validation_data=val, epochs=10)

# Sauvegarde
model.save("school_model.h5")
print("✅ Modèle 'school_model.h5' entraîné et sauvegardé avec succès !")
