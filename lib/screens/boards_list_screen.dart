import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/board.dart';
import '../state/board_provider.dart';
import '../theme/app_themes.dart';
import 'board_detail_screen.dart';

class BoardsListScreen extends StatelessWidget {
  const BoardsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BoardProvider>();
    final boards = provider.boards;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewBoardDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New board'),
      ),
      body: boards.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              // bottom padding = FAB extended (~56) + safe area gesture inset + breathing room
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                96 + MediaQuery.of(context).viewPadding.bottom,
              ),
              itemCount: boards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _BoardTile(board: boards[i]),
            ),
    );
  }

  Future<void> _showNewBoardDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New board'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "e.g. Last week's spending",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, name);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      await context.read<BoardProvider>().createBoard(name: result);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_alt_outlined,
                size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No boards yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "New board" to start tracking expenses.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  final Board board;
  const _BoardTile({required this.board});

  @override
  Widget build(BuildContext context) {
    final t = AppThemes.byIndex(board.themeIndex);
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => BoardDetailScreen(boardId: board.id)),
          );
        },
        onLongPress: () => _showBoardMenu(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.divider.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 48,
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      board.name,
                      style: TextStyle(
                        color: t.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(board),
                      style: TextStyle(
                        color: t.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${board.total.toStringAsFixed(2)}',
                style: TextStyle(
                  color: t.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(Board b) {
    final t = AppThemes.byIndex(b.themeIndex);
    final s =
        BoardStyle.values[b.styleIndex.clamp(0, BoardStyle.values.length - 1)];
    final parts = <String>[
      '${b.rows.length} ${b.rows.length == 1 ? 'item' : 'items'}',
      s.label,
      t.name,
    ];
    if (b.budget != null) {
      parts.insert(1, 'budget \$${b.budget!.toStringAsFixed(0)}');
    }
    final planned = b.plannedTotal;
    if (planned > 0) {
      parts.add('+\$${planned.toStringAsFixed(0)} planned');
    }
    return parts.join(' • ');
  }

  Future<void> _showBoardMenu(BuildContext context) async {
    final provider = context.read<BoardProvider>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(board.budget == null
                  ? 'Set budget'
                  : 'Edit budget (${'\$${board.budget!.toStringAsFixed(0)}'})'),
              onTap: () => Navigator.pop(context, 'budget'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'rename') {
      await _rename(context, provider);
    } else if (action == 'budget') {
      await _editBudget(context, provider);
    } else if (action == 'delete') {
      await _confirmDelete(context, provider);
    }
  }

  Future<void> _editBudget(BuildContext context, BoardProvider provider) async {
    final controller =
        TextEditingController(text: board.budget?.toStringAsFixed(0) ?? '');
    final result = await showDialog<double?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(board.budget == null ? 'Set budget' : 'Edit budget'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(prefixText: '\$ ', hintText: '0 to clear'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final t = controller.text.trim();
              if (t.isEmpty) {
                Navigator.pop(context, 0.0); // 0 = clear
                return;
              }
              final v = double.tryParse(t);
              if (v == null || v < 0) return;
              Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await provider.setBoardBudget(board, result == 0 ? null : result);
    }
  }

  Future<void> _rename(BuildContext context, BoardProvider provider) async {
    final controller = TextEditingController(text: board.name);
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
    if (result != null) {
      await provider.renameBoard(board, result);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, BoardProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${board.name}"?'),
        content: const Text(
            'This will remove the board and all its entries. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await provider.deleteBoard(board);
    }
  }
}
