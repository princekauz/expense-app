import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/recurrence_engine.dart';
import '../data/storage_service.dart';
import '../models/board.dart';

class BoardProvider extends ChangeNotifier {
  BoardProvider(this._storage) {
    _boards = _storage.getAllBoards();
    _materializeAll();
  }

  final StorageService _storage;
  final _uuid = const Uuid();

  List<Board> _boards = [];
  List<Board> get boards => List.unmodifiable(_boards);

  void refresh() {
    _boards = _storage.getAllBoards();
    _materializeAll();
    notifyListeners();
  }

  void _materializeAll() {
    var any = false;
    for (final b in _boards) {
      if (b.recurring.isNotEmpty) {
        final added = RecurrenceEngine.materialize(b);
        if (added > 0) any = true;
        // sort by date so future-dated items appear in chronological position
        b.rows.sort((a, b) => a.date.compareTo(b.date));
        _storage.saveBoard(b);
      }
    }
    if (any) {
      // No notify here — refresh() will call us, OR the caller will after explicit save
    }
  }

  Future<Board> createBoard({
    required String name,
    int themeIndex = 0,
    int styleIndex = 0,
    double? budget,
  }) async {
    final b = Board(
      id: _uuid.v4(),
      name: name,
      themeIndex: themeIndex,
      styleIndex: styleIndex,
      createdAt: DateTime.now(),
      budget: budget,
    );
    await _storage.saveBoard(b);
    refresh();
    return b;
  }

  Future<void> renameBoard(Board b, String newName) async {
    b.name = newName;
    await _storage.saveBoard(b);
    notifyListeners();
  }

  Future<void> setBoardTheme(Board b, int themeIndex, int styleIndex) async {
    b.themeIndex = themeIndex;
    b.styleIndex = styleIndex;
    await _storage.saveBoard(b);
    notifyListeners();
  }

  Future<void> setBoardBudget(Board b, double? budget) async {
    b.budget = budget;
    await _storage.saveBoard(b);
    notifyListeners();
  }

  Future<void> deleteBoard(Board b) async {
    await _storage.deleteBoard(b);
    refresh();
  }

  Future<ExpenseRow> addRow(
    Board b, {
    required String label,
    required double amount,
    required String category,
    DateTime? date,
  }) async {
    final now = DateTime.now();
    final r = ExpenseRow(
      id: _uuid.v4(),
      label: label,
      amount: amount,
      category: category,
      createdAt: now,
      date: date ?? now,
    );
    b.rows.add(r);
    b.rows.sort((a, b) => a.date.compareTo(b.date));
    await _storage.saveBoard(b);
    notifyListeners();
    return r;
  }

  Future<void> updateRow(
    Board b,
    ExpenseRow row, {
    String? label,
    double? amount,
    String? category,
    DateTime? date,
  }) async {
    if (label != null) row.label = label;
    if (amount != null) row.amount = amount;
    if (category != null) row.category = category;
    if (date != null) row.date = date;
    b.rows.sort((a, b) => a.date.compareTo(b.date));
    await _storage.saveBoard(b);
    notifyListeners();
  }

  Future<void> deleteRow(Board b, ExpenseRow row) async {
    b.rows.removeWhere((r) => r.id == row.id);
    await _storage.saveBoard(b);
    notifyListeners();
  }

  Future<void> restoreRow(Board b, ExpenseRow row, int index) async {
    if (index < 0 || index > b.rows.length) {
      b.rows.add(row);
    } else {
      b.rows.insert(index, row);
    }
    b.rows.sort((a, b) => a.date.compareTo(b.date));
    await _storage.saveBoard(b);
    notifyListeners();
  }

  Future<RecurringRowTemplate> addRecurring(
    Board b, {
    required String label,
    required double amount,
    required String category,
    required RecurrenceFrequency frequency,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now();
    // start a day before so first materialization lands on startDate itself
    final initMaterialized = start.subtract(const Duration(days: 1));
    final tpl = RecurringRowTemplate(
      id: _uuid.v4(),
      label: label,
      amount: amount,
      category: category,
      rule: RecurrenceRule(
        frequency: frequency,
        startDate: start,
        endDate: endDate,
        lastMaterialized: initMaterialized,
      ),
    );
    b.recurring.add(tpl);
    await _storage.saveBoard(b);
    notifyListeners();
    return tpl;
  }

  Future<void> deleteRecurring(Board b, RecurringRowTemplate tpl) async {
    b.recurring.removeWhere((t) => t.id == tpl.id);
    // NOTE: materialized rows in b.rows are NOT deleted — they're historical
    // entries the user already saw. Future instances will no longer be added.
    await _storage.saveBoard(b);
    notifyListeners();
  }
}
