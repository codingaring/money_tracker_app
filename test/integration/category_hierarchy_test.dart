// Plan SC: FR-53 — Category hierarchy 통합 테스트 4건.
// listTopLevel / listChildren / setParent (순환 방지) / ON DELETE SET NULL.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/db/app_database.dart';
import 'package:money_tracker_app/features/categories/data/category_repository.dart';
import 'package:money_tracker_app/features/categories/domain/category.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('listTopLevel returns parent NULL only, filtered by kind', () async {
    final foodId = await repo.create(name: '식비', kind: CategoryKind.expense);
    final transportId =
        await repo.create(name: '교통', kind: CategoryKind.expense);
    final salaryId = await repo.create(name: '급여', kind: CategoryKind.income);
    // child of 식비
    await repo.create(
      name: '점심',
      kind: CategoryKind.expense,
      parentCategoryId: foodId,
    );

    final expenseTops = await repo.listTopLevel(kind: CategoryKind.expense);
    expect(expenseTops.map((c) => c.id), containsAll([foodId, transportId]));
    expect(expenseTops.map((c) => c.name), isNot(contains('점심')));
    expect(expenseTops.map((c) => c.name), isNot(contains('급여')));

    final incomeTops = await repo.listTopLevel(kind: CategoryKind.income);
    expect(incomeTops.map((c) => c.id), [salaryId]);
  });

  test('listChildren returns only children of given parent', () async {
    final foodId = await repo.create(name: '식비', kind: CategoryKind.expense);
    final transportId =
        await repo.create(name: '교통', kind: CategoryKind.expense);
    final lunchId = await repo.create(
      name: '점심',
      kind: CategoryKind.expense,
      parentCategoryId: foodId,
    );
    final dinnerId = await repo.create(
      name: '저녁',
      kind: CategoryKind.expense,
      parentCategoryId: foodId,
    );
    // 다른 부모의 자식
    await repo.create(
      name: '대중교통',
      kind: CategoryKind.expense,
      parentCategoryId: transportId,
    );

    final foodChildren = await repo.listChildren(foodId);
    expect(foodChildren.map((c) => c.id), containsAll([lunchId, dinnerId]));
    expect(foodChildren.length, 2);
    expect(foodChildren.map((c) => c.name), isNot(contains('대중교통')));
  });

  test('setParent — 자기 자신 부모 지정 거부 + 2-level 강제', () async {
    final foodId = await repo.create(name: '식비', kind: CategoryKind.expense);
    final lunchId = await repo.create(
      name: '점심',
      kind: CategoryKind.expense,
      parentCategoryId: foodId,
    );

    // 자기 자신을 부모로
    expect(
      () => repo.setParent(foodId, foodId),
      throwsA(isA<ArgumentError>()),
    );

    // 2-level 강제 — 점심(소분류)을 식비의 부모로 시도하면 거부
    // (점심이 본인이 leaf니까 부모 후보 자격 없음)
    expect(
      () => repo.setParent(foodId, lunchId),
      throwsA(isA<StateError>()),
    );

    // 정상 — 점심을 다른 대분류로 옮기기
    final newTopId = await repo.create(name: '외식', kind: CategoryKind.expense);
    await repo.setParent(lunchId, newTopId);
    final updated = await repo.findById(lunchId);
    expect(updated?.parentCategoryId, newTopId);
  });

  test('ON DELETE SET NULL — 부모 삭제 시 자식이 대분류로 승격', () async {
    final foodId = await repo.create(name: '식비', kind: CategoryKind.expense);
    final lunchId = await repo.create(
      name: '점심',
      kind: CategoryKind.expense,
      parentCategoryId: foodId,
    );

    // 식비 삭제
    await repo.deleteById(foodId);

    // 점심은 살아있되, parent_category_id가 NULL이 됨 (= 대분류로 승격)
    final lunch = await repo.findById(lunchId);
    expect(lunch, isNotNull);
    expect(lunch!.parentCategoryId, isNull);

    // listTopLevel에서 점심이 보임
    final tops = await repo.listTopLevel(kind: CategoryKind.expense);
    expect(tops.map((c) => c.id), contains(lunchId));
  });
}
