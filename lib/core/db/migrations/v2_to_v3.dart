// Design Ref: §3.2 — v2→v3 first migration. addColumn(accounts.due_day).
// Idempotent metadata-only change; no data rewrite. M1 데이터 0손실.

import 'package:drift/drift.dart';

import '../app_database.dart';

class V2ToV3 {
  const V2ToV3._();

  /// Adds `accounts.due_day INTEGER NULL`. Safe to run on tables already
  /// containing the column (Drift's [Migrator.addColumn] checks pragma).
  static Future<void> apply(Migrator m, AppDatabase db) async {
    await m.addColumn(db.accounts, db.accounts.dueDay);
  }
}
