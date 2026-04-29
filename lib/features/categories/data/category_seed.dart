// Design Ref: §3.2 categories seed (detail.md §99~106).
// Variable expense / fixed expense / income split. Idempotent.

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../domain/category.dart';
import 'category_repository.dart';

class CategorySeeder {
  CategorySeeder(this._repo);

  final CategoryRepository _repo;

  // Sort blocks: 변동지출 100s · 고정지출 200s · 수입 300s.
  // detail.md §99~106 ordering preserved.
  static const List<({String name, CategoryKind kind, bool isFixed, int sortOrder})>
      _seed = [
    // 변동지출
    (name: '식비',     kind: CategoryKind.expense, isFixed: false, sortOrder: 110),
    (name: '교통',     kind: CategoryKind.expense, isFixed: false, sortOrder: 120),
    (name: '쇼핑',     kind: CategoryKind.expense, isFixed: false, sortOrder: 130),
    (name: '여가',     kind: CategoryKind.expense, isFixed: false, sortOrder: 140),
    (name: '의료',     kind: CategoryKind.expense, isFixed: false, sortOrder: 150),
    (name: '경조사',   kind: CategoryKind.expense, isFixed: false, sortOrder: 160),
    (name: '기타',     kind: CategoryKind.expense, isFixed: false, sortOrder: 190),

    // 고정지출
    (name: '월세/관리비', kind: CategoryKind.expense, isFixed: true, sortOrder: 210),
    (name: '통신비',      kind: CategoryKind.expense, isFixed: true, sortOrder: 220),
    (name: '구독료',      kind: CategoryKind.expense, isFixed: true, sortOrder: 230),
    (name: '보험료',      kind: CategoryKind.expense, isFixed: true, sortOrder: 240),
    (name: '대출이자',    kind: CategoryKind.expense, isFixed: true, sortOrder: 250),

    // 수입
    (name: '급여',     kind: CategoryKind.income,  isFixed: false, sortOrder: 310),
    (name: '이자',     kind: CategoryKind.income,  isFixed: false, sortOrder: 320),
    (name: '배당',     kind: CategoryKind.income,  isFixed: false, sortOrder: 330),
    (name: '환급',     kind: CategoryKind.income,  isFixed: false, sortOrder: 340),
    (name: '기타수입', kind: CategoryKind.income,  isFixed: false, sortOrder: 390),
  ];

  Future<void> run() async {
    for (final item in _seed) {
      await _repo.upsertByName(CategoriesCompanion.insert(
        name: item.name,
        kind: item.kind,
        isFixed: Value(item.isFixed),
        sortOrder: Value(item.sortOrder),
      ));
    }
  }

  static int get seedCount => _seed.length;

  static Iterable<({String name, CategoryKind kind, bool isFixed, int sortOrder})>
      get seedItems => _seed;
}
