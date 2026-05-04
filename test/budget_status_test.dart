// Plan SC: FR-48 — BudgetStatus 순수 함수 단위 테스트 3건.

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/features/analytics/data/budget_repository.dart';

void main() {
  group('BudgetStatus.ratio / isOver', () {
    test('spent 350k / limit 500k → ratio 0.7, not over', () {
      const s = BudgetStatus(
        categoryId: 1,
        categoryName: 'test',
        spent: 350000,
        limit: 500000,
      );
      expect(s.ratio, closeTo(0.7, 0.0001));
      expect(s.isOver, isFalse);
    });

    test('spent 105k / limit 100k → ratio 1.05, over', () {
      const s = BudgetStatus(
        categoryId: 1,
        categoryName: 'test',
        spent: 105000,
        limit: 100000,
      );
      expect(s.ratio, closeTo(1.05, 0.0001));
      expect(s.isOver, isTrue);
    });

    test('spent 0 / limit 0 → ratio 0.0 (zero division guard)', () {
      const s = BudgetStatus(
        categoryId: 1,
        categoryName: 'test',
        spent: 0,
        limit: 0,
      );
      expect(s.ratio, 0.0);
      expect(s.isOver, isFalse);
    });
  });
}
