import 'package:hive/hive.dart';

part 'board.g.dart';

@HiveType(typeId: 1)
class Board extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int themeIndex;

  @HiveField(3)
  int styleIndex;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  List<ExpenseRow> rows;

  @HiveField(6)
  String? note;

  Board({
    required this.id,
    required this.name,
    required this.themeIndex,
    required this.styleIndex,
    required this.createdAt,
    List<ExpenseRow>? rows,
    this.note,
  }) : rows = rows ?? <ExpenseRow>[];

  double get total => rows.fold(0.0, (sum, r) => sum + r.amount);

  Map<String, double> totalsByCategory() {
    final map = <String, double>{};
    for (final r in rows) {
      map[r.category] = (map[r.category] ?? 0) + r.amount;
    }
    return map;
  }
}

@HiveType(typeId: 2)
class ExpenseRow extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String label;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String category;

  @HiveField(4)
  DateTime createdAt;

  ExpenseRow({
    required this.id,
    required this.label,
    required this.amount,
    required this.category,
    required this.createdAt,
  });
}
