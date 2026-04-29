// Design Ref: §2.1, Module-1 — Categories has no separate DAO (small surface).
// CategoryRepository is a thin wrapper over AppDatabase select/insert.
//
// M3 Design Ref: §4.6 — hierarchy 메서드 추가
// (listTopLevel/listChildren/setParent/reorder).

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../domain/category.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  Future<List<Category>> listAll({CategoryKind? kind}) =>
      _buildAllQuery(kind: kind).get();

  /// 변경(create/update/delete/reorder)이 발생하면 자동으로 다시 emit.
  /// CategoryPicker / CategoriesScreen / FilterChip 모두 이 stream 기반.
  Stream<List<Category>> watchAll({CategoryKind? kind}) =>
      _buildAllQuery(kind: kind).watch();

  /// Plan SC: FR-48 — 대분류만 (parent_category_id IS NULL).
  /// CategoryPicker 1단 chip + CategoryFormSheet 부모 dropdown에 사용.
  Future<List<Category>> listTopLevel({CategoryKind? kind}) =>
      _buildTopLevelQuery(kind: kind).get();

  Stream<List<Category>> watchTopLevel({CategoryKind? kind}) =>
      _buildTopLevelQuery(kind: kind).watch();

  /// Plan SC: FR-48 — 특정 부모의 자식들. CategoryPicker 2단 chip에 사용.
  Future<List<Category>> listChildren(int parentId) =>
      _buildChildrenQuery(parentId).get();

  Stream<List<Category>> watchChildren(int parentId) =>
      _buildChildrenQuery(parentId).watch();

  // ── Query builders (shared between Future/Stream variants) ──────────────────
  $CategoriesTable get _categories => _db.categories;

  SimpleSelectStatement<$CategoriesTable, Category> _buildAllQuery({
    CategoryKind? kind,
  }) {
    final query = _db.select(_categories);
    if (kind != null) {
      query.where((c) => c.kind.equalsValue(kind));
    }
    query.orderBy([
      (c) => OrderingTerm.asc(c.sortOrder),
      (c) => OrderingTerm.asc(c.name),
    ]);
    return query;
  }

  SimpleSelectStatement<$CategoriesTable, Category> _buildTopLevelQuery({
    CategoryKind? kind,
  }) {
    final query = _db.select(_categories)
      ..where((c) => c.parentCategoryId.isNull());
    if (kind != null) {
      query.where((c) => c.kind.equalsValue(kind));
    }
    query.orderBy([
      (c) => OrderingTerm.asc(c.sortOrder),
      (c) => OrderingTerm.asc(c.name),
    ]);
    return query;
  }

  SimpleSelectStatement<$CategoriesTable, Category> _buildChildrenQuery(
      int parentId) {
    return _db.select(_categories)
      ..where((c) => c.parentCategoryId.equals(parentId))
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.name),
      ]);
  }

  Future<Category?> findById(int id) {
    return (_db.select(_db.categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Category?> findByName(String name) {
    return (_db.select(_db.categories)..where((c) => c.name.equals(name)))
        .getSingleOrNull();
  }

  /// Plan SC: FR-48 — 부모 지정 (NULL 가능 — 대분류로 승격).
  /// 순환 방지: 후보 부모가 자기 자신이거나 이미 자기 자손이면 거부.
  /// 2-level 강제: 후보 부모는 parentCategoryId가 NULL이어야 함 (즉, 대분류만
  /// 부모가 될 수 있음). 이로써 grandchild 자동 차단.
  Future<void> setParent(int id, int? parentId) async {
    if (parentId != null) {
      if (parentId == id) {
        throw ArgumentError('자기 자신을 부모로 지정할 수 없습니다');
      }
      final candidate = await findById(parentId);
      if (candidate == null) {
        throw ArgumentError('부모 카테고리가 존재하지 않습니다: $parentId');
      }
      // 2-level 강제 — 후보 부모는 본인이 대분류여야 함.
      if (candidate.parentCategoryId != null) {
        throw StateError(
            '2-level만 지원합니다. 부모는 대분류(parent NULL)만 가능');
      }
    }
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(parentCategoryId: Value(parentId)),
    );
  }

  /// Plan SC: FR-48 — drag-reorder 후 호출. sortOrder 10단위로 부여.
  Future<void> reorder(List<int> idsInOrder) async {
    await _db.transaction(() async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await (_db.update(_db.categories)
              ..where((c) => c.id.equals(idsInOrder[i])))
            .write(CategoriesCompanion(sortOrder: Value(i * 10)));
      }
    });
  }

  Future<int> create({
    required String name,
    required CategoryKind kind,
    bool isFixed = false,
    int? parentCategoryId,
    int sortOrder = 0,
  }) {
    return _db.into(_db.categories).insert(CategoriesCompanion.insert(
          name: name,
          kind: kind,
          isFixed: Value(isFixed),
          sortOrder: Value(sortOrder),
          parentCategoryId: Value(parentCategoryId),
        ));
  }

  Future<void> updateMeta(
    int id, {
    String? name,
    bool? isFixed,
  }) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        isFixed: isFixed == null ? const Value.absent() : Value(isFixed),
      ),
    );
  }

  Future<int> deleteById(int id) {
    return (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  /// Returns the inserted row's id, or the existing id if [name] already exists.
  /// Idempotent — used by [CategorySeeder].
  Future<int> upsertByName(CategoriesCompanion data) async {
    final existing = await findByName(data.name.value);
    if (existing != null) return existing.id;
    return _db.into(_db.categories).insert(data);
  }
}
