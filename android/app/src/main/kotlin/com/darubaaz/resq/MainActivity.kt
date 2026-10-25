package com.darubaaz.resq

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * Attaches to the process-wide engine created in ResqApplication, so closing
 * the screen never destroys the engine that runs the mesh.
 */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(ResqApplication.ENGINE_ID)

    override fun shouldDestroyEngineWithHost(): Boolean = false
}
