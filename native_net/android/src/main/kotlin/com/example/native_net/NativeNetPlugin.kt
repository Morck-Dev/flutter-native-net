package com.example.native_net

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * NativeNetPlugin - Flutter plugin that uses OkHttp for HTTP networking on Android.
 *
 * OkHttp is Square's industry-standard HTTP client for Android and Java.
 * Features: HTTP/2 support, connection pooling, transparent GZIP,
 * response caching, and automatic retries.
 */
class NativeNetPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var client: OkHttpClient? = null
    private val activeCalls = ConcurrentHashMap<String, Call>()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_net")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE} (OkHttp 4.12.0)")
            }
            "initialize" -> handleInitialize(call, result)
            "request" -> handleRequest(call, result)
            "cancelRequest" -> handleCancelRequest(call, result)
            "dispose" -> handleDispose(result)
            else -> result.notImplemented()
        }
    }

    /**
     * Initializes the OkHttp client with the given configuration.
     */
    private fun handleInitialize(call: MethodCall, result: Result) {
        try {
            val connectTimeout = call.argument<Number>("connectTimeout")?.toLong() ?: 30000L
            val readTimeout = call.argument<Number>("readTimeout")?.toLong() ?: 30000L
            val writeTimeout = call.argument<Number>("writeTimeout")?.toLong() ?: 30000L
            val followRedirects = call.argument<Boolean>("followRedirects") ?: true
            val enableLogging = call.argument<Boolean>("enableLogging") ?: false
            val maxIdleConnections = call.argument<Number>("maxIdleConnections")?.toInt() ?: 5
            val keepAliveDuration = call.argument<Number>("keepAliveDuration")?.toLong() ?: 300000L

            val builder = OkHttpClient.Builder()
                .connectTimeout(connectTimeout, TimeUnit.MILLISECONDS)
                .readTimeout(readTimeout, TimeUnit.MILLISECONDS)
                .writeTimeout(writeTimeout, TimeUnit.MILLISECONDS)
                .followRedirects(followRedirects)
                .followSslRedirects(followRedirects)
                .connectionPool(
                    ConnectionPool(
                        maxIdleConnections,
                        keepAliveDuration,
                        TimeUnit.MILLISECONDS
                    )
                )
                .retryOnConnectionFailure(true)

            if (enableLogging) {
                val loggingInterceptor = HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.BODY
                }
                builder.addInterceptor(loggingInterceptor)
            }

            client = builder.build()
            result.success(null)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize OkHttp client: ${e.message}", null)
        }
    }

    /**
     * Handles an HTTP request using OkHttp.
     */
    private fun handleRequest(call: MethodCall, result: Result) {
        val currentClient = client
        if (currentClient == null) {
            result.error("NOT_INITIALIZED", "Client not initialized. Call initialize() first.", null)
            return
        }

        try {
            val url = call.argument<String>("url")
                ?: return result.error("INVALID_ARGUMENT", "URL is required", null)
            val method = call.argument<String>("method")
                ?: return result.error("INVALID_ARGUMENT", "Method is required", null)
            val headers = call.argument<Map<String, String>>("headers")
            val body = call.argument<String>("body")
            val bodyBytes = call.argument<ByteArray>("bodyBytes")
            val followRedirects = call.argument<Boolean>("followRedirects")
            val connectTimeout = call.argument<Number>("connectTimeout")?.toLong()
            val readTimeout = call.argument<Number>("readTimeout")?.toLong()
            val writeTimeout = call.argument<Number>("writeTimeout")?.toLong()
            val tag = call.argument<String>("tag")

            // Multipart support
            val files = call.argument<List<Map<String, Any>>>("files")
            val formFields = call.argument<Map<String, String>>("formFields")

            // Build a per-request client if there are custom timeouts or redirect settings
            val requestClient = if (connectTimeout != null || readTimeout != null ||
                writeTimeout != null || followRedirects != null) {
                currentClient.newBuilder().apply {
                    connectTimeout?.let { connectTimeout(it, TimeUnit.MILLISECONDS) }
                    readTimeout?.let { readTimeout(it, TimeUnit.MILLISECONDS) }
                    writeTimeout?.let { writeTimeout(it, TimeUnit.MILLISECONDS) }
                    followRedirects?.let { followRedirects(it); followSslRedirects(it) }
                }.build()
            } else {
                currentClient
            }

            // Build request body
            val requestBody = buildRequestBody(method, headers, body, bodyBytes, files, formFields)

            // Build the OkHttp request
            val requestBuilder = Request.Builder().url(url)

            // Set headers
            headers?.forEach { (key, value) ->
                requestBuilder.addHeader(key, value)
            }

            // Set method and body
            requestBuilder.method(method, requestBody)

            val okHttpRequest = requestBuilder.build()
            val okHttpCall = requestClient.newCall(okHttpRequest)

            // Store call for cancellation support
            tag?.let { activeCalls[it] = okHttpCall }

            val startTime = System.currentTimeMillis()

            // Execute asynchronously to avoid blocking the main thread
            okHttpCall.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    tag?.let { activeCalls.remove(it) }
                    mainHandler.post {
                        val errorCode = when {
                            e.message?.contains("timeout", ignoreCase = true) == true -> "TIMEOUT"
                            e.message?.contains("cancel", ignoreCase = true) == true -> "CANCELLED"
                            e.message?.contains("SSL", ignoreCase = true) == true ||
                            e.message?.contains("certificate", ignoreCase = true) == true -> "CERTIFICATE_ERROR"
                            else -> "CONNECTION_ERROR"
                        }
                        result.error(errorCode, e.message ?: "Request failed", null)
                    }
                }

                override fun onResponse(call: Call, response: Response) {
                    tag?.let { activeCalls.remove(it) }
                    try {
                        val duration = System.currentTimeMillis() - startTime
                        val responseBodyBytes = response.body?.bytes() ?: ByteArray(0)

                        // Collect response headers
                        val responseHeaders = HashMap<String, String>()
                        response.headers.forEach { (name, value) ->
                            responseHeaders[name] = value
                        }

                        val responseMap = HashMap<String, Any?>()
                        responseMap["statusCode"] = response.code
                        responseMap["headers"] = responseHeaders
                        responseMap["bodyBytes"] = responseBodyBytes
                        responseMap["reasonPhrase"] = response.message
                        responseMap["contentLength"] = responseBodyBytes.size
                        responseMap["duration"] = duration
                        responseMap["finalUrl"] = response.request.url.toString()

                        mainHandler.post {
                            result.success(responseMap)
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("RESPONSE_ERROR", e.message ?: "Failed to read response", null)
                        }
                    } finally {
                        response.close()
                    }
                }
            })
        } catch (e: Exception) {
            result.error("REQUEST_ERROR", e.message ?: "Failed to create request", null)
        }
    }

    /**
     * Builds the appropriate OkHttp RequestBody based on the request parameters.
     */
    private fun buildRequestBody(
        method: String,
        headers: Map<String, String>?,
        body: String?,
        bodyBytes: ByteArray?,
        files: List<Map<String, Any>>?,
        formFields: Map<String, String>?
    ): RequestBody? {
        // GET and HEAD methods should not have a body
        if (method == "GET" || method == "HEAD") {
            return null
        }

        // Multipart request (file upload)
        if (files != null && files.isNotEmpty()) {
            val multipartBuilder = MultipartBody.Builder()
                .setType(MultipartBody.FORM)

            // Add form fields
            formFields?.forEach { (key, value) ->
                multipartBuilder.addFormDataPart(key, value)
            }

            // Add files
            files.forEach { fileMap ->
                val field = fileMap["field"] as? String ?: "file"
                val fileName = fileMap["fileName"] as? String ?: "file"
                val bytes = fileMap["bytes"] as? ByteArray ?: return@forEach
                val contentType = fileMap["contentType"] as? String ?: "application/octet-stream"

                multipartBuilder.addFormDataPart(
                    field,
                    fileName,
                    bytes.toRequestBody(contentType.toMediaTypeOrNull())
                )
            }

            return multipartBuilder.build()
        }

        // Form fields only (application/x-www-form-urlencoded)
        if (formFields != null && formFields.isNotEmpty()) {
            val formBuilder = FormBody.Builder()
            formFields.forEach { (key, value) ->
                formBuilder.add(key, value)
            }
            return formBuilder.build()
        }

        // Binary body
        if (bodyBytes != null) {
            val contentType = headers?.entries
                ?.firstOrNull { it.key.equals("Content-Type", ignoreCase = true) }
                ?.value ?: "application/octet-stream"
            return bodyBytes.toRequestBody(contentType.toMediaType())
        }

        // String body
        if (body != null) {
            val contentType = headers?.entries
                ?.firstOrNull { it.key.equals("Content-Type", ignoreCase = true) }
                ?.value ?: "text/plain; charset=utf-8"
            return body.toRequestBody(contentType.toMediaType())
        }

        // Empty body for POST/PUT/PATCH
        if (method == "POST" || method == "PUT" || method == "PATCH") {
            return ByteArray(0).toRequestBody(null)
        }

        return null
    }

    /**
     * Cancels a request identified by its tag.
     */
    private fun handleCancelRequest(call: MethodCall, result: Result) {
        val tag = call.argument<String>("tag")
        if (tag != null) {
            activeCalls[tag]?.cancel()
            activeCalls.remove(tag)
        }
        result.success(null)
    }

    /**
     * Disposes of the OkHttp client and releases resources.
     */
    private fun handleDispose(result: Result) {
        try {
            // Cancel all active calls
            activeCalls.values.forEach { it.cancel() }
            activeCalls.clear()

            // Shutdown the connection pool and dispatcher
            client?.dispatcher?.executorService?.shutdown()
            client?.connectionPool?.evictAll()
            client?.cache?.close()
            client = null

            result.success(null)
        } catch (e: Exception) {
            result.error("DISPOSE_ERROR", e.message ?: "Failed to dispose client", null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // Clean up
        activeCalls.values.forEach { it.cancel() }
        activeCalls.clear()
        client?.dispatcher?.executorService?.shutdown()
        client?.connectionPool?.evictAll()
        client = null
    }
}
