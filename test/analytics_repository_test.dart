// Plan SC: FR-46 (계산 정확) — AnalyticsRepository unit tests.
// dailyExpenseMap 6건 + categoryDonut rollup 2건.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/db/app_database.dart';
import 'package:money_tracker_app/features/accounts/domain/account.dart';
import 'package:money_tracker_app/features/analytics/data/analytics_repository.dart';
import 'package:money_tracker_app/features/categories/domain/category.dart';
import 'package:money_tracker_app/features/transactions/domain/transaction.dart';

void main() {
  late AppDatabase db;
  late AnalyticsRepository repo;
  late int bankId;
  late int foodId;
  late int lunchId;
  late int transportId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AnalyticsRepository(db);

    bankId = await db.accountsDao.insertOne(AccountsCompanion.insert(
      name: '신한',
      type: AccountType.cash,
      balance: const Value(1000000),
    ));
    foodId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: '식비',
          kind: CategoryKind.expense,
        ));
    lunchId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: '점심',
          kind: CategoryKind.expense,
          parentCategoryId: Value(foodId),
        ));
    transportId =
        await db.into(db.categories).insert(CategoriesCompanion.insert(
              name: '교통',
              kind: CategoryKind.expense,
            ));
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTx({
    required int amount,
    required DateTime occurredAt,
    int? categoryId,
    TxType type = TxType.expense,
  }) async {
    await db.transactionsDao.insertOne(TransactionsCompanion.insert(
      localId: 'tx-${occurredAt.millisecondsSinceEpoch}-$amount',
      type: type,
      amount: amount,
      categoryId: Value(categoryId),
      fromAccountId: type == TxType.expense ? Value(bankId) : const Value.absent(),
      toAccountId: type == TxType.income ? Value(bankId) : const Value.absent(),
      fromDelta: type == TxType.expense ? Value(-amount) : const Value.absent(),
      toDelta: type == TxType.income ? Value(amount) : const Value.absent(),
      occurredAt: occurredAt,
    ));
  }

  group('dailyExpenseMap', () {
    test('빈 달 → 빈 Map', () async {
      final map = await repo.dailyExpenseMap(month: DateTime(2026, 7));
      expect(map, isEmpty);
    });

    test('단일 날짜 1건 → {day: amount}', () async {
      await insertTx(
        amount: 12000,
        occurredAt: DateTime(2026, 4, 15, 12, 30),
        categoryId: lunchId,
      );
      final map = await repo.dailyExpenseMap(month: DateTime(2026, 4));
      expect(map.length, 1);
      expect(map[DateTime(2026, 4, 15)], 12000);
    });

    test('같은 날짜 여러 건 → sum', () async {
      await insertTx(
        amount: 5000,
        occurredAt: DateTime(2026, 4, 15, 9),
        categoryId: lunchId,
      );
      await insertTx(
        amount: 8000,
        occurredAt: DateTime(2026, 4, 15, 18),
        categoryId: lunchId,
      );
      final map = await repo.dailyExpenseMap(month: DateTime(2026, 4));
      expect(map[DateTime(2026, 4, 15)], 13000);
    });

    test('월 경계 — 이전/다음달 거래 포함 안됨', () async {
      await insertTx(
        amount: 1000,
        occurredAt: DateTime(2026, 3, 31, 23, 59),
        categoryId: lunchId,
      );
      await insertTx(
        amount: 2000,
        occurredAt: DateTime(2026, 4, 15),
        categoryId: lunchId,
      );
      await insertTx(
        amount: 3000,
        occurredAt: DateTime(2026, 5, 1, 0, 0),
        categoryId: lunchId,
      );
      final map = await repo.dailyExpenseMap(month: DateTime(2026, 4));
      expect(map.length, 1);
      expect(map[DateTime(2026, 4, 15)], 2000);
    });

    test('expense 외 type 제외 (income/transfer)', () async {
      await insertTx(
        amount: 5000,
        occurredAt: DateTime(2026, 4, 10),
        categoryId: lunchId,
      );
      await insertTx(
        amount: 100000,
        occurredAt: DateTime(2026, 4, 11),
        categoryId: foodId,
        type: TxType.income,
      );
      final map = await repo.dailyExpenseMap(month: DateTime(2026, 4));
      expect(map.length, 1);
      expect(map[DateTime(2026, 4, 10)], 5000);
      expect(map.containsKey(DateTime(2026, 4, 11)), isFalse);
    });

    test('deletedAt 거래 제외', () async {
      await insertTx(
        amount: 5000,
        occurredAt: DateTime(2026, 4, 5),
        categoryId: lunchId,
      );
      // soft delete via raw DAO method
      final all = await db.transactionsDao.readAll();
      await db.transactionsDao.softDeleteByLocalId(all.first.localId);

      final map = await repo.dailyExpenseMap(month: DateTime(2026, 4));
      expect(map, isEmpty);
    });
  });

  group('categoryDonut rollup', () {
    test('모든 leaf가 대분류 — 기존 동작 유지', () async {
      await insertTx(
        amount: 5000,
        occurredAt: DateTime(2026, 4, 5),
        categoryId: foodId,
      );
      await insertTx(
        amount: 2000,
        occurredAt: DateTime(2026, 4, 6),
        categoryId: transportId,
      );
      final segs = await repo.categoryDonut(month: DateTime(2026, 4));
      expect(segs.length, 2);
      expect(
        segs.firstWhere((s) => s.categoryId == foodId).totalAmount,
        5000,
      );
      expect(
        segs.firstWhere((s) => s.categoryId == transportId).totalAmount,
        2000,
      );
    });

    test('소분류는 부모로 합산 (점심 → 식비 rollup)', () async {
      // 점심 5,000 + 식비 자체 (대분류) 8,000 → 식비 슬라이스 = 13,000
      await insertTx(
        amount: 5000,
        occurredAt: DateTime(2026, 4, 5),
        categoryId: lunchId,
      );
      await insertTx(
        amount: 8000,
        occurredAt: DateTime(2026, 4, 6),
        categoryId: foodId,
      );
      final segs = await repo.categoryDonut(month: DateTime(2026, 4));
      // 모두 식비(부모) 1개 슬라이스
      expect(segs.length, 1);
      expect(segs.first.categoryId, foodId);
      expect(segs.first.categoryName, '식비');
      expect(segs.first.totalAmount, 13000);
    });
  });
}
