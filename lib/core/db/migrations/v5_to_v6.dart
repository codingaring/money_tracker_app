// Design Ref: §3.3 — v5→v6. recurring_rules에 recurrence_type + day_of_week 추가.

import 'package:drift/drift.dart';
import '../app_database.dart';

class V5ToV6 {
  const V5ToV6._();

  static Future<void> apply(Migrator m, AppDatabase db) async {
    await m.addColumn(db.recurringRules, db.recurringRules.recurrenceType);
    await m.addColumn(db.recurringRules, db.recurringRules.dayOfWeek);
  }
}
