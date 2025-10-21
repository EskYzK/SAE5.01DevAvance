package com.example.school_object_detector

import android.content.Context
import android.hardware.camera2.CameraManager
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private lateinit var cameraManager: CameraManager
    private var cameraId: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cameraId = cameraManager.cameraIdList.firstOrNull()

        cameraId?.let {
            try {
                cameraManager.registerAvailabilityCallback(object: CameraManager.AvailabilityCallback() {
                    override fun onCameraAvailable(id: String) {
                        super.onCameraAvailable(id)
                        Log.d("Camera", "Camera disponible : $id")
                    }

                    override fun onCameraUnavailable(id: String) {
                        super.onCameraUnavailable(id)
                        Log.e("Camera", "Camera indisponible : $id")
                        // Ici tu peux envoyer un event à Flutter via MethodChannel
                    }
                }, null)
            } catch (e: Exception) {
                Log.e("Camera", "Erreur CameraManager: ${e.message}")
            }
        }
    }
}