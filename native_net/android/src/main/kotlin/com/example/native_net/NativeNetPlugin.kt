package com.example.native_net

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Minimal plugin registration class.
 * All HTTP networking is done via dart:ffi calling libcurl directly.
 * This class exists only to satisfy Flutter's pluginClass requirement,
 * which allows us to use the AAR-based native library distribution.
 */
class NativeNetPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
