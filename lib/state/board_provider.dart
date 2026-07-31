import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/storage_service.dart';
import '../models/board.dart';

class BoardProvider extends ChangeNotifier {
  BoardProvider(this._storage) {
    _boards = _storage.getAllBoards();
  }

  final StorageService _storage;
  final _uuid = const Uuid();

  List<Board> _boards = [];
  List<Board> get boards => List.unmodifiable(_boards);

  void refresh() {
    _boards = _storage.getAllBoards();
    notifyListeners();
  }

  Future<Board> createBoard(
      {required String name, int themeIndex = 0, int styleIndex = 0}) async {
    final b = Board(
      id: _uuid.v4(),
      name: name,
      themeIndex: themeIndex,
      styleIndex: styleIndex,
      createdAt: DateTime.now(),
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

  Future<void> deleteBoard(Board b) async {
    await _storage.deleteBoard(b);
    refresh();
  }

  Future<ExpenseRow> addRow(Board b,
      {required String label,
      required double amount,
      required String category}) async {
    final r = ExpenseRow(
      id: _uuid.v4(),
      label: label,
      amount: amount,
      category: category,
      createdAt: DateTime.now(),
    );
    b.rows.add(r);
    await _storage.saveBoard(b);
    notifyListeners();
    return r;
  }

  Future<void> updateRow(Board b, ExpenseRow row,
      {String? label, double? amount, String? category}) async {
    if (label != null) row.label = label;
    if (amount != null) row.amount = amount;
    if (category != null) row.category = category;
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
    await _storage.saveBoard(b);
    notifyListeners();
  }
}
