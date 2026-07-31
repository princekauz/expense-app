import 'package:flutter_test/flutter_test.dart';

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
