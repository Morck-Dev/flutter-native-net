import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../native_net_platform_interface.dart';
import '../models/exceptions.dart';
import 'bindings.dart';
import 'native_library.dart';

/// Creates the default FFI-based platform implementation.
NativeNetPlatform createDefaultPlatform() => FfiNativeNetPlatform();

/// Platform implementation that uses libcurl via dart:ffi.
class FfiNativeNetPlatform extends NativeNetPlatform {
  static bool _globalInitDone = false;
  static NativeNetBindings? _bindings;

  @override
  Future<String?> getPlatformVersion() async => 'libcurl (native FFI)';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    if (!_globalInitDone) {
      final lib = openNativeLibrary();
      _bindings = NativeNetBindings(lib);
      final code = _bindings!.init();
      if (code != 0) {
        throw NativeNetException(
          message: 'curl_global_init failed with code $code',
          code: 'INIT_ERROR',
        );
      }
      _globalInitDone = true;
    }
  }

  @override
  Future<Map<dynamic, dynamic>> request(Map<String, dynamic> requestData) =>
      Isolate.run(() => _exec(requestData, _ExecMode.request));

  @override
  Future<Map<dynamic, dynamic>> downloadFile(Map<String, dynamic> data) =>
      Isolate.run(() => _exec(data, _ExecMode.download));

  @override
  Future<Map<dynamic, dynamic>> uploadFile(Map<String, dynamic> data) =>
      Isolate.run(() => _exec(data, _ExecMode.upload));

  @override
  Future<void> cancelRequest(String tag) async {}

  @override
  Future<void> dispose() async {
    // curl_global_init/cleanup are process-level.
    // Don't reset _globalInitDone — the library stays loaded for the
    // process lifetime. Multiple NativeNetClient instances share it.
  }
}

enum _ExecMode { request, download, upload }

// ─── Worker isolate entry point ───────────────────────────────────────────

/// Fills the C options struct, calls the appropriate libcurl wrapper
/// function, and returns the parsed response map.
Map<dynamic, dynamic> _exec(Map<String, dynamic> d, _ExecMode mode) {
  final lib = openNativeLibrary();
  final b = NativeNetBindings(lib);
  final arena = Arena();

  try {
    final opts = arena<NativeNetRequestOptionsStruct>();

    // ── Required ──
    opts.ref.url    = _str(arena, d['url'] as String?);
    opts.ref.method = _str(arena, d['method'] as String? ?? 'GET');

    // Build headers string
    final hm = d['headers'] as Map<String, String>?;
    if (hm != null && hm.isNotEmpty) {
      final sb = StringBuffer();
      hm.forEach((k, v) => sb.write('$k: $v\r\n'));
      opts.ref.headers = sb.toString().toNativeUtf8(allocator: arena);
    } else {
      opts.ref.headers = nullptr;
    }

    // Body
    final bodyStr   = d['body'] as String?;
    final bodyBytes = d['bodyBytes'] as Uint8List?;
    if (bodyBytes != null && bodyBytes.isNotEmpty) {
      final p = arena<Uint8>(bodyBytes.length);
      p.asTypedList(bodyBytes.length).setAll(0, bodyBytes);
      opts.ref.body = p;
      opts.ref.bodyLength = bodyBytes.length;
    } else if (bodyStr != null && bodyStr.isNotEmpty) {
      final bytes = Uint8List.fromList(bodyStr.codeUnits);
      final p = arena<Uint8>(bytes.length);
      p.asTypedList(bytes.length).setAll(0, bytes);
      opts.ref.body = p;
      opts.ref.bodyLength = bytes.length;
    } else {
      opts.ref.body = nullptr;
      opts.ref.bodyLength = 0;
    }

    // ── Timeouts ──
    opts.ref.connectTimeoutMs = _int(d['connectTimeout']);
    opts.ref.timeoutMs        = _int(d['readTimeout']);

    // ── Redirects ──
    final fr = d['followRedirects'];
    opts.ref.followRedirects = (fr == false) ? 0 : 1;
    opts.ref.maxRedirects    = _int(d['maxRedirects']);

    // ── TLS ──
    opts.ref.sslVerifyPeer  = _int(d['sslVerifyPeer']);
    opts.ref.sslVerifyHost  = _int(d['sslVerifyHost']);
    opts.ref.caInfo         = _str(arena, d['caInfo'] as String?);
    opts.ref.caPath         = _str(arena, d['caPath'] as String?);
    opts.ref.clientCert     = _str(arena, d['clientCert'] as String?);
    opts.ref.clientKey      = _str(arena, d['clientKey'] as String?);
    opts.ref.clientCertType = _str(arena, d['clientCertType'] as String?);
    opts.ref.pinnedPublicKey= _str(arena, d['pinnedPublicKey'] as String?);

    // ── Proxy ──
    opts.ref.proxy           = _str(arena, d['proxy'] as String?);
    opts.ref.proxyUserpwd    = _str(arena, d['proxyUserpwd'] as String?);
    opts.ref.proxyType       = _int(d['proxyType']);
    opts.ref.httpProxyTunnel = _int(d['httpProxyTunnel']);

    // ── Auth ──
    opts.ref.userpwd  = _str(arena, d['userpwd'] as String?);
    opts.ref.httpAuth = _int(d['httpAuth']);

    // ── Cookies ──
    opts.ref.cookie     = _str(arena, d['cookie'] as String?);
    opts.ref.cookieFile = _str(arena, d['cookieFile'] as String?);
    opts.ref.cookieJar  = _str(arena, d['cookieJar'] as String?);

    // ── HTTP version ──
    opts.ref.httpVersion = _int(d['httpVersion']);

    // ── Speed limits ──
    opts.ref.maxRecvSpeed = _int(d['maxRecvSpeed']);
    opts.ref.maxSendSpeed = _int(d['maxSendSpeed']);

    // ── Resume / Range ──
    opts.ref.resumeFrom = _int(d['resumeFrom']);
    opts.ref.range      = _str(arena, d['range'] as String?);

    // ── User-Agent ──
    opts.ref.userAgent  = _str(arena, d['userAgent'] as String?);

    // ── DNS ──
    opts.ref.dnsServers = _str(arena, d['dnsServers'] as String?);
    opts.ref.resolve    = _str(arena, d['resolve'] as String?);

    // ── File ops ──
    opts.ref.filePath    = _str(arena, d['filePath'] as String?);
    opts.ref.fileField   = _str(arena, d['fileField'] as String?);
    opts.ref.fileName    = _str(arena, d['fileName'] as String?);
    opts.ref.mimeType    = _str(arena, d['mimeType'] as String?);
    opts.ref.extraFields = _str(arena, d['extraFields'] as String?);

    // ── Misc ──
    opts.ref.verbose = (d['verbose'] == true) ? 1 : 0;

    final pa = d['_progressAddr'] as int? ?? 0;
    opts.ref.progress = pa != 0
        ? Pointer<NativeNetProgressStruct>.fromAddress(pa)
        : nullptr;

    // ── Execute ──
    final Pointer<NativeNetResponseStruct> rp;
    switch (mode) {
      case _ExecMode.request:  rp = b.request(opts);      break;
      case _ExecMode.download: rp = b.downloadFile(opts);  break;
      case _ExecMode.upload:   rp = b.uploadFile(opts);    break;
    }

    return _parseResponse(rp, b);
  } finally {
    arena.releaseAll();
  }
}

// ─── Tiny helpers ─────────────────────────────────────────────────────────

Pointer<Utf8> _str(Arena a, String? s) =>
    (s != null && s.isNotEmpty) ? s.toNativeUtf8(allocator: a) : nullptr;

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  return 0;
}

Map<dynamic, dynamic> _parseResponse(
    Pointer<NativeNetResponseStruct> rp, NativeNetBindings b) {
  if (rp == nullptr) {
    throw const NativeNetException(
        message: 'native_net returned NULL', code: 'INTERNAL_ERROR');
  }

  final ref = rp.ref;
  if (ref.curlCode != 0) {
    final msg = ref.errorMessage != nullptr
        ? ref.errorMessage.toDartString()
        : 'curl error ${ref.curlCode}';
    b.freeResponse(rp);
    throw createExceptionFromPlatformError(_mapCurlErr(ref.curlCode), msg, null);
  }

  Uint8List bodyBytes;
  if (ref.body != nullptr && ref.bodyLength > 0) {
    bodyBytes = Uint8List.fromList(ref.body.asTypedList(ref.bodyLength));
  } else {
    bodyBytes = Uint8List(0);
  }

  final hdrs = <String, String>{};
  if (ref.headers != nullptr && ref.headersLength > 0) {
    for (final line in ref.headers.toDartString().split('\r\n')) {
      final i = line.indexOf(':');
      if (i > 0) hdrs[line.substring(0, i).trim().toLowerCase()] = line.substring(i + 1).trim();
    }
  }

  String? eff;
  if (ref.effectiveUrl != nullptr) eff = ref.effectiveUrl.toDartString();

  final sc = ref.statusCode;
  final ms = ref.totalTimeMs.toInt();
  b.freeResponse(rp);

  return {
    'statusCode': sc,
    'headers': hdrs,
    'bodyBytes': bodyBytes,
    'reasonPhrase': _phrase(sc),
    'contentLength': bodyBytes.length,
    'duration': ms,
    'finalUrl': eff,
  };
}

String _mapCurlErr(int c) {
  if (c == 28) return 'TIMEOUT';
  if (c == 42) return 'CANCELLED';
  if (const {6,7,9,45,55,56}.contains(c)) return 'CONNECTION_ERROR';
  if (const {35,51,53,54,58,59,60,64,66,77,82,83,90,91}.contains(c)) return 'CERTIFICATE_ERROR';
  return 'REQUEST_ERROR';
}

String _phrase(int c) => const {
  200:'OK',201:'Created',204:'No Content',301:'Moved Permanently',
  302:'Found',304:'Not Modified',400:'Bad Request',401:'Unauthorized',
  403:'Forbidden',404:'Not Found',500:'Internal Server Error',
  502:'Bad Gateway',503:'Service Unavailable',504:'Gateway Timeout',
}[c] ?? '';
