// Plan SC: FR-45 — TemplateRepository 통합 테스트 4건.
// In-memory Drift로 CRUD + markUsed 동작 검증.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/db/app_database.dart';
import 'package:money_tracker_app/features/templates/data/template_repository.dart';
import 'package:money_tracker_app/features/templates/data/templates_dao.dart';
import 'package:money_tracker_app/features/transactions/domain/transaction.dart';

void main() {
  late AppDatabase db;
  late TemplateRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TemplateRepository(dao: TemplatesDao(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('create — row inserted with auto timestamps', () async {
    final t = await repo.create(
      name: '월세',
      type: TxType.expense,
      amount: 650000,
      memo: '자동이체',
    );
    expect(t.name, '월세');
    expect(t.type, TxType.expense);
    expect(t.amount, 650000);
    expect(t.memo, '자동이체');
    expect(t.createdAt, isNotNull);
    expect(t.updatedAt, isNotNull);
    expect(t.lastUsedAt, isNull); // 사용 전이라 NULL
  });

  test('update — clearAmount sets amount to NULL, updatedAt 갱신', () async {
    final original = await repo.create(
      name: '통신비',
      type: TxType.expense,
      amount: 80000,
    );
    final originalUpdatedAt = original.updatedAt;

    // 시간 흐름이 보이도록 약간 대기 (epoch 초 단위라 1초 충분).
    await Future<void>.delayed(const Duration(seconds: 1));

    await repo.update(
      original.id,
      name: '통신비 (변동)',
      clearAmount: true,
    );

    final updated = await db.templatesDao.findById(original.id);
    expect(updated, isNotNull);
    expect(updated!.name, '통신비 (변동)');
    expect(updated.amount, isNull);
    expect(updated.updatedAt.isAfter(originalUpdatedAt), isTrue);
  });

  test('markUsed — lastUsedAt 자동 set + updatedAt 갱신', () async {
    final t = await repo.create(
      name: '구독료',
      type: TxType.expense,
      amount: 14900,
    );
    expect(t.lastUsedAt, isNull);

    await repo.markUsed(t.id);

    final after = await db.templatesDao.findById(t.id);
    expect(after, isNotNull);
    expect(after!.lastUsedAt, isNotNull);
    // markUsed는 strftime('%s','now') 사용 — DateTime이 이번 초 안에 있어야 함.
    final now = DateTime.now();
    final diff = now.difference(after.lastUsedAt!).inSeconds.abs();
    expect(diff, lessThan(5)); // 5초 이내
  });

  test('delete — row 제거 + readAll에서 사라짐', () async {
    final t = await repo.create(
      name: '임시',
      type: TxType.income,
      amount: 1000,
    );
    expect(await repo.readAll(), isNotEmpty);

    await repo.delete(t.id);

    expect(await repo.readAll(), isEmpty);
    expect(await db.templatesDao.findById(t.id), isNull);
  });
}
