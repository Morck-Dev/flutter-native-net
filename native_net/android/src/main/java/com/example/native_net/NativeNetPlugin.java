package com.example.native_net;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Minimal plugin registration class.
 * All HTTP networking is done via dart:ffi calling libcurl directly.
 * This class exists only to satisfy Flutter's pluginClass requirement,
 * which allows us to use the AAR-based native library distribution.
 */
public class NativeNetPlugin implements FlutterPlugin {
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    }
}
