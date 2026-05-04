// Design Ref: §4.2 — Budget domain + repo.
// Plan SC: FR-48 — 카테고리별 월 한도 설정.

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    required this.categoryName,
  });
  final int id;
  final int categoryId;
  final int monthlyLimit;
  final String categoryName;
}

class BudgetStatus {
  const BudgetStatus({
    required this.categoryId,
    required this.categoryName,
    required this.spent,
    required this.limit,
  });
  final int categoryId;
  final String categoryName;
  final int spent;
  final int limit;

  double get ratio => limit > 0 ? spent / limit : 0.0;
  bool get isOver => spent > limit;
}

class BudgetRepository {
  BudgetRepository(this._db);
  final AppDatabase _db;

  /// Budget entries joined with category names. Sorted by category sortOrder.
  Stream<List<Budget>> watchAll() {
    return (_db.select(_db.budgets).join([
          innerJoin(
            _db.categories,
            _db.categories.id.equalsExp(_db.budgets.categoryId),
          ),
        ])
          ..orderBy([OrderingTerm.asc(_db.categories.sortOrder)]))
        .watch()
        .map(
          (rows) => rows.map((row) {
            final cat = row.readTable(_db.categories);
            final b = row.readTable(_db.budgets);
            return Budget(
              id: b.id,
              categoryId: cat.id,
              monthlyLimit: b.monthlyLimit,
              categoryName: cat.name,
            );
          }).toList(),
        );
  }

  /// INSERT … ON CONFLICT(category_id) DO UPDATE — UNIQUE category_id constraint.
  Future<void> upsert(int categoryId, int monthlyLimit) =>
      _db.into(_db.budgets).insert(
            BudgetsCompanion.insert(
              categoryId: categoryId,
              monthlyLimit: monthlyLimit,
            ),
            onConflict: DoUpdate(
              (_) => BudgetsCompanion(monthlyLimit: Value(monthlyLimit)),
              target: [_db.budgets.categoryId],
            ),
          );

  Future<void> delete(int categoryId) =>
      (_db.delete(_db.budgets)
            ..where((b) => b.categoryId.equals(categoryId)))
          .go();
}
