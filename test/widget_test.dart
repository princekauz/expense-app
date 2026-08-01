import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:expense_app/data/recurrence_engine.dart';
import 'package:expense_app/models/board.dart';
import 'package:expense_app/theme/app_themes.dart';

void main() {
  Board makeBoard({
    List<ExpenseRow>? rows,
    List<RecurringRowTemplate>? recurring,
    double? budget,
  }) {
    return Board(
      id: 'b1',
      name: 'Test',
      themeIndex: 0,
      styleIndex: 0,
      createdAt: DateTime(2026, 1, 1),
      rows: rows,
      recurring: recurring,
      budget: budget,
    );
  }

  ExpenseRow row(String id, double amount, DateTime date,
      {String category = 'Food'}) {
    return ExpenseRow(
      id: id,
      label: 'item-$id',
      amount: amount,
      category: category,
      createdAt: date,
      date: date,
    );
  }

  group('Board.total + category aggregation', () {
    test('empty board totals zero', () {
      final b = makeBoard();
      expect(b.total, 0.0);
      expect(b.realizedTotal, 0.0);
      expect(b.plannedTotal, 0.0);
      expect(b.totalsByCategory(), isEmpty);
    });

    test('sums rows by category and separates realized vs planned', () {
      final now = DateTime.now();
      // midnight today so the row is not after today's 00:00
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final yesterday = today.subtract(const Duration(days: 1));
      final b = makeBoard(
        rows: [
          row('r1', 12.50, yesterday),
          row('r2', 30.00, today),
          row('r3', 8.25, tomorrow),
        ],
      );
      expect(b.total, 50.75);
      expect(b.realizedTotal, 42.50);
      expect(b.plannedTotal, 8.25);
      expect(b.totalsByCategory(), {'Food': 50.75});
    });
  });

  group('Budget threshold helpers', () {
    test('0% to 80% is safe', () {
      final b = makeBoard(
        rows: [row('a', 40, DateTime.now().subtract(const Duration(days: 1)))],
        budget: 100,
      );
      expect(b.realizedTotal / b.budget!, 0.4);
    });
    test('exactly 80% is the warning boundary', () {
      final b = makeBoard(
        rows: [row('a', 80, DateTime.now().subtract(const Duration(days: 1)))],
        budget: 100,
      );
      expect(b.realizedTotal / b.budget!, 0.8);
    });
    test('100%+ is over budget', () {
      final b = makeBoard(
        rows: [row('a', 150, DateTime.now().subtract(const Duration(days: 1)))],
        budget: 100,
      );
      expect(b.realizedTotal > b.budget!, isTrue);
    });
  });

  group('RecurrenceEngine.materialize', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tmp = await Directory.systemTemp.createTemp('expense_test_');
      Hive.init(tmp.path);
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(BoardAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ExpenseRowAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(RecurrenceFrequencyAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(RecurrenceRuleAdapter());
      }
    });

    test('daily rule over 3 days produces 3 rows, idempotent on rerun', () {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 3));
      final b = makeBoard(
        recurring: [
          RecurringRowTemplate(
            id: 'coffee',
            label: 'Coffee',
            amount: 5,
            category: 'Food',
            rule: RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
              startDate: start,
              lastMaterialized: start.subtract(const Duration(days: 1)),
            ),
          ),
        ],
      );

      final added1 = RecurrenceEngine.materialize(b, now: now);
      expect(added1, 4, reason: '4 days inclusive of start..today');
      expect(b.rows.length, 4);
      expect(b.rows.every((r) => r.label == 'Coffee'), isTrue);

      // Re-run — no new rows because lastMaterialized is now `today`.
      final added2 = RecurrenceEngine.materialize(b, now: now);
      expect(added2, 0);
      expect(b.rows.length, 4);
    });

    test('weekly rule only fires on matching weekday', () {
      final now = DateTime.now();
      final mondayLastWeek = now.subtract(Duration(days: now.weekday + 6));
      final b = makeBoard(
        recurring: [
          RecurringRowTemplate(
            id: 'gym',
            label: 'Gym',
            amount: 20,
            category: 'Bills',
            rule: RecurrenceRule(
              frequency: RecurrenceFrequency.weekly,
              startDate: mondayLastWeek,
              lastMaterialized:
                  mondayLastWeek.subtract(const Duration(days: 1)),
            ),
          ),
        ],
      );
      final added = RecurrenceEngine.materialize(b, now: now);
      expect(added, greaterThanOrEqualTo(1));
      expect(b.rows.every((r) => r.date.weekday == DateTime.monday), isTrue);
    });
  });

  group('Hive round-trip (regression: newly-constructed boards must persist)',
      () {
    test('Box.put() inserts AND updates — the fix for "create does nothing"',
        () async {
      final box = await Hive.openBox<Board>('boards_regression');
      await box.clear();

      final b = Board(
        id: 'regression-1',
        name: 'Persistence Test',
        themeIndex: 0,
        styleIndex: 0,
        createdAt: DateTime(2026, 1, 1),
      );

      await box.put(b.id, b);
      expect(box.values.length, 1,
          reason: 'put() must insert a freshly constructed board');
      expect(box.get(b.id)!.name, 'Persistence Test');

      b.name = 'Renamed';
      await box.put(b.id, b);
      expect(box.values.length, 1,
          reason: 'put() with same key updates, not inserts');
      expect(box.get(b.id)!.name, 'Renamed');

      await box.close();
    });
  });

  group('AppThemes', () {
    test('six themes defined', () {
      expect(AppThemes.all.length, 6);
    });

    test('byIndex clamps to valid range', () {
      expect(AppThemes.byIndex(-1).name, AppThemes.all.first.name);
      expect(AppThemes.byIndex(99).name, AppThemes.all.last.name);
    });

    test('BoardStyle has 3 entries with labels', () {
      expect(BoardStyle.values.length, 3);
      expect(BoardStyle.ruled.label, 'Ruled');
      expect(BoardStyle.boxed.label, 'Boxed');
      expect(BoardStyle.minimal.label, 'Minimal');
    });

    test('AppCategories has presets', () {
      expect(AppCategories.presets,
          containsAll(['Food', 'Travel', 'Bills', 'Shopping', 'Other']));
    });
  });
}
