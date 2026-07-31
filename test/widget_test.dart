import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:expense_app/models/board.dart';
import 'package:expense_app/theme/app_themes.dart';

void main() {
  group('Board.total + category aggregation', () {
    test('empty board totals zero', () {
      final b = Board(
        id: 'b1',
        name: 'Test',
        themeIndex: 0,
        styleIndex: 0,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(b.total, 0.0);
      expect(b.totalsByCategory(), isEmpty);
    });

    test('sums rows by category', () {
      final b = Board(
        id: 'b1',
        name: 'Test',
        themeIndex: 0,
        styleIndex: 0,
        createdAt: DateTime(2026, 1, 1),
        rows: [
          ExpenseRow(
              id: 'r1',
              label: 'Lunch',
              amount: 12.50,
              category: 'Food',
              createdAt: DateTime(2026, 1, 1)),
          ExpenseRow(
              id: 'r2',
              label: 'Dinner',
              amount: 30.00,
              category: 'Food',
              createdAt: DateTime(2026, 1, 1)),
          ExpenseRow(
              id: 'r3',
              label: 'Train',
              amount: 8.25,
              category: 'Travel',
              createdAt: DateTime(2026, 1, 1)),
        ],
      );
      expect(b.total, 50.75);
      expect(b.totalsByCategory(), {'Food': 42.50, 'Travel': 8.25});
    });
  });

  group('Hive round-trip (regression: newly-constructed boards must persist)',
      () {
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
    });

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

      // First-save path (the bug): box.put() must insert a never-before-seen board.
      await box.put(b.id, b);
      expect(box.values.length, 1,
          reason: 'put() must insert a freshly constructed board');
      expect(box.get(b.id)!.name, 'Persistence Test');

      // Update path (the success path that always worked): mutate then put again.
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
