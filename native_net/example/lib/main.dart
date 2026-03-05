import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:native_net/native_net.dart';

void main() {
  runApp(const NativeNetExampleApp());
}

class NativeNetExampleApp extends StatelessWidget {
  const NativeNetExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NativeNet Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late NativeNetClient _client;
  String _platformVersion = 'Unknown';
  final List<_RequestLog> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _client = NativeNetClient(
      config: const NativeNetConfig(
        connectTimeout: Duration(seconds: 15),
        readTimeout: Duration(seconds: 15),
        enableLogging: true,
        defaultHeaders: {
          'User-Agent': 'NativeNet-Example/1.0',
        },
      ),
    );
    _initPlatform();
  }

  Future<void> _initPlatform() async {
    try {
      final version = await _client.getPlatformVersion() ?? 'Unknown';
      if (mounted) {
        setState(() {
          _platformVersion = version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _platformVersion = 'Error: $e';
        });
      }
    }
  }

  Future<void> _performRequest(String name, Future<NativeNetResponse> Function() action) async {
    setState(() => _isLoading = true);

    final stopwatch = Stopwatch()..start();
    try {
      final response = await action();
      stopwatch.stop();

      String bodyPreview;
      try {
        final jsonData = json.decode(response.body);
        bodyPreview = const JsonEncoder.withIndent('  ').convert(jsonData);
        if (bodyPreview.length > 1000) {
          bodyPreview = '${bodyPreview.substring(0, 1000)}\n... (truncated)';
        }
      } catch (_) {
        bodyPreview = response.body;
        if (bodyPreview.length > 1000) {
          bodyPreview = '${bodyPreview.substring(0, 1000)}\n... (truncated)';
        }
      }

      setState(() {
        _logs.insert(0, _RequestLog(
          name: name,
          success: true,
          statusCode: response.statusCode,
          duration: stopwatch.elapsed,
          body: bodyPreview,
          headers: response.headers,
        ));
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _logs.insert(0, _RequestLog(
          name: name,
          success: false,
          statusCode: 0,
          duration: stopwatch.elapsed,
          body: e.toString(),
          headers: {},
        ));
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('NativeNet Example'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Platform info card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _platformVersion,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Request buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RequestButton(
                  label: 'GET',
                  color: Colors.green,
                  onPressed: _isLoading ? null : () => _performRequest(
                    'GET /posts/1',
                    () => _client.get('https://jsonplaceholder.typicode.com/posts/1'),
                  ),
                ),
                _RequestButton(
                  label: 'POST JSON',
                  color: Colors.blue,
                  onPressed: _isLoading ? null : () => _performRequest(
                    'POST /posts',
                    () => _client.post(
                      'https://jsonplaceholder.typicode.com/posts',
                      jsonBody: {
                        'title': 'NativeNet Test',
                        'body': 'Testing native HTTP networking',
                        'userId': 1,
                      },
                    ),
                  ),
                ),
                _RequestButton(
                  label: 'PUT',
                  color: Colors.orange,
                  onPressed: _isLoading ? null : () => _performRequest(
                    'PUT /posts/1',
                    () => _client.put(
                      'https://jsonplaceholder.typicode.com/posts/1',
                      jsonBody: {
                        'id': 1,
                        'title': 'Updated Title',
                        'body': 'Updated body',
                        'userId': 1,
                      },
                    ),
                  ),
                ),
                _RequestButton(
                  label: 'DELETE',
                  color: Colors.red,
                  onPressed: _isLoading ? null : () => _performRequest(
                    'DELETE /posts/1',
                    () => _client.delete('https://jsonplaceholder.typicode.com/posts/1'),
                  ),
                ),
                _RequestButton(
                  label: 'PATCH',
                  color: Colors.purple,
                  onPressed: _isLoading ? null : () => _performRequest(
                    'PATCH /posts/1',
                    () => _client.patch(
                      'https://jsonplaceholder.typicode.com/posts/1',
                      jsonBody: {'title': 'Patched Title'},
                    ),
                  ),
                ),
                _RequestButton(
                  label: 'HEAD',
                  color: Colors.teal,
                  onPressed: _isLoading ? null : () => _performRequest(
                    'HEAD /posts/1',
                    () => _client.head('https://jsonplaceholder.typicode.com/posts/1'),
                  ),
                ),
                _RequestButton(
                  label: 'GET List',
                  color: Colors.indigo,
                  onPressed: _isLoading ? null : () => _performRequest(
                    'GET /posts (list)',
                    () => _client.get(
                      'https://jsonplaceholder.typicode.com/posts',
                      headers: {'Accept': 'application/json'},
                    ),
                  ),
                ),
                _RequestButton(
                  label: 'Timeout Test',
                  color: Colors.grey,
                  onPressed: _isLoading ? null : () => _performRequest(
                    'GET timeout test',
                    () => _client.get(
                      'https://httpbin.org/delay/10',
                      readTimeout: const Duration(seconds: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          // Results
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Text(
                      'Tap a button to make a request',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) => _RequestLogCard(log: _logs[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RequestButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _RequestButton({
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
      ),
      child: Text(label),
    );
  }
}

class _RequestLog {
  final String name;
  final bool success;
  final int statusCode;
  final Duration duration;
  final String body;
  final Map<String, String> headers;

  _RequestLog({
    required this.name,
    required this.success,
    required this.statusCode,
    required this.duration,
    required this.body,
    required this.headers,
  });
}

class _RequestLogCard extends StatefulWidget {
  final _RequestLog log;

  const _RequestLogCard({required this.log});

  @override
  State<_RequestLogCard> createState() => _RequestLogCardState();
}

class _RequestLogCardState extends State<_RequestLogCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final log = widget.log;
    final statusColor = log.success
        ? (log.statusCode >= 200 && log.statusCode < 300 ? Colors.green : Colors.orange)
        : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log.success ? '${log.statusCode}' : 'ERR',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${log.duration.inMilliseconds}ms',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
              if (_expanded) ...[
                const Divider(height: 16),
                if (log.headers.isNotEmpty) ...[
                  Text(
                    'Headers',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log.headers.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Body',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      log.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
