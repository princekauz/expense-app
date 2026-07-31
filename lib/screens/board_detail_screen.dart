import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/board.dart';
import '../state/board_provider.dart';
import '../theme/app_themes.dart';
import '../util/csv_export.dart';

class BoardDetailScreen extends StatefulWidget {
  final String boardId;
  const BoardDetailScreen({super.key, required this.boardId});

  @override
  State<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends State<BoardDetailScreen> {
  int? _lastDeletedIndex;
  ExpenseRow? _lastDeletedRow;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BoardProvider>();
    final board = provider.boards.firstWhere(
      (b) => b.id == widget.boardId,
      orElse: () => Board(
        id: widget.boardId,
        name: 'Unknown',
        themeIndex: 0,
        styleIndex: 0,
        createdAt: DateTime.now(),
      ),
    );
    final t = AppThemes.byIndex(board.themeIndex);
    final style = BoardStyle
        .values[board.styleIndex.clamp(0, BoardStyle.values.length - 1)];
    final money =
        NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);

    return Theme(
      data: AppThemes.materialThemeFor(board.themeIndex),
      child: Scaffold(
        backgroundColor: t.scaffold,
        appBar: AppBar(
          backgroundColor: t.scaffold,
          surfaceTintColor: Colors.transparent,
          title: Text(board.name, style: TextStyle(color: t.onSurface)),
          iconTheme: IconThemeData(color: t.onSurface),
          actions: [
            IconButton(
              tooltip: 'Style & theme',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => _showStyleSheet(board),
            ),
            IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.ios_share),
              onPressed: () => CsvExporter.share(board),
            ),
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _renameBoard(board),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          onPressed: () => _quickAddRow(board),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
        body: Column(
          children: [
            Expanded(
              child: board.rows.isEmpty
                  ? _EmptyBoard(t: t)
                  : _RowList(
                      board: board,
                      style: style,
                      t: t,
                      money: money,
                      onSwipedAway: (row, index) async {
                        _lastDeletedRow = row;
                        _lastDeletedIndex = index;
                        await context
                            .read<BoardProvider>()
                            .deleteRow(board, row);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted "${row.label}"'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () async {
                                if (_lastDeletedRow != null) {
                                  await context
                                      .read<BoardProvider>()
                                      .restoreRow(
                                        board,
                                        _lastDeletedRow!,
                                        _lastDeletedIndex ?? board.rows.length,
                                      );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _TotalBar(board: board, t: t, style: style, money: money),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAddRow(Board b) async {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = AppCategories.presets.first;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSt) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('New entry',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'What did you spend on?'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  autofocus: false,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Amount', prefixText: '\$ '),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in AppCategories.presets)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setSt(() => category = v ?? category),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final label = labelCtrl.text.trim();
                          final amt =
                              double.tryParse(amountCtrl.text.trim()) ?? 0;
                          if (label.isEmpty || amt <= 0) return;
                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true && mounted) {
      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (labelCtrl.text.trim().isNotEmpty && amt > 0) {
        await context.read<BoardProvider>().addRow(
              b,
              label: labelCtrl.text.trim(),
              amount: amt,
              category: category,
            );
      }
    }
  }

  Future<void> _renameBoard(Board b) async {
    final controller = TextEditingController(text: b.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename board'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = controller.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(context, n);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await context.read<BoardProvider>().renameBoard(b, result);
    }
  }

  Future<void> _showStyleSheet(Board b) async {
    int themeIdx = b.themeIndex;
    int styleIdx = b.styleIndex;
    await showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Theme',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < AppThemes.all.length; i++)
                      GestureDetector(
                        onTap: () => setSt(() => themeIdx = i),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppThemes.all[i].scaffold,
                            border: Border.all(
                              color: themeIdx == i
                                  ? AppThemes.all[i].accent
                                  : Colors.black12,
                              width: themeIdx == i ? 3 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppThemes.all[i].accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Style',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: [
                    for (int i = 0; i < BoardStyle.values.length; i++)
                      ButtonSegment(
                          value: i, label: Text(BoardStyle.values[i].label)),
                  ],
                  selected: {styleIdx},
                  onSelectionChanged: (s) => setSt(() => styleIdx = s.first),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    context
                        .read<BoardProvider>()
                        .setBoardTheme(b, themeIdx, styleIdx);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  final BoardTheme t;
  const _EmptyBoard({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: t.onSurface.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              'No entries yet',
              style: TextStyle(
                  color: t.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "Add" to log an expense.',
              style: TextStyle(color: t.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowList extends StatelessWidget {
  final Board board;
  final BoardStyle style;
  final BoardTheme t;
  final NumberFormat money;
  final Future<void> Function(ExpenseRow row, int index) onSwipedAway;

  const _RowList({
    required this.board,
    required this.style,
    required this.t,
    required this.money,
    required this.onSwipedAway,
  });

  @override
  Widget build(BuildContext context) {
    final rows = board.rows;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        return Dismissible(
          key: ValueKey(r.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.red.withOpacity(0.85),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => onSwipedAway(r, i),
          child: _RowTile(row: r, style: style, t: t, money: money),
        );
      },
    );
  }
}

class _RowTile extends StatelessWidget {
  final ExpenseRow row;
  final BoardStyle style;
  final BoardTheme t;
  final NumberFormat money;
  const _RowTile(
      {required this.row,
      required this.style,
      required this.t,
      required this.money});

  @override
  Widget build(BuildContext context) {
    final color = CategoryColors.of(row.category);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: TextStyle(
                      color: t.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  row.category,
                  style: TextStyle(
                      color: t.onSurface.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            money.format(row.amount),
            style: TextStyle(
                color: t.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

    final base = style == BoardStyle.boxed
        ? BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.divider.withOpacity(0.06)),
          )
        : style == BoardStyle.ruled
            ? BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(color: t.divider.withOpacity(0.08)),
                ),
              )
            : const BoxDecoration(); // minimal — no decoration, no divider

    return Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: base,
        child: content);
  }
}

class _TotalBar extends StatelessWidget {
  final Board board;
  final BoardTheme t;
  final BoardStyle style;
  final NumberFormat money;

  const _TotalBar(
      {required this.board,
      required this.t,
      required this.style,
      required this.money});

  @override
  Widget build(BuildContext context) {
    final totals = board.totalsByCategory();
    final total = board.total;
    final topEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = topEntries.take(3).toList();

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.divider, width: 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              if (top3.isNotEmpty && total > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      for (final e in top3) ...[
                        Expanded(
                          flex: (e.value * 100).round().clamp(1, 1000),
                          child: Container(
                            height: 4,
                            margin:
                                EdgeInsets.only(right: top3.last == e ? 0 : 2),
                            decoration: BoxDecoration(
                              color: CategoryColors.of(e.key),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                      if (top3.length < topEntries.length)
                        for (final e in topEntries.skip(3)) ...[
                          Expanded(
                            flex: (e.value * 100).round().clamp(1, 1000),
                            child: Container(
                              height: 4,
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                color:
                                    CategoryColors.of(e.key).withOpacity(0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
              Row(
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      color: t.onSurface.withOpacity(0.6),
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    money.format(total),
                    style: TextStyle(
                      color: t.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
