// Design Ref: §3.3 — v3→v4 마이그레이션. 두 변경 동시 적용.
// (1) tx_templates 테이블 신규 (createTable)
// (2) categories.parent_category_id 컬럼 추가 (addColumn)
//
// 기존 17개 카테고리는 모두 parent_category_id = NULL = 대분류로 시작.
// 사용자가 카테고리 관리 화면에서 소분류를 추가할 때까지 동작은 v3와 동일.

import 'package:drift/drift.dart';

import '../app_database.dart';

class V3ToV4 {
  const V3ToV4._();

  /// Idempotent — Drift's createTable/addColumn skip if the table/column
  /// already exists (PRAGMA table_info check).
  static Future<void> apply(Migrator m, AppDatabase db) async {
    await m.createTable(db.txTemplates);
    await m.addColumn(db.categories, db.categories.parentCategoryId);
  }
}
