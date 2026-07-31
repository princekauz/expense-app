import 'package:hive_flutter/hive_flutter.dart';
import '../models/board.dart';

class StorageService {
  static const String boardsBoxName = 'boards';
  static const String settingsBoxName = 'settings';

  late Box<Board> boardsBox;
  late Box settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(BoardAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ExpenseRowAdapter());
    }
    boardsBox = await Hive.openBox<Board>(boardsBoxName);
    settingsBox = await Hive.openBox(settingsBoxName);
  }

  List<Board> getAllBoards() {
    final list = boardsBox.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveBoard(Board board) async {
    await board.save();
  }

  Future<void> deleteBoard(Board board) async {
    await board.delete();
  }

  // settings
  int getThemeIndex() => settingsBox.get('themeIndex', defaultValue: 0) as int;
  Future<void> setThemeIndex(int v) async => settingsBox.put('themeIndex', v);

  String getCurrency() => settingsBox.get('currency', defaultValue: 'USD') as String;
  Future<void> setCurrency(String c) async => settingsBox.put('currency', c);
}
