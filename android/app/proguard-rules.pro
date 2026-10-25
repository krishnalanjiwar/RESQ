# RESQ release shrinking rules.
# Plugins ship their own consumer rules; these keep the pieces reached only
# via reflection / method channels so R8 can't strip them.

# Google Nearby Connections (play-services-nearby) used by nearby_connections.
-keep class com.google.android.gms.nearby.** { *; }
-dontwarn com.google.android.gms.**

# nearby_connections plugin (method/event channel handlers).
-keep class com.pkmnapps.nearby_connections.** { *; }

# Our native foreground service, referenced from the manifest and the method channel.
-keep class com.darubaaz.resq.MeshForegroundService { *; }

# flutter_secure_storage uses the Android Keystore via reflection-friendly APIs.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Flutter deferred components reference Play Core classes that are not bundled.
-dontwarn com.google.android.play.core.**
