package com.darubaaz.resq

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Owns one long-lived Flutter engine for the whole process.
 *
 * The mesh runs in Dart, so it must survive the Activity: swiping the app away
 * destroys the Activity but not this engine, and the foreground service keeps
 * the process alive. If Android restarts the process for the sticky service,
 * this runs again and Dart main() restores the mesh without any UI.
 */
class ResqApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        NativeChannels.register(this, engine)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "resq_engine"
    }
}
