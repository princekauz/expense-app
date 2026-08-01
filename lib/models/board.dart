import 'package:hive/hive.dart';

part 'board.g.dart';

/// Frequency of a recurring row.
@HiveType(typeId: 3)
enum RecurrenceFrequency {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
  @HiveField(2)
  monthly,
  @HiveField(3)
  weekdays,
  @HiveField(4)
  weekends,
}

@HiveType(typeId: 4)
class RecurrenceRule extends HiveObject {
  @HiveField(0)
  RecurrenceFrequency frequency;

  /// Anchor date — the rule fires on this date and every period after.
  @HiveField(1)
  DateTime startDate;

  /// Optional end date. Null = runs forever.
  @HiveField(2)
  DateTime? endDate;

  /// Last date we materialized up to. Prevents duplicates on subsequent opens.
  @HiveField(3)
  DateTime lastMaterialized;

  RecurrenceRule({
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.lastMaterialized,
  });

  bool _matchesDay(DateTime d) {
    if (endDate != null && d.isAfter(endDate!)) return false;
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return true;
      case RecurrenceFrequency.weekly:
        return d.weekday == startDate.weekday;
      case RecurrenceFrequency.monthly:
        return d.day == startDate.day;
      case RecurrenceFrequency.weekdays:
        return d.weekday >= DateTime.monday && d.weekday <= DateTime.friday;
      case RecurrenceFrequency.weekends:
        return d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
    }
  }

  /// All dates in [from..to] inclusive that this rule fires on, after lastMaterialized.
  List<DateTime> dueDatesBetween(DateTime from, DateTime to) {
    final out = <DateTime>[];
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    // start at max(from, lastMaterialized + 1, startDate)
    var cursor = start.isAfter(lastMaterialized)
        ? start
        : DateTime(lastMaterialized.year, lastMaterialized.month,
                lastMaterialized.day)
            .add(const Duration(days: 1));
    if (cursor.isBefore(startDate)) {
      cursor = DateTime(startDate.year, startDate.month, startDate.day);
    }
    while (!cursor.isAfter(end)) {
      if (_matchesDay(cursor)) out.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return out;
  }
}

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

  /// Optional budget cap. Null = no budget.
  @HiveField(7)
  double? budget;

  /// Recurring row templates — materialize into [rows] over time.
  @HiveField(8)
  List<RecurringRowTemplate> recurring;

  Board({
    required this.id,
    required this.name,
    required this.themeIndex,
    required this.styleIndex,
    required this.createdAt,
    List<ExpenseRow>? rows,
    this.note,
    this.budget,
    List<RecurringRowTemplate>? recurring,
  })  : rows = rows ?? <ExpenseRow>[],
        recurring = recurring ?? <RecurringRowTemplate>[];

  double get total => rows.fold(0.0, (sum, r) => sum + r.amount);

  /// Total of past/today rows only (excludes future-planned).
  double get realizedTotal {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return rows
        .where((r) => !r.date.isAfter(today))
        .fold(0.0, (s, r) => s + r.amount);
  }

  /// Total of future-dated rows only.
  double get plannedTotal {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return rows
        .where((r) => r.date.isAfter(today))
        .fold(0.0, (s, r) => s + r.amount);
  }

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

  /// Date this expense is for. Defaults to createdAt.
  /// Future = planned/scheduled. Past = backdated. Today = current.
  @HiveField(5)
  DateTime date;

  /// If this row was generated from a recurring template, the template id.
  /// Used so deleting the template can offer to also delete future instances.
  @HiveField(6)
  String? fromRecurringId;

  ExpenseRow({
    required this.id,
    required this.label,
    required this.amount,
    required this.category,
    required this.createdAt,
    required this.date,
    this.fromRecurringId,
  });

  bool get isFuture {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isAfter(today);
  }

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

/// A template that generates ExpenseRow instances according to [RecurrenceRule].
class RecurringRowTemplate {
  final String id;
  final String label;
  final double amount;
  final String category;
  final RecurrenceRule rule;

  RecurringRowTemplate({
    required this.id,
    required this.label,
    required this.amount,
    required this.category,
    required this.rule,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'category': category,
        'rule': {
          'frequency': rule.frequency.name,
          'startDate': rule.startDate.toIso8601String(),
          'endDate': rule.endDate?.toIso8601String(),
          'lastMaterialized': rule.lastMaterialized.toIso8601String(),
        },
      };
}
