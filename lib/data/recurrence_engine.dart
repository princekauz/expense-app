import '../models/board.dart';

/// Pure logic for materializing recurring templates into dated rows.
/// Called by BoardProvider on app open and when the user pulls to refresh.
class RecurrenceEngine {
  /// For each recurring template in the board, append generated ExpenseRows
  /// for dates that have passed but weren't yet materialized (up to and
  /// including [now]).
  ///
  /// Mutates [board.recurring] (advances lastMaterialized) and [board.rows]
  /// (appends new instances). Caller is responsible for persisting the board.
  static int materialize(Board board, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    var added = 0;
    for (final tpl in board.recurring) {
      final due = tpl.rule.dueDatesBetween(tpl.rule.lastMaterialized, today);
      for (final d in due) {
        board.rows.add(ExpenseRow(
          id: '${tpl.id}_${d.toIso8601String()}',
          label: tpl.label,
          amount: tpl.amount,
          category: tpl.category,
          createdAt: now ?? DateTime.now(),
          date: d,
          fromRecurringId: tpl.id,
        ));
        added++;
      }
      tpl.rule.lastMaterialized = today;
    }
    return added;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
