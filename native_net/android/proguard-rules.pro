# native_net plugin - keep the plugin class for Flutter registration
-keep class com.example.native_net.NativeNetPlugin { *; }

# Keep native method names (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}
