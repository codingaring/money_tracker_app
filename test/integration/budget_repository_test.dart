import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/db/app_database.dart';
import 'package:money_tracker_app/features/analytics/data/budget_repository.dart';
import 'package:money_tracker_app/features/categories/domain/category.dart';

Future<int> _insertCategory(AppDatabase db, String name) => db
    .into(db.categories)
    .insert(CategoriesCompanion.insert(name: name, kind: CategoryKind.expense));

void main() {
  late AppDatabase db;
  late BudgetRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BudgetRepository(db);
  });

  tearDown(() async => db.close());

  test('upsert → watchAll returns 1 Budget with correct limit', () async {
    final catId = await _insertCategory(db, '식비');
    await repo.upsert(catId, 500000);

    final budgets = await repo.watchAll().first;
    expect(budgets, hasLength(1));
    expect(budgets[0].categoryId, catId);
    expect(budgets[0].monthlyLimit, 500000);
  });

  test('double upsert same categoryId → 1 row, limit updated', () async {
    final catId = await _insertCategory(db, '교통비');
    await repo.upsert(catId, 100000);
    await repo.upsert(catId, 200000);

    final budgets = await repo.watchAll().first;
    expect(budgets, hasLength(1));
    expect(budgets[0].monthlyLimit, 200000);
  });
}
