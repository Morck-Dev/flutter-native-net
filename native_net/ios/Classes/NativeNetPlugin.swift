import Flutter
import UIKit

/// NativeNetPlugin - Flutter plugin that uses URLSession for HTTP networking on iOS.
///
/// URLSession is Apple's native networking framework providing:
/// - HTTP/2 and HTTP/3 support
/// - System-level certificate management
/// - Automatic proxy configuration
/// - Background transfer support
/// - Intelligent connection coalescing
public class NativeNetPlugin: NSObject, FlutterPlugin {

    private var session: URLSession?
    private var sessionConfig: URLSessionConfiguration?
    private var activeTasks: [String: URLSessionTask] = [:]
    private var enableLogging: Bool = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "native_net", binaryMessenger: registrar.messenger())
        let instance = NativeNetPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion + " (URLSession)")
        case "initialize":
            handleInitialize(call: call, result: result)
        case "request":
            handleRequest(call: call, result: result)
        case "cancelRequest":
            handleCancelRequest(call: call, result: result)
        case "dispose":
            handleDispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Initialize

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
            return
        }

        let connectTimeout = (args["connectTimeout"] as? NSNumber)?.doubleValue ?? 30000.0
        let readTimeout = (args["readTimeout"] as? NSNumber)?.doubleValue ?? 30000.0
        let enableLog = args["enableLogging"] as? Bool ?? false

        self.enableLogging = enableLog

        let config = URLSessionConfiguration.default

        // Convert milliseconds to seconds
        config.timeoutIntervalForRequest = readTimeout / 1000.0
        config.timeoutIntervalForResource = connectTimeout / 1000.0

        // Connection pooling (URLSession handles this automatically)
        config.httpMaximumConnectionsPerHost = 6

        // Enable HTTP pipelining for performance
        config.httpShouldUsePipelining = true

        // Use system proxy settings automatically
        config.connectionProxyDictionary = nil

        // Enable cookies
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true

        // Set default headers
        if let defaultHeaders = args["defaultHeaders"] as? [String: String] {
            config.httpAdditionalHeaders = defaultHeaders
        }

        self.sessionConfig = config
        self.session = URLSession(configuration: config)

        result(nil)
    }

    // MARK: - Request

    private func handleRequest(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let session = self.session else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Client not initialized. Call initialize() first.", details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String,
              let method = args["method"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "URL and method are required", details: nil))
            return
        }

        guard let url = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid URL: \(urlString)", details: nil))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        // Set headers
        if let headers = args["headers"] as? [String: String] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Per-request timeouts
        if let connectTimeout = args["connectTimeout"] as? NSNumber {
            request.timeoutInterval = connectTimeout.doubleValue / 1000.0
        }
        if let readTimeout = args["readTimeout"] as? NSNumber {
            request.timeoutInterval = readTimeout.doubleValue / 1000.0
        }

        // Set request body
        let files = args["files"] as? [[String: Any]]
        let formFields = args["formFields"] as? [String: String]

        if let files = files, !files.isEmpty {
            // Multipart body
            let boundary = "NativeNet-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = buildMultipartBody(boundary: boundary, formFields: formFields, files: files)
        } else if let formFields = formFields, !formFields.isEmpty, method != "GET" && method != "HEAD" {
            // URL-encoded form body
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let formString = formFields.map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }.joined(separator: "&")
            request.httpBody = formString.data(using: .utf8)
        } else if let bodyBytes = args["bodyBytes"] as? FlutterStandardTypedData {
            request.httpBody = bodyBytes.data
        } else if let body = args["body"] as? String {
            request.httpBody = body.data(using: .utf8)
        }

        // Follow redirects handling
        let followRedirects = args["followRedirects"] as? Bool ?? true
        let tag = args["tag"] as? String

        let startTime = Date()

        if enableLogging {
            logRequest(request)
        }

        // Create a custom session for redirect handling if needed
        let taskSession: URLSession
        if !followRedirects {
            let config = self.sessionConfig?.copy() as? URLSessionConfiguration ?? URLSessionConfiguration.default
            taskSession = URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
        } else {
            taskSession = session
        }

        let task = taskSession.dataTask(with: request) { [weak self] data, response, error in
            // Remove from active tasks
            if let tag = tag {
                self?.activeTasks.removeValue(forKey: tag)
            }

            if let error = error {
                let nsError = error as NSError
                let errorCode: String
                let errorMessage: String

                switch nsError.code {
                case NSURLErrorTimedOut:
                    errorCode = "TIMEOUT"
                    errorMessage = "Request timed out"
                case NSURLErrorCancelled:
                    errorCode = "CANCELLED"
                    errorMessage = "Request was cancelled"
                case NSURLErrorSecureConnectionFailed,
                     NSURLErrorServerCertificateHasBadDate,
                     NSURLErrorServerCertificateUntrusted,
                     NSURLErrorServerCertificateHasUnknownRoot,
                     NSURLErrorServerCertificateNotYetValid,
                     NSURLErrorClientCertificateRejected:
                    errorCode = "CERTIFICATE_ERROR"
                    errorMessage = error.localizedDescription
                case NSURLErrorCannotConnectToHost,
                     NSURLErrorNetworkConnectionLost,
                     NSURLErrorNotConnectedToInternet,
                     NSURLErrorDNSLookupFailed:
                    errorCode = "CONNECTION_ERROR"
                    errorMessage = error.localizedDescription
                default:
                    errorCode = "REQUEST_ERROR"
                    errorMessage = error.localizedDescription
                }

                DispatchQueue.main.async {
                    result(FlutterError(code: errorCode, message: errorMessage, details: nil))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "RESPONSE_ERROR", message: "Invalid response", details: nil))
                }
                return
            }

            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            let bodyBytes = data ?? Data()

            // Collect response headers
            var responseHeaders: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                responseHeaders[String(describing: key)] = String(describing: value)
            }

            if self?.enableLogging == true {
                self?.logResponse(httpResponse, data: bodyBytes, duration: duration)
            }

            let responseMap: [String: Any?] = [
                "statusCode": httpResponse.statusCode,
                "headers": responseHeaders,
                "bodyBytes": FlutterStandardTypedData(bytes: bodyBytes),
                "reasonPhrase": HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                "contentLength": bodyBytes.count,
                "duration": duration,
                "finalUrl": httpResponse.url?.absoluteString
            ]

            DispatchQueue.main.async {
                result(responseMap)
            }
        }

        // Store task for cancellation
        if let tag = tag {
            activeTasks[tag] = task
        }

        task.resume()
    }

    // MARK: - Multipart Body Builder

    private func buildMultipartBody(boundary: String, formFields: [String: String]?, files: [[String: Any]]) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        // Add form fields
        if let fields = formFields {
            for (key, value) in fields {
                body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
                body.append("\(value)\(lineBreak)".data(using: .utf8)!)
            }
        }

        // Add files
        for fileMap in files {
            guard let field = fileMap["field"] as? String,
                  let fileName = fileMap["fileName"] as? String,
                  let bytes = fileMap["bytes"] as? FlutterStandardTypedData else {
                continue
            }
            let contentType = fileMap["contentType"] as? String ?? "application/octet-stream"

            body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(fileName)\"\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Type: \(contentType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
            body.append(bytes.data)
            body.append(lineBreak.data(using: .utf8)!)
        }

        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }

    // MARK: - Cancel

    private func handleCancelRequest(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let args = call.arguments as? [String: Any],
           let tag = args["tag"] as? String {
            activeTasks[tag]?.cancel()
            activeTasks.removeValue(forKey: tag)
        }
        result(nil)
    }

    // MARK: - Dispose

    private func handleDispose(result: @escaping FlutterResult) {
        // Cancel all active tasks
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()

        // Invalidate and cancel the session
        session?.invalidateAndCancel()
        session = nil
        sessionConfig = nil

        result(nil)
    }

    // MARK: - Logging

    private func logRequest(_ request: URLRequest) {
        print("[NativeNet] --> \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "")")
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                print("[NativeNet] \(key): \(value)")
            }
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            let truncated = bodyString.prefix(500)
            print("[NativeNet] Body: \(truncated)")
        }
        print("[NativeNet] --> END \(request.httpMethod ?? "UNKNOWN")")
    }

    private func logResponse(_ response: HTTPURLResponse, data: Data, duration: Int) {
        print("[NativeNet] <-- \(response.statusCode) \(response.url?.absoluteString ?? "") (\(duration)ms)")
        for (key, value) in response.allHeaderFields {
            print("[NativeNet] \(key): \(value)")
        }
        if let bodyString = String(data: data, encoding: .utf8) {
            let truncated = bodyString.prefix(500)
            print("[NativeNet] Body: \(truncated)")
        }
        print("[NativeNet] <-- END HTTP")
    }

    // MARK: - Helpers

    private func percentEncode(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}

// MARK: - No Redirect Delegate

/// A URLSession delegate that prevents automatic redirect following.
private class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Return nil to prevent redirect
        completionHandler(nil)
    }
}
