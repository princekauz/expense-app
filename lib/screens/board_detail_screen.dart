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
              tooltip: 'Recurring',
              icon: const Icon(Icons.repeat),
              onPressed: () => _showRecurringSheet(board),
            ),
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
        floatingActionButton: Padding(
          // Push FAB up above the gesture-bar inset on gesture-nav devices.
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewPadding.bottom),
          child: FloatingActionButton.extended(
            backgroundColor: t.accent,
            foregroundColor: Colors.white,
            onPressed: () => _quickAddRow(board),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: board.rows.isEmpty && board.recurring.isEmpty
                  ? _EmptyBoard(t: t)
                  : CustomScrollView(
                      slivers: [
                        if (board.recurring.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _RecurringSection(
                                board: board, t: t, money: money),
                          ),
                        SliverPadding(
                          // Bottom padding = FAB height (~56) + safe-area inset + breathing room.
                          padding: EdgeInsets.only(
                            left: 0,
                            right: 0,
                            top: 4,
                            bottom:
                                80 + MediaQuery.of(context).viewPadding.bottom,
                          ),
                          sliver: board.rows.isEmpty
                              ? const SliverToBoxAdapter(
                                  child: SizedBox.shrink())
                              : SliverList.builder(
                                  itemCount: board.rows.length,
                                  itemBuilder: (_, i) {
                                    final r = board.rows[i];
                                    return Dismissible(
                                      key: ValueKey(r.id),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        color: Colors.red.withOpacity(0.85),
                                        child: const Icon(Icons.delete_outline,
                                            color: Colors.white),
                                      ),
                                      onDismissed: (_) =>
                                          _onSwipedAway(board, r, i),
                                      child: _RowTile(
                                        row: r,
                                        style: style,
                                        t: t,
                                        money: money,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
            _TotalBar(board: board, t: t, money: money),
          ],
        ),
      ),
    );
  }

  Future<void> _onSwipedAway(Board b, ExpenseRow row, int index) async {
    _lastDeletedRow = row;
    _lastDeletedIndex = index;
    await context.read<BoardProvider>().deleteRow(b, row);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${row.label}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            if (_lastDeletedRow != null) {
              await context.read<BoardProvider>().restoreRow(
                    b,
                    _lastDeletedRow!,
                    _lastDeletedIndex ?? b.rows.length,
                  );
            }
          },
        ),
      ),
    );
  }

  Future<void> _quickAddRow(Board b) async {
    final result = await showModalBottomSheet<_AddRowResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _AddRowSheet(initialCategory: AppCategories.presets.first),
    );
    if (result == null || !mounted) return;
    await context.read<BoardProvider>().addRow(
          b,
          label: result.label,
          amount: result.amount,
          category: result.category,
          date: result.date,
        );
  }

  Future<void> _renameBoard(Board b) async {
    final controller = TextEditingController(text: b.name);
    final res = await showDialog<String>(
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
    if (res != null && mounted) {
      await context.read<BoardProvider>().renameBoard(b, res);
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

  Future<void> _showRecurringSheet(Board b) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecurringSheet(board: b),
    );
  }
}

class _AddRowResult {
  final String label;
  final double amount;
  final String category;
  final DateTime date;
  _AddRowResult(
      {required this.label,
      required this.amount,
      required this.category,
      required this.date});
}

class _AddRowSheet extends StatefulWidget {
  final String initialCategory;
  const _AddRowSheet({required this.initialCategory});

  @override
  State<_AddRowSheet> createState() => _AddRowSheetState();
}

class _AddRowSheetState extends State<_AddRowSheet> {
  final _labelCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late String _category = widget.initialCategory;
  late DateTime _date = DateTime.now();
  bool _isPlanned = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _isPlanned = _date.isAfter(_today());
      });
    }
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _dateLabel() {
    final today = _today();
    final d = DateTime(_date.year, _date.month, _date.day);
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat.yMMMd().format(_date);
  }

  void _submit() {
    final label = _labelCtrl.text.trim();
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (label.isEmpty || amt <= 0) return;
    Navigator.pop(
      context,
      _AddRowResult(
          label: label, amount: amt, category: _category, date: _date),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'New entry',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _labelCtrl,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'What did you spend on?'),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                    labelText: 'Amount', prefixText: '\$ '),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in AppCategories.presets)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPlanned
                            ? Icons.event_outlined
                            : Icons.today_outlined,
                        color: _isPlanned ? Colors.orange : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dateLabel(),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            if (_isPlanned)
                              Text(
                                'planned — counts toward budget',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Text(
                        'Change',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isPlanned)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Today'),
                        onPressed: () => setState(() {
                          _date = _today();
                          _isPlanned = false;
                        }),
                      ),
                      ActionChip(
                        label: const Text('Tomorrow'),
                        onPressed: () => setState(() {
                          _date = _today().add(const Duration(days: 1));
                          _isPlanned = true;
                        }),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                        onPressed: _submit, child: const Text('Add')),
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
              'Tap "Add" to log a past, current, or planned expense.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final ExpenseRow row;
  final BoardStyle style;
  final BoardTheme t;
  final NumberFormat money;
  const _RowTile({
    required this.row,
    required this.style,
    required this.t,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final color = CategoryColors.of(row.category);
    final isFuture = row.isFuture;
    final plannedLabel = isFuture ? _futureLabel(row.date) : null;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: TextStyle(
                          color: t.onSurface.withOpacity(isFuture ? 0.85 : 1.0),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          fontStyle:
                              isFuture ? FontStyle.italic : FontStyle.normal,
                          decoration: isFuture
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationStyle:
                              isFuture ? TextDecorationStyle.dotted : null,
                          decorationColor: t.onSurface.withOpacity(0.4),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (plannedLabel != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.4),
                              width: 0.5),
                        ),
                        child: Text(
                          plannedLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isFuture
                      ? '${row.category} • ${DateFormat.MMMd().format(row.date)}'
                      : row.category,
                  style: TextStyle(
                    color: t.onSurface.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            money.format(row.amount),
            style: TextStyle(
              color: t.onSurface.withOpacity(isFuture ? 0.7 : 1.0),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
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
            : const BoxDecoration();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: base,
      child: content,
    );
  }

  String _futureLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 1) return 'tomorrow';
    if (diff < 7) return 'in $diff days';
    if (diff < 14) return 'next week';
    return DateFormat.MMMd().format(d);
  }
}

class _TotalBar extends StatelessWidget {
  final Board board;
  final BoardTheme t;
  final NumberFormat money;

  const _TotalBar({required this.board, required this.t, required this.money});

  @override
  Widget build(BuildContext context) {
    final totals = board.totalsByCategory();
    final total = board.total;
    final realized = board.realizedTotal;
    final planned = board.plannedTotal;
    final topEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = topEntries.take(3).toList();

    final budget = board.budget;
    final overBudget = budget != null && realized > budget;
    final remaining = budget != null ? budget - realized : null;
    final fillPct = budget != null && budget > 0
        ? (realized / budget).clamp(0.0, 2.0)
        : null;
    Color barColor = Colors.green;
    if (fillPct != null) {
      if (fillPct >= 1.0) {
        barColor = Colors.red;
      } else if (fillPct >= 0.8) {
        barColor = Colors.amber.shade700;
      }
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.divider, width: 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            children: [
              if (top3.isNotEmpty && total > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
              if (budget != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            overBudget
                                ? 'Over budget by ${money.format(realized - budget)}'
                                : '${money.format(realized)} of ${money.format(budget)}',
                            style: TextStyle(
                              color: barColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (planned > 0)
                            Text(
                              '+${money.format(planned)} planned',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: fillPct != null
                              ? (fillPct > 1.0 ? 1.0 : fillPct)
                              : 0,
                          minHeight: 6,
                          backgroundColor: t.divider.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                      if (!overBudget && remaining != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${money.format(remaining)} left',
                            style: TextStyle(
                              color: t.onSurface.withOpacity(0.5),
                              fontSize: 10,
                            ),
                          ),
                        ),
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

class _RecurringSection extends StatelessWidget {
  final Board board;
  final BoardTheme t;
  final NumberFormat money;
  const _RecurringSection(
      {required this.board, required this.t, required this.money});

  String _freqLabel(RecurrenceFrequency f) {
    switch (f) {
      case RecurrenceFrequency.daily:
        return 'every day';
      case RecurrenceFrequency.weekly:
        return 'weekly';
      case RecurrenceFrequency.monthly:
        return 'monthly';
      case RecurrenceFrequency.weekdays:
        return 'weekdays';
      case RecurrenceFrequency.weekends:
        return 'weekends';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat, size: 14, color: t.accent),
              const SizedBox(width: 6),
              Text(
                'Recurring',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final tpl in board.recurring)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tpl.label} • ${money.format(tpl.amount)} • ${_freqLabel(tpl.rule.frequency)}',
                      style: TextStyle(
                          fontSize: 12, color: t.onSurface.withOpacity(0.8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecurringSheet extends StatefulWidget {
  final Board board;
  const _RecurringSheet({required this.board});

  @override
  State<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends State<_RecurringSheet> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BoardProvider>();
    final b = provider.boards.firstWhere(
      (x) => x.id == widget.board.id,
      orElse: () => widget.board,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recurring entries',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _addRecurring(context, b),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (b.recurring.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.repeat,
                        size: 32, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 8),
                    const Text(
                      'No recurring entries yet',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coffee, subscriptions, weekly groceries — auto-added.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: b.recurring.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final tpl = b.recurring[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tpl.label),
                      subtitle: Text(
                        '\$${tpl.amount.toStringAsFixed(2)} • ${tpl.category} • ${tpl.rule.frequency.name}',
                      ),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => provider.deleteRecurring(b, tpl),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Editing a template keeps historical entries; new dates stop generating after deletion.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addRecurring(BuildContext context, Board b) async {
    // Capture provider BEFORE any await so we never use BuildContext across async gaps.
    final provider = context.read<BoardProvider>();
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = AppCategories.presets.first;
    RecurrenceFrequency freq = RecurrenceFrequency.weekly;
    DateTime? endDate;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (c, setSt) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'New recurring entry',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: labelCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Label'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountCtrl,
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
                    const SizedBox(height: 12),
                    const Text('Frequency',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final f in RecurrenceFrequency.values)
                          ChoiceChip(
                            label: Text(f.name),
                            selected: freq == f,
                            onSelected: (_) => setSt(() => freq = f),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: c,
                                initialDate: endDate ??
                                    DateTime.now()
                                        .add(const Duration(days: 90)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365 * 5)),
                              );
                              if (picked != null) setSt(() => endDate = picked);
                            },
                            icon: const Icon(Icons.event_outlined),
                            label: Text(endDate == null
                                ? 'No end date'
                                : 'Until ${DateFormat.yMMMd().format(endDate!)}'),
                          ),
                        ),
                        if (endDate != null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setSt(() => endDate = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(c, false),
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
                              Navigator.pop(c, true);
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
      },
    );

    if (saved == true && mounted) {
      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (labelCtrl.text.trim().isNotEmpty && amt > 0) {
        await provider.addRecurring(
          b,
          label: labelCtrl.text.trim(),
          amount: amt,
          category: category,
          frequency: freq,
          endDate: endDate,
        );
      }
    }
  }
}
