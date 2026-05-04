// Design Ref: §3.3 — v4→v5. recurring_rules + budgets 동시 생성.

import 'package:drift/drift.dart';
import '../app_database.dart';

class V4ToV5 {
  const V4ToV5._();

  static Future<void> apply(Migrator m, AppDatabase db) async {
    await m.createTable(db.recurringRules);
    await m.createTable(db.budgets);
  }
}
