import 'dart:collection';
import 'package:flutter/foundation.dart';

/// In-memory ring buffer of log lines. Backed by a [ChangeNotifier] so the
/// LogScreen can `watch` it for live updates.
class AppLog {
  AppLog._();
  static final AppLog instance = AppLog._();

  static const int maxLines = 500;
  final ListQueue<LogLine> _lines = ListQueue<LogLine>();
  final List<VoidCallback> _listeners = [];

  List<LogLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;

  void log(String message, {LogLevel level = LogLevel.info, String? tag}) {
    final line = LogLine(
      timestamp: DateTime.now(),
      level: level,
      tag: tag ?? 'app',
      message: message,
    );
    _lines.addLast(line);
    if (_lines.length > maxLines) {
      _lines.removeFirst();
    }
    for (final cb in List<VoidCallback>.from(_listeners)) {
      cb();
    }
  }

  void clear() {
    _lines.clear();
    for (final cb in List<VoidCallback>.from(_listeners)) {
      cb();
    }
  }

  String exportText() {
    final buf = StringBuffer();
    for (final l in _lines) {
      buf.writeln(l.toString());
    }
    return buf.toString();
  }

  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);
}

enum LogLevel { debug, info, warn, error }

class LogLine {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  LogLine(
      {required this.timestamp,
      required this.level,
      required this.tag,
      required this.message});

  @override
  String toString() {
    final ts = timestamp.toIso8601String();
    return '[$ts] [${level.name.toUpperCase()}] [$tag] $message';
  }
}

/// Convenience: mirror a print() to the in-app log.
void appPrint(String message, {String tag = 'print'}) {
  // ignore: avoid_print
  print(message);
  AppLog.instance.log(message, tag: tag);
}
