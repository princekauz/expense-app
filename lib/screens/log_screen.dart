import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../util/app_log.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late VoidCallback _cb;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _cb = () {
      if (mounted) setState(() {});
      // Auto-scroll to bottom on new lines.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      });
    };
    AppLog.instance.addListener(_cb);
  }

  @override
  void dispose() {
    AppLog.instance.removeListener(_cb);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: AppLog.instance.exportText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = AppLog.instance.lines;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log'),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_all),
            onPressed: _copyAll,
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => AppLog.instance.clear(),
          ),
        ],
      ),
      body: lines.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bug_report_outlined,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No log entries yet'),
                    SizedBox(height: 4),
                    Text(
                      'Actions in the app will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              itemCount: lines.length,
              itemBuilder: (_, i) => _LogLineTile(line: lines[i]),
            ),
    );
  }
}

class _LogLineTile extends StatelessWidget {
  final LogLine line;
  const _LogLineTile({required this.line});

  Color _colorFor(LogLevel l) {
    switch (l) {
      case LogLevel.debug:
        return Colors.blueGrey;
      case LogLevel.info:
        return Colors.black87;
      case LogLevel.warn:
        return Colors.orange.shade800;
      case LogLevel.error:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: line.toString()));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Line copied'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: SelectableText(
          line.toString(),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: _colorFor(line.level),
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
