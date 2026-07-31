import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/board.dart';

class CsvExporter {
  static String escape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String build(Board b) {
    final buf = StringBuffer()
      ..writeln('label,amount,category,created_at')
      ..writeln('# Board: ${escape(b.name)}')
      ..writeln('# Total: ${b.total.toStringAsFixed(2)}');
    for (final r in b.rows) {
      buf.writeln(
        '${escape(r.label)},${r.amount.toStringAsFixed(2)},${escape(r.category)},${r.createdAt.toIso8601String()}',
      );
    }
    return buf.toString();
  }

  static Future<void> share(Board b) async {
    final dir = await getTemporaryDirectory();
    final safeName = b.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${dir.path}/expense_${safeName}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(build(b));
    await Share.shareXFiles([XFile(file.path)], subject: 'Expenses: ${b.name}');
  }
}
