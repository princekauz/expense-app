import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/recurrence_engine.dart';
import '../data/storage_service.dart';
import '../models/board.dart';
import '../util/app_log.dart';

class BoardProvider extends ChangeNotifier {
  BoardProvider(this._storage) {
    _boards = _storage.getAllBoards();
    AppLog.instance.log('BoardProvider init: loaded ${_boards.length} boards',
        tag: 'provider');
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

  /// Re-read a board from the box (so we hold the canonical, freshly-deserialized
  /// instance) and splice it into [_boards] in place of the old reference.
  ///
  /// This is required because Hive's `box.put()` can internally invalidate the
  /// boxed object reference on some Hive versions — the in-memory object we
  /// mutated is no longer the same object the box stores. Without this,
  /// subsequent reads of `provider.boards` would still return the stale instance.
  Board _reloadAndSplice(String id) {
    final fresh = _storage.boardsBox.get(id);
    if (fresh == null) {
      // Defensive: board was deleted under us — drop the in-memory copy too.
      _boards.removeWhere((b) => b.id == id);
      throw StateError('Board $id vanished from storage');
    }
    final idx = _boards.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      _boards[idx] = fresh;
    } else {
      _boards.add(fresh);
      _boards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return fresh;
  }

  void _materializeAll() {
    var any = false;
    for (final b in _boards) {
      if (b.recurring.isNotEmpty) {
        final added = RecurrenceEngine.materialize(b);
        if (added > 0) any = true;
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
    _reloadAndSplice(b.id);
    notifyListeners();
  }

  Future<void> setBoardTheme(Board b, int themeIndex, int styleIndex) async {
    b.themeIndex = themeIndex;
    b.styleIndex = styleIndex;
    try {
      await _storage.saveBoard(b);
      final fresh = _reloadAndSplice(b.id); // ignore: unused_local_variable
      AppLog.instance.log(
          'setBoardTheme: theme=$themeIndex style=$styleIndex b===fresh?=\${identical(b, fresh)} fresh.themeIndex=\${fresh.themeIndex}',
          tag: 'provider');
      notifyListeners();
    } catch (e) {
      AppLog.instance.log('setBoardTheme FAILED: \$e',
          level: LogLevel.error, tag: 'provider');
      rethrow;
    }
  }

  Future<void> setBoardBudget(Board b, double? budget) async {
    b.budget = budget;
    await _storage.saveBoard(b);
    _reloadAndSplice(b.id);
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
    _reloadAndSplice(b.id);
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
    _reloadAndSplice(b.id);
    notifyListeners();
  }

  Future<void> deleteRow(Board b, ExpenseRow row) async {
    b.rows.removeWhere((r) => r.id == row.id);
    await _storage.saveBoard(b);
    _reloadAndSplice(b.id);
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
    _reloadAndSplice(b.id);
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
    AppLog.instance.log(
        'addRecurring: pre-save board.b.id=${b.id} recurring.count=${b.recurring.length} b.hashCode=${b.hashCode}',
        tag: 'provider');
    try {
      await _storage.saveBoard(b);
      final fresh = _reloadAndSplice(b.id);
      AppLog.instance.log(
          'addRecurring: post-splice fresh.recurring.count=${fresh.recurring.length} fresh.hashCode=${fresh.hashCode} b===fresh?=${identical(b, fresh)}',
          tag: 'provider');
      notifyListeners();
    } catch (e) {
      AppLog.instance.log('addRecurring FAILED: \$e',
          level: LogLevel.error, tag: 'provider');
      rethrow;
    }
    return tpl;
  }

  Future<void> deleteRecurring(Board b, RecurringRowTemplate tpl) async {
    b.recurring.removeWhere((t) => t.id == tpl.id);
    // NOTE: materialized rows in b.rows are NOT deleted — they're historical
    // entries the user already saw. Future instances will no longer be added.
    await _storage.saveBoard(b);
    _reloadAndSplice(b.id);
    notifyListeners();
  }
}
